import SwiftUI

struct ResourceDirectoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SamouraiStore.self) private var store
    @Environment(AppState.self) private var appState

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
            .navigationTitle(localized("Ajouter depuis l'annuaire"))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("Sélectionner une ou plusieurs ressources de l'annuaire global à affecter à ") + projectName + ".")
                .font(.callout)
                .foregroundStyle(secondaryTextColor)

            TextField(localized("Rechercher dans l'annuaire"), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 28)

            HStack {
                Text("\(availableResources.count) " + localized("ressource(s) disponible(s)") + " — \(selectedResourceIDs.count) " + localized("sélectionnée(s)"))
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                Spacer()
                if selectedResourceIDs.isEmpty == false {
                    Button(localized("Tout désélectionner")) { selectedResourceIDs.removeAll() }
                        .buttonStyle(.plain)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var content: some View {
        if store.resources.isEmpty {
            ContentUnavailableView(
                localized("Annuaire vide"),
                systemImage: "person.3",
                description: Text(localized("Ajoute des ressources dans l'annuaire global avant de les affecter à un projet."))
            )
        } else if availableResources.isEmpty {
            ContentUnavailableView(
                localized("Toutes les ressources sont déjà affectées"),
                systemImage: "checkmark.seal",
                description: Text(localized("Aucune ressource disponible dans l'annuaire n'est actuellement libre pour ce projet."))
            )
        } else if filteredResources.isEmpty {
            ContentUnavailableView(
                localized("Aucun résultat"),
                systemImage: "magnifyingglass",
                description: Text(localized("Ajuste la recherche pour retrouver une ressource."))
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredResources, id: \.id) { resource in
                        ResourceDirectoryRow(
                            resource: resource,
                            isSelected: selectedResourceIDs.contains(resource.id),
                            secondaryColor: secondaryTextColor,
                            assignedLabel: "\(resource.assignedProjectIDs.count) " + localized("projet(s)")
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { toggleSelection(resource.id) }
                        Divider().padding(.horizontal, 24)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(localized("Annuler")) { dismiss() }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
            Button(localized("Ajouter au projet")) { applySelection() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedResourceIDs.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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

    private var secondaryTextColor: Color {
        Color.primary.opacity(0.72)
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private struct ResourceDirectoryRow: View {
    let resource: Resource
    let isSelected: Bool
    let secondaryColor: Color
    let assignedLabel: String

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .font(.title3)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 8) {
                Text(resource.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(roleLine)
                    .font(.caption)
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(assignedLabel)
                .font(.caption)
                .foregroundStyle(secondaryColor)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(rowBackground)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var roleLine: String {
        var parts: [String] = []
        if resource.jobTitle.isEmpty == false { parts.append(resource.jobTitle) }
        if resource.department.isEmpty == false { parts.append(resource.department) }
        if resource.email.isEmpty == false { parts.append(resource.email) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            Color.accentColor.opacity(0.12)
        } else if isHovered {
            Color.primary.opacity(0.06)
        } else {
            Color.clear
        }
    }
}
