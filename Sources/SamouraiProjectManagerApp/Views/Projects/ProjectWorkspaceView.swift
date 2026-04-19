import SwiftUI

struct ProjectWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    var body: some View {
        @Bindable var appState = appState
        let projects = store.projects

        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Portefeuille projets")
                            .font(.title2.weight(.semibold))
                        Text("\(projects.count) projet(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        appState.isShowingProjectEditor = true
                    } label: {
                        Label("Nouveau projet", systemImage: "plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                List(projects, selection: $appState.selectedProjectID) { project in
                    ProjectListRow(
                        project: project,
                        onNameChange: { updatedName in
                            store.updateProjectQuick(projectID: project.id, name: updatedName, health: project.health)
                        },
                        onHealthChange: { updatedHealth in
                            store.updateProjectQuick(projectID: project.id, name: project.name, health: updatedHealth)
                        }
                    )
                        .tag(project.id)
                }
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
    let onNameChange: (String) -> Void
    let onHealthChange: (ProjectHealth) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(
                    "Nom du projet",
                    text: Binding(
                        get: { project.name },
                        set: { onNameChange($0) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.headline)
                Spacer()
                Picker(
                    "Santé",
                    selection: Binding(
                        get: { project.health },
                        set: { onHealthChange($0) }
                    )
                ) {
                    ForEach(ProjectHealth.allCases) { health in
                        Text(health.label).tag(health)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 18)
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
