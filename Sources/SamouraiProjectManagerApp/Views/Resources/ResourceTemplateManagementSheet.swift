import SwiftUI

struct ResourceTemplateManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let template: Resource
    let onLink: (UUID) -> Void
    let onUnlink: (UUID) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(localized("Rôle"), value: template.displayPrimaryRole.isEmpty ? "-" : template.displayPrimaryRole)
                    LabeledContent(localized("Département"), value: template.displayDepartment.isEmpty ? "-" : template.displayDepartment)
                } header: {
                    Text(template.displayName)
                        .font(.headline)
                }

                let linked = store.projectResourcesLinkedToTemplate(template.id)
                let candidates = store.resources.filter { r in
                    r.id != template.id && r.assignedProjectIDs.isEmpty == false && r.templateResourceID != template.id
                }

                Section(localized("Ressources de projet liées (\(linked.count))")) {
                    if linked.isEmpty {
                        Text(localized("Aucune ressource de projet liée à ce template."))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(linked) { resource in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resource.displayName)
                                        .font(.subheadline)
                                    Text(resource.displayPrimaryRole.isEmpty ? "-" : resource.displayPrimaryRole)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(localized("Délier"), role: .destructive) {
                                    onUnlink(resource.id)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(Color.samouraiDanger)
                            }
                        }
                    }
                }

                if candidates.isEmpty == false {
                    Section(localized("Lier une ressource de projet")) {
                        ForEach(candidates) { resource in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resource.displayName)
                                        .font(.subheadline)
                                    let projectNames = resource.assignedProjectIDs.compactMap { store.project(with: $0)?.name }.joined(separator: ", ")
                                    Text(projectNames.isEmpty ? "-" : projectNames)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(localized("Lier")) {
                                    onLink(resource.id)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(localized("Ressources liées au template"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Fermer")) { dismiss() }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 480)
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

