import SwiftUI

struct AppShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(AppSection.allCases, selection: $appState.selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch appState.selectedSection ?? .dashboard {
                case .dashboard:
                    DashboardView()
                case .projects:
                    ProjectWorkspaceView()
                case .resources:
                    ResourceWorkspaceView()
                case .risks:
                    RiskRegisterView()
                case .deliverables:
                    DeliverableBoardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $appState.isShowingProjectEditor) {
            ProjectEditorSheet()
        }
        .task {
            await store.loadIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.selectedSection = .projects
                    appState.isShowingProjectEditor = true
                } label: {
                    Label("Nouveau projet", systemImage: "plus")
                }
            }
        }
        .alert("Action impossible", isPresented: Binding(
            get: { store.lastErrorMessage != nil },
            set: { if $0 == false { store.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastErrorMessage ?? "Une erreur inconnue s'est produite.")
        }
    }
}
