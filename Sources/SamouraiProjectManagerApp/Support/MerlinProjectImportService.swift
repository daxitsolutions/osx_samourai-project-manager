import CryptoKit
import Foundation
import SQLite3
import UniformTypeIdentifiers

private let merlinNamespaceURI = "http://schemas.projectwizards.net/merlin"

struct MerlinProjectImportResult {
    let projectID: UUID
    let projectName: String
    let createdProject: Bool
    let resourceCount: Int
    let activityCount: Int
    let assignmentCount: Int
    let dependencyCount: Int
    let calendarCount: Int
    let customAttributeCount: Int
    let warnings: [String]

    var summary: String {
        let action = createdProject ? "Projet créé" : "Projet mis à jour"
        var parts = [
            "\(action) : \(projectName)",
            "\(resourceCount) ressource(s)",
            "\(activityCount) activité(s)",
            "\(assignmentCount) affectation(s)",
            "\(dependencyCount) dépendance(s)",
            "\(calendarCount) calendrier(s)",
            "\(customAttributeCount) attribut(s) personnalisé(s)"
        ]
        if warnings.isEmpty == false {
            parts.append("\(warnings.count) avertissement(s)")
        }
        return parts.joined(separator: ", ") + "."
    }
}

struct MerlinProjectImportPayload {
    let project: MerlinProjectRecord
    let resources: [MerlinResourceRecord]
    let activities: [MerlinActivityRecord]
    let dependencies: [MerlinDependencyRecord]
    let calendars: [MerlinCalendarRecord]
    let customAttributes: [MerlinCustomAttributeRecord]
    let warnings: [String]

    var assignmentCount: Int {
        activities.reduce(0) { $0 + $1.assignments.count }
    }
}

struct MerlinProjectRecord {
    let id: String
    let title: String
    let summary: String
    let startDate: Date?
    let endDate: Date?
    let globalFields: [String: String]
}

struct MerlinResourceRecord {
    let id: String
    let title: String
    let initials: String?
    let type: String?
    let isUser: Bool?
    let availableUnits: String?
    let baseCalendarID: String?
    let baseCostType: String?
    let fields: [String: String]
}

struct MerlinActivityRecord {
    let id: String
    let parentID: String?
    let displayOrder: Int
    let depth: Int
    let title: String
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let isMilestone: Bool
    let priority: String?
    let givenWork: String?
    let assignments: [MerlinAssignmentRecord]
    var predecessorIDs: [String]
    let fields: [String: String]
}

struct MerlinAssignmentRecord {
    let id: String
    let resourceID: String?
    let fields: [String: String]
}

struct MerlinDependencyRecord {
    let id: String
    let type: String
    let previousActivityID: String
    let nextActivityID: String
}

struct MerlinCalendarRecord {
    struct WeekDayRule {
        let weekDay: String
        let startTime: String?
        let endTime: String?
    }

    let id: String
    let title: String
    let weekDayRules: [WeekDayRule]
}

struct MerlinCustomAttributeRecord {
    let id: String
    let title: String?
    let targetEntityName: String
    let type: String
}

enum MerlinProjectImportError: LocalizedError {
    case unsupportedFileType
    case invalidXML(String)
    case invalidSchema([String])

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            "Le fichier importé doit être un fichier XML."
        case .invalidXML(let message):
            "XML Merlin invalide : \(message)"
        case .invalidSchema(let messages):
            "Le fichier XML ne respecte pas la structure Merlin Project : \(messages.joined(separator: " "))"
        }
    }
}

enum MerlinProjectImportService {
    static func importProject(from fileURL: URL, reporter: ImportProgressReporter = .noop) throws -> MerlinProjectImportPayload {
        let normalizedExtension = fileURL.pathExtension.lowercased()
        if normalizedExtension == "mproject" || fileURL.hasDirectoryPath {
            return try importNativeProject(from: fileURL, reporter: reporter)
        }

        guard normalizedExtension == "xml" else {
            throw MerlinProjectImportError.unsupportedFileType
        }

        reporter.setStage(.reading)
        let data = try Data(contentsOf: fileURL)
        guard data.isEmpty == false else {
            throw MerlinProjectImportError.invalidXML("le fichier est vide.")
        }

        reporter.setStage(.parsing)
        let document: XMLDocument
        do {
            document = try XMLDocument(data: data, options: [.nodePreserveWhitespace])
        } catch {
            throw MerlinProjectImportError.invalidXML(error.localizedDescription)
        }

        guard let root = document.rootElement(), root.localElementName == "Project" else {
            throw MerlinProjectImportError.invalidXML("la racine attendue est Project.")
        }

        reporter.setStage(.analyzing)
        let payload = try parse(root: root)
        reporter.setTotal(payload.resources.count + payload.activities.count + payload.dependencies.count + payload.calendars.count + payload.customAttributes.count)
        reporter.setProcessed(payload.resources.count + payload.activities.count + payload.dependencies.count + payload.calendars.count + payload.customAttributes.count)
        return payload
    }

