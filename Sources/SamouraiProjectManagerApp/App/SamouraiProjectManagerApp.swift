import SwiftUI

@main
struct SamouraiProjectManagerApp: App {
    @State private var appState = AppState()
    @State private var store = SamouraiStore()
    @State private var typography = SamouraiTypography()

    var body: some Scene {
        WindowGroup("Samourai Project Manager") {
            AppShellView()
                .environment(appState)
                .environment(store)
                .environment(typography)
                .environment(\.dynamicTypeSize, appState.dynamicTypeSize)
                .tint(SamouraiColorTheme.color(.brandBlue))
                .task { typography.fontSizeOffset = appState.fontSizeOffset }
                .onChange(of: appState.fontSizeOffset) { _, offset in
                    typography.fontSizeOffset = offset
                }
        }
        .defaultSize(width: 1_480, height: 920)
        .commands {
            SidebarCommands()
        }
    }
}
