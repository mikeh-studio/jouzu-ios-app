import SwiftUI

@MainActor
@Observable
final class AnalysisViewModel {
    var result: AnalysisResult
    var selectedToken: Token?

    init(result: AnalysisResult) {
        self.result = result
    }

    func selectToken(_ token: Token) {
        if selectedToken?.id == token.id {
            selectedToken = nil
        } else {
            selectedToken = token
        }
    }
}
