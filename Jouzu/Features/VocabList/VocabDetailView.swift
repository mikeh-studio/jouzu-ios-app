import SwiftUI
import SwiftData

struct VocabDetailView: View {
    let card: VocabCard
    @Environment(\.modelContext) private var modelContext
    @State private var isEditingExample = false
    @State private var exampleDraft = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Word + Reading
                    VStack(spacing: 8) {
                        Text(card.word)
                            .font(.system(size: 48, weight: .bold))

                        if !card.reading.isEmpty {
                            Text(card.reading)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    Divider()

                    // Definition
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Definition")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(card.definition)
                            .font(.body)
                    }
                    .padding(.horizontal)

                    // Part of Speech
                    if !card.partOfSpeech.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Part of Speech")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(card.partOfSpeech)
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(GrammarHighlighter.color(forDisplayName: card.partOfSpeech).opacity(0.1))
                                .foregroundStyle(GrammarHighlighter.color(forDisplayName: card.partOfSpeech))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal)
                    }

                    exampleSection

                    // Source Image
                    if let imageData = card.sourceImageData,
                       let uiImage = UIImage(data: imageData) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Source")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal)
                    }

                    // Date
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Added")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(card.dateCreated, style: .date)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                exampleDraft = normalizedExampleSentence ?? ""
            }
            .alert("Save Failed", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                if let saveError {
                    Text(saveError)
                }
            }
        }
    }

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if isEditingExample {
                TextEditor(text: $exampleDraft)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("Cancel") {
                        exampleDraft = normalizedExampleSentence ?? ""
                        isEditingExample = false
                    }

                    Spacer()

                    Button("Save") {
                        let trimmed = exampleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        card.exampleSentence = trimmed.isEmpty ? nil : trimmed
                        isEditingExample = false
                        do {
                            try modelContext.save()
                        } catch {
                            saveError = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let sentence = normalizedExampleSentence {
                Text(sentence)
                    .font(.callout)

                Button("Edit Example") {
                    exampleDraft = sentence
                    isEditingExample = true
                }
                .font(.caption)
            } else {
                Text("No example sentence saved yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Add Example") {
                    exampleDraft = ""
                    isEditingExample = true
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
    }

    private var normalizedExampleSentence: String? {
        guard let value = card.exampleSentence?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
