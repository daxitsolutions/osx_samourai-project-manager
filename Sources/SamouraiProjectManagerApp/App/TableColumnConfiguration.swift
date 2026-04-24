import Foundation

struct AppTableColumnDescriptor: Identifiable, Hashable {
    let id: String
    let title: String
}

struct TableColumnConfiguration: Codable, Equatable {
    var visibleColumnIDs: [String]
    var orderedColumnIDs: [String]
}

enum AppTableID: String, CaseIterable, Codable, Hashable, Identifiable {
    case actions
    case events
    case meetings
    case decisions
    case resources
    case planning
    case testing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .actions:
            "Actions PM"
        case .events:
            "Événements"
        case .meetings:
            "Réunions"
        case .decisions:
            "Décisions"
        case .resources:
            "Ressources"
        case .planning:
            "Planning"
        case .testing:
            "Testing"
        }
    }

    var subtitle: String {
        switch self {
        case .actions:
            "Liste opérationnelle des actions projet."
        case .events:
            "Journal des événements projet."
        case .meetings:
            "Registre des réunions."
        case .decisions:
            "Registre de gouvernance des décisions."
        case .resources:
            "Table de l'annuaire et des ressources projet."
        case .planning:
            "Vue table des activités de planning."
        case .testing:
            "Suivi des phases de tests."
        }
    }

    var systemImage: String {
        switch self {
        case .actions:
            "list.clipboard"
        case .events:
            "bell.badge"
        case .meetings:
            "person.2.badge.gearshape"
        case .decisions:
            "scale.3d"
        case .resources:
            "person.3"
        case .planning:
            "calendar.badge.checkmark"
        case .testing:
            "testtube.2"
        }
    }

    var columnDescriptors: [AppTableColumnDescriptor] {
        switch self {
        case .actions:
            [
                .init(id: "done", title: "Terminée"),
                .init(id: "status", title: "Statut"),
                .init(id: "flow", title: "Flux"),
                .init(id: "priority", title: "Priorité"),
                .init(id: "title", title: "Titre"),
                .init(id: "activity", title: "Activité"),
                .init(id: "project", title: "Projet"),
                .init(id: "dueDate", title: "Échéance"),
                .init(id: "createdAt", title: "Créée le")
            ]
        case .events:
            [
                .init(id: "happenedAt", title: "Date/Heure"),
                .init(id: "priority", title: "Priorité"),
                .init(id: "title", title: "Événement"),
                .init(id: "source", title: "Source"),
                .init(id: "project", title: "Projet"),
                .init(id: "resources", title: "Ressources")
            ]
        case .meetings:
            [
                .init(id: "meetingAt", title: "Date"),
                .init(id: "title", title: "Réunion"),
                .init(id: "project", title: "Projet"),
                .init(id: "mode", title: "Mode"),
                .init(id: "duration", title: "Durée"),
                .init(id: "aiSummary", title: "Résumé IA")
            ]
        case .decisions:
            [
                .init(id: "reference", title: "Ref"),
                .init(id: "status", title: "Statut"),
                .init(id: "title", title: "Décision"),
                .init(id: "project", title: "Projet"),
                .init(id: "meetings", title: "Réunions liées"),
                .init(id: "events", title: "Événements liés"),
                .init(id: "revisions", title: "Révisions"),
                .init(id: "comments", title: "Commentaires")
            ]
        case .resources:
            [
                .init(id: "name", title: "Nom"),
                .init(id: "primaryResourceRole", title: "Primary Role"),
                .init(id: "parentDescription", title: "Parent Description"),
                .init(id: "projects", title: "Projet(s)"),
                .init(id: "allocationPercent", title: "Allocation"),
                .init(id: "status", title: "Statut"),
                .init(id: "engagement", title: "Engagement"),
                .init(id: "email", title: "E-mail"),
                .init(id: "phone", title: "Téléphone"),
                .init(id: "resourceRoles", title: "Resource Roles"),
                .init(id: "organizationalResource", title: "Organizational Resource"),
                .init(id: "competence1", title: "Compétence 1"),
                .init(id: "resourceCalendar", title: "Resource Calendar"),
                .init(id: "resourceStartDate", title: "Resource Start Date"),
                .init(id: "resourceFinishDate", title: "Resource Finish Date"),
                .init(id: "responsableOperationnel", title: "Responsable Opérationnel"),
                .init(id: "responsableInterne", title: "Responsable Interne"),
                .init(id: "localisation", title: "Localisation"),
                .init(id: "typeDeRessource", title: "Type de Ressource"),
                .init(id: "journeesTempsPartiel", title: "Journée(s) temps partiel"),
                .init(id: "notes", title: "Notes"),
                .init(id: "createdAt", title: "Créée le"),
                .init(id: "updatedAt", title: "Modifiée le")
            ]
        case .planning:
            [
                .init(id: "title", title: "Titre"),
                .init(id: "type", title: "Type"),
                .init(id: "parent", title: "Parent"),
                .init(id: "startDate", title: "Début"),
                .init(id: "endDate", title: "Fin"),
                .init(id: "milestone", title: "Jalon"),
                .init(id: "completed", title: "Clôturée"),
                .init(id: "dependencies", title: "Dépendances"),
                .init(id: "edit", title: "Éditer")
            ]
        case .testing:
            [
                .init(id: "project", title: "Projet"),
                .init(id: "phase", title: "Phase"),
                .init(id: "status", title: "Statut"),
                .init(id: "progress", title: "Progression"),
                .init(id: "owner", title: "Owner"),
                .init(id: "blocked", title: "Bloqué")
            ]
        }
    }

    var defaultVisibleColumnIDs: [String] {
        switch self {
        case .resources:
            [
                "name",
                "primaryResourceRole",
                "parentDescription",
                "projects",
                "allocationPercent",
                "status",
                "engagement",
                "email",
                "phone"
            ]
        case .actions, .events, .meetings, .decisions, .planning, .testing:
            defaultColumnOrder
        }
    }

    var defaultColumnOrder: [String] {
        columnDescriptors.map(\.id)
    }

    var defaultConfiguration: TableColumnConfiguration {
        TableColumnConfiguration(
            visibleColumnIDs: defaultVisibleColumnIDs,
            orderedColumnIDs: defaultColumnOrder
        )
    }

    func columnTitle(for columnID: String) -> String {
        columnDescriptors.first(where: { $0.id == columnID })?.title ?? columnID
    }

    func orderedColumnDescriptors(for configuration: TableColumnConfiguration) -> [AppTableColumnDescriptor] {
        let descriptorsByID = Dictionary(uniqueKeysWithValues: columnDescriptors.map { ($0.id, $0) })
        return normalizedConfiguration(configuration).orderedColumnIDs.compactMap { descriptorsByID[$0] }
    }

    func normalizedConfiguration(_ configuration: TableColumnConfiguration?) -> TableColumnConfiguration {
        let allColumnIDs = defaultColumnOrder
        let allColumnIDSet = Set(allColumnIDs)
        guard allColumnIDs.isEmpty == false else {
            return TableColumnConfiguration(visibleColumnIDs: [], orderedColumnIDs: [])
        }

        var orderedIDs: [String] = []
        var seenOrderedIDs = Set<String>()
        for columnID in configuration?.orderedColumnIDs ?? defaultColumnOrder where allColumnIDSet.contains(columnID) {
            if seenOrderedIDs.insert(columnID).inserted {
                orderedIDs.append(columnID)
            }
        }
        for columnID in allColumnIDs where seenOrderedIDs.contains(columnID) == false {
            orderedIDs.append(columnID)
        }

        var visibleIDs: [String] = []
        var seenVisibleIDs = Set<String>()
        for columnID in configuration?.visibleColumnIDs ?? defaultVisibleColumnIDs where allColumnIDSet.contains(columnID) {
            if seenVisibleIDs.insert(columnID).inserted {
                visibleIDs.append(columnID)
            }
        }
        if visibleIDs.isEmpty {
            visibleIDs = defaultVisibleColumnIDs
        }

        return TableColumnConfiguration(
            visibleColumnIDs: visibleIDs,
            orderedColumnIDs: orderedIDs
        )
    }
}

