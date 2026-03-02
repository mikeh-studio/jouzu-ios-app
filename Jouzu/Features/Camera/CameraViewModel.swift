import SwiftUI
import AVFoundation

@MainActor
@Observable
final class CameraViewModel {
    var capturedImage: UIImage?
    var showImagePicker = false
    var showCamera = false
    var isProcessing = false
    var errorMessage: String?
    var analysisResult: AnalysisResult?
    var showAnalysis = false

    private let ocrService = OCRService()
    private let tokenizerService = TokenizerService()
    private let dictionaryService = DictionaryService()
    private let grammarService = GrammarService()

    func captureFromCamera() {
        showCamera = true
    }

    func importFromLibrary() {
        showImagePicker = true
    }

    func processImage(_ image: UIImage) {
        capturedImage = image
        isProcessing = true
        errorMessage = nil

        let ocr = ocrService
        let tokenizer = tokenizerService
        let dictionary = dictionaryService
        let grammar = grammarService

        Task {
            do {
                // Run OCR + enrichment off main thread
                let (tokens, fullText) = try await Task.detached {
                    let ocrResult = try await ocr.recognizeText(in: image)
                    var tokens = tokenizer.tokenize(ocrResult.fullText)
                    tokens = dictionary.enrichTokens(tokens)
                    tokens = grammar.enrichTokens(tokens)
                    return (tokens, ocrResult.fullText)
                }.value

                let result = AnalysisResult(
                    originalImage: image,
                    recognizedText: fullText,
                    tokens: tokens
                )

                self.analysisResult = result
                self.showAnalysis = true
                self.isProcessing = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }

    func reset() {
        capturedImage = nil
        analysisResult = nil
        showAnalysis = false
        errorMessage = nil
    }
}