    static var allowedContentTypes: [UTType] {
        var types: [UTType] = [.xml, .folder, .package]
        if let mprojectType = UTType(filenameExtension: "mproject") {
            types.append(mprojectType)
        }
        return types
    }

    private static func importNativeProject(from fileURL: URL, reporter: ImportProgressReporter) throws -> MerlinProjectImportPayload {
        reporter.setStage(.reading)
        let stateURL = fileURL.hasDirectoryPath || fileURL.pathExtension.lowercased() == "mproject"
            ? fileURL.appending(path: "state.sql")
            : fileURL
        guard FileManager.default.fileExists(atPath: stateURL.path()) else {
            throw MerlinProjectImportError.invalidXML("le paquet Merlin ne contient pas state.sql.")
        }

        reporter.setStage(.parsing)
        let database = try MerlinSQLiteDatabase(url: stateURL)
        defer { database.close() }
        let payload = try parseNativeDatabase(database)
        reporter.setTotal(payload.resources.count + payload.activities.count + payload.dependencies.count + payload.calendars.count + payload.customAttributes.count)
        reporter.setProcessed(payload.resources.count + payload.activities.count + payload.dependencies.count + payload.calendars.count + payload.customAttributes.count)
        return payload
    }

    private static func parse(root: XMLElement) throws -> MerlinProjectImportPayload {
        var errors: [String] = []
        var warnings: [String] = []
        if let namespace = root.resolvedNamespaceURI, namespace.isEmpty == false, namespace != merlinNamespaceURI {
            warnings.append("Namespace XML différent du namespace Merlin attendu : \(namespace). Import poursuivi en mode permissif.")
        } else if root.resolvedNamespaceURI == nil {
            warnings.append("Namespace XML absent. Import poursuivi en mode permissif.")
        }

        let explicitProjectID = cleaned(root.attributeString("id")) ?? cleaned(root.attributeString("uniqueID"))
        let projectID = explicitProjectID ?? stableTextID(prefix: "xml-project", value: root.xmlString)
        if explicitProjectID == nil {
            warnings.append("Project@id absent. Un identifiant stable a été dérivé du contenu XML.")
        }

        let projectTitle = readableTitle(from: root.firstChildElement(named: "title")) ?? "Projet Merlin \(projectID)"
        let rootChildren = root.elementChildren
        let resources = rootChildren
            .filter { $0.localElementName == "Resource" }
            .map(parseResource(_:))
        let calendars = rootChildren
            .filter { $0.localElementName == "BaseCalendar" }
            .map(parseCalendar(_:))
        let customAttributes = rootChildren
            .filter { $0.localElementName == "CustomAttribute" }
            .map(parseCustomAttribute(_:))
        let dependencies = rootChildren
            .filter { $0.localElementName == "Dependency" }
            .map(parseDependency(_:))

        var activities: [MerlinActivityRecord] = []
        for (index, element) in rootChildren.filter({ $0.localElementName == "Activity" }).enumerated() {
            parseActivity(element, parentID: nil, depth: 0, displayOrder: index, into: &activities)
        }

        let resourceIDs = resources.map(\.id)
        let activityIDs = activities.map(\.id)
        let calendarIDs = calendars.map(\.id)
        appendDuplicateIDErrors(resourceIDs, label: "Resource", into: &errors)
        appendDuplicateIDErrors(activityIDs, label: "Activity", into: &errors)
        appendDuplicateIDErrors(calendarIDs, label: "BaseCalendar", into: &errors)

        let resourceIDSet = Set(resourceIDs)
        let activityIDSet = Set(activityIDs)
        let calendarIDSet = Set(calendarIDs)

        for resource in resources where resource.id.isEmpty {
            errors.append("Resource@id est obligatoire.")
        }
        for activity in activities where activity.id.isEmpty {
            errors.append("Activity@id est obligatoire.")
        }
        for calendar in calendars where calendar.id.isEmpty {
            errors.append("BaseCalendar@id est obligatoire.")
        }

        for activity in activities {
            for assignment in activity.assignments {
                guard let resourceID = assignment.resourceID, resourceID.isEmpty == false else {
                    warnings.append("Affectation \(assignment.id) sans référence de ressource dans l'activité \(activity.id).")
                    continue
                }
                if resourceIDSet.contains(resourceID) == false {
                    warnings.append("Référence ressource non résolue : \(resourceID) dans l'affectation \(assignment.id).")
                }
            }
        }

        for dependency in dependencies {
            if activityIDSet.contains(dependency.previousActivityID) == false {
                warnings.append("Dépendance \(dependency.id) : activité précédente introuvable \(dependency.previousActivityID).")
            }
            if activityIDSet.contains(dependency.nextActivityID) == false {
                warnings.append("Dépendance \(dependency.id) : activité suivante introuvable \(dependency.nextActivityID).")
            }
        }

        for resource in resources {
            if let calendarID = resource.baseCalendarID, calendarIDSet.contains(calendarID) == false {
                warnings.append("Ressource \(resource.id) : calendrier de base introuvable \(calendarID).")
            }
        }

        guard errors.isEmpty else {
            throw MerlinProjectImportError.invalidSchema(errors)
        }

        var activityRecords = activities
        let previousByNext = Dictionary(grouping: dependencies, by: \.nextActivityID)
        for index in activityRecords.indices {
            let merlinID = activityRecords[index].id
            activityRecords[index].predecessorIDs = (previousByNext[merlinID] ?? [])
                .map(\.previousActivityID)
                .filter { activityIDSet.contains($0) }
                .removingDuplicateValues()
        }

        let startDate = activityRecords.compactMap(\.startDate).min()
        let endDate = activityRecords.compactMap(\.endDate).max()
        let project = MerlinProjectRecord(
            id: projectID,
            title: projectTitle,
            summary: projectSummary(root: root, calendars: calendars, customAttributes: customAttributes, warnings: warnings),
            startDate: startDate,
            endDate: endDate,
            globalFields: valueChildren(in: root, excluding: ["title", "meta", "Resource", "Activity", "Dependency", "BaseCalendar", "CustomAttribute"])
        )

        return MerlinProjectImportPayload(
            project: project,
            resources: resources,
            activities: activityRecords,
            dependencies: dependencies,
            calendars: calendars,
            customAttributes: customAttributes,
            warnings: warnings
        )
    }

