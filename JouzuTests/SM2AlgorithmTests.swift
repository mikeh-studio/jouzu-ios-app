import XCTest
import UIKit
import SQLite3
@testable import Jouzu

final class SM2AlgorithmTests: XCTestCase {
    func testFirstSuccessfulReviewStartsAtOneDay() {
        let result = SM2Algorithm.calculate(quality: 4, repetitions: 0, easeFactor: 2.5, interval: 0)

        XCTAssertEqual(result.repetitions, 1)
        XCTAssertEqual(result.interval, 1)
        XCTAssertEqual(result.easeFactor, 2.5, accuracy: 0.0001)
    }

    func testSecondSuccessfulReviewSetsSixDayInterval() {
        let result = SM2Algorithm.calculate(quality: 4, repetitions: 1, easeFactor: 2.5, interval: 1)

        XCTAssertEqual(result.repetitions, 2)
        XCTAssertEqual(result.interval, 6)
        XCTAssertEqual(result.easeFactor, 2.5, accuracy: 0.0001)
    }

    func testThirdSuccessfulReviewUsesEaseFactorMultiplier() {
        let result = SM2Algorithm.calculate(quality: 5, repetitions: 2, easeFactor: 2.5, interval: 6)

        XCTAssertEqual(result.repetitions, 3)
        XCTAssertEqual(result.interval, 15)
        XCTAssertEqual(result.easeFactor, 2.6, accuracy: 0.0001)
    }

    func testFailedReviewResetsRepetitionsAndReducesEaseFactor() {
        let result = SM2Algorithm.calculate(quality: 1, repetitions: 4, easeFactor: 2.0, interval: 20)

        XCTAssertEqual(result.repetitions, 0)
        XCTAssertEqual(result.interval, 1)
        XCTAssertEqual(result.easeFactor, 1.8, accuracy: 0.0001)
    }

    func testEaseFactorNeverDropsBelowMinimum() {
        let result = SM2Algorithm.calculate(quality: 0, repetitions: 10, easeFactor: 1.31, interval: 30)

        XCTAssertEqual(result.easeFactor, 1.3, accuracy: 0.0001)
    }

    func testQualityInputIsClampedToValidRange() {
        let low = SM2Algorithm.calculate(quality: -10, repetitions: 1, easeFactor: 2.5, interval: 6)
        let high = SM2Algorithm.calculate(quality: 10, repetitions: 2, easeFactor: 2.5, interval: 6)

        XCTAssertEqual(low.repetitions, 0)
        XCTAssertEqual(low.interval, 1)
        XCTAssertEqual(high.repetitions, 3)
        XCTAssertEqual(high.interval, 15)
    }
}

final class PartOfSpeechNormalizationTests: XCTestCase {
    func testDictionaryPOSNormalization() {
        XCTAssertEqual(PartOfSpeech(dictionaryPOS: "verb"), .verb)
        XCTAssertEqual(PartOfSpeech(dictionaryPOS: "noun"), .noun)
        XCTAssertEqual(PartOfSpeech(dictionaryPOS: "i-adjective"), .iAdjective)
        XCTAssertEqual(PartOfSpeech(dictionaryPOS: "na-adjective"), .naAdjective)
        XCTAssertEqual(PartOfSpeech(dictionaryPOS: "particle"), .particle)
        XCTAssertEqual(PartOfSpeech(dictionaryPOS: "symbol"), .symbol)
        XCTAssertEqual(PartOfSpeech(dictionaryPOS: "unknown-value"), .unknown)
    }
}

final class ExampleSentenceExtractorTests: XCTestCase {
    func testReturnsSentenceContainingSurfaceForm() {
        let token = Token(
            surface: "猫",
            reading: "ねこ",
            partOfSpeech: .noun,
            baseForm: "猫",
            inflectionType: nil,
            inflectionForm: nil
        )

        let text = "今日は雨です。猫が魚を食べる。明日は晴れです。"
        let result = ExampleSentenceExtractor.extract(from: text, token: token)

        XCTAssertEqual(result, "猫が魚を食べる。")
    }

    func testReturnsSentenceContainingBaseFormWhenSurfaceNotPresent() {
        let token = Token(
            surface: "食べた",
            reading: "たべた",
            partOfSpeech: .verb,
            baseForm: "食べる",
            inflectionType: nil,
            inflectionForm: nil
        )

        let text = "昨日は寿司を食べる。とても美味しかった。"
        let result = ExampleSentenceExtractor.extract(from: text, token: token)

        XCTAssertEqual(result, "昨日は寿司を食べる。")
    }

