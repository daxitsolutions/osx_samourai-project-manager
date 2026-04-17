import SwiftUI

struct ProjectWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    var body: some View {
        @Bindable var appState = appState
        let projects = store.projects

        HSplitView {
            List(projects, selection: $appState.selectedProjectID) { project in
                ProjectListRow(project: project)
                    .tag(project.id)
            }
            .frame(minWidth: 280, idealWidth: 320)
            .overlay {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "Aucun projet",
                        systemImage: "square.grid.2x2",
                        description: Text("Ajoute un projet pour commencer ton pilotage Samourai.")
                    )
                }
            }

            Group {
                if let selectedProjectID = appState.selectedProjectID {
                    ProjectDetailView(projectID: selectedProjectID)
                } else {
                    ContentUnavailableView(
                        "Sélectionne un projet",
                        systemImage: "sidebar.left",
                        description: Text("La vue détail t'aidera à tenir les risques, livrables et jalons sous contrôle.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ProjectListRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.name)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(Color(project.health.tintName))
                    .frame(width: 10, height: 10)
            }

            Text(project.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text(project.phase.label)
                Spacer()
                Text(project.targetDate.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
