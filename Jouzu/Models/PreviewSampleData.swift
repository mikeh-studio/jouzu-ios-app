import SwiftUI
import SwiftData

// MARK: - Sample Data for SwiftUI Previews

enum PreviewSampleData {

    static let sampleTokens: [Token] = [
        Token(
            surface: "猫",
            reading: "ねこ",
            partOfSpeech: .noun,
            baseForm: "猫",
            inflectionType: nil,
            inflectionForm: nil,
            definitions: ["cat"],
            grammarNote: nil
        ),
        Token(
            surface: "が",
            reading: "が",
            partOfSpeech: .particle,
            baseForm: "が",
            inflectionType: nil,
            inflectionForm: nil,
            definitions: [],
            grammarNote: "Subject marker: identifies who/what performs the action"
        ),
        Token(
            surface: "食べた",
            reading: "たべた",
            partOfSpeech: .verb,
            baseForm: "食べる",
            inflectionType: "連用タ接続",
            inflectionForm: "一段",
            definitions: ["to eat"],
            grammarNote: "Verb (ichidan/る-verb) — ta-connection form. Past (plain) form"
        ),
        Token(
            surface: "魚",
            reading: "さかな",
            partOfSpeech: .noun,
            baseForm: "魚",
            inflectionType: nil,
            inflectionForm: nil,
            definitions: ["fish"],
            grammarNote: nil
        ),
        Token(
            surface: "を",
            reading: "を",
            partOfSpeech: .particle,
            baseForm: "を",
            inflectionType: nil,
            inflectionForm: nil,
            definitions: [],
            grammarNote: "Object marker: indicates the direct object of the verb"
        ),
        Token(
            surface: "美味しい",
            reading: "おいしい",
            partOfSpeech: .iAdjective,
            baseForm: "美味しい",
            inflectionType: nil,
            inflectionForm: nil,
            definitions: ["delicious", "tasty"],
            grammarNote: "i-adjective"
        ),
        Token(
            surface: "です",
            reading: "です",
            partOfSpeech: .auxiliaryVerb,
            baseForm: "です",
            inflectionType: nil,
            inflectionForm: nil,
            definitions: [],
            grammarNote: "Polite copula: polite equivalent of だ (is/am/are)"
        ),
    ]

    static let sampleText = "猫が食べた魚を美味しいです"

    static var sampleAnalysisResult: AnalysisResult {
        let size = CGSize(width: 400, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            UIColor.systemGray5.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let text = "猫が食べた魚" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48),
                .foregroundColor: UIColor.label,
            ]
            text.draw(at: CGPoint(x: 40, y: 70), withAttributes: attrs)
        }

        return AnalysisResult(
            originalImage: image,
            recognizedText: sampleText,
            tokens: sampleTokens,
            translation: "The cat ate the delicious fish."
        )
    }

    static func sampleVocabCard(
        word: String = "食べる",
        reading: String = "たべる",
        definition: String = "to eat",
        dueInDays: Int = 0
    ) -> VocabCard {
        let card = VocabCard(
            word: word,
            reading: reading,
            definition: definition,
            partOfSpeech: "Verb",
            exampleSentence: "猫が魚を食べる"
        )
        card.srsDueDate = Calendar.current.date(byAdding: .day, value: dueInDays, to: Date())!
        return card
    }

    @MainActor
    static var previewModelContainer: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: VocabCard.self, configurations: config)

        // Insert sample cards
        let samples = [
            sampleVocabCard(word: "食べる", reading: "たべる", definition: "to eat", dueInDays: 0),
            sampleVocabCard(word: "猫", reading: "ねこ", definition: "cat", dueInDays: 0),
            sampleVocabCard(word: "学校", reading: "がっこう", definition: "school", dueInDays: 3),
            sampleVocabCard(word: "美しい", reading: "うつくしい", definition: "beautiful", dueInDays: 7),
            sampleVocabCard(word: "走る", reading: "はしる", definition: "to run", dueInDays: -1),
        ]
        for card in samples {
            container.mainContext.insert(card)
        }

        return container
    }
}
