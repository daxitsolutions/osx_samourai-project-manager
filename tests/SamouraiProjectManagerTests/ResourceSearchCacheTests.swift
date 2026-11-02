import Foundation
import Testing
@testable import SamouraiProjectManagerApp

@MainActor
struct ResourceSearchCacheTests {
    private let order: [KeyPathComparator<Resource>] = [.init(\.fullName)]
    private func resource(_ name: String, project: UUID? = nil) -> Resource {
        Resource(fullName: name, jobTitle: "Ingénieur", department: "Études", email: "test@example.test",
                 phone: "0123", engagement: .internalEmployee, status: .active, allocationPercent: 80,
                 assignedProjectIDs: project.map { [$0] } ?? [], notes: "Analyse", createdAt: .distantPast, updatedAt: .distantPast)
    }

    @Test func matchesOriginalTermsDomainsFavoritesScopeAndSort() {
        let project = UUID(), other = UUID()
        var alice = resource("Élodie", project: project)
        alice.favoriteProjectIDs = [project]
        alice.competence1 = "Swift"
        var bob = resource("Bob", project: other)
        bob.email = "bob@different.test"
        let resources = [alice, bob, resource("Alice")]
        let names = [project: "Projet Été", other: "Second"]
        let cache = ResourceSearchCache()
        for language in AppLanguage.allCases {
            for scope in [nil, project, other] as [UUID?] {
                for favorites in [false, true] {
                    for query in ["", "  ", "elodie", "ingenieur etudes", "@example.test", "@", "Swift ete", "Bob @different.test", "missing", "analyse"] {
                        for sorting in [order, [.init(\.fullName, order: .reverse)]] {
                            let expected = original(resources, names: names, query: query, scope: scope, favorites: favorites, sorting: sorting, language: language)
                            let actual = cache.results(resources: resources, projectNames: names, query: query, projectID: scope, favoritesOnly: favorites, sortOrder: sorting, language: language)
                            #expect(actual == expected)
                        }
                    }
                }
            }
        }
    }

    @Test func editsRenameReassignmentDeletionAndLocaleInputsInvalidateResults() {
        let p = UUID(), q = UUID(), cache = ResourceSearchCache()
        var resources = [resource("Élodie", project: p)]
        var names = [p: "Old", q: "New"]
        func search(_ query: String, scope: UUID? = nil, favorites: Bool = false, language: AppLanguage = .fr) -> [Resource] {
            cache.results(resources: resources, projectNames: names, query: query, projectID: scope, favoritesOnly: favorites, sortOrder: order, language: language)
        }
        #expect(search("old").count == 1)
        names[p] = "Renamed"
        #expect(search("old").isEmpty)
        #expect(search("renamed").count == 1)
        resources[0].email = "updated@new.test"
        #expect(search("@example.test").isEmpty)
        #expect(search("@new.test").first?.email == "updated@new.test")
        resources[0].notes = "Changed through API"
        #expect(search("changed").count == 1)
        resources[0].assignedProjectIDs = [q]
        #expect(search("", scope: p).isEmpty)
        #expect(search("new", scope: q).count == 1)
        #expect(search("", scope: q, favorites: true).isEmpty)
        resources[0].favoriteProjectIDs = [q]
        #expect(search("", scope: q, favorites: true).count == 1)
        for language in AppLanguage.allCases {
            #expect(search(resources[0].status.label.appLocalized(language: language), language: language).count == 1)
        }
        let id = resources[0].id
        resources.removeAll()
        #expect(search("new").isEmpty)
        var replacement = resource("Replacement")
        replacement.id = id
        resources = [replacement]
        #expect(search("replacement").count == 1)
        #expect(search("changed").isEmpty)
    }

    @Test func measureThousandAndTenThousandResources() {
        for count in [1_000, 10_000] {
            let resources = (0..<count).map { resource("Person \($0)") }
            let queries = ["ingenieur etudes @example.test", "person analyse", "@example.test"]
            let cache = ResourceSearchCache(), clock = ContinuousClock()
            let before = clock.now
            let expected = queries.map { original(resources, names: [:], query: $0, scope: nil, favorites: false, sorting: order, language: .fr) }
            let oldTime = clock.now - before
            let cold = clock.now
            let actual = queries.map { cache.results(resources: resources, projectNames: [:], query: $0, projectID: nil, favoritesOnly: false, sortOrder: order, language: .fr) }
            let coldTime = clock.now - cold
            #expect(actual == expected)
            let warm = clock.now
            for _ in 0..<10 {
                #expect(cache.results(resources: resources, projectNames: [:], query: queries.last!, projectID: nil, favoritesOnly: false, sortOrder: order, language: .fr) == expected.last!)
            }
            print("[#56] count=\(count) original-three-queries=\(oldTime) cached-three-queries-including-index=\(coldTime) repeated-last-query-10x=\(clock.now - warm)")
        }
    }

    // Frozen pre-change predicate, including per-field matching (no cross-field substring).
    private func original(_ resources: [Resource], names: [UUID: String], query: String, scope: UUID?, favorites: Bool, sorting: [KeyPathComparator<Resource>], language: AppLanguage) -> [Resource] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: \.isWhitespace)
            .map { normalize(String($0)) }.filter { !$0.isEmpty }
        return resources.filter { resource in
            if let scope {
                guard resource.assignedProjectIDs.contains(scope), !favorites || resource.isFavorite(in: scope) else { return false }
            }
            guard !terms.isEmpty else { return true }
            let values = originalValues(for: resource, assignedProjectNames: resource.assignedProjectIDs.compactMap { names[$0] }, language: language)
            let email = normalize(resource.email)
            return terms.allSatisfy { term in
                if term.hasPrefix("@") {
                    let token = String(term.dropFirst())
                    return token.isEmpty || email.contains(token)
                }
                return values.contains { normalize($0).contains(term) }
            }
        }.sorted(using: sorting)
    }
    private func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func originalValues(for resource: Resource, assignedProjectNames: [String], language: AppLanguage) -> [String] {
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
