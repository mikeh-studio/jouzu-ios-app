import Foundation

/// Implementation of the SM-2 spaced repetition algorithm (used by Anki)
///
/// Quality ratings:
///   0 - Complete blackout
///   1 - Incorrect; correct answer remembered upon seeing it
///   2 - Incorrect; correct answer seemed easy to recall
///   3 - Correct with serious difficulty
///   4 - Correct after hesitation
///   5 - Perfect response
enum SM2Algorithm {

    struct ReviewResult {
        let interval: Int        // Days until next review
        let easeFactor: Double   // Updated ease factor
        let repetitions: Int     // Updated repetition count
    }

    /// Calculate next review parameters based on quality of response
    /// - Parameters:
    ///   - quality: Rating from 0-5
    ///   - repetitions: Current consecutive correct count
    ///   - easeFactor: Current ease factor (minimum 1.3)
    ///   - interval: Current interval in days
    static func calculate(
        quality: Int,
        repetitions: Int,
        easeFactor: Double,
        interval: Int
    ) -> ReviewResult {
        let q = min(max(quality, 0), 5)

        if q < 3 {
            // Failed: reset repetitions, review again soon
            return ReviewResult(
                interval: 1,
                easeFactor: max(1.3, easeFactor - 0.2),
                repetitions: 0
            )
        }

        // Successful review
        let newRepetitions = repetitions + 1
        let newInterval: Int

        switch newRepetitions {
        case 1:
            newInterval = 1
        case 2:
            newInterval = 6
        default:
            newInterval = Int(round(Double(interval) * easeFactor))
        }

        // Update ease factor: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        let qd = Double(5 - q)
        let newEF = easeFactor + (0.1 - qd * (0.08 + qd * 0.02))

        return ReviewResult(
            interval: max(1, newInterval),
            easeFactor: max(1.3, newEF),
            repetitions: newRepetitions
        )
    }

    /// Simplified 4-button rating that maps to SM-2 quality scores
    enum Rating: Int, CaseIterable {
        case again = 1    // maps to quality 1
        case hard = 3     // maps to quality 3
        case good = 4     // maps to quality 4
        case easy = 5     // maps to quality 5

        var label: String {
            switch self {
            case .again: return "Again"
            case .hard: return "Hard"
            case .good: return "Good"
            case .easy: return "Easy"
            }
        }

        var color: String {
            switch self {
            case .again: return "red"
            case .hard: return "orange"
            case .good: return "green"
            case .easy: return "blue"
            }
        }
    }
}

extension VocabCard {
    /// Apply SM-2 review result to this card
    func applyReview(rating: SM2Algorithm.Rating) {
        let result = SM2Algorithm.calculate(
            quality: rating.rawValue,
            repetitions: srsRepetitions,
            easeFactor: srsEaseFactor,
            interval: srsInterval
        )

        srsInterval = result.interval
        srsEaseFactor = result.easeFactor
        srsRepetitions = result.repetitions
        srsDueDate = Calendar.current.date(
            byAdding: .day,
            value: result.interval,
            to: Date()
        ) ?? Date()
        markUpdated()
    }
}