private enum AppTableColumnConfigurationStorage {
    static let key = "app.tableColumnConfigurations"
    static let legacyResourceVisibleColumnsKey = "resources.visibleColumns"
    static let legacyPlanningVisibleColumnsKey = "planning.table.visibleColumns"
    static let legacyPlanningColumnOrderKey = "planning.table.columnOrder"
}

extension AppState {
    static func loadPersistedTableColumnConfigurations() -> [AppTableID: TableColumnConfiguration] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: AppTableColumnConfigurationStorage.key),
           let decoded = try? JSONDecoder().decode([String: TableColumnConfiguration].self, from: data) {
            return normalizeTableColumnConfigurations(decoded)
        }

        var migrated: [AppTableID: TableColumnConfiguration] = [:]
        if let rawResourceColumns = defaults.string(forKey: AppTableColumnConfigurationStorage.legacyResourceVisibleColumnsKey) {
            migrated[.resources] = AppTableID.resources.normalizedConfiguration(
                TableColumnConfiguration(
                    visibleColumnIDs: rawResourceColumns.samouraiColumnConfigurationTokens,
                    orderedColumnIDs: AppTableID.resources.defaultColumnOrder
                )
            )
        }
        if let rawPlanningColumns = defaults.string(forKey: AppTableColumnConfigurationStorage.legacyPlanningVisibleColumnsKey) {
            migrated[.planning] = AppTableID.planning.normalizedConfiguration(
                TableColumnConfiguration(
                    visibleColumnIDs: rawPlanningColumns.samouraiColumnConfigurationTokens,
                    orderedColumnIDs: defaults
                        .string(forKey: AppTableColumnConfigurationStorage.legacyPlanningColumnOrderKey)?
                        .samouraiColumnConfigurationTokens ?? AppTableID.planning.defaultColumnOrder
                )
            )
        }
        let migratedPayload = Dictionary(uniqueKeysWithValues: migrated.map { tableID, configuration in
            (tableID.rawValue, configuration)
        })
        return normalizeTableColumnConfigurations(migratedPayload)
    }

    func persistTableColumnConfigurations() {
        let payload = Dictionary(uniqueKeysWithValues: tableColumnConfigurations.map { tableID, configuration in
            (tableID.rawValue, tableID.normalizedConfiguration(configuration))
        })
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: AppTableColumnConfigurationStorage.key)
        }
    }

    func tableColumnConfiguration(for tableID: AppTableID) -> TableColumnConfiguration {
        tableID.normalizedConfiguration(tableColumnConfigurations[tableID])
    }

    func visibleTableColumnIDs(for tableID: AppTableID) -> Set<String> {
        Set(tableColumnConfiguration(for: tableID).visibleColumnIDs)
    }

    func orderedVisibleTableColumnIDs(for tableID: AppTableID) -> [String] {
        let configuration = tableColumnConfiguration(for: tableID)
        let visibleIDs = Set(configuration.visibleColumnIDs)
        return configuration.orderedColumnIDs.filter { visibleIDs.contains($0) }
    }

    func setTableColumnVisibility(tableID: AppTableID, columnID: String, isVisible: Bool) {
        var configuration = tableColumnConfiguration(for: tableID)
        var visibleIDs = configuration.visibleColumnIDs
        if isVisible {
            if visibleIDs.contains(columnID) == false {
                visibleIDs.append(columnID)
            }
        } else {
            visibleIDs.removeAll { $0 == columnID }
        }
        configuration.visibleColumnIDs = visibleIDs
        tableColumnConfigurations[tableID] = tableID.normalizedConfiguration(configuration)
    }

    func moveTableColumn(tableID: AppTableID, columnID: String, offset: Int) {
        guard offset != 0 else { return }
        var configuration = tableColumnConfiguration(for: tableID)
        guard let currentIndex = configuration.orderedColumnIDs.firstIndex(of: columnID) else { return }
        let targetIndex = min(max(currentIndex + offset, 0), configuration.orderedColumnIDs.count - 1)
        guard targetIndex != currentIndex else { return }
        let movedID = configuration.orderedColumnIDs.remove(at: currentIndex)
        configuration.orderedColumnIDs.insert(movedID, at: targetIndex)
        tableColumnConfigurations[tableID] = tableID.normalizedConfiguration(configuration)
    }

    func resetTableColumnConfiguration(tableID: AppTableID) {
        tableColumnConfigurations[tableID] = tableID.defaultConfiguration
    }

    func showAllTableColumns(tableID: AppTableID) {
        var configuration = tableColumnConfiguration(for: tableID)
        configuration.visibleColumnIDs = tableID.defaultColumnOrder
        tableColumnConfigurations[tableID] = tableID.normalizedConfiguration(configuration)
    }

    private static func normalizeTableColumnConfigurations(
        _ rawConfigurations: [String: TableColumnConfiguration]
    ) -> [AppTableID: TableColumnConfiguration] {
        var configurations: [AppTableID: TableColumnConfiguration] = [:]
        for tableID in AppTableID.allCases {
            if let rawConfiguration = rawConfigurations[tableID.rawValue] {
                configurations[tableID] = tableID.normalizedConfiguration(rawConfiguration)
            }
        }
        return configurations
    }
}

private extension String {
    var samouraiColumnConfigurationTokens: [String] {
        split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}