    private static func parseNativeDatabase(_ database: MerlinSQLiteDatabase) throws -> MerlinProjectImportPayload {
        let projectRows = try database.rows(
            """
            select Z_PK, ZTITLE, ZUNIQUEID, ZROOTACTIVITY, ZHOURSPERDAY, ZHOURSPERWEEK, ZDAYSPERMONTH, ZCURRENCYSYMBOL
            from ZPROJECT
            order by Z_PK
            limit 1
            """
        )
        guard let projectRow = projectRows.first,
              let projectPK = projectRow.int("Z_PK"),
              let projectUniqueID = projectRow.string("ZUNIQUEID")
        else {
            throw MerlinProjectImportError.invalidSchema(["ZPROJECT est absent ou incomplet dans state.sql."])
        }

        let scheduleRows = try database.rows(
            """
            select Z_PK, Z_ENT, ZTITLE, ZUNIQUEID, ZPROJECT, ZPARENTACTIVITY_, Z45_PARENTACTIVITY_, ZACTIVITY_, Z45_ACTIVITY_,
                   ZRESOURCE, ZORDERINPARENTACTIVITY, ZORDERINACTIVITY, ZISMILESTONE, ZPRIORITY,
                   ZGIVENSTARTDATEMIN_, ZGIVENSTARTDATEMAX_, ZGIVENENDDATEMIN_, ZGIVENENDDATEMAX_,
                   ZGIVENWORK_ is not null as HASGIVENWORK, ZRESOURCEUNITS_ is not null as HASRESOURCEUNITS,
                   ZOBJECTDESCRIPTION
            from ZSCHEDULEITEM
            where ZPROJECT = \(projectPK)
            order by ZORDERINPARENTACTIVITY, Z_PK
            """
        )
        let activityRows = scheduleRows.filter { $0.int("Z_ENT") == 45 }
        let assignmentRows = scheduleRows.filter { $0.int("Z_ENT") == 47 }
        let activityPKs = Set(activityRows.compactMap { $0.int("Z_PK") })
        let rootActivityPK = projectRow.int("ZROOTACTIVITY")
        let rootActivityRow = rootActivityPK.flatMap { rootPK in activityRows.first { $0.int("Z_PK") == rootPK } }
        let rootActivityTitle = cleaned(rootActivityRow?.string("ZTITLE"))
        let projectTitle = cleaned(projectRow.string("ZTITLE")) ?? rootActivityTitle ?? "Projet Merlin \(projectUniqueID)"

        let assignmentsByActivityPK = Dictionary(grouping: assignmentRows) { row in
            row.int("ZACTIVITY_") ?? row.int("Z45_ACTIVITY_") ?? -1
        }
        let resourcesByPK = try nativeResources(database: database, projectPK: projectPK)
        let resources = resourcesByPK.values.sorted { lhs, rhs in
            lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }

        let dependencies = try nativeDependencies(database: database, projectPK: projectPK, activityPKs: activityPKs)
        let calendars = try nativeCalendars(database: database, projectPK: projectPK)
        let customAttributes = try nativeCustomAttributes(database: database, projectPK: projectPK)

        let childRowsByParentPK = Dictionary(grouping: activityRows.filter { row in
            guard let parent = row.int("ZPARENTACTIVITY_") ?? row.int("Z45_PARENTACTIVITY_") else { return false }
            return parent != row.int("Z_PK")
        }) { row in
            row.int("ZPARENTACTIVITY_") ?? row.int("Z45_PARENTACTIVITY_") ?? -1
        }
        var activities: [MerlinActivityRecord] = []
        var visitedActivityPKs = Set<Int>()

        if let rootActivityPK {
            let rootChildren = childRowsByParentPK[rootActivityPK] ?? []
            for (index, row) in rootChildren.sorted(by: nativeActivitySort).enumerated() {
                appendNativeActivity(
                    row,
                    parentID: nil,
                    depth: 0,
                    displayOrder: index,
                    childRowsByParentPK: childRowsByParentPK,
                    assignmentsByActivityPK: assignmentsByActivityPK,
                    resourcesByPK: resourcesByPK,
                    dependencies: dependencies,
                    visitedActivityPKs: &visitedActivityPKs,
                    activities: &activities
                )
            }
        }

        let remainingRoots = activityRows
            .filter { row in
                guard let pk = row.int("Z_PK"), visitedActivityPKs.contains(pk) == false else { return false }
                let parent = row.int("ZPARENTACTIVITY_") ?? row.int("Z45_PARENTACTIVITY_")
                return parent == nil || activityPKs.contains(parent ?? -1) == false || pk == rootActivityPK
            }
            .sorted(by: nativeActivitySort)
        for (index, row) in remainingRoots.enumerated() {
            guard row.int("Z_PK") != rootActivityPK else { continue }
            appendNativeActivity(
                row,
                parentID: nil,
                depth: 0,
                displayOrder: activities.count + index,
                childRowsByParentPK: childRowsByParentPK,
                assignmentsByActivityPK: assignmentsByActivityPK,
                resourcesByPK: resourcesByPK,
                dependencies: dependencies,
                visitedActivityPKs: &visitedActivityPKs,
                activities: &activities
            )
        }

        var warnings: [String] = [
            "Fichier Merlin natif .mproject lu depuis state.sql."
        ]
        if activities.isEmpty {
            warnings.append("Aucune activité exploitable trouvée dans ZSCHEDULEITEM.")
        }

        let globalFields = [
            "hoursPerDay": projectRow.string("ZHOURSPERDAY"),
            "hoursPerWeek": projectRow.string("ZHOURSPERWEEK"),
            "daysPerMonth": projectRow.string("ZDAYSPERMONTH"),
            "currencySymbol": projectRow.string("ZCURRENCYSYMBOL")
        ].compactMapValues { cleaned($0) }

        let project = MerlinProjectRecord(
            id: projectUniqueID,
            title: projectTitle,
            summary: nativeProjectSummary(
                globalFields: globalFields,
                rootActivityTitle: rootActivityTitle,
                calendars: calendars,
                customAttributes: customAttributes,
                warnings: warnings
            ),
            startDate: activities.compactMap(\.startDate).min(),
            endDate: activities.compactMap(\.endDate).max(),
            globalFields: globalFields
        )

        return MerlinProjectImportPayload(
            project: project,
            resources: resources,
            activities: activities,
            dependencies: dependencies,
            calendars: calendars,
            customAttributes: customAttributes,
            warnings: warnings
        )
    }

