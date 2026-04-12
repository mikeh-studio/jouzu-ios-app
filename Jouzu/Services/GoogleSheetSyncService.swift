import Foundation
import Observation
import SwiftData

struct GoogleSheetSyncConfiguration {
    let baseURL: URL?
    let apiKey: String?

    var isConfigured: Bool {
        baseURL != nil && !(apiKey?.isEmpty ?? true)
    }

    static func current(bundle: Bundle = .main) -> GoogleSheetSyncConfiguration {
        let baseURLString = bundle.object(forInfoDictionaryKey: "GOOGLE_SHEET_SYNC_BASE_URL") as? String
        let apiKey = bundle.object(forInfoDictionaryKey: "GOOGLE_SHEET_SYNC_API_KEY") as? String

        let trimmedURL = baseURLString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)

        return GoogleSheetSyncConfiguration(
            baseURL: trimmedURL.flatMap(URL.init(string:)),
            apiKey: trimmedKey
        )
    }
}

struct SheetWordRow: Codable, Sendable {
    let id: String
    let ownerId: String
    let word: String
    let reading: String
    let definition: String
    let partOfSpeech: String
    let exampleSentence: String?
    let deckName: String
    let srsInterval: Int
    let srsDueDate: Date
    let srsEaseFactor: Double
    let srsRepetitions: Int
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case word
        case reading
        case definition
        case partOfSpeech = "part_of_speech"
        case exampleSentence = "example_sentence"
        case deckName = "deck_name"
        case srsInterval = "srs_interval"
        case srsDueDate = "srs_due_date"
        case srsEaseFactor = "srs_ease_factor"
        case srsRepetitions = "srs_repetitions"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case source
    }
}

struct SyncResult: Sendable {
    var pulledCreated = 0
    var pulledUpdated = 0
    var pushedUpserts = 0
    var pushedDeletes = 0
    var failed = 0
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case succeeded
    case failed
    case disabled
}

enum SyncServiceError: LocalizedError {
    case notConfigured
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Sheet sync is not configured."
        case .invalidResponse:
            return "The sync service returned an invalid response."
        case .httpError(let code):
            return "The sync service returned HTTP \(code)."
        }
    }
}

@MainActor
@Observable
final class SyncCoordinator {
    private let configuration: GoogleSheetSyncConfiguration
    private var hasBootstrapped = false
    private var isSyncing = false
    private var pendingSyncRequest = false

    var status: SyncStatus
    var lastSyncAt: Date?
    var lastError: String?
    var lastResult = SyncResult()

    init(configuration: GoogleSheetSyncConfiguration = .current()) {
        self.configuration = configuration
        self.status = configuration.isConfigured ? .idle : .disabled
    }

    var isConfigured: Bool {
        configuration.isConfigured
    }

    var ownerId: String {
        AppUserIdentity.currentOwnerId()
    }

    func bootstrapIfNeeded(context: ModelContext) async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        migrateExistingCards(in: context)

        guard isConfigured else {
            status = .disabled
            return
        }

