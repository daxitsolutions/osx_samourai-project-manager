import SwiftUI

struct DeliverableBoardView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pilotage des livrables")
                .font(.largeTitle.weight(.semibold))

            if store.deliverables.isEmpty {
                ContentUnavailableView(
                    "Aucun livrable",
                    systemImage: "doc.badge.plus",
                    description: Text("Les livrables créés dans les projets seront visibles ici.")
                )
            } else {
                Table(store.deliverables) {
                    TableColumn("Livrable") { entry in
                        HStack {
                            Image(systemName: entry.deliverable.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(entry.deliverable.isDone ? .green : .secondary)
                            Text(entry.deliverable.title)
                        }
                    }

                    TableColumn("Projet") { entry in
                        Button(entry.projectName) {
                            appState.openProject(entry.projectID)
                        }
                        .buttonStyle(.link)
                    }

                    TableColumn("Owner") { entry in
                        Text(entry.deliverable.owner)
                    }

                    TableColumn("Échéance") { entry in
                        Text(entry.deliverable.dueDate.formatted(date: .abbreviated, time: .omitted))
                    }

                    TableColumn("Statut") { entry in
                        Text(entry.deliverable.isDone ? "Fait" : "Ouvert")
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
