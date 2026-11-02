import Foundation

/// Derived values only. The view reads observable inputs before consulting this cache;
/// cache writes do not publish view state or change resources.
@MainActor
final class ResourceSearchCache {
    private struct Inputs: Equatable {
        var resources: [Resource]
        var projectNames: [UUID: String]
        var query: String
        var projectID: UUID?
        var favoritesOnly: Bool
        var sortOrder: [KeyPathComparator<Resource>]
        var language: AppLanguage
        var locale: Locale
        var timeZone: TimeZone
    }

    private struct Document {
        var resource: Resource
        var projectNames: [String]
        var text: String
        var email: String
    }

    private var inputs: Inputs?
    private var documents: [UUID: Document] = [:]
    private var result: [Resource] = []

    func results(
        resources: [Resource], projectNames: [UUID: String], query: String,
        projectID: UUID?, favoritesOnly: Bool,
        sortOrder: [KeyPathComparator<Resource>], language: AppLanguage
    ) -> [Resource] {
        let current = Inputs(resources: resources, projectNames: projectNames, query: query,
                             projectID: projectID, favoritesOnly: favoritesOnly,
                             sortOrder: sortOrder, language: language, locale: .current, timeZone: .current)
        if inputs == current { return result }
        if inputs?.language != language || inputs?.locale != current.locale || inputs?.timeZone != current.timeZone {
            documents.removeAll(keepingCapacity: true)
        }
        let liveIDs = Set(resources.map(\.id))
        documents = documents.filter { liveIDs.contains($0.key) }
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace).map { Self.normalize(String($0)) }.filter { !$0.isEmpty }
        result = resources.filter { resource in
            if let projectID {
                guard resource.assignedProjectIDs.contains(projectID) else { return false }
                guard !favoritesOnly || resource.isFavorite(in: projectID) else { return false }
            }
            guard !terms.isEmpty else { return true }
            let names = resource.assignedProjectIDs.compactMap { projectNames[$0] }
            let document: Document
            if let cached = documents[resource.id], cached.resource == resource, cached.projectNames == names {
                document = cached
            } else {
                document = Document(resource: resource, projectNames: names,
                    text: Self.searchableValues(for: resource, assignedProjectNames: names, language: language)
                        .map(Self.normalize).joined(separator: "\n"),
                    email: Self.normalize(resource.email))
                documents[resource.id] = document
            }
            return terms.allSatisfy { term in
                if term.hasPrefix("@") {
                    let token = String(term.dropFirst())
                    return token.isEmpty || document.email.contains(token)
                }
                return document.text.contains(term)
            }
        }.sorted(using: sortOrder)
        inputs = current
        return result
    }

    static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func searchableValues(for resource: Resource, assignedProjectNames: [String], language: AppLanguage) -> [String] {
        [
            resource.displayName,
            resource.fullName,
            resource.nom ?? "",
            resource.displayPrimaryRole,
            resource.primaryResourceRole ?? "",
            resource.resourceRoles ?? "",
            resource.jobTitle,
            resource.displayDepartment,
            resource.parentDescription ?? "",
            resource.organizationalResource ?? "",
            assignedProjectNames.joined(separator: ", "),
            resource.engagement.label.appLocalized(language: language),
            resource.status.label.appLocalized(language: language),
            resource.allocationLabel,
            "\(resource.allocationPercent)",
            resource.email,
            resource.phone,
            resource.notes,
            resource.localisation ?? "",
            resource.typeDeRessource ?? "",
            resource.competence1 ?? "",
            resource.resourceCalendar ?? "",
            resource.responsableOperationnel ?? "",
            resource.responsableInterne ?? "",
            resource.createdAt.formatted(date: .abbreviated, time: .omitted),
            resource.updatedAt.formatted(date: .abbreviated, time: .omitted)
        ]
    }

}
