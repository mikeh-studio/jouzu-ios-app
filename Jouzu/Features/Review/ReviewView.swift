import SwiftUI
import SwiftData

struct ReviewView: View {
    @State private var viewModel = ReviewViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.sessionComplete {
                    completionView
                } else if let card = viewModel.currentCard {
                    cardReviewView(card: card)
                }
            }
            .navigationTitle("Review")
            .toolbar {
                if !viewModel.sessionComplete {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 8) {
                            if viewModel.isPracticeMode {
                                Text("Practice Mode")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.purple.opacity(0.15))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }
                            Text("\(viewModel.remainingCount) remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadDueCards(from: modelContext)
            }
        }
    }

    // MARK: - Card Review

    private func cardReviewView(card: VocabCard) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Card
            VStack(spacing: 16) {
                // Front: word
                Text(card.word)
                    .font(.system(size: 48, weight: .bold))

                if viewModel.isFlipped {
                    // Back: reading + definition
                    VStack(spacing: 12) {
                        if !card.reading.isEmpty {
                            Text(card.reading)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .padding(.horizontal, 40)

                        Text(card.definition)
                            .font(.title3)
                            .multilineTextAlignment(.center)

                        if !card.partOfSpeech.isEmpty {
                            Text(card.partOfSpeech)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        if let example = card.exampleSentence, !example.isEmpty {
                            VStack(spacing: 4) {
                                Text("Example")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Text(example)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 5)
            .padding(.horizontal)

            Spacer()

            // Actions
            if viewModel.isFlipped {
                ratingButtons
            } else {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.flip()
                    }
                } label: {
                    Text("Show Answer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Show answer for \(card.word)")
                .padding(.horizontal)
            }

            Spacer()
                .frame(height: 20)
        }
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        HStack(spacing: 12) {
            ForEach(SM2Algorithm.Rating.allCases, id: \.rawValue) { rating in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.rate(rating)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(rating.label)
                            .font(.subheadline.bold())
                        Text(intervalPreview(for: rating))
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ratingColor(rating).opacity(0.15))
                    .foregroundStyle(ratingColor(rating))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("\(rating.label): next review in \(intervalPreview(for: rating))")
            }
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func ratingColor(_ rating: SM2Algorithm.Rating) -> Color {
        switch rating {
        case .again: return .red
        case .hard: return .orange
        case .good: return .green
        case .easy: return .blue
        }
    }

    private func intervalPreview(for rating: SM2Algorithm.Rating) -> String {
        guard let card = viewModel.currentCard else { return "" }
        let result = SM2Algorithm.calculate(
            quality: rating.rawValue,
            repetitions: card.srsRepetitions,
            easeFactor: card.srsEaseFactor,
            interval: card.srsInterval
        )
        if result.interval == 1 { return "1 day" }
        if result.interval < 30 { return "\(result.interval) days" }
        return "\(result.interval / 30) mo"
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: viewModel.cardsReviewed > 0 ? "checkmark.circle.fill" : "tray")
                .font(.system(size: 64))
                .foregroundStyle(viewModel.cardsReviewed > 0 ? .green : .secondary)

            if viewModel.cardsReviewed > 0 {
                Text("Session Complete!")
                    .font(.title2.bold())
                Text("You reviewed \(viewModel.cardsReviewed) card\(viewModel.cardsReviewed == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            } else {
                Text("No Cards Due")
                    .font(.title2.bold())
                Text("All caught up! Take a photo to add new vocabulary.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                if viewModel.cardsReviewed > 0 && viewModel.reviewMode == .due {
                    Button("Review Due Again") {
                        viewModel.cardsReviewed = 0
                        viewModel.loadDueCards(from: modelContext)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    viewModel.loadAllCards(from: modelContext)
                } label: {
                    Label("Practice All Cards", systemImage: "rectangle.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)

                if viewModel.isPracticeMode {
                    Toggle("Update SRS scheduling", isOn: $viewModel.updateSRS)
                        .font(.callout)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .padding()
    }
}

#Preview("With Due Cards") {
    ReviewView()
        .modelContainer(PreviewSampleData.previewModelContainer)
}

#Preview("Empty") {
    ReviewView()
        .modelContainer(for: VocabCard.self, inMemory: true)
}
