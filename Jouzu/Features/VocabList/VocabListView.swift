import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct VocabListView: View {
    @Query private var allCards: [VocabCard]
    @State private var viewModel = VocabListViewModel()
    @State private var selectedCard: VocabCard?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if allCards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
            .navigationTitle("Vocabulary")
            .searchable(text: $viewModel.searchText, prompt: "Search words...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        importButton
                        if !allCards.isEmpty {
                            groupToggle
                            sortMenu
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $viewModel.showFileImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    viewModel.importResult = viewModel.importCSV(from: url, context: modelContext)
                case .failure:
                    viewModel.importResult = VocabListViewModel.ImportResult(
                        importedCount: 0, skippedCount: 0, errors: ["Could not open file."]
                    )
                }
            }
            .alert("Import Complete", isPresented: showImportAlert) {
                Button("OK") { viewModel.importResult = nil }
            } message: {
                if let r = viewModel.importResult {
                    Text(importSummary(r))
                }
            }
            .sheet(item: $selectedCard) { card in
                VocabDetailView(card: card)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Card List

    private var cardList: some View {
        List {
            filterChipsSection

            if viewModel.isGrouped {
                groupedContent
            } else {
                flatContent
            }
        }
        .listSectionSeparator(.hidden, edges: .top)
    }

    // MARK: - Filter Chips

    private var filterChipsSection: some View {
        Section {
            let filters = viewModel.availableFilters(allCards)
            if !filters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            count: allCards.count,
                            isSelected: viewModel.selectedFilters.isEmpty,
                            color: .secondary
                        ) {
                            viewModel.selectedFilters.removeAll()
                        }

                        ForEach(filters, id: \.self) { pos in
                            let count = allCards.filter { $0.partOfSpeech == pos }.count
                            FilterChip(
                                title: pos,
                                count: count,
                                isSelected: viewModel.selectedFilters.contains(pos),
                                color: GrammarHighlighter.color(forDisplayName: pos)
                            ) {
                                if viewModel.selectedFilters.contains(pos) {
                                    viewModel.selectedFilters.remove(pos)
                                } else {
                                    viewModel.selectedFilters.insert(pos)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }

    // MARK: - Flat Content

    @ViewBuilder
    private var flatContent: some View {
        let filtered = viewModel.filteredCards(allCards)

        if filtered.isEmpty {
            noResultsView
        } else {
            ForEach(filtered) { card in
                VocabCardRow(card: card)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedCard = card }
            }
            .onDelete { indexSet in
                let filtered = viewModel.filteredCards(allCards)
                for index in indexSet {
                    modelContext.delete(filtered[index])
                }
            }
        }
    }

    // MARK: - Grouped Content

    @ViewBuilder
    private var groupedContent: some View {
        let groups = viewModel.groupedCards(allCards)

        if groups.isEmpty {
            noResultsView
        } else {
            ForEach(groups, id: \.0) { posName, cards in
                Section {
                    ForEach(cards) { card in
                        VocabCardRow(card: card)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedCard = card }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(cards[index])
                        }
                    }
                } header: {
                    HStack {
                        Text(posName)
                            .foregroundStyle(GrammarHighlighter.color(forDisplayName: posName))
                        Text("\(cards.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - No Results

    @ViewBuilder
    private var noResultsView: some View {
        if !viewModel.searchText.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            ContentUnavailableView(
                "No Matches",
                systemImage: "line.3.horizontal.decrease",
                description: Text("No cards match the selected filters.")
            )
        }
    }

    // MARK: - Group Toggle

    private var groupToggle: some View {
        Button {
            withAnimation {
                viewModel.isGrouped.toggle()
            }
        } label: {
            Image(systemName: viewModel.isGrouped ? "list.bullet.indent" : "list.bullet")
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(VocabListViewModel.SortOrder.allCases, id: \.self) { order in
                Button {
                    viewModel.sortOrder = order
                } label: {
                    HStack {
                        Text(order.rawValue)
                        if viewModel.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    // MARK: - Import

    private var importButton: some View {
        Button {
            viewModel.showFileImporter = true
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
    }

    private var showImportAlert: Binding<Bool> {
        Binding(
            get: { viewModel.importResult != nil },
            set: { if !$0 { viewModel.importResult = nil } }
        )
    }

    private func importSummary(_ result: VocabListViewModel.ImportResult) -> String {
        var parts: [String] = []
        parts.append("Imported \(result.importedCount) card\(result.importedCount == 1 ? "" : "s").")
        if result.skippedCount > 0 {
            parts.append("Skipped \(result.skippedCount) duplicate\(result.skippedCount == 1 ? "" : "s").")
        }
        if !result.errors.isEmpty {
            parts.append("\(result.errors.count) row\(result.errors.count == 1 ? "" : "s") had errors.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Vocabulary Yet",
            systemImage: "character.book.closed",
            description: Text("Take a photo of Japanese text and tap words to save them here.")
        )
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? color : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? color : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Row

private struct VocabCardRow: View {
    let card: VocabCard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.word)
                    .font(.headline)

                if !card.reading.isEmpty {
                    Text(card.reading)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(card.definition)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                if !card.partOfSpeech.isEmpty {
                    Text(card.partOfSpeech)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(GrammarHighlighter.color(forDisplayName: card.partOfSpeech).opacity(0.1))
                        .foregroundStyle(GrammarHighlighter.color(forDisplayName: card.partOfSpeech))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(card.dateCreated, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

}

#Preview("With Cards") {
    VocabListView()
        .modelContainer(PreviewSampleData.previewModelContainer)
}

#Preview("Empty") {
    VocabListView()
        .modelContainer(for: VocabCard.self, inMemory: true)
}