        await syncNow(context: context)
    }

    func syncNow(context: ModelContext) async {
        guard isConfigured else {
            status = .disabled
            return
        }

        if isSyncing {
            pendingSyncRequest = true
            return
        }

        isSyncing = true
        status = .syncing
        lastError = nil

        do {
            migrateExistingCards(in: context)
            let result = try await performSync(context: context)
            lastResult = result
            lastSyncAt = Date()
            status = .succeeded
        } catch {
            lastError = error.localizedDescription
            status = .failed
        }

        isSyncing = false

        if pendingSyncRequest {
            pendingSyncRequest = false
            await syncNow(context: context)
        }
    }

    private func performSync(context: ModelContext) async throws -> SyncResult {
        let client = GoogleSheetSyncClient(configuration: configuration)
        let currentOwnerId = ownerId
        var result = SyncResult()

        let remoteRows = try await client.fetchWords(ownerId: currentOwnerId)
        let remoteByID = Dictionary(uniqueKeysWithValues: remoteRows.compactMap { row -> (UUID, SheetWordRow)? in
            guard let id = UUID(uuidString: row.id) else { return nil }
            return (id, row)
        })

        for row in remoteRows {
            guard let rowID = UUID(uuidString: row.id) else { continue }
            let descriptor = FetchDescriptor<VocabCard>(
                predicate: #Predicate<VocabCard> { card in
                    card.id == rowID
                }
            )
            let localCard = try context.fetch(descriptor).first

            if let localCard {
                _ = localCard.ensureSyncMetadata(defaultOwnerId: currentOwnerId)
                if row.updatedAt > localCard.resolvedUpdatedAt {
                    apply(row: row, to: localCard)
                    localCard.markSynced()
                    result.pulledUpdated += 1
                }
            } else {
                context.insert(makeCard(from: row))
                result.pulledCreated += 1
            }
        }

        let pendingDescriptor = FetchDescriptor<VocabCard>(
            predicate: #Predicate<VocabCard> { card in
                card.ownerId == currentOwnerId && card.syncStateRaw != "synced"
            }
        )
        let pendingCards = try context.fetch(pendingDescriptor)
        let pendingUpserts = pendingCards.filter { !$0.isDeleted }
        let pendingDeletes = pendingCards.filter { $0.isDeleted }

        for batch in pendingUpserts.chunked(into: 50) {
            let rows = batch.map(makeRow)
            let response = try await client.upsert(rows: rows)
            result.pushedUpserts += response.appliedIds.count
            result.failed += response.failed.count
            applyBatchResponse(response, to: batch, serverRows: remoteByID)
        }

        for batch in pendingDeletes.chunked(into: 50) {
            let rows = batch.map(makeDeleteRow)
            let response = try await client.delete(rows: rows)
            result.pushedDeletes += response.appliedIds.count
            result.failed += response.failed.count
            applyBatchResponse(response, to: batch, serverRows: remoteByID)
        }

        try context.save()
        return result
    }

    private func migrateExistingCards(in context: ModelContext) {
        let descriptor = FetchDescriptor<VocabCard>()

        guard let cards = try? context.fetch(descriptor) else { return }

        let currentOwnerId = ownerId
        var hasChanges = false

        for card in cards {
            if card.ensureSyncMetadata(defaultOwnerId: currentOwnerId) {
                hasChanges = true
            }
        }

        if hasChanges {
            try? context.save()
        }
    }

    private func applyBatchResponse(
        _ response: BatchResponse,
        to cards: [VocabCard],
        serverRows: [UUID: SheetWordRow]
    ) {
        let appliedSet = Set(response.appliedIds)
        let failures = Dictionary(uniqueKeysWithValues: response.failed.map { ($0.id, $0.message) })

        for card in cards {
            _ = card.ensureSyncMetadata()
            let id = card.resolvedID.uuidString
            if appliedSet.contains(id) {
                if let remoteRow = serverRows[card.resolvedID], remoteRow.updatedAt > card.resolvedUpdatedAt {
                    apply(row: remoteRow, to: card)
                }
                card.markSynced()
            } else if let message = failures[id] {
                card.markFailed(message)
            } else {
                card.markFailed("Sync did not confirm this row.")
            }
        }
    }

    private func makeCard(from row: SheetWordRow) -> VocabCard {
        let card = VocabCard(
            id: UUID(uuidString: row.id) ?? UUID(),
            ownerId: row.ownerId,
            word: row.word,
            reading: row.reading,
            definition: row.definition,
            partOfSpeech: row.partOfSpeech,
            exampleSentence: row.exampleSentence,
            sourceImageData: nil,
            deckName: row.deckName,
            dateCreated: row.createdAt,
            source: row.source
        )
        card.srsInterval = row.srsInterval
        card.srsDueDate = row.srsDueDate
        card.srsEaseFactor = row.srsEaseFactor
        card.srsRepetitions = row.srsRepetitions
        card.createdAt = row.createdAt
        card.updatedAt = row.updatedAt
        card.deletedAt = row.deletedAt
        card.markSynced()
        return card
    }

    private func apply(row: SheetWordRow, to card: VocabCard) {
        card.ownerId = row.ownerId
        card.word = row.word
        card.reading = row.reading
        card.definition = row.definition
        card.partOfSpeech = row.partOfSpeech
        card.exampleSentence = row.exampleSentence
        card.deckName = row.deckName
        card.srsInterval = row.srsInterval
        card.srsDueDate = row.srsDueDate
        card.srsEaseFactor = row.srsEaseFactor
        card.srsRepetitions = row.srsRepetitions
        card.createdAt = row.createdAt
        card.dateCreated = row.createdAt
        card.updatedAt = row.updatedAt
        card.deletedAt = row.deletedAt
        card.source = row.source
    }

    private func makeRow(from card: VocabCard) -> SheetWordRow {
        _ = card.ensureSyncMetadata()
        return SheetWordRow(
            id: card.resolvedID.uuidString,
            ownerId: card.resolvedOwnerId,
            word: card.word,
            reading: card.reading,
            definition: card.definition,
            partOfSpeech: card.partOfSpeech,
            exampleSentence: card.exampleSentence,
            deckName: card.deckName,
            srsInterval: card.srsInterval,
            srsDueDate: card.srsDueDate,
            srsEaseFactor: card.srsEaseFactor,
            srsRepetitions: card.srsRepetitions,
            createdAt: card.resolvedCreatedAt,
            updatedAt: card.resolvedUpdatedAt,
            deletedAt: card.deletedAt,
            source: card.source
        )
    }

    private func makeDeleteRow(from card: VocabCard) -> DeleteRow {
        _ = card.ensureSyncMetadata()
        return DeleteRow(
            id: card.resolvedID.uuidString,
            ownerId: card.resolvedOwnerId,
            updatedAt: card.resolvedUpdatedAt,
            deletedAt: card.deletedAt ?? card.resolvedUpdatedAt
        )
    }
}

