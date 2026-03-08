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
    var analysisViewModel: AnalysisViewModel?

    /// Set to trigger the .translationTask modifier for translation enrichment
    var translationConfiguration: TranslationSession.Configuration?
    var translationTaskID = UUID()

    private let ocrService = OCRService()
    private let tokenizerService = TokenizerService()
    private let dictionaryService = DictionaryService()
    private let grammarService = GrammarService()

    private struct PendingAnalysisRequest {
        let requestID: UUID
        let recognizedText: String
        let tokens: [Token]
        let needsDefinitionTranslation: Bool
    }

    private var pendingAnalysisRequest: PendingAnalysisRequest?
    private var activeRequestID: UUID?
    private var processingTask: Task<Void, Never>?
    private var translationTimeoutTask: Task<Void, Never>?

    func captureFromCamera() {
        showCamera = true
    }

    func importFromLibrary() {
        showImagePicker = true
    }

    func processImage(_ image: UIImage) {
        let requestID = UUID()
        activeRequestID = requestID

        processingTask?.cancel()
        clearPendingTranslationState()

        capturedImage = image
        isProcessing = true
        errorMessage = nil
        analysisViewModel = nil

        let ocr = ocrService
        let tokenizer = tokenizerService
        let dictionary = dictionaryService
        let grammar = grammarService

        processingTask = Task {
            do {
                let (tokens, fullText) = try await Task.detached {
                    let ocrResult = try await ocr.recognizeText(in: image)
                    var tokens = tokenizer.tokenize(ocrResult.fullText)
                    tokens = JapaneseTokenFilter.filterWords(tokens)
                    tokens = dictionary.enrichTokens(tokens)
                    tokens = grammar.enrichTokens(tokens)
                    return (tokens, ocrResult.fullText)
                }.value

                guard !Task.isCancelled else { return }
                guard self.activeRequestID == requestID else { return }

                let cleanedText = AnalysisTextFormatter.normalizedSourceText(from: fullText)
                let baseResult = AnalysisResult(
                    originalImage: image,
                    recognizedText: cleanedText,
                    tokens: tokens
                )

                let analysisViewModel = AnalysisViewModel(result: baseResult)
                analysisViewModel.beginTranslation()

                self.analysisViewModel = analysisViewModel
                self.isProcessing = false
                self.processingTask = nil

                scheduleTranslation(tokens: tokens, fullText: cleanedText, requestID: requestID)
            } catch {
                guard !Task.isCancelled else { return }
                guard self.activeRequestID == requestID else { return }
                finishProcessing(with: error.localizedDescription, requestID: requestID)
            }
        }
    }

    func handleTranslationSession(_ session: TranslationSession) async {
        guard let pendingRequest = pendingAnalysisRequest,
              pendingRequest.requestID == activeRequestID else {
            return
        }

        let dictionary = dictionaryService
        nonisolated(unsafe) let s = session

        let enrichedTokens: [Token]
        if pendingRequest.needsDefinitionTranslation {
            enrichedTokens = await dictionary.enrichTokensWithTranslation(pendingRequest.tokens, session: s)
        } else {
            enrichedTokens = pendingRequest.tokens
        }

        let translation = await translateFullText(pendingRequest.recognizedText, session: s)

        await MainActor.run {
            guard self.activeRequestID == pendingRequest.requestID else { return }
            guard let analysisViewModel else {
                clearPendingTranslationState()
                return
            }

            analysisViewModel.applyEnrichment(tokens: enrichedTokens, translation: translation)
            clearPendingTranslationState()
        }
    }

    func dismissAnalysis() {
        activeRequestID = nil
        analysisViewModel = nil
        clearPendingTranslationState()
    }

    func reset() {
        processingTask?.cancel()
        processingTask = nil
        activeRequestID = nil
        capturedImage = nil
        analysisViewModel = nil
        clearPendingTranslationState()
        translationTaskID = UUID()
        isProcessing = false
        errorMessage = nil
    }

    private func scheduleTranslation(tokens: [Token], fullText: String, requestID: UUID) {
        guard activeRequestID == requestID else { return }

        let needsDefinitionTranslation = tokens.contains { token in
            token.definitions.isEmpty &&
            token.partOfSpeech != .symbol &&
            token.partOfSpeech != .filler &&
            token.partOfSpeech != .particle &&
            token.partOfSpeech != .auxiliaryVerb
        }

        pendingAnalysisRequest = PendingAnalysisRequest(
            requestID: requestID,
            recognizedText: fullText,
            tokens: tokens,
            needsDefinitionTranslation: needsDefinitionTranslation
        )

        translationTaskID = requestID
        translationConfiguration = TranslationSession.Configuration(
            source: .init(identifier: "ja"),
            target: .init(identifier: "en")
        )
        startTranslationTimeout(for: requestID)
    }

    private func translateFullText(_ text: String, session: TranslationSession) async -> String? {
        guard !text.isEmpty else { return nil }

        do {
            nonisolated(unsafe) let s = session
            let response = try await s.translate(text)
            let cleaned = AnalysisTextFormatter.cleanedTranslation(response.targetText)
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }

    private func startTranslationTimeout(for requestID: UUID) {
        translationTimeoutTask?.cancel()
        translationTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.activeRequestID == requestID else { return }
                self.analysisViewModel?.markTranslationUnavailable()
                clearPendingTranslationState()
            }
        }
    }

    private func finishProcessing(with errorMessage: String, requestID: UUID) {
        guard activeRequestID == requestID else { return }

        self.errorMessage = errorMessage
        self.analysisViewModel = nil
        self.isProcessing = false
        self.processingTask = nil
        clearPendingTranslationState()
    }

    private func clearPendingTranslationState() {
        translationTimeoutTask?.cancel()
        translationTimeoutTask = nil
        translationConfiguration = nil
        pendingAnalysisRequest = nil
    }
}
