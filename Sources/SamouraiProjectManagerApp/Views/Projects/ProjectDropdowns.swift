import SwiftUI

struct SearchableSingleSelectDropdown<Item: Identifiable>: View where Item.ID: Hashable {
    @Environment(AppState.self) private var appState

    let title: String
    let placeholder: String
    let items: [Item]
    @Binding var selectedID: Item.ID?
    @Binding var query: String
    let itemLabel: (Item) -> String

    @State private var isExpanded = false

    private var filteredItems: [Item] {
        let normalizedQuery = query
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedQuery.isEmpty == false else { return items }
        return items.filter { item in
            itemLabel(item)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(normalizedQuery)
        }
    }

    private var summary: String {
        guard let selectedID, let selected = items.first(where: { $0.id == selectedID }) else {
            return localized("Aucune")
        }
        return itemLabel(selected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized(title))
                            .foregroundStyle(.primary)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                TextField(localized(placeholder), text: $query)
                    .textFieldStyle(.roundedBorder)

                Button(localized("Aucune activité parente")) {
                    selectedID = nil
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                if filteredItems.isEmpty {
                    Text(localized("Aucun résultat"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(filteredItems) { item in
                                Button {
                                    selectedID = item.id
                                } label: {
                                    HStack {
                                        Text(itemLabel(item))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedID == item.id {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        key.appLocalized(language: appState.interfaceLanguage)
    }
}

struct SearchableMultiSelectDropdown<Item: Identifiable>: View where Item.ID: Hashable {
    @Environment(AppState.self) private var appState

    let title: String
    let placeholder: String
    let items: [Item]
    @Binding var selectedIDs: Set<Item.ID>
    @Binding var query: String
    let itemLabel: (Item) -> String

    @State private var isExpanded = false

    private var filteredItems: [Item] {
        let normalizedQuery = query
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedQuery.isEmpty == false else { return items }
        return items.filter { item in
            itemLabel(item)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(normalizedQuery)
        }
    }

    private var summary: String {
        let count = selectedIDs.count
        if count == 0 { return localized("Aucune sélection") }
        if count == 1 { return AppLocalizer.localizedFormat("%d sélection", language: appState.interfaceLanguage, count) }
        return AppLocalizer.localizedFormat("%d sélections", language: appState.interfaceLanguage, count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized(title))
                            .foregroundStyle(.primary)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                TextField(localized(placeholder), text: $query)
                    .textFieldStyle(.roundedBorder)

                if filteredItems.isEmpty {
                    Text(localized("Aucun résultat"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(filteredItems) { item in
                                Toggle(
                                    itemLabel(item),
                                    isOn: Binding(
                                        get: { selectedIDs.contains(item.id) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedIDs.insert(item.id)
                                            } else {
                                                selectedIDs.remove(item.id)
                                            }
                                        }
                                    )
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        key.appLocalized(language: appState.interfaceLanguage)
    }
}