extension SyncCoordinator {
    @MainActor
    static var preview: SyncCoordinator {
        SyncCoordinator(configuration: GoogleSheetSyncConfiguration(baseURL: nil, apiKey: nil))
    }
}

private struct GoogleSheetSyncClient {
    let configuration: GoogleSheetSyncConfiguration
    private let session = URLSession.shared

    func fetchWords(ownerId: String) async throws -> [SheetWordRow] {
        guard let baseURL = configuration.baseURL else {
            throw SyncServiceError.notConfigured
        }

        var components = URLComponents(url: baseURL.appending(path: "words"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "ownerId", value: ownerId)]

        guard let url = components?.url else {
            throw SyncServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try Self.decoder.decode(WordsResponse.self, from: data).rows
    }

    func upsert(rows: [SheetWordRow]) async throws -> BatchResponse {
        try await send(
            path: "words/upsert",
            body: RowsBody(rows: rows)
        )
    }

    func delete(rows: [DeleteRow]) async throws -> BatchResponse {
        try await send(
            path: "words/delete",
            body: DeleteRowsBody(rows: rows)
        )
    }

    private func send<Body: Encodable>(path: String, body: Body) async throws -> BatchResponse {
        guard let baseURL = configuration.baseURL else {
            throw SyncServiceError.notConfigured
        }

        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        applyHeaders(to: &request)
        request.httpBody = try Self.encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try Self.decoder.decode(BatchResponse.self, from: data)
    }

    private func applyHeaders(to request: inout URLRequest) {
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-Jouzu-Api-Key")
        }
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SyncServiceError.httpError(httpResponse.statusCode)
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = SyncDateCodec.formatter.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected ISO-8601 date string."
                )
            }
            return date
        }
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(SyncDateCodec.formatter.string(from: date))
        }
        return encoder
    }()
}

private struct WordsResponse: Codable {
    let rows: [SheetWordRow]
}

private struct RowsBody: Codable {
    let rows: [SheetWordRow]
}

private struct DeleteRowsBody: Codable {
    let rows: [DeleteRow]
}

private struct DeleteRow: Codable, Sendable {
    let id: String
    let ownerId: String
    let updatedAt: Date
    let deletedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

private struct BatchResponse: Codable {
    let appliedIds: [String]
    let failed: [FailedRow]

    enum CodingKeys: String, CodingKey {
        case appliedIds = "applied_ids"
        case failed
    }
}

private struct FailedRow: Codable {
    let id: String
    let message: String
}

private enum SyncDateCodec {
    nonisolated(unsafe) static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return [] }

        var result: [[Element]] = []
        result.reserveCapacity((count / size) + 1)

        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }

        return result
    }
}
