import SwiftUI
import SwiftData

@Observable
final class ReviewViewModel {
    var dueCards: [VocabCard] = []
    var currentIndex = 0
    var isFlipped = false
    var sessionComplete = false
    var cardsReviewed = 0

    var currentCard: VocabCard? {
        guard currentIndex < dueCards.count else { return nil }
        return dueCards[currentIndex]
    }

    var remainingCount: Int {
        max(0, dueCards.count - currentIndex)
    }

    func loadDueCards(from context: ModelContext) {
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

    func flip() {
        isFlipped = true
    }

    func rate(_ rating: SM2Algorithm.Rating) {
        guard let card = currentCard else { return }
        card.applyReview(rating: rating)
        cardsReviewed += 1

        currentIndex += 1
        isFlipped = false

        if currentIndex >= dueCards.count {
            sessionComplete = true
        }
    }
}
