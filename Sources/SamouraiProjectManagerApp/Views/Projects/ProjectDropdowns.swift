import SwiftUI

struct SearchableSingleSelectDropdown<Item: Identifiable>: View where Item.ID: Hashable {
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
            return "Aucune"
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
                        Text(title)
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
                TextField(placeholder, text: $query)
                    .textFieldStyle(.roundedBorder)

                Button("Aucune activité parente") {
                    selectedID = nil
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                if filteredItems.isEmpty {
                    Text("Aucun résultat")
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
}

struct SearchableMultiSelectDropdown<Item: Identifiable>: View where Item.ID: Hashable {
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
        if count == 0 { return "Aucune sélection" }
        if count == 1 { return "1 sélection" }
        return "\(count) sélections"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
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
                TextField(placeholder, text: $query)
                    .textFieldStyle(.roundedBorder)

                if filteredItems.isEmpty {
                    Text("Aucun résultat")
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
}
