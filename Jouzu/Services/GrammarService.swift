import Foundation

/// Rule-based grammar explanation engine using MeCab POS output
final class GrammarService: Sendable {

    /// Generate a grammar note for a token based on its POS and inflection
    func explain(_ token: Token) -> String? {
        switch token.partOfSpeech {
        case .verb:
            return explainVerb(token)
        case .iAdjective:
            return explainAdjective(token)
        case .particle:
            return explainParticle(token)
        case .auxiliaryVerb:
            return explainAuxiliaryVerb(token)
        case .naAdjective:
            return "na-adjective: used with な before nouns, だ/です for predicate"
        case .adverb:
            return "Adverb: modifies verbs, adjectives, or other adverbs"
        default:
            return nil
        }
    }

    /// Enrich tokens with grammar notes
    func enrichTokens(_ tokens: [Token]) -> [Token] {
        tokens.map { token in
            var enriched = token
            enriched.grammarNote = explain(token)
            return enriched
        }
    }

    // MARK: - Verb Explanations

    private func explainVerb(_ token: Token) -> String {
        var explanation = "Verb"

        // Determine verb group from base form
        if token.baseForm.hasSuffix("る") {
            let beforeRu = token.baseForm.dropLast()
            if let lastChar = beforeRu.last {
                let scalar = lastChar.unicodeScalars.first!.value
                // Check if it ends in i/e-dan + る (ichidan)
                if isIchidanEnding(scalar) {
                    explanation += " (ichidan/る-verb)"
                } else {
                    explanation += " (godan/う-verb)"
                }
            }
        } else {
            explanation += " (godan/う-verb)"
        }

        // Inflection form
        if let form = token.inflectionForm {
            if let formExplanation = inflectionFormExplanations[form] {
                explanation += " — \(formExplanation)"
            }
        }

        // Detect conjugation from surface vs base form
        if token.surface != token.baseForm {
            if let conjugation = detectConjugation(surface: token.surface, base: token.baseForm) {
                explanation += ". \(conjugation)"
            }
        }

        return explanation
    }

    private func isIchidanEnding(_ scalar: UInt32) -> Bool {
        // Hiragana i-dan and e-dan characters before る
        let ichidanEndings: Set<UInt32> = [
            0x3044, 0x304D, 0x3057, 0x3061, 0x306B, 0x3072, 0x307F, 0x308A, // i-dan
            0x3048, 0x3051, 0x305B, 0x3066, 0x306D, 0x3078, 0x3081, 0x308C, // e-dan
        ]
        return ichidanEndings.contains(scalar)
    }

    private func detectConjugation(surface: String, base: String) -> String? {
        // Common conjugation patterns
        if surface.hasSuffix("ます") { return "Polite (masu) form" }
        if surface.hasSuffix("ません") { return "Polite negative form" }
        if surface.hasSuffix("ました") { return "Polite past form" }
        if surface.hasSuffix("ませんでした") { return "Polite past negative" }
        if surface.hasSuffix("て") || surface.hasSuffix("で") { return "te-form (connecting/requesting)" }
        if surface.hasSuffix("た") || surface.hasSuffix("だ") { return "Past (plain) form" }
        if surface.hasSuffix("ない") { return "Negative (plain) form" }
        if surface.hasSuffix("なかった") { return "Past negative (plain)" }
        if surface.hasSuffix("たい") { return "Desire form (want to...)" }
        if surface.hasSuffix("れる") || surface.hasSuffix("られる") { return "Passive or potential form" }
        if surface.hasSuffix("せる") || surface.hasSuffix("させる") { return "Causative form (make/let someone...)" }
        if surface.hasSuffix("ろ") || surface.hasSuffix("よ") { return "Imperative form (command)" }
        if surface.hasSuffix("よう") { return "Volitional form (let's...)" }
        if surface.hasSuffix("ている") || surface.hasSuffix("てる") { return "Progressive/state (~ing)" }
        return nil
    }

    // MARK: - Adjective Explanations

