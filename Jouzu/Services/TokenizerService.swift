import Foundation
#if canImport(Mecab_Swift) && canImport(IPADic)
import Mecab_Swift
import IPADic
#endif

/// Wraps MeCab for Japanese text tokenization
/// Falls back to character-level splitting if MeCab is unavailable
final class TokenizerService: Sendable {

    /// Tokenize Japanese text into word segments with POS tags
    func tokenize(_ text: String) -> [Token] {
        // Try MeCab first, fall back to basic tokenization
        if let mecabTokens = tokenizeWithMeCab(text) {
            return mecabTokens
        }
        return basicTokenize(text)
    }

    // MARK: - MeCab Integration

    private func tokenizeWithMeCab(_ text: String) -> [Token]? {
        #if canImport(Mecab_Swift) && canImport(IPADic)
        return performMeCabTokenization(text)
        #else
        return nil
        #endif
    }

    #if canImport(Mecab_Swift) && canImport(IPADic)
    private func performMeCabTokenization(_ text: String) -> [Token]? {
        do {
            let tokenizer = try Tokenizer(dictionary: IPADic())
            let annotations = tokenizer.tokenize(text: text, transliteration: .hiragana)

            return annotations.compactMap { annotation -> Token? in
                let surface = annotation.base
                guard !surface.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

                let baseForm = annotation.dictionaryForm.isEmpty ? surface : annotation.dictionaryForm
                let reading = annotation.reading == surface ? "" : annotation.reading

                return Token(
                    surface: surface,
                    reading: reading,
                    partOfSpeech: mapMeCabPOS(annotation.partOfSpeech.description),
                    baseForm: baseForm,
                    inflectionType: nil,
                    inflectionForm: nil
                )
            }
        } catch {
            // MeCab unavailable or failed — fall back to basic tokenizer
            return nil
        }
    }
    #endif

    private func mapMeCabPOS(_ value: String) -> PartOfSpeech {
        switch value.lowercased() {
        case "verb":
            return .verb
        case "particle":
            return .particle
        case "noun":
            return .noun
        case "adjective":
            return .iAdjective
        case "adverb":
            return .adverb
        case "prefix":
            return .prefix
        case "symbol":
            return .symbol
        default:
            return .unknown
        }
    }

    // MARK: - Basic Fallback Tokenizer

    /// Simple character-class-based tokenization when MeCab is unavailable
    private func basicTokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var currentWord = ""
        var currentType: CharType?

        for char in text {
            let charType = classifyChar(char)

            if charType != currentType && !currentWord.isEmpty {
                tokens.append(makeBasicToken(currentWord))
                currentWord = ""
            }

            currentType = charType
            if charType != .whitespace {
                currentWord.append(char)
            }
        }

        if !currentWord.isEmpty {
            tokens.append(makeBasicToken(currentWord))
        }

        return tokens
    }

    private enum CharType {
        case kanji, hiragana, katakana, latin, whitespace, other
    }

    private func classifyChar(_ char: Character) -> CharType {
        let scalar = char.unicodeScalars.first!.value
        switch scalar {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF: return .kanji
        case 0x3040...0x309F: return .hiragana
        case 0x30A0...0x30FF: return .katakana
        case 0x0041...0x005A, 0x0061...0x007A, 0x0030...0x0039: return .latin
        case 0x0020, 0x3000, 0x000A, 0x000D, 0x0009: return .whitespace
        default: return .other
        }
    }

    private func makeBasicToken(_ surface: String) -> Token {
        let pos: PartOfSpeech
        if Self.particleSet.contains(surface) {
            pos = .particle
        } else if Self.symbolSet.contains(surface) {
            pos = .symbol
        } else {
            pos = .unknown
        }

        return Token(
            surface: surface,
            reading: "",
            partOfSpeech: pos,
            baseForm: surface,
            inflectionType: nil,
            inflectionForm: nil
        )
    }

    private static let particleSet: Set<String> = [
        "は", "が", "を", "に", "で", "と", "へ", "の", "も", "から", "まで", "より", "や", "か", "ね", "よ", "な", "ぞ", "さ"
    ]

    private static let symbolSet: Set<String> = [
        "。", "、", "！", "？", "!", "?", "「", "」", "『", "』", "（", "）", "(", ")", "…", "・", ":", "：", ";", "；"
    ]

    // MARK: - Utilities

    private func katakanaToHiragana(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x30A0 && scalar.value <= 0x30FF {
                if let hiragana = Unicode.Scalar(scalar.value - 0x60) {
                    result.append(Character(hiragana))
                } else {
                    result.append(Character(scalar))
                }
            } else {
                result.append(Character(scalar))
            }
        }
        return result
    }
}