    private static func appendNativeActivity(
        _ row: MerlinSQLiteRow,
        parentID: String?,
        depth: Int,
        displayOrder: Int,
        childRowsByParentPK: [Int: [MerlinSQLiteRow]],
        assignmentsByActivityPK: [Int: [MerlinSQLiteRow]],
        resourcesByPK: [Int: MerlinResourceRecord],
        dependencies: [MerlinDependencyRecord],
        visitedActivityPKs: inout Set<Int>,
        activities: inout [MerlinActivityRecord]
    ) {
        guard let pk = row.int("Z_PK"), visitedActivityPKs.insert(pk).inserted else { return }
        let uniqueID = row.string("ZUNIQUEID") ?? "schedule-\(pk)"
        let assignments = (assignmentsByActivityPK[pk] ?? []).map { assignmentRow in
            let assignmentPK = assignmentRow.int("Z_PK") ?? 0
            let resourcePK = assignmentRow.int("ZRESOURCE")
            return MerlinAssignmentRecord(
                id: assignmentRow.string("ZUNIQUEID") ?? "assignment-\(assignmentPK)",
                resourceID: resourcePK.flatMap { resourcesByPK[$0]?.id },
                fields: [
                    "resourceUnits": assignmentRow.boolText("HASRESOURCEUNITS"),
                    "givenWork": assignmentRow.boolText("HASGIVENWORK"),
                    "order": assignmentRow.string("ZORDERINACTIVITY")
                ].compactMapValues { cleaned($0) }
            )
        }
        let predecessorIDs = dependencies
            .filter { $0.nextActivityID == uniqueID }
            .map(\.previousActivityID)
            .removingDuplicateValues()
        let fields = [
            "pk": String(pk),
            "priority": row.string("ZPRIORITY"),
            "givenWork": row.boolText("HASGIVENWORK")
        ].compactMapValues { cleaned($0) }

        activities.append(
            MerlinActivityRecord(
                id: uniqueID,
                parentID: parentID,
                displayOrder: displayOrder,
                depth: depth,
                title: cleaned(row.string("ZTITLE")) ?? "Activité Merlin \(pk)",
                description: cleaned(row.string("ZOBJECTDESCRIPTION")),
                startDate: coreDataDate(row.double("ZGIVENSTARTDATEMIN_") ?? row.double("ZGIVENSTARTDATEMAX_")),
                endDate: coreDataDate(row.double("ZGIVENENDDATEMAX_") ?? row.double("ZGIVENENDDATEMIN_")),
                isMilestone: row.int("ZISMILESTONE") == 1,
                priority: row.string("ZPRIORITY"),
                givenWork: row.int("HASGIVENWORK") == 1 ? "présent dans state.sql" : nil,
                assignments: assignments,
                predecessorIDs: predecessorIDs,
                fields: fields
            )
        )

        let children = (childRowsByParentPK[pk] ?? []).sorted(by: nativeActivitySort)
        for (index, child) in children.enumerated() {
            appendNativeActivity(
                child,
                parentID: uniqueID,
                depth: depth + 1,
                displayOrder: index,
                childRowsByParentPK: childRowsByParentPK,
                assignmentsByActivityPK: assignmentsByActivityPK,
                resourcesByPK: resourcesByPK,
                dependencies: dependencies,
                visitedActivityPKs: &visitedActivityPKs,
                activities: &activities
            )
        }
    }

