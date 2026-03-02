import SwiftUI
import SwiftData

@main
struct JouzuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: VocabCard.self)
    }
}
