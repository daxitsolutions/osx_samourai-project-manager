import SwiftUI

struct ResourceDirectoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SamouraiStore.self) private var store

    let projectID: UUID
    let projectName: String

    @State private var searchText = ""
    @State private var selectedResourceIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                content
                Divider()
                footer
            }
            .frame(minWidth: 560, idealWidth: 680, minHeight: 480, idealHeight: 620)
            .navigationTitle("Ajouter depuis l'annuaire")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sélectionner une ou plusieurs ressources de l'annuaire global à affecter à \(projectName).")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Rechercher dans l'annuaire", text: $searchText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("\(availableResources.count) ressource(s) disponible(s) — \(selectedResourceIDs.count) sélectionnée(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if selectedResourceIDs.isEmpty == false {
                    Button("Tout désélectionner") { selectedResourceIDs.removeAll() }
                        .buttonStyle(.plain)
                        .font(.caption)
                }
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        if store.resources.isEmpty {
            ContentUnavailableView(
                "Annuaire vide",
                systemImage: "person.3",
                description: Text("Ajoute des ressources dans l'annuaire global avant de les affecter à un projet.")
            )
        } else if availableResources.isEmpty {
            ContentUnavailableView(
                "Toutes les ressources sont déjà affectées",
                systemImage: "checkmark.seal",
                description: Text("Aucune ressource disponible dans l'annuaire n'est actuellement libre pour ce projet.")
            )
        } else if filteredResources.isEmpty {
            ContentUnavailableView(
                "Aucun résultat",
                systemImage: "magnifyingglass",
                description: Text("Ajuste la recherche pour retrouver une ressource.")
            )
        } else {
            List(filteredResources, id: \.id) { resource in
                row(for: resource)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleSelection(resource.id) }
            }
            .listStyle(.inset)
        }
    }

    private func row(for resource: Resource) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selectedResourceIDs.contains(resource.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedResourceIDs.contains(resource.id) ? Color.accentColor : Color.secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(resource.displayName)
                    .font(.body.weight(.medium))
                HStack(spacing: 8) {
                    if resource.jobTitle.isEmpty == false {
                        Text(resource.jobTitle)
                    }
                    if resource.department.isEmpty == false {
                        Text("·")
                        Text(resource.department)
                    }
                    if resource.email.isEmpty == false {
                        Text("·")
                        Text(resource.email)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(resource.assignedProjectIDs.count) projet(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Annuler") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Ajouter au projet") { applySelection() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedResourceIDs.isEmpty)
        }
        .padding(16)
    }

    private var availableResources: [Resource] {
        store.resources
            .filter { $0.assignedProjectIDs.contains(projectID) == false }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private var filteredResources: [Resource] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.isEmpty == false else { return availableResources }
        return availableResources.filter { resource in
            resource.displayName.lowercased().contains(trimmed)
                || resource.jobTitle.lowercased().contains(trimmed)
                || resource.department.lowercased().contains(trimmed)
                || resource.email.lowercased().contains(trimmed)
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedResourceIDs.contains(id) {
            selectedResourceIDs.remove(id)
        } else {
            selectedResourceIDs.insert(id)
        }
    }

    private func applySelection() {
        for resourceID in selectedResourceIDs {
            store.assignResource(resourceID: resourceID, to: projectID)
        }
        dismiss()
    }
}