    func testReturnsNilForFragmentWithoutSentenceTerminator() {
        let token = Token(
            surface: "猫",
            reading: "ねこ",
            partOfSpeech: .noun,
            baseForm: "猫",
            inflectionType: nil,
            inflectionForm: nil
        )

        let text = "猫が魚を食べる"
        let result = ExampleSentenceExtractor.extract(from: text, token: token)

        XCTAssertNil(result)
    }

    func testReturnsNilWhenNoSentenceContainsToken() {
        let token = Token(
            surface: "猫",
            reading: "ねこ",
            partOfSpeech: .noun,
            baseForm: "猫",
            inflectionType: nil,
            inflectionForm: nil
        )

        let text = "今日は雨です。明日は晴れです。"
        let result = ExampleSentenceExtractor.extract(from: text, token: token)

        XCTAssertNil(result)
    }
}

final class JapaneseTokenFilterTests: XCTestCase {
    func testContainsJapaneseScript() {
        XCTAssertTrue(JapaneseTokenFilter.containsJapaneseScript("猫"))
        XCTAssertTrue(JapaneseTokenFilter.containsJapaneseScript("ねこ"))
        XCTAssertTrue(JapaneseTokenFilter.containsJapaneseScript("カタカナ"))
        XCTAssertTrue(JapaneseTokenFilter.containsJapaneseScript("iPhoneケース"))

        XCTAssertFalse(JapaneseTokenFilter.containsJapaneseScript("hello"))
        XCTAssertFalse(JapaneseTokenFilter.containsJapaneseScript("12345"))
        XCTAssertFalse(JapaneseTokenFilter.containsJapaneseScript("!?.,"))
    }

    func testFilterWordsRemovesNonJapaneseAndParticles() {
        let tokens: [Token] = [
            Token(surface: "猫", reading: "ねこ", partOfSpeech: .noun, baseForm: "猫", inflectionType: nil, inflectionForm: nil),
            Token(surface: "は", reading: "は", partOfSpeech: .particle, baseForm: "は", inflectionType: nil, inflectionForm: nil),
            Token(surface: "iPhoneケース", reading: "", partOfSpeech: .noun, baseForm: "iPhoneケース", inflectionType: nil, inflectionForm: nil),
            Token(surface: "SALE", reading: "", partOfSpeech: .noun, baseForm: "SALE", inflectionType: nil, inflectionForm: nil),
            Token(surface: "2026", reading: "", partOfSpeech: .noun, baseForm: "2026", inflectionType: nil, inflectionForm: nil),
        ]

        let filtered = JapaneseTokenFilter.filterWords(tokens)
        let surfaces = filtered.map(\.surface)

        XCTAssertEqual(surfaces, ["猫", "iPhoneケース"])
    }

    func testUniqueVocabularyTokensDeduplicatesByBaseForm() {
        let tokens: [Token] = [
            Token(surface: "食べた", reading: "たべた", partOfSpeech: .verb, baseForm: "食べる", inflectionType: nil, inflectionForm: nil),
            Token(surface: "食べる", reading: "たべる", partOfSpeech: .verb, baseForm: "食べる", inflectionType: nil, inflectionForm: nil),
            Token(surface: "猫", reading: "ねこ", partOfSpeech: .noun, baseForm: "猫", inflectionType: nil, inflectionForm: nil),
        ]

        let filtered = JapaneseTokenFilter.uniqueVocabularyTokens(from: tokens)

        XCTAssertEqual(filtered.map(\.surface), ["食べた", "猫"])
    }

    func testUniqueVocabularyTokensFiltersGrammarDenyList() {
        let tokens: [Token] = [
            Token(surface: "です", reading: "です", partOfSpeech: .unknown, baseForm: "です", inflectionType: nil, inflectionForm: nil),
            Token(surface: "ます", reading: "ます", partOfSpeech: .unknown, baseForm: "ます", inflectionType: nil, inflectionForm: nil),
            Token(surface: "た", reading: "た", partOfSpeech: .unknown, baseForm: "た", inflectionType: nil, inflectionForm: nil),
            Token(surface: "ました", reading: "ました", partOfSpeech: .unknown, baseForm: "ます", inflectionType: nil, inflectionForm: nil),
            Token(surface: "食べる", reading: "たべる", partOfSpeech: .verb, baseForm: "食べる", inflectionType: nil, inflectionForm: nil),
        ]

        let filtered = JapaneseTokenFilter.uniqueVocabularyTokens(from: tokens)

        XCTAssertEqual(filtered.map(\.surface), ["食べる"])
    }

