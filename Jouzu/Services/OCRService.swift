import Vision
import UIKit

/// Wraps Apple Vision framework for Japanese text recognition
final class OCRService: Sendable {

    struct OCRResult: Sendable {
        let fullText: String
        // VNRecognizedTextObservation is not Sendable; store only what we need
        nonisolated(unsafe) let observations: [VNRecognizedTextObservation]
    }

    func recognizeText(in image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = lines.joined(separator: "\n")

                if fullText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: OCRResult(
                        fullText: fullText,
                        observations: observations
                    ))
                }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process image"
        case .noTextFound: return "No Japanese text found in image"
        }
    }
}
