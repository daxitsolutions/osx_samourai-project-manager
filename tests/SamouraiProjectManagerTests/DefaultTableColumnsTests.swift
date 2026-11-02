import Foundation
import Testing
@testable import SamouraiProjectManagerApp

/// Issue #53 : colonnes par défaut réduites, colonnes secondaires accessibles, préférences enregistrées conservées.
@MainActor
@Suite(.serialized)
struct DefaultTableColumnsTests {
    private static let storageKey = "app.tableColumnConfigurations"

    @Test(arguments: AppTableID.allCases)
    func defaultsShowFewKnownColumnsFirst(table: AppTableID) {
        let allIDs = table.columnDescriptors.map(\.id)
        let visible = table.defaultVisibleColumnIDs

        #expect((3...5).contains(visible.count))
        #expect(Set(visible).count == visible.count)
        #expect(visible.allSatisfy(allIDs.contains))
        #expect(visible.count < allIDs.count)
        #expect(Array(table.defaultColumnOrder.prefix(visible.count)) == visible)
        #expect(table.defaultColumnOrder.sorted() == allIDs.sorted())
    }

    @Test(arguments: AppTableID.allCases)
    func secondaryColumnsStayInCustomization(table: AppTableID) throws {
        let configuration = table.normalizedConfiguration(table.defaultConfiguration)
        #expect(configuration.visibleColumnIDs == table.defaultVisibleColumnIDs)
        #expect(Set(table.orderedColumnDescriptors(for: configuration).map(\.id)) == Set(table.columnDescriptors.map(\.id)))

        try withStoredConfigurations { defaults in
            defaults.removeObject(forKey: Self.storageKey)
            let appState = AppState()
            #expect(appState.orderedVisibleTableColumnIDs(for: table) == table.defaultVisibleColumnIDs)
            appState.showAllTableColumns(tableID: table)
            #expect(appState.orderedVisibleTableColumnIDs(for: table).count == table.columnDescriptors.count)
            appState.resetTableColumnConfiguration(tableID: table)
            #expect(appState.orderedVisibleTableColumnIDs(for: table) == table.defaultVisibleColumnIDs)
        }
    }

    @Test func savedPreferencesAreKeptAndOtherTablesUseNewDefaults() throws {
        try withStoredConfigurations { defaults in
            let previousResourceDefaults = ["name", "primaryResourceRole", "parentDescription", "projects",
                                            "allocationPercent", "status", "engagement", "email", "phone"]
            let savedResources = TableColumnConfiguration(
                visibleColumnIDs: previousResourceDefaults,
                orderedColumnIDs: AppTableID.resources.columnDescriptors.map(\.id)
            )
            let savedActions = TableColumnConfiguration(
                visibleColumnIDs: ["createdAt", "done", "title"],
                orderedColumnIDs: ["createdAt", "done", "title"]
            )
            let payload = ["resources": savedResources, "actions": savedActions]
            defaults.set(try JSONEncoder().encode(payload), forKey: Self.storageKey)

            let loaded = AppState.loadPersistedTableColumnConfigurations()

            #expect(loaded[.resources] == savedResources)
            #expect(loaded[.actions]?.visibleColumnIDs == ["createdAt", "done", "title"])
            #expect(Array(loaded[.actions]?.orderedColumnIDs.prefix(3) ?? []) == ["createdAt", "done", "title"])
            #expect(loaded[.risks] == nil)
            let appState = AppState()
            appState.tableColumnConfigurations = loaded
            #expect(appState.orderedVisibleTableColumnIDs(for: .resources) == previousResourceDefaults)
            #expect(appState.orderedVisibleTableColumnIDs(for: .risks) == AppTableID.risks.defaultVisibleColumnIDs)
        }
    }

    @Test func legacyResourcePreferenceIsMigratedUnchanged() throws {
        try withStoredConfigurations { defaults in
            let legacyKey = "resources.visibleColumns"
            let previous = defaults.object(forKey: legacyKey)
            defer { defaults.set(previous, forKey: legacyKey) }
            defaults.removeObject(forKey: Self.storageKey)
            defaults.set("name,email,phone", forKey: legacyKey)

            let loaded = AppState.loadPersistedTableColumnConfigurations()
            #expect(loaded[.resources]?.visibleColumnIDs == ["name", "email", "phone"])
        }
    }

    /// Isole la clé de préférences du runner de tests et la restaure ensuite.
    private func withStoredConfigurations(_ body: (UserDefaults) throws -> Void) throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: Self.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: Self.storageKey) } else { defaults.removeObject(forKey: Self.storageKey) }
        }
        try body(defaults)
    }
}