    private static func nativeResources(database: MerlinSQLiteDatabase, projectPK: Int) throws -> [Int: MerlinResourceRecord] {
        let rows = try database.rows(
            """
            select Z_PK, ZTITLE_, ZUNIQUEID, ZTYPE, ZISUSER, ZINITIALS_, ZEMAIL, ZPHONE, ZORDERINPROJECT,
                   ZRESOURCECALENDAR, ZAVAILABLEUNITS_ is not null as HASAVAILABLEUNITS
            from ZRESOURCE
            where ZPROJECT = \(projectPK)
            order by ZORDERINPROJECT, Z_PK
            """
        )
        return Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            guard let pk = row.int("Z_PK") else { return nil }
            let uniqueID = row.string("ZUNIQUEID") ?? "resource-\(pk)"
            let title = cleaned(row.string("ZTITLE_")) ?? "Ressource Merlin \(pk)"
            return (
                pk,
                MerlinResourceRecord(
                    id: uniqueID,
                    title: title,
                    initials: cleaned(row.string("ZINITIALS_")),
                    type: row.string("ZTYPE"),
                    isUser: row.int("ZISUSER").map { $0 == 1 },
                    availableUnits: row.int("HASAVAILABLEUNITS") == 1 ? "présent dans state.sql" : nil,
                    baseCalendarID: row.string("ZRESOURCECALENDAR"),
                    baseCostType: nil,
                    fields: [
                        "pk": String(pk),
                        "email": row.string("ZEMAIL"),
                        "phone": row.string("ZPHONE"),
                        "order": row.string("ZORDERINPROJECT")
                    ].compactMapValues { cleaned($0) }
                )
            )
        })
    }

    private static func nativeDependencies(database: MerlinSQLiteDatabase, projectPK: Int, activityPKs: Set<Int>) throws -> [MerlinDependencyRecord] {
        let rows = try database.rows(
            """
            select Z_PK, ZTYPE, ZNEXTACTIVITY_, ZPREVIOUSACTIVITY_, ZUNIQUEID
            from ZDEPENDENCY
            where ZPROJECT = \(projectPK)
            order by Z_PK
            """
        )
        let activityIDsByPK = try nativeActivityIDsByPK(database: database, activityPKs: activityPKs)
        return rows.compactMap { row in
            guard let previousPK = row.int("ZPREVIOUSACTIVITY_"),
                  let nextPK = row.int("ZNEXTACTIVITY_"),
                  let previousID = activityIDsByPK[previousPK],
                  let nextID = activityIDsByPK[nextPK]
            else {
                return nil
            }
            let pk = row.int("Z_PK") ?? 0
            return MerlinDependencyRecord(
                id: row.string("ZUNIQUEID") ?? "dependency-\(pk)",
                type: nativeDependencyType(row.int("ZTYPE")),
                previousActivityID: previousID,
                nextActivityID: nextID
            )
        }
    }

    private static func nativeActivityIDsByPK(database: MerlinSQLiteDatabase, activityPKs: Set<Int>) throws -> [Int: String] {
        guard activityPKs.isEmpty == false else { return [:] }
        let rows = try database.rows(
            """
            select Z_PK, ZUNIQUEID
            from ZSCHEDULEITEM
            where Z_ENT = 45
            """
        )
        return Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            guard let pk = row.int("Z_PK"), activityPKs.contains(pk), let uniqueID = row.string("ZUNIQUEID") else { return nil }
            return (pk, uniqueID)
        })
    }

    private static func nativeCalendars(database: MerlinSQLiteDatabase, projectPK: Int) throws -> [MerlinCalendarRecord] {
        let rows = try database.rows(
            """
            select Z_PK, ZTITLE, ZUNIQUEID, ZBASECALENDAR, ZRESOURCE
            from ZCALENDAR
            where ZPROJECT = \(projectPK) or ZPROJECT is null
            order by Z_PK
            """
        )
        return rows.map { row in
            let pk = row.int("Z_PK") ?? 0
            return MerlinCalendarRecord(
                id: row.string("ZUNIQUEID") ?? "calendar-\(pk)",
                title: cleaned(row.string("ZTITLE")) ?? "Calendrier Merlin \(pk)",
                weekDayRules: []
            )
        }
    }

    private static func nativeCustomAttributes(database: MerlinSQLiteDatabase, projectPK: Int) throws -> [MerlinCustomAttributeRecord] {
        let rows = try database.rows(
            """
            select Z_PK, ZTITLE_, ZUNIQUEID, ZTARGETENTITYNAME, ZTYPE, ZUNIT
            from ZCUSTOMATTRIBUTE
            where ZPROJECT = \(projectPK)
            order by Z_PK
            """
        )
        return rows.map { row in
            let pk = row.int("Z_PK") ?? 0
            return MerlinCustomAttributeRecord(
                id: row.string("ZUNIQUEID") ?? "custom-attribute-\(pk)",
                title: cleaned(row.string("ZTITLE_")),
                targetEntityName: row.string("ZTARGETENTITYNAME") ?? "",
                type: row.string("ZTYPE") ?? ""
            )
        }
    }

    private static func nativeActivitySort(_ lhs: MerlinSQLiteRow, _ rhs: MerlinSQLiteRow) -> Bool {
        let lhsOrder = lhs.double("ZORDERINPARENTACTIVITY") ?? lhs.double("ZORDERINACTIVITY") ?? 0
        let rhsOrder = rhs.double("ZORDERINPARENTACTIVITY") ?? rhs.double("ZORDERINACTIVITY") ?? 0
        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }
        return (lhs.int("Z_PK") ?? 0) < (rhs.int("Z_PK") ?? 0)
    }

    private static func nativeDependencyType(_ rawValue: Int?) -> String {
        switch rawValue {
        case 1: "startToStart"
        case 2: "endToEnd"
        case 3: "startToEnd"
        default: "endToStart"
        }
    }

    private static func nativeProjectSummary(
        globalFields: [String: String],
        rootActivityTitle: String?,
        calendars: [MerlinCalendarRecord],
        customAttributes: [MerlinCustomAttributeRecord],
        warnings: [String]
    ) -> String {
        var lines = ["Import Merlin Project natif (.mproject/state.sql)."]
        if let rootActivityTitle {
            lines.append("Activité racine Merlin: \(rootActivityTitle)")
        }
        if globalFields.isEmpty == false {
            lines.append("Paramètres globaux: " + globalFields.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; "))
        }
        if calendars.isEmpty == false {
            lines.append("Calendriers: " + calendars.map { "\($0.title) [\($0.id)]" }.joined(separator: "; "))
        }
        if customAttributes.isEmpty == false {
            lines.append("Attributs personnalisés: " + customAttributes.map { "\($0.title ?? $0.id) (\($0.targetEntityName), \($0.type))" }.joined(separator: "; "))
        }
        if warnings.isEmpty == false {
            lines.append("Notes d'import: " + warnings.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    private static func coreDataDate(_ seconds: Double?) -> Date? {
        guard let seconds else { return nil }
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    private static func stableTextID(prefix: String, value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        let token = digest.prefix(12).map { String(format: "%02x", $0) }.joined()
        return "\(prefix)-\(token)"
    }

    private static func parseResource(_ element: XMLElement) -> MerlinResourceRecord {
        let fields = valueChildren(in: element, excluding: ["title", "ResourceCalendar"])
        let calendarID = element
            .firstChildElement(named: "ResourceCalendar")?
            .firstChildElement(named: "baseCalendar")?
            .attributeString("idref")
        return MerlinResourceRecord(
            id: element.attributeString("id") ?? "",
            title: readableTitle(from: element.firstChildElement(named: "title")) ?? "Ressource Merlin",
            initials: valueAttribute(in: element, named: "initials"),
            type: valueAttribute(in: element, named: "type"),
            isUser: valueAttribute(in: element, named: "isUser").flatMap(Bool.init),
            availableUnits: amountDescription(element.firstChildElement(named: "availableUnits")),
            baseCalendarID: calendarID,
            baseCostType: valueAttribute(in: element, named: "baseCostType"),
            fields: fields
        )
    }

    private static func parseActivity(
        _ element: XMLElement,
        parentID: String?,
        depth: Int,
        displayOrder: Int,
        into activities: inout [MerlinActivityRecord]
    ) {
        let fields = valueChildren(in: element, excluding: ["title", "objectDescription", "Activity", "Assignment"])
        let assignments = element.elementChildren
            .filter { $0.localElementName == "Assignment" }
            .map(parseAssignment(_:))
        let activityID = element.attributeString("id") ?? ""
        let startDate = dateValue(in: element, names: ["givenStartDateMin", "givenStartDateMax"])
        let endDate = dateValue(in: element, names: ["givenEndDateMax", "givenEndDateMin"])
        activities.append(
            MerlinActivityRecord(
                id: activityID,
                parentID: parentID,
                displayOrder: displayOrder,
                depth: depth,
                title: readableTitle(from: element.firstChildElement(named: "title")) ?? "Activité Merlin",
                description: objectDescription(from: element.firstChildElement(named: "objectDescription")),
                startDate: startDate,
                endDate: endDate,
                isMilestone: valueAttribute(in: element, named: "isMilestone").flatMap(Bool.init) ?? false,
                priority: valueAttribute(in: element, named: "priority"),
                givenWork: amountDescription(element.firstChildElement(named: "givenWork")),
                assignments: assignments,
                predecessorIDs: [],
                fields: fields
            )
        )

        let children = element.elementChildren.filter { $0.localElementName == "Activity" }
        for (index, child) in children.enumerated() {
            parseActivity(child, parentID: activityID, depth: depth + 1, displayOrder: index, into: &activities)
        }
    }

    private static func parseAssignment(_ element: XMLElement) -> MerlinAssignmentRecord {
        MerlinAssignmentRecord(
            id: element.attributeString("id") ?? "",
            resourceID: element.firstChildElement(named: "resource")?.attributeString("idref"),
            fields: valueChildren(in: element, excluding: ["resource"])
        )
    }

    private static func parseDependency(_ element: XMLElement) -> MerlinDependencyRecord {
        MerlinDependencyRecord(
            id: element.attributeString("id") ?? "",
            type: valueAttribute(in: element, named: "type") ?? "endToStart",
            previousActivityID: element.firstChildElement(named: "previousActivity")?.attributeString("idref") ?? "",
            nextActivityID: element.firstChildElement(named: "nextActivity")?.attributeString("idref") ?? ""
        )
    }

    private static func parseCalendar(_ element: XMLElement) -> MerlinCalendarRecord {
        let rules = element.elementChildren
            .filter { $0.localElementName == "CalendarWeekDayRule" }
            .map { rule in
                let interval = rule.firstChildElement(named: "dayTimeInterval")
                return MerlinCalendarRecord.WeekDayRule(
                    weekDay: rule.attributeString("weekDay") ?? "",
                    startTime: interval?.attributeString("startTime"),
                    endTime: interval?.attributeString("endTime")
                )
            }
        return MerlinCalendarRecord(
            id: element.attributeString("id") ?? "",
            title: readableTitle(from: element.firstChildElement(named: "title")) ?? "Calendrier Merlin",
            weekDayRules: rules
        )
    }

    private static func parseCustomAttribute(_ element: XMLElement) -> MerlinCustomAttributeRecord {
        MerlinCustomAttributeRecord(
            id: element.attributeString("id") ?? "",
            title: element.attributeString("title"),
            targetEntityName: valueAttribute(in: element, named: "targetEntityName") ?? "",
            type: valueAttribute(in: element, named: "type") ?? ""
        )
    }

    private static func readableTitle(from element: XMLElement?) -> String? {
        guard let element else { return nil }
        let value = element.attributeString("value") ?? element.stringValue
        return cleaned(value)
    }

    private static func objectDescription(from element: XMLElement?) -> String? {
        guard let element else { return nil }
        let paragraphValues = element.elementChildren
            .filter { $0.localElementName == "par" }
            .compactMap { cleaned($0.stringValue) }
        if paragraphValues.isEmpty == false {
            return paragraphValues.joined(separator: "\n")
        }
        return cleaned(element.stringValue)
    }

    private static func valueAttribute(in element: XMLElement, named name: String) -> String? {
        element.firstChildElement(named: name)?.attributeString("value")
    }

    private static func dateValue(in element: XMLElement, names: [String]) -> Date? {
        for name in names {
            if let value = valueAttribute(in: element, named: name), let date = merlinDate(from: value) {
                return date
            }
        }
        return nil
    }

    private static func amountDescription(_ element: XMLElement?) -> String? {
        guard let element else { return nil }
        let amount = element.attributeString("amount")
        let unit = element.attributeString("unit")
        let resolved = element.attributeString("resolvedAmount")
        let pieces = [
            amount.map { "amount=\($0)" },
            unit.map { "unit=\($0)" },
            resolved.map { "resolvedAmount=\($0)" }
        ].compactMap { $0 }
        return pieces.isEmpty ? nil : pieces.joined(separator: ", ")
    }

    private static func valueChildren(in element: XMLElement, excluding excludedNames: Set<String>) -> [String: String] {
        var values: [String: String] = [:]
        for child in element.elementChildren where excludedNames.contains(child.localElementName) == false {
            if let value = child.attributeString("value") ?? amountDescription(child) ?? cleaned(child.stringValue) {
                values[child.localElementName] = value
            }
        }
        return values
    }

    private static func projectSummary(
        root: XMLElement,
        calendars: [MerlinCalendarRecord],
        customAttributes: [MerlinCustomAttributeRecord],
        warnings: [String]
    ) -> String {
        var lines: [String] = ["Import Merlin Project XML."]
        let globals = valueChildren(in: root, excluding: ["title", "Resource", "Activity", "Dependency", "BaseCalendar", "CustomAttribute"])
        if globals.isEmpty == false {
            lines.append("Paramètres globaux: " + globals.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; "))
        }
        if calendars.isEmpty == false {
            lines.append("Calendriers: " + calendars.map { "\($0.title) [\($0.id)]" }.joined(separator: "; "))
        }
        if customAttributes.isEmpty == false {
            lines.append("Attributs personnalisés: " + customAttributes.map { "\($0.title ?? $0.id) (\($0.targetEntityName), \($0.type))" }.joined(separator: "; "))
        }
        if warnings.isEmpty == false {
            lines.append("Références à vérifier: " + warnings.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    private static func appendDuplicateIDErrors(_ ids: [String], label: String, into errors: inout [String]) {
        let grouped = Dictionary(grouping: ids.filter { $0.isEmpty == false }, by: { $0 })
        for (id, values) in grouped where values.count > 1 {
            errors.append("\(label)@id dupliqué : \(id).")
        }
    }

    private static func merlinDate(from value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }

        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return localFormatter.date(from: value)
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension MerlinProjectImportService {
    static func stableUUID(namespace: String, merlinID: String) -> UUID {
        let digest = SHA256.hash(data: Data("\(namespace):\(merlinID)".utf8))
        let bytes = Array(digest.prefix(16))
        let uuid = uuid_t(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }
}

private extension XMLNode {
    var localElementName: String {
        localName ?? name ?? ""
    }
}

private extension XMLElement {
    var resolvedNamespaceURI: String? {
        uri
    }

    var elementChildren: [XMLElement] {
        children?.compactMap { $0 as? XMLElement } ?? []
    }

    func firstChildElement(named name: String) -> XMLElement? {
        elementChildren.first { $0.localElementName == name }
    }

    func attributeString(_ name: String) -> String? {
        attribute(forName: name)?.stringValue
    }
}

final class MerlinSQLiteDatabase {
    private var handle: OpaquePointer?

    init(url: URL) throws {
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "ouverture impossible"
            throw MerlinProjectImportError.invalidXML("state.sql illisible : \(message).")
        }
    }

    func close() {
        if let handle {
            sqlite3_close(handle)
            self.handle = nil
        }
    }

    func rows(_ sql: String) throws -> [MerlinSQLiteRow] {
        guard let handle else {
            throw MerlinProjectImportError.invalidXML("base SQLite fermée.")
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(handle))
            throw MerlinProjectImportError.invalidXML("requête SQLite invalide : \(message).")
        }
        defer { sqlite3_finalize(statement) }

        var result: [MerlinSQLiteRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let columnCount = sqlite3_column_count(statement)
            var values: [String: String?] = [:]
            for index in 0..<columnCount {
                guard let columnNamePointer = sqlite3_column_name(statement, index) else { continue }
                let columnName = String(cString: columnNamePointer)
                if sqlite3_column_type(statement, index) == SQLITE_NULL {
                    values[columnName] = nil
                } else if let textPointer = sqlite3_column_text(statement, index) {
                    values[columnName] = String(cString: textPointer)
                } else {
                    values[columnName] = nil
                }
            }
            result.append(MerlinSQLiteRow(values: values))
        }
        return result
    }

    deinit {
        close()
    }
}

struct MerlinSQLiteRow {
    let values: [String: String?]

    func string(_ key: String) -> String? {
        guard let value = values[key] else { return nil }
        return value
    }

    func int(_ key: String) -> Int? {
        string(key).flatMap(Int.init)
    }

    func double(_ key: String) -> Double? {
        string(key).flatMap(Double.init)
    }

    func boolText(_ key: String) -> String? {
        guard let value = int(key) else { return nil }
        return value == 1 ? "true" : "false"
    }
}
