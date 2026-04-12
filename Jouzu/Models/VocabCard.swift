import Foundation
import SwiftData
import UIKit

enum SyncState: String, Codable, CaseIterable {
    case pendingCreate
    case pendingUpdate
    case pendingDelete
    case synced
    case failed
}

@Model
final class VocabCard {
    var id: UUID?
    var ownerId: String?
    var word: String
    var reading: String
    var definition: String
    var partOfSpeech: String
    var exampleSentence: String?
    var sourceImageData: Data?

    // SM-2 SRS fields
    var srsInterval: Int          // Days until next review
    var srsDueDate: Date
    var srsEaseFactor: Double     // Minimum 1.3
    var srsRepetitions: Int       // Consecutive correct answers

    var dateCreated: Date
    var deckName: String
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var syncStateRaw: String?
    var lastSyncAt: Date?
    var syncErrorMessage: String?
    var source: String?

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw ?? "") ?? .pendingCreate }
        set { syncStateRaw = newValue.rawValue }
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    var resolvedID: UUID {
        if let id {
            return id
        }

        let generated = UUID()
        id = generated
        return generated
    }

    var resolvedOwnerId: String {
        let trimmed = ownerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? AppUserIdentity.currentOwnerId() : trimmed
    }

    var resolvedCreatedAt: Date {
        createdAt ?? dateCreated
    }

    var resolvedUpdatedAt: Date {
        updatedAt ?? createdAt ?? dateCreated
    }

    init(
        id: UUID? = UUID(),
        ownerId: String? = AppUserIdentity.currentOwnerId(),
        word: String,
        reading: String,
        definition: String,
        partOfSpeech: String,
        exampleSentence: String? = nil,
        sourceImageData: Data? = nil,
        deckName: String = "Default",
        dateCreated: Date = Date(),
        source: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
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
        self.dateCreated = dateCreated
        self.deckName = deckName
        self.createdAt = dateCreated
        self.updatedAt = dateCreated
        self.deletedAt = nil
        self.syncStateRaw = SyncState.pendingCreate.rawValue
        self.lastSyncAt = nil
        self.syncErrorMessage = nil
        self.source = source
    }

    @discardableResult
    func ensureSyncMetadata(defaultOwnerId: String = AppUserIdentity.currentOwnerId()) -> Bool {
        var didChange = false

        if id == nil {
            id = UUID()
            didChange = true
        }

        let trimmedOwnerId = ownerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedOwnerId.isEmpty {
            ownerId = defaultOwnerId
            didChange = true
        }

        if createdAt == nil {
            createdAt = dateCreated
            didChange = true
        }

        if updatedAt == nil {
            updatedAt = createdAt ?? dateCreated
            didChange = true
        }

        if (syncStateRaw ?? "").isEmpty {
            syncStateRaw = SyncState.pendingCreate.rawValue
            didChange = true
        }

        return didChange
    }

    func markUpdated() {
        _ = ensureSyncMetadata()
        updatedAt = Date()
        syncErrorMessage = nil
        if syncState != .pendingCreate {
            syncState = .pendingUpdate
        }
    }

    func markDeleted() {
        _ = ensureSyncMetadata()
        let now = Date()
        deletedAt = now
        updatedAt = now
        syncErrorMessage = nil
        syncState = .pendingDelete
    }

    func markSynced(at date: Date = Date()) {
        _ = ensureSyncMetadata()
        lastSyncAt = date
        syncErrorMessage = nil
        syncState = .synced
    }

    func markFailed(_ message: String) {
        _ = ensureSyncMetadata()
        syncErrorMessage = message
        syncState = .failed
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
