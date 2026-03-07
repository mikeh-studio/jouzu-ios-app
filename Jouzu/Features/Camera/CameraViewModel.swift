import SwiftUI
import AVFoundation
import Translation

@MainActor
@Observable
final class CameraViewModel {
    var capturedImage: UIImage?
    var showImagePicker = false
    var showCamera = false
    var isProcessing = false
    var errorMessage: String?
    var analysisResult: AnalysisResult?

    /// Set to trigger the .translationTask modifier for definition fallback
    var translationConfiguration: TranslationSession.Configuration?

    private let ocrService = OCRService()
    private let tokenizerService = TokenizerService()
    private let dictionaryService = DictionaryService()
    private let grammarService = GrammarService()

    /// Tokens awaiting translation enrichment
    private var pendingTokens: [Token]?
    private var pendingFullText: String?
    private var pendingImage: UIImage?
    private var pendingRequestID: UUID?
    private var activeRequestID: UUID?

    func captureFromCamera() {
        showCamera = true
    }

    func importFromLibrary() {
        showImagePicker = true
    }

    func processImage(_ image: UIImage) {
        let requestID = UUID()
        activeRequestID = requestID

        capturedImage = image
        isProcessing = true
        errorMessage = nil
        analysisResult = nil
        translationConfiguration = nil
        pendingTokens = nil
        pendingFullText = nil
        pendingImage = nil
        pendingRequestID = nil

        let ocr = ocrService
        let tokenizer = tokenizerService
        let dictionary = dictionaryService
        let grammar = grammarService

        Task {
            do {
                // Run OCR + dictionary enrichment off main thread
                let (tokens, fullText) = try await Task.detached {
                    let ocrResult = try await ocr.recognizeText(in: image)
                    var tokens = tokenizer.tokenize(ocrResult.fullText)
                    tokens = JapaneseTokenFilter.filterWords(tokens)
                    tokens = dictionary.enrichTokens(tokens)
                    tokens = grammar.enrichTokens(tokens)
                    return (tokens, ocrResult.fullText)
                }.value

                guard self.activeRequestID == requestID else { return }

                // Check if any tokens still need definitions
                let needsTranslation = tokens.contains { token in
                    token.definitions.isEmpty &&
                    token.partOfSpeech != .symbol &&
                    token.partOfSpeech != .filler &&
                    token.partOfSpeech != .particle
                }

                if needsTranslation {
                    // Store pending state and trigger translation
                    pendingTokens = tokens
                    pendingFullText = fullText
                    pendingImage = image
                    pendingRequestID = requestID
                    translationConfiguration = .init(
                        source: .init(identifier: "ja"),
                        target: .init(identifier: "en")
                    )
                } else {
                    finishProcessing(tokens: tokens, fullText: fullText, image: image, requestID: requestID)
                }
            } catch {
                guard self.activeRequestID == requestID else { return }
                self.errorMessage = error.localizedDescription
                self.translationConfiguration = nil
                self.pendingTokens = nil
                self.pendingFullText = nil
                self.pendingImage = nil
                self.pendingRequestID = nil
                self.isProcessing = false
            }
        }
    }

    /// Called from .translationTask modifier when session is available
    func handleTranslationSession(_ session: TranslationSession) async {
        guard let requestID = pendingRequestID,
              requestID == activeRequestID else {
            return
        }

        guard let tokens = pendingTokens,
              let fullText = pendingFullText,
              let image = pendingImage else {
            return
        }

        let dictionary = dictionaryService
        nonisolated(unsafe) let s = session
        let enriched = await dictionary.enrichTokensWithTranslation(tokens, session: s)

        await MainActor.run {
            guard self.activeRequestID == requestID else { return }
            finishProcessing(tokens: enriched, fullText: fullText, image: image, requestID: requestID)
        }
    }

    private func finishProcessing(tokens: [Token], fullText: String, image: UIImage, requestID: UUID) {
        guard activeRequestID == requestID else { return }

        pendingTokens = nil
        pendingFullText = nil
        pendingImage = nil
        pendingRequestID = nil
        translationConfiguration = nil

        let result = AnalysisResult(
            originalImage: image,
            recognizedText: fullText,
            tokens: tokens
        )

        self.analysisResult = result
        self.isProcessing = false
    }

    func reset() {
        activeRequestID = nil
        capturedImage = nil
        analysisResult = nil
        translationConfiguration = nil
        pendingTokens = nil
        pendingFullText = nil
        pendingImage = nil
        pendingRequestID = nil
        isProcessing = false
        errorMessage = nil
    }
}
