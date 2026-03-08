import SwiftUI

@MainActor
@Observable
final class AnalysisViewModel {
    enum TranslationState: Equatable {
        case idle
        case loading
        case complete
        case unavailable
    }

    var result: AnalysisResult
    var selectedToken: Token?
    var translationState: TranslationState

    init(result: AnalysisResult) {
        self.result = result
        self.translationState = if let translation = result.translation,
                                   !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            .complete
        } else {
            .idle
        }
    }

    var translation: String? {
        guard let translation = result.translation?.trimmingCharacters(in: .whitespacesAndNewlines),
              !translation.isEmpty else {
            return nil
        }

        return translation
    }

    var words: [Token] {
        JapaneseTokenFilter.uniqueVocabularyTokens(from: result.tokens)
    }

    var isTranslationLoading: Bool {
        translationState == .loading
    }

    var showTranslationUnavailable: Bool {
        translation == nil && translationState == .unavailable
    }

    func beginTranslation() {
        if translation == nil {
            translationState = .loading
        }
    }

    func applyEnrichment(tokens: [Token], translation: String?) {
        let updatedResult = AnalysisResult(
            originalImage: result.originalImage,
            recognizedText: result.recognizedText,
            tokens: tokens,
            translation: translation
        )

        if let selectedToken {
            self.selectedToken = tokens.first { $0.id == selectedToken.id }
        }

        result = updatedResult
        translationState = translation == nil ? .unavailable : .complete
    }

    func markTranslationUnavailable() {
        if translation == nil {
            translationState = .unavailable
        }
    }

    func selectToken(_ token: Token) {
        if selectedToken?.id == token.id {
            selectedToken = nil
        } else {
            selectedToken = token
        }
    }
}
