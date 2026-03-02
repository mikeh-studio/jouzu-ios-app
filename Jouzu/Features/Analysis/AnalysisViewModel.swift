import SwiftUI
import Translation

@MainActor
@Observable
final class AnalysisViewModel {
    var result: AnalysisResult
    var selectedToken: Token?
    var translation: String?
    var isTranslating = false
    var translationConfiguration: TranslationSession.Configuration?

    init(result: AnalysisResult) {
        self.result = result
        self.translation = result.translation
    }

    func requestTranslation() {
        guard translation == nil else { return }
        isTranslating = true
        // Trigger translation via SwiftUI's .translationTask modifier
        translationConfiguration = .init(
            source: .init(identifier: "ja"),
            target: .init(identifier: "en")
        )
    }

    func handleTranslationResult(_ response: TranslationSession.Response) {
        translation = response.targetText
        isTranslating = false
    }

    func selectToken(_ token: Token) {
        if selectedToken?.id == token.id {
            selectedToken = nil
        } else {
            selectedToken = token
        }
    }
}
