import SwiftUI

struct AnalysisView: View {
    @Bindable var viewModel: AnalysisViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Original image
                imageSection

                if let translation = viewModel.translation {
                    translationSection(translation)
                } else if viewModel.isTranslationLoading {
                    translationLoadingSection
                } else if viewModel.showTranslationUnavailable {
                    translationUnavailableSection
                }

                // Grammar legend
                GrammarLegendView()
                    .padding(.horizontal)

                // Tokenized words grid
                tokenGridSection
            }
        }
        .navigationTitle("Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let token = viewModel.selectedToken {
                WordPopoverView(
                    token: token,
                    sourceText: viewModel.result.recognizedText,
                    sourceImage: viewModel.result.originalImage,
                    onDismiss: { viewModel.selectedToken = nil }
                )
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: viewModel.selectedToken?.id)
            }
        }
    }

    // MARK: - Sections

    private var imageSection: some View {
        Image(uiImage: viewModel.result.originalImage)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
    }

    private func translationSection(_ translation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(translation)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }

    private var translationLoadingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)

                Text("Translating...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }

    private var translationUnavailableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text("Translation unavailable.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }

    private var tokenGridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Words")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            FlowLayout(spacing: 6) {
                ForEach(viewModel.words) { token in
                    TokenChipView(
                        token: token,
                        isSelected: viewModel.selectedToken?.id == token.id
                    ) {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.selectToken(token)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Token Chip

private struct TokenChipView: View {
    let token: Token
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            if !token.reading.isEmpty && token.reading != token.surface {
                Text(token.reading)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Text(token.surface)
                    .font(.callout)
                if let level = token.jlptLevel {
                    Text("N\(level)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected
            ? GrammarHighlighter.color(for: token.partOfSpeech).opacity(0.2)
            : GrammarHighlighter.backgroundColor(for: token.partOfSpeech)
        )
        .foregroundStyle(GrammarHighlighter.color(for: token.partOfSpeech))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? GrammarHighlighter.color(for: token.partOfSpeech) : .clear,
                    lineWidth: 2
                )
        )
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Tap to view definition and grammar details")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if !token.reading.isEmpty && token.reading != token.surface {
            parts.append("\(token.surface), read as \(token.reading)")
        } else {
            parts.append(token.surface)
        }
        parts.append(token.partOfSpeech.displayName)
        if let level = token.jlptLevel {
            parts.append("JLPT N\(level)")
        }
        if let first = token.definitions.first {
            parts.append(first)
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return LayoutResult(
            size: CGSize(width: maxX, height: currentY + lineHeight),
            positions: positions
        )
    }
}

#Preview {
    NavigationStack {
        AnalysisView(viewModel: AnalysisViewModel(result: PreviewSampleData.sampleAnalysisResult))
    }
    .modelContainer(PreviewSampleData.previewModelContainer)
}
