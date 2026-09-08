import SwiftUI

@main
struct VoyApp: App {
    @State private var appState = AppState()
    @State private var syncCoordinator = VoySyncCoordinator()

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environment(appState)
                .environment(syncCoordinator)
        }
        .modelContainer(appState.modelContainer)
    }
}
