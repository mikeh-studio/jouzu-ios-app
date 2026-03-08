import Foundation
import SwiftUI

/// The result of analyzing a captured image
struct AnalysisResult: Identifiable {
    let id = UUID()
    let originalImage: UIImage
    let recognizedText: String
    let tokens: [Token]
    var translation: String?
    let timestamp: Date

    init(originalImage: UIImage, recognizedText: String, tokens: [Token], translation: String? = nil) {
        self.originalImage = originalImage
        self.recognizedText = recognizedText
        self.tokens = tokens
        self.translation = translation
        self.timestamp = Date()
    }
}

enum AnalysisTextFormatter {
    static func normalizedSourceText(from text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return collapseWhitespace(in: lines.joined(separator: " "))
    }

    static func cleanedTranslation(_ text: String) -> String {
        collapseWhitespace(in: text)
    }

    private static func collapseWhitespace(in text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