    private func explainAdjective(_ token: Token) -> String {
        let explanation = "i-adjective"

        if token.surface != token.baseForm {
            if token.surface.hasSuffix("くない") { return "i-adjective: negative form" }
            if token.surface.hasSuffix("かった") { return "i-adjective: past form" }
            if token.surface.hasSuffix("くなかった") { return "i-adjective: past negative" }
            if token.surface.hasSuffix("く") { return "i-adjective: adverbial form (modifying verb)" }
            if token.surface.hasSuffix("くて") { return "i-adjective: te-form (connecting)" }
            if token.surface.hasSuffix("ければ") { return "i-adjective: conditional form" }
        }

        return explanation
    }

    // MARK: - Particle Explanations

    private func explainParticle(_ token: Token) -> String? {
        particleExplanations[token.surface]
    }

    private let particleExplanations: [String: String] = [
        "は": "Topic marker: indicates what the sentence is about",
        "が": "Subject marker: identifies who/what performs the action",
        "を": "Object marker: indicates the direct object of the verb",
        "に": "Target/location marker: indicates direction, time, or indirect object",
        "で": "Location of action / means: where something happens or by what means",
        "と": "And / with / quotation: lists items, companion, or quoted speech",
        "も": "Also / too: adds inclusion, similar to 'も' replacing は/が",
        "の": "Possessive / nominalizer: shows possession or turns phrases into noun clauses",
        "へ": "Direction marker: indicates direction of movement (similar to に)",
        "から": "From / because: starting point in time/space, or reason",
        "まで": "Until / up to: endpoint in time or space",
        "より": "Comparison marker: 'more than' or 'rather than'",
        "か": "Question marker: makes a sentence into a question",
        "よ": "Emphasis: adds assertion or new information for the listener",
        "ね": "Confirmation seeker: 'right?' or 'isn't it?'",
        "な": "Prohibition (with verbs) / exclamation / na-adjective connector",
        "けど": "But / although: soft contrast connector",
        "し": "And also / listing reasons: non-exhaustive listing",
        "ば": "Conditional: if (hypothetical condition)",
        "たら": "Conditional: if/when (after completion)",
        "ても": "Even if / even though: concessive conditional",
        "のに": "Despite / although: unexpected result",
        "ながら": "While: simultaneous actions",
    ]

    // MARK: - Auxiliary Verb Explanations

    private func explainAuxiliaryVerb(_ token: Token) -> String? {
        auxiliaryVerbExplanations[token.surface]
    }

    private let auxiliaryVerbExplanations: [String: String] = [
        "です": "Polite copula: polite equivalent of だ (is/am/are)",
        "だ": "Plain copula: plain form of です (is/am/are)",
        "ます": "Polite suffix: makes verbs polite",
        "た": "Past tense marker: indicates completed action",
        "ない": "Negative: negates verbs and adjectives",
        "たい": "Desire: expresses wanting to do something",
        "れる": "Passive/potential: indicates passive voice or ability",
        "られる": "Passive/potential (ichidan): indicates passive voice or ability",
        "せる": "Causative: 'make/let someone do'",
        "させる": "Causative (ichidan): 'make/let someone do'",
        "そう": "Appearance: 'looks like' / 'seems'",
        "らしい": "Hearsay/typicality: 'apparently' / 'seems' / '-like'",
        "よう": "Volitional/resemblance: 'let's' / 'like'",
        "べき": "Obligation: 'should' / 'ought to'",
        "はず": "Expectation: 'should be' / 'is expected to'",
    ]

    // MARK: - Inflection Forms (MeCab output)

    private let inflectionFormExplanations: [String: String] = [
        "基本形": "dictionary form",
        "連用形": "continuative form (connects to other words)",
        "連用タ接続": "ta-connection form (used before た/だ)",
        "連用テ接続": "te-connection form (used before て/で)",
        "未然形": "irrealis form (not yet happened, used with ない)",
        "未然ウ接続": "volitional base (used before う/よう)",
        "仮定形": "conditional form (used with ば)",
        "命令形": "imperative form (command)",
        "体言接続": "noun-connecting form",
        "仮定縮約": "contracted conditional",
        "ガル接続": "garu-connection (shows signs of)",
    ]
}
