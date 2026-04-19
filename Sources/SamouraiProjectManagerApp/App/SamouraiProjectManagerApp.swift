import SwiftUI

@main
struct SamouraiProjectManagerApp: App {
    @State private var appState = AppState()
    @State private var store = SamouraiStore()

    var body: some Scene {
        WindowGroup("Samourai Project Manager") {
            AppShellView()
                .environment(appState)
                .environment(store)
                .tint(SamouraiColorTheme.color(.brandPurple))
        }
        .defaultSize(width: 1_480, height: 920)
        .commands {
            SidebarCommands()
        }
    }
}
