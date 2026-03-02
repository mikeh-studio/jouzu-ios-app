import SwiftUI
import SwiftData

@Observable
final class VocabListViewModel {
    var searchText = ""
    var sortOrder: SortOrder = .dateNewest
    var selectedFilters: Set<String> = []
    var isGrouped: Bool = false
    var showFileImporter = false
    var importResult: ImportResult?

    struct ImportResult {
        let importedCount: Int
        let skippedCount: Int
        let errors: [String]
    }

    enum SortOrder: String, CaseIterable {
        case dateNewest = "Newest"
        case dateOldest = "Oldest"
        case alphabetical = "A-Z"
        case dueDate = "Due Date"
    }

    func availableFilters(_ cards: [VocabCard]) -> [String] {
        let posValues = Set(cards.map(\.partOfSpeech)).filter { !$0.isEmpty }
        return posValues.sorted()
    }

    func filteredCards(_ cards: [VocabCard]) -> [VocabCard] {
        var result = cards

        // Filter by POS
        if !selectedFilters.isEmpty {
            result = result.filter { selectedFilters.contains($0.partOfSpeech) }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { card in
                card.word.localizedCaseInsensitiveContains(searchText) ||
                card.reading.localizedCaseInsensitiveContains(searchText) ||
                card.definition.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOrder {
        case .dateNewest:
            result.sort { $0.dateCreated > $1.dateCreated }
        case .dateOldest:
            result.sort { $0.dateCreated < $1.dateCreated }
        case .alphabetical:
            result.sort { $0.word < $1.word }
        case .dueDate:
            result.sort { $0.srsDueDate < $1.srsDueDate }
        }

        return result
    }

    func groupedCards(_ cards: [VocabCard]) -> [(String, [VocabCard])] {
        let filtered = filteredCards(cards)
        let grouped = Dictionary(grouping: filtered) { $0.partOfSpeech.isEmpty ? "Other" : $0.partOfSpeech }
        return grouped.sorted { $0.key < $1.key }
    }

    // MARK: - CSV Import

    private static let maxFileSize: UInt64 = 5 * 1024 * 1024 // 5 MB
    private static let maxRowCount = 5_000

    func importCSV(from url: URL, context: ModelContext) -> ImportResult {
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gotAccess { url.stopAccessingSecurityScopedResource() }
        }

        // Check file size before loading into memory
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attrs[.size] as? UInt64,
           fileSize > Self.maxFileSize {
            return ImportResult(importedCount: 0, skippedCount: 0, errors: ["File too large (max 5 MB)."])
        }

        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return ImportResult(importedCount: 0, skippedCount: 0, errors: ["Could not read file as UTF-8 text."])
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else {
            return ImportResult(importedCount: 0, skippedCount: 0, errors: ["File is empty."])
        }

        var startIndex = 0
        let firstFields = parseCSVLine(lines[0])
        if firstFields.count >= 3 {
            let lower = firstFields.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            if lower[0] == "word" && lower[1] == "reading" && lower[2] == "definition" {
                startIndex = 1
            }
        }

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        let rowLimit = min(lines.count, startIndex + Self.maxRowCount)
        let rowsSkippedByLimit = lines.count - rowLimit

        for i in startIndex..<rowLimit {
            let fields = parseCSVLine(lines[i])
            guard fields.count >= 3 else {
                errors.append("Row \(i + 1): expected at least 3 columns, got \(fields.count).")
                continue
            }

            let word = fields[0].trimmingCharacters(in: .whitespaces)
            let reading = fields[1].trimmingCharacters(in: .whitespaces)
            let definition = fields[2].trimmingCharacters(in: .whitespaces)

            guard !word.isEmpty else {
                errors.append("Row \(i + 1): word is empty.")
                continue
            }

            // Check for duplicate
            let descriptor = FetchDescriptor<VocabCard>(predicate: #Predicate { $0.word == word })
            let existingCount = (try? context.fetchCount(descriptor)) ?? 0
            if existingCount > 0 {
                skipped += 1
                continue
            }

            let card = VocabCard(
                word: word,
                reading: reading,
                definition: definition,
                partOfSpeech: "",
                exampleSentence: ""
            )
            context.insert(card)
            imported += 1
        }

        if rowsSkippedByLimit > 0 {
            errors.append("File contained \(lines.count - startIndex) rows; only the first \(Self.maxRowCount) were imported.")
        }

        return ImportResult(importedCount: imported, skippedCount: skipped, errors: errors)
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var chars = line.makeIterator()

        while let c = chars.next() {
            if inQuotes {
                if c == "\"" {
                    // Check for escaped quote ("")
                    if let next = chars.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else {
                            inQuotes = false
                            if next == "," {
                                fields.append(current)
                                current = ""
                            } else {
                                current.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            }
        }
        fields.append(current)
        return fields
    }
}
