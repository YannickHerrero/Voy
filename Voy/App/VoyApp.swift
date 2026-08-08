import SwiftUI

@main
struct VoyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environment(appState)
        }
        .modelContainer(appState.modelContainer)
    }
}
