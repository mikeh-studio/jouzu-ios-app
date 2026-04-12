import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    init(selectedTab: Int = 0) {
        _selectedTab = State(initialValue: selectedTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView()
                .tabItem {
                    Label("Capture", systemImage: "camera.fill")
                }
                .tag(0)

            VocabListView()
                .tabItem {
                    Label("Vocabulary", systemImage: "character.book.closed")
                }
                .tag(1)

            ReviewView()
                .tabItem {
                    Label("Review", systemImage: "rectangle.on.rectangle.angled")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.previewModelContainer)
        .environment(SyncCoordinator.preview)
}
