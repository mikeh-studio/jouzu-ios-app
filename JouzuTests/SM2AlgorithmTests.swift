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
