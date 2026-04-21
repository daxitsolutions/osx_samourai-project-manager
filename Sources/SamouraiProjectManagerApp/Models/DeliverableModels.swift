import Foundation

enum DeliverablePhase: String, Codable, CaseIterable, Identifiable {
    case cadrage
    case design
    case build
    case tests
    case deployment
    case transition
    case delivery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cadrage:
            "Cadrage"
        case .design:
            "Design"
        case .build:
            "Build"
        case .tests:
            "Tests"
        case .deployment:
            "Déploiement"
        case .transition:
            "Transition"
        case .delivery:
            "Delivery"
        }
    }
}

struct DeliverableAcceptanceCriterion: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var isValidated: Bool

    init(id: UUID = UUID(), text: String, isValidated: Bool = false) {
        self.id = id
        self.text = text
        self.isValidated = isValidated
    }
}

struct Deliverable: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var details: String
    var owner: String
    var dueDate: Date
    var isDone: Bool
    var phase: DeliverablePhase
    var parentDeliverableID: UUID?
    var isMilestone: Bool
    var acceptanceCriteria: [DeliverableAcceptanceCriterion]
    var integratedSourceProjectID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        owner: String,
        dueDate: Date,
        isDone: Bool = false,
        phase: DeliverablePhase = .delivery,
        parentDeliverableID: UUID? = nil,
        isMilestone: Bool = false,
        acceptanceCriteria: [DeliverableAcceptanceCriterion] = [],
        integratedSourceProjectID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.owner = owner
        self.dueDate = dueDate
        self.isDone = isDone
        self.phase = phase
        self.parentDeliverableID = parentDeliverableID
        self.isMilestone = isMilestone
        self.acceptanceCriteria = acceptanceCriteria
        self.integratedSourceProjectID = integratedSourceProjectID
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, details, owner, dueDate, isDone, phase
        case parentDeliverableID, isMilestone, acceptanceCriteria
        case integratedSourceProjectID, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decode(String.self, forKey: .details)
        owner = try container.decode(String.self, forKey: .owner)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        phase = try container.decodeIfPresent(DeliverablePhase.self, forKey: .phase) ?? .delivery
        parentDeliverableID = try container.decodeIfPresent(UUID.self, forKey: .parentDeliverableID)
        isMilestone = try container.decodeIfPresent(Bool.self, forKey: .isMilestone) ?? false
        acceptanceCriteria = try container.decodeIfPresent([DeliverableAcceptanceCriterion].self, forKey: .acceptanceCriteria) ?? []
        integratedSourceProjectID = try container.decodeIfPresent(UUID.self, forKey: .integratedSourceProjectID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(details, forKey: .details)
        try container.encode(owner, forKey: .owner)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(isDone, forKey: .isDone)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(parentDeliverableID, forKey: .parentDeliverableID)
        try container.encode(isMilestone, forKey: .isMilestone)
        try container.encode(acceptanceCriteria, forKey: .acceptanceCriteria)
        try container.encodeIfPresent(integratedSourceProjectID, forKey: .integratedSourceProjectID)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

extension Deliverable {
    var isMainDeliverable: Bool {
        parentDeliverableID == nil
    }

    var validatedAcceptanceCount: Int {
        acceptanceCriteria.filter(\.isValidated).count
    }

    var acceptanceCompletionPercent: Int {
        guard acceptanceCriteria.isEmpty == false else { return 0 }
        return Int((Double(validatedAcceptanceCount) / Double(acceptanceCriteria.count) * 100).rounded())
    }

    var isAccepted: Bool {
        if acceptanceCriteria.isEmpty {
            return isDone
        }
        return validatedAcceptanceCount == acceptanceCriteria.count
    }
}