    func testUniqueVocabularyTokensRemovesSingleHiraganaAndGrammarTokens() {
        let tokens: [Token] = [
            Token(surface: "で", reading: "で", partOfSpeech: .particle, baseForm: "で", inflectionType: nil, inflectionForm: nil),
            Token(surface: "は", reading: "は", partOfSpeech: .noun, baseForm: "は", inflectionType: nil, inflectionForm: nil),
            Token(surface: "です", reading: "です", partOfSpeech: .auxiliaryVerb, baseForm: "です", inflectionType: nil, inflectionForm: nil),
            Token(surface: "すごい", reading: "すごい", partOfSpeech: .iAdjective, baseForm: "すごい", inflectionType: nil, inflectionForm: nil),
            Token(surface: "カメラ", reading: "かめら", partOfSpeech: .noun, baseForm: "カメラ", inflectionType: nil, inflectionForm: nil),
        ]

        let filtered = JapaneseTokenFilter.uniqueVocabularyTokens(from: tokens)

        XCTAssertEqual(filtered.map(\.surface), ["すごい", "カメラ"])
    }
}

final class AnalysisTextFormatterTests: XCTestCase {
    func testNormalizedSourceTextCollapsesLinesAndWhitespace() {
        let text = "  一行目  \n\n 二行目\t\n三行目  "

        let cleaned = AnalysisTextFormatter.normalizedSourceText(from: text)

        XCTAssertEqual(cleaned, "一行目 二行目 三行目")
    }

    func testCleanedTranslationCollapsesWhitespace() {
        let translation = "  The   cat\n\n ate\t fish.  "

        let cleaned = AnalysisTextFormatter.cleanedTranslation(translation)

        XCTAssertEqual(cleaned, "The cat ate fish.")
    }
}

final class VocabCardSyncMetadataTests: XCTestCase {
    func testEnsureSyncMetadataBackfillsMissingSyncFields() {
        let originalDate = Date(timeIntervalSince1970: 1_712_345_678)
        let card = VocabCard(
            id: nil,
            ownerId: nil,
            word: "猫",
            reading: "ねこ",
            definition: "cat",
            partOfSpeech: "Noun",
            dateCreated: originalDate
        )
        card.createdAt = nil
        card.updatedAt = nil
        card.syncStateRaw = nil

        let didChange = card.ensureSyncMetadata(defaultOwnerId: "owner-123")

        XCTAssertTrue(didChange)
        XCTAssertEqual(card.ownerId, "owner-123")
        XCTAssertNotNil(card.id)
        XCTAssertEqual(card.createdAt, originalDate)
        XCTAssertEqual(card.updatedAt, originalDate)
        XCTAssertEqual(card.syncState, .pendingCreate)
    }
}

@MainActor
final class AnalysisViewModelTests: XCTestCase {
    func testTranslationLifecycleTransitionsWithoutBlockingResult() {
        let baseResult = AnalysisResult(
            originalImage: UIImage(),
            recognizedText: "猫 食べる",
            tokens: [
                Token(surface: "猫", reading: "ねこ", partOfSpeech: .noun, baseForm: "猫", inflectionType: nil, inflectionForm: nil),
                Token(surface: "食べる", reading: "たべる", partOfSpeech: .verb, baseForm: "食べる", inflectionType: nil, inflectionForm: nil),
            ]
        )

        let viewModel = AnalysisViewModel(result: baseResult)

        XCTAssertEqual(viewModel.translationState, .idle)
        XCTAssertNil(viewModel.translation)

        viewModel.beginTranslation()
        XCTAssertEqual(viewModel.translationState, .loading)

        let enrichedTokens = [
            Token(surface: "猫", reading: "ねこ", partOfSpeech: .noun, baseForm: "猫", inflectionType: nil, inflectionForm: nil, definitions: ["cat"]),
            Token(surface: "食べる", reading: "たべる", partOfSpeech: .verb, baseForm: "食べる", inflectionType: nil, inflectionForm: nil, definitions: ["to eat"]),
        ]
        viewModel.applyEnrichment(tokens: enrichedTokens, translation: "The cat eats.")

        XCTAssertEqual(viewModel.translationState, .complete)
        XCTAssertEqual(viewModel.translation, "The cat eats.")
        XCTAssertEqual(viewModel.result.tokens[0].definitions, ["cat"])
    }

    func testMarkTranslationUnavailableOnlyAffectsMissingTranslation() {
        let baseResult = AnalysisResult(
            originalImage: UIImage(),
            recognizedText: "ねこ",
            tokens: [Token(surface: "ねこ", reading: "ねこ", partOfSpeech: .noun, baseForm: "ねこ", inflectionType: nil, inflectionForm: nil)]
        )

        let viewModel = AnalysisViewModel(result: baseResult)
        viewModel.beginTranslation()
        viewModel.markTranslationUnavailable()

        XCTAssertEqual(viewModel.translationState, .unavailable)
        XCTAssertTrue(viewModel.showTranslationUnavailable)
    }
}

