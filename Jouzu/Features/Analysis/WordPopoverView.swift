import SwiftUI
import SwiftData

struct WordPopoverView: View {
    let token: Token
    let exampleSentence: String
    let sourceImage: UIImage?
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isSaved = false
    @State private var isDuplicate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: word + reading
            HStack(alignment: .bottom) {
                Text(token.surface)
                    .font(.title.bold())

                if !token.reading.isEmpty && token.reading != token.surface {
                    Text("【\(token.reading)】")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            // Base form (if different from surface)
            if token.baseForm != token.surface {
                HStack(spacing: 4) {
                    Text("Dictionary form:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(token.baseForm)
                        .font(.callout.bold())
                }
            }

            Divider()

            // Part of speech
            HStack {
                Text(token.partOfSpeech.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(GrammarHighlighter.backgroundColor(for: token.partOfSpeech))
                    .foregroundStyle(GrammarHighlighter.color(for: token.partOfSpeech))
                    .clipShape(Capsule())

                if let inflection = token.inflectionType {
                    Text(inflection)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Definitions
            if !token.definitions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Definitions")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ForEach(Array(token.definitions.enumerated()), id: \.offset) { index, definition in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(definition)
                                .font(.callout)
                        }
                    }
                }
            } else {
                Text("No definition found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // Grammar note
            if let grammarNote = token.grammarNote {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grammar")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(grammarNote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Save to deck button
            Button {
                saveToVocab()
            } label: {
                Label(
                    isSaved ? "Saved!" : isDuplicate ? "Already in Deck" : "Save to Deck",
                    systemImage: isSaved ? "checkmark.circle.fill" : isDuplicate ? "checkmark.circle" : "plus.circle"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSaved ? Color.green.opacity(0.15) : isDuplicate ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.15))
                .foregroundStyle(isSaved ? .green : isDuplicate ? .secondary : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isSaved || isDuplicate)
            .onAppear { checkDuplicate() }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }

    private func checkDuplicate() {
        let word = token.baseForm.isEmpty ? token.surface : token.baseForm
        let predicate = #Predicate<VocabCard> { card in
            card.word == word
        }
        let descriptor = FetchDescriptor<VocabCard>(predicate: predicate)
        isDuplicate = (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    private func saveToVocab() {
        let card = VocabCard(
            word: token.baseForm.isEmpty ? token.surface : token.baseForm,
            reading: token.reading,
            definition: token.definitions.joined(separator: "; "),
            partOfSpeech: token.partOfSpeech.displayName,
            exampleSentence: exampleSentence,
            sourceImageData: sourceImage.flatMap { VocabCard.compressThumbnail(from: $0) }
        )

        modelContext.insert(card)
        isSaved = true
    }
}

#Preview {
    WordPopoverView(
        token: PreviewSampleData.sampleTokens[2], // 食べた
        exampleSentence: PreviewSampleData.sampleText,
        sourceImage: nil,
        onDismiss: {}
    )
    .padding()
    .modelContainer(PreviewSampleData.previewModelContainer)
}

#Preview("Noun") {
    WordPopoverView(
        token: PreviewSampleData.sampleTokens[0], // 猫
        exampleSentence: PreviewSampleData.sampleText,
        sourceImage: nil,
        onDismiss: {}
    )
    .padding()
    .modelContainer(PreviewSampleData.previewModelContainer)
}
