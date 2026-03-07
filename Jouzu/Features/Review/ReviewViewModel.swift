import SwiftUI
import SwiftData

@Observable
final class ReviewViewModel {
    enum ReviewMode {
        case due
        case practiceAll
    }

    var dueCards: [VocabCard] = []
    var currentIndex = 0
    var isFlipped = false
    var sessionComplete = false
    var cardsReviewed = 0
    var reviewMode: ReviewMode = .due
    var updateSRS = false

    var currentCard: VocabCard? {
        guard currentIndex < dueCards.count else { return nil }
        return dueCards[currentIndex]
    }

    var remainingCount: Int {
        max(0, dueCards.count - currentIndex)
    }

    var isPracticeMode: Bool {
        reviewMode == .practiceAll
    }

    func loadDueCards(from context: ModelContext) {
        reviewMode = .due
        let now = Date()
        let predicate = #Predicate<VocabCard> { card in
            card.srsDueDate <= now
        }
        let descriptor = FetchDescriptor<VocabCard>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.srsDueDate)]
        )

        do {
            dueCards = try context.fetch(descriptor)
            currentIndex = 0
            isFlipped = false
            sessionComplete = dueCards.isEmpty
        } catch {
            dueCards = []
            sessionComplete = true
        }
    }

    func loadAllCards(from context: ModelContext) {
        reviewMode = .practiceAll
        updateSRS = false
        let descriptor = FetchDescriptor<VocabCard>()

        do {
            dueCards = try context.fetch(descriptor).shuffled()
            currentIndex = 0
            isFlipped = false
            cardsReviewed = 0
            sessionComplete = dueCards.isEmpty
        } catch {
            dueCards = []
            sessionComplete = true
        }
    }

    func flip() {
        isFlipped = true
    }

    func rate(_ rating: SM2Algorithm.Rating) {
        guard let card = currentCard else { return }

        if reviewMode == .due || updateSRS {
            card.applyReview(rating: rating)
        }

        cardsReviewed += 1
        currentIndex += 1
        isFlipped = false

        if currentIndex >= dueCards.count {
            sessionComplete = true
        }
    }
}
