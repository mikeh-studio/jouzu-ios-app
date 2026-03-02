import Foundation

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
        #if canImport(MeCab)
        return performMeCabTokenization(text)
        #else
        return nil
        #endif
    }

    #if canImport(MeCab)
    private func performMeCabTokenization(_ text: String) -> [Token]? {
        do {
            let mecab = try MeCab.Tokenizer()
            let nodes = try mecab.tokenize(text)

            return nodes.compactMap { node -> Token? in
                let surface = node.surface
                guard !surface.isEmpty else { return nil }

                // MeCab feature format: POS,POS-sub1,POS-sub2,POS-sub3,conjugationType,conjugationForm,baseForm,reading,pronunciation
                let features = node.features

                let pos = PartOfSpeech(mecabPOS: features.first ?? "")
                let baseForm = features.count > 6 ? features[6] : surface
                let reading = features.count > 7 ? features[7] : ""
                let inflectionType = features.count > 4 ? features[4] : nil
                let inflectionForm = features.count > 5 ? features[5] : nil

                // Convert katakana reading to hiragana
                let hiraganaReading = katakanaToHiragana(reading)

                return Token(
                    surface: surface,
                    reading: hiraganaReading,
                    partOfSpeech: pos,
                    baseForm: baseForm,
                    inflectionType: inflectionType == "*" ? nil : inflectionType,
                    inflectionForm: inflectionForm == "*" ? nil : inflectionForm
                )
            }
        } catch {
            // MeCab unavailable or failed — fall back to basic tokenizer
            return nil
        }
    }
    #endif

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
        Token(
            surface: surface,
            reading: "",
            partOfSpeech: .unknown,
            baseForm: surface,
            inflectionType: nil,
            inflectionForm: nil
        )
    }

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
