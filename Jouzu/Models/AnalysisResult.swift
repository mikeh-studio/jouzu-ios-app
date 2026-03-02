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
