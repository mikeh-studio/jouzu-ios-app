import SwiftUI
import SwiftData

#if DEBUG
enum ScreenshotDestination: String {
    case home
    case analysis
    case analysisDetail = "analysis-detail"
    case vocabulary
    case review

    static var current: ScreenshotDestination? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"),
              arguments.indices.contains(arguments.index(after: index)) else {
            return nil
        }

        return ScreenshotDestination(rawValue: arguments[arguments.index(after: index)])
    }
}

@MainActor
struct ScreenshotRootView: View {
    let destination: ScreenshotDestination
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        screenshotContent
            .task(id: destination) {
                seedSampleCardsIfNeeded()
            }
    }

    @ViewBuilder
    private var screenshotContent: some View {
        switch destination {
        case .home:
            ContentView(selectedTab: 0)
        case .analysis:
            NavigationStack {
                AnalysisView(viewModel: AnalysisViewModel(result: PreviewSampleData.sampleAnalysisResult))
            }
        case .analysisDetail:
            AnalysisDetailScreenshotView()
        case .vocabulary:
            ContentView(selectedTab: 1)
        case .review:
            ReviewView(viewModel: screenshotReviewViewModel(), loadsCardsOnAppear: false)
        }
    }

    private func screenshotReviewViewModel() -> ReviewViewModel {
        let viewModel = ReviewViewModel()
        viewModel.dueCards = Array(screenshotSampleCards().prefix(2))
        viewModel.currentIndex = 0
        viewModel.isFlipped = true
        viewModel.sessionComplete = false
        viewModel.cardsReviewed = 0
        viewModel.reviewMode = .due
        viewModel.updateSRS = false
        return viewModel
    }

    private func seedSampleCardsIfNeeded() {
        guard destination == .vocabulary || destination == .review else { return }

        let descriptor = FetchDescriptor<VocabCard>()
        guard ((try? modelContext.fetchCount(descriptor)) ?? 0) == 0 else { return }

        for card in screenshotSampleCards() {
            modelContext.insert(card)
        }

        try? modelContext.save()
    }

    private func screenshotSampleCards() -> [VocabCard] {
        [
            PreviewSampleData.sampleVocabCard(word: "食べる", reading: "たべる", definition: "to eat", partOfSpeech: "Verb", dueInDays: -1),
            PreviewSampleData.sampleVocabCard(word: "魚", reading: "さかな", definition: "fish", partOfSpeech: "Noun", dueInDays: 0),
            PreviewSampleData.sampleVocabCard(word: "学校", reading: "がっこう", definition: "school", partOfSpeech: "Noun", dueInDays: 3),
            PreviewSampleData.sampleVocabCard(word: "美味しい", reading: "おいしい", definition: "delicious", partOfSpeech: "i-Adjective", dueInDays: 1),
        ]
    }
}

private struct AnalysisDetailScreenshotView: View {
    private let token = PreviewSampleData.sampleTokens[3]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemGray6),
                    Color(.systemGray5),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            WordPopoverView(
                token: token,
                sourceText: PreviewSampleData.sampleText,
                sourceImage: PreviewSampleData.sampleAnalysisResult.originalImage,
                onDismiss: {}
            )
            .frame(maxWidth: 340)
            .padding(24)
        }
    }
}
#endif
