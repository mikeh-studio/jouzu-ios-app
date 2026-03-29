import Foundation

/// Represents a tokenized segment of Japanese text from MeCab
struct Token: Identifiable, Hashable {
    let id = UUID()
    let surface: String       // The word as it appears in text
    let reading: String       // Hiragana reading
    var partOfSpeech: PartOfSpeech
    let baseForm: String      // Dictionary form
    let inflectionType: String? // e.g., 連用形, 未然形
    let inflectionForm: String? // e.g., 一段, 五段

    /// Definition from JMdict, populated after dictionary lookup
    var definitions: [String] = []

    /// JLPT proficiency level (1–5, where 5 = N5/easiest), nil if unclassified
    var jlptLevel: Int?

    /// Grammar explanation from rule-based engine
    var grammarNote: String?

    static func == (lhs: Token, rhs: Token) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum PartOfSpeech: String, Codable, CaseIterable {
    case noun = "名詞"
    case verb = "動詞"
    case iAdjective = "形容詞"
    case naAdjective = "形容動詞"
    case particle = "助詞"
    case auxiliaryVerb = "助動詞"
    case adverb = "副詞"
    case conjunction = "接続詞"
    case interjection = "感動詞"
    case prefix = "接頭詞"
    case symbol = "記号"
    case filler = "フィラー"
    case other = "その他"
    case unknown = "未知語"

    /// Display color for grammar highlighting
    var highlightColorName: String {
        switch self {
        case .verb: return "verbBlue"
        case .iAdjective, .naAdjective: return "adjectiveGreen"
        case .particle: return "particleOrange"
        case .auxiliaryVerb: return "auxVerbPurple"
        case .noun: return "nounDefault"
        default: return "nounDefault"
        }
    }

    var displayName: String {
        switch self {
        case .noun: return "Noun"
        case .verb: return "Verb"
        case .iAdjective: return "i-Adjective"
        case .naAdjective: return "na-Adjective"
        case .particle: return "Particle"
        case .auxiliaryVerb: return "Auxiliary Verb"
        case .adverb: return "Adverb"
        case .conjunction: return "Conjunction"
        case .interjection: return "Interjection"
        case .prefix: return "Prefix"
        case .symbol: return "Symbol"
        case .filler: return "Filler"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }

    init(mecabPOS: String) {
        self = PartOfSpeech(rawValue: mecabPOS) ?? .unknown
    }

    init(dictionaryPOS: String) {
        switch dictionaryPOS.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "verb", "動詞":
            self = .verb
        case "noun", "名詞":
            self = .noun
        case "i-adjective", "adjective", "形容詞":
            self = .iAdjective
        case "na-adjective", "形容動詞":
            self = .naAdjective
        case "particle", "助詞":
            self = .particle
        case "auxiliary", "auxiliary-verb", "助動詞":
            self = .auxiliaryVerb
        case "adverb", "副詞":
            self = .adverb
        case "conjunction", "接続詞":
            self = .conjunction
        case "interjection", "感動詞":
            self = .interjection
        case "prefix", "接頭詞":
            self = .prefix
        case "symbol", "記号":
            self = .symbol
        default:
            self = .unknown
        }
    }
}

enum ExampleSentenceExtractor {
    private static let sentenceTerminators: Set<Character> = ["。", "！", "？", "!", "?"]

    static func extract(from text: String, token: Token) -> String? {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return nil }

        let lookupTerms = [token.surface, token.baseForm]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lookupTerms.isEmpty else { return nil }

        for sentence in splitSentences(source) {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isCompleteSentence(trimmed) else { continue }
            if lookupTerms.contains(where: { trimmed.contains($0) }) {
                return trimmed
            }
        }

        return nil
    }

    private static func isCompleteSentence(_ sentence: String) -> Bool {
        guard let last = sentence.last else { return false }
        return sentenceTerminators.contains(last)
    }

    private static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var buffer = ""

        for char in text {
            buffer.append(char)
            if sentenceTerminators.contains(char) {
                sentences.append(buffer)
                buffer = ""
            }
        }

        return sentences
    }
}

enum JapaneseTokenFilter {
    static func filterWords(_ tokens: [Token]) -> [Token] {
        tokens.filter { token in
            containsJapaneseScript(token.surface) && token.partOfSpeech != .particle
        }
    }

    static func uniqueVocabularyTokens(from tokens: [Token]) -> [Token] {
        var seen: Set<AnalysisWordKey> = []

        return tokens.filter { token in
            guard isVocabularyToken(token) else { return false }

            let key = AnalysisWordKey(token: token)
            return seen.insert(key).inserted
        }
    }

    static func containsJapaneseScript(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x309F, // Hiragana
                 0x30A0...0x30FF, // Katakana
                 0x4E00...0x9FFF, // CJK Unified Ideographs
                 0x3400...0x4DBF: // CJK Extension A
                return true
            default:
                continue
            }
        }
        return false
    }

    private static func isVocabularyToken(_ token: Token) -> Bool {
        guard containsJapaneseScript(token.surface) else { return false }

        switch token.partOfSpeech {
        case .particle, .auxiliaryVerb, .symbol, .filler:
            return false
        default:
            break
        }

        // MeCab-Swift's IPADic maps auxiliary verbs to .unknown, so they
        // bypass the POS check above. Catch them by surface/base form.
        if grammarSurfaceDenyList.contains(token.surface) ||
           grammarSurfaceDenyList.contains(token.baseForm) {
            return false
        }

        let dedupeText = normalizedWordText(for: token)
        return !isSingleHiraganaToken(dedupeText)
    }

    private static let grammarSurfaceDenyList: Set<String> = [
        // Auxiliary verbs (助動詞) — MeCab tags these as .unknown
        "です", "ます", "た", "だ", "ない",
        "れる", "られる", "せる", "させる", "たい",
        "らしい", "ようだ", "そうだ", "べき",
        // Conjugated copula / endings
        "でした", "ました", "ません", "だった",
    ]

    private static func normalizedWordText(for token: Token) -> String {
        let candidate = token.baseForm.trimmingCharacters(in: .whitespacesAndNewlines)
        if !candidate.isEmpty {
            return candidate
        }

        return token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isSingleHiraganaToken(_ text: String) -> Bool {
        guard text.count == 1 else { return false }

        for scalar in text.unicodeScalars {
            guard (0x3040...0x309F).contains(scalar.value) else {
                return false
            }
        }

        return !text.isEmpty
    }
}

private struct AnalysisWordKey: Hashable {
    let normalizedText: String
    let partOfSpeech: PartOfSpeech

    init(token: Token) {
        let base = token.baseForm.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)

        self.normalizedText = base.isEmpty ? fallback : base
        self.partOfSpeech = token.partOfSpeech
    }
}
