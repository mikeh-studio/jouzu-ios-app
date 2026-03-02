import Foundation
import SwiftData
import UIKit

@Model
final class VocabCard {
    var word: String
    var reading: String
    var definition: String
    var partOfSpeech: String
    var exampleSentence: String
    var sourceImageData: Data?

    // SM-2 SRS fields
    var srsInterval: Int          // Days until next review
    var srsDueDate: Date
    var srsEaseFactor: Double     // Minimum 1.3
    var srsRepetitions: Int       // Consecutive correct answers

    var dateCreated: Date
    var deckName: String

    init(
        word: String,
        reading: String,
        definition: String,
        partOfSpeech: String,
        exampleSentence: String,
        sourceImageData: Data? = nil,
        deckName: String = "Default"
    ) {
        self.word = word
        self.reading = reading
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.exampleSentence = exampleSentence
        self.sourceImageData = sourceImageData
        self.srsInterval = 0
        self.srsDueDate = Date()
        self.srsEaseFactor = 2.5
        self.srsRepetitions = 0
        self.dateCreated = Date()
        self.deckName = deckName
    }

    /// Compressed thumbnail from source image (max 200x200)
    static func compressThumbnail(from image: UIImage) -> Data? {
        let maxSize: CGFloat = 200
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail?.jpegData(compressionQuality: 0.6)
    }
}