final class DictionaryServiceTests: XCTestCase {
    func testUsesCustomDatabaseWhenProvided() throws {
        let databasePath = try makeDictionaryDatabase(entries: [
            ("試験", "しけん", "exam; test", "noun", 2, nil),
        ])

        let service = DictionaryService(databasePath: databasePath)
        let entries = service.lookup(word: "試験")

        XCTAssertEqual(service.databaseSource, .custom)
        XCTAssertEqual(entries.first?.definitions, ["exam", "test"])
    }

    func testFallsBackToDevelopmentDatabaseWhenCustomDatabaseIsMissing() {
        let service = DictionaryService(databasePath: "/tmp/does-not-exist-jouzu.sqlite")
        let entries = service.lookup(word: "猫")

        XCTAssertEqual(service.databaseSource, .development)
        XCTAssertEqual(entries.first?.definitions, ["cat"])
    }

    func testEnrichTokensFallsBackToReadingLookup() throws {
        let databasePath = try makeDictionaryDatabase(entries: [
            ("猫", "ねこ", "cat", "noun", 1, nil),
        ])

        let service = DictionaryService(databasePath: databasePath)
        let token = Token(
            surface: "ネコ",
            reading: "ねこ",
            partOfSpeech: .noun,
            baseForm: "ネコ",
            inflectionType: nil,
            inflectionForm: nil
        )

        let enriched = service.enrichTokens([token])

        XCTAssertEqual(enriched.first?.definitions, ["cat"])
    }

    func testEnrichTokensPrefersBaseFormBeforeSurface() throws {
        let databasePath = try makeDictionaryDatabase(entries: [
            ("食べる", "たべる", "to eat", "verb", 1, nil),
        ])

        let service = DictionaryService(databasePath: databasePath)
        let token = Token(
            surface: "食べた",
            reading: "たべた",
            partOfSpeech: .verb,
            baseForm: "食べる",
            inflectionType: nil,
            inflectionForm: nil
        )

        let enriched = service.enrichTokens([token])

        XCTAssertEqual(enriched.first?.definitions, ["to eat"])
    }

    func testLookupReturnsJLPTLevelWhenPresent() throws {
        let databasePath = try makeDictionaryDatabase(entries: [
            ("猫", "ねこ", "cat", "noun", 1, 4),
        ])

        let service = DictionaryService(databasePath: databasePath)
        let entries = service.lookup(word: "猫")

        XCTAssertEqual(entries.first?.jlptLevel, 4)
    }

    func testLookupReturnsNilJLPTLevelForUnclassifiedWord() throws {
        let databasePath = try makeDictionaryDatabase(entries: [
            ("薔薇", "ばら", "rose", "noun", 1, nil),
        ])

        let service = DictionaryService(databasePath: databasePath)
        let entries = service.lookup(word: "薔薇")

        XCTAssertNil(entries.first?.jlptLevel)
    }

    func testEnrichTokensPassesJLPTLevel() throws {
        let databasePath = try makeDictionaryDatabase(entries: [
            ("食べる", "たべる", "to eat", "verb", 1, 5),
        ])

        let service = DictionaryService(databasePath: databasePath)
        let token = Token(
            surface: "食べた",
            reading: "たべた",
            partOfSpeech: .verb,
            baseForm: "食べる",
            inflectionType: nil,
            inflectionForm: nil
        )

        let enriched = service.enrichTokens([token])

        XCTAssertEqual(enriched.first?.jlptLevel, 5)
    }

    private func makeDictionaryDatabase(entries: [(String, String, String, String, Int32, Int32?)]) throws -> String {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        var db: OpaquePointer?
        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            throw NSError(domain: "DictionaryServiceTests", code: 1)
        }

        defer {
            sqlite3_close(db)
        }

        let createSQL = """
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY,
            kanji TEXT,
            reading TEXT,
            definition TEXT,
            pos TEXT,
            priority INTEGER DEFAULT 9999,
            jlpt_level INTEGER
        );
        CREATE INDEX idx_kanji ON entries(kanji);
        CREATE INDEX idx_reading ON entries(reading);
        """
        XCTAssertEqual(sqlite3_exec(db, createSQL, nil, nil, nil), SQLITE_OK)

        let insertSQL = "INSERT INTO entries (kanji, reading, definition, pos, priority, jlpt_level) VALUES (?, ?, ?, ?, ?, ?)"
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil), SQLITE_OK)

        for entry in entries {
            sqlite3_bind_text(statement, 1, (entry.0 as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (entry.1 as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (entry.2 as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (entry.3 as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 5, entry.4)
            if let jlpt = entry.5 {
                sqlite3_bind_int(statement, 6, jlpt)
            } else {
                sqlite3_bind_null(statement, 6)
            }
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }

        sqlite3_finalize(statement)
        return fileURL.path
    }
}
