import Foundation

/// Represents a tokenized segment of Japanese text from MeCab
struct Token: Identifiable, Hashable {
    let id = UUID()
    let surface: String       // The word as it appears in text
    let reading: String       // Hiragana reading
    let partOfSpeech: PartOfSpeech
    let baseForm: String      // Dictionary form
    let inflectionType: String? // e.g., 連用形, 未然形
    let inflectionForm: String? // e.g., 一段, 五段

    /// Definition from JMdict, populated after dictionary lookup
    var definitions: [String] = []

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
}
