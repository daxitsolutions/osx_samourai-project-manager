import Foundation

enum ResourceInlineEditError: LocalizedError {
    case missingResource
    case invalidName
    case invalidAllocation
    case conflict(String)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            AppLocalizer.localized("Ressource introuvable.")
        case .invalidName:
            AppLocalizer.localized("Le nom ne peut pas être vide.")
        case .invalidAllocation:
            AppLocalizer.localized("Allocation invalide. Saisis une valeur entière entre 0 et 100.")
        case .conflict(let field):
            AppLocalizer.localizedFormat("Le champ « %@ » a été modifié ailleurs. Ta saisie n'a pas été enregistrée. Vérifie la valeur actuelle ou abandonne la saisie.", AppLocalizer.localized(field))
        }
    }
}

struct ResourceInlineDraft: Equatable {
    private let original: Resource
    var resourceID: UUID { original.id }
    var nom: String
    var primaryResourceRole: String
    var parentDescription: String
    var email: String
    var phone: String
    var allocationPercentText: String
    var status: ResourceStatus
    var engagement: ResourceEngagement

    init(resource: Resource) {
        original = resource
        nom = resource.displayName
        primaryResourceRole = resource.primaryResourceRole ?? resource.displayPrimaryRole
        parentDescription = resource.parentDescription ?? resource.displayDepartment
        email = resource.email
        phone = resource.phone
        allocationPercentText = "\(resource.allocationPercent)"
        status = resource.status
        engagement = resource.engagement
    }

    /// Les champs non saisis suivent la version courante, sans modifier le brouillon.
    func value<Value: Equatable>(for field: KeyPath<Self, Value>, current: Resource) -> Value {
        let baseline = Self(resource: original)
        return self[keyPath: field] == baseline[keyPath: field]
            ? Self(resource: current)[keyPath: field]
            : self[keyPath: field]
    }

    /// Fusion à trois versions : seuls les champs saisis sont appliqués. Un conflit
    /// sur le même champ fait échouer toute la fusion avant publication dans le store.
    func applying(to current: Resource) throws -> Resource {
        guard current.id == resourceID else { throw ResourceInlineEditError.missingResource }
        let baseline = Self(resource: original)
        let latest = Self(resource: current)

        func changed<Value: Equatable>(
            _ field: KeyPath<Self, Value>, label: String,
            normalize: (Value) -> Value = { $0 }
        ) throws -> Value? {
            guard self[keyPath: field] != baseline[keyPath: field] else { return nil }
            let desired = normalize(self[keyPath: field])
            let previous = normalize(baseline[keyPath: field])
            guard desired != previous else { return nil }
            let actual = normalize(latest[keyPath: field])
            guard actual == previous || actual == desired else {
                throw ResourceInlineEditError.conflict(label)
            }
            return desired
        }

        func trimmed(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func checkAlias(_ previous: String, _ actual: String, desired: String, label: String) throws {
            guard trimmed(previous) == trimmed(actual) || trimmed(actual) == desired else {
                throw ResourceInlineEditError.conflict(label)
            }
        }

        var result = current
        if let name = try changed(\.nom, label: "Nom", normalize: trimmed) {
            guard !name.isEmpty else { throw ResourceInlineEditError.invalidName }
            try checkAlias(original.fullName, current.fullName, desired: name, label: "Nom")
            result.fullName = name
            result.nom = name
        }
        if let role = try changed(\.primaryResourceRole, label: "Rôle", normalize: trimmed) {
            try checkAlias(original.jobTitle, current.jobTitle, desired: role, label: "Rôle")
            result.primaryResourceRole = role.isEmpty ? nil : role
            result.jobTitle = role
        }
        if let department = try changed(\.parentDescription, label: "Département", normalize: trimmed) {
            try checkAlias(original.department, current.department, desired: department, label: "Département")
            result.parentDescription = department.isEmpty ? nil : department
            result.department = department
        }
        if let email = try changed(\.email, label: "Email", normalize: trimmed) { result.email = email }
        if let phone = try changed(\.phone, label: "Téléphone", normalize: trimmed) { result.phone = phone }
        if let rawAllocation = try changed(\.allocationPercentText, label: "Allocation", normalize: trimmed) {
            guard let allocation = Int(rawAllocation), (0...100).contains(allocation) else {
                throw ResourceInlineEditError.invalidAllocation
            }
            result.allocationPercent = allocation
        }
        if let status = try changed(\.status, label: "Statut") { result.status = status }
        if let engagement = try changed(\.engagement, label: "Engagement") { result.engagement = engagement }
        return result
    }
}
