import XCTest
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
}
