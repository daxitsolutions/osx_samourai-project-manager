import Foundation

struct ProjectEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var subject: String
    var communication: String
    var author: String
    var distribution: String
    var projectID: UUID?
    var resourceIDs: [UUID]
    var createdAt: Date
    var publishedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        subject: String,
        communication: String = "",
        author: String = "",
        distribution: String = "",
        projectID: UUID? = nil,
        resourceIDs: [UUID] = [],
        createdAt: Date = .now,
        publishedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.subject = subject
        self.communication = communication
        self.author = author
        self.distribution = distribution
        self.projectID = projectID
        self.resourceIDs = resourceIDs.removingDuplicateValues()
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case subject
        case communication
        case author
        case distribution
        case projectID
        case resourceIDs
        case createdAt
        case publishedAt
        case updatedAt

        // Legacy fields kept for one-way migration from the previous event log model.
        case title
        case details
        case source
        case happenedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? ""
        communication = try container.decodeIfPresent(String.self, forKey: .communication)
            ?? container.decodeIfPresent(String.self, forKey: .details)
            ?? ""
        author = try container.decodeIfPresent(String.self, forKey: .author)
            ?? container.decodeIfPresent(String.self, forKey: .source)
            ?? ""
        distribution = try container.decodeIfPresent(String.self, forKey: .distribution) ?? ""
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        resourceIDs = try container.decodeIfPresent([UUID].self, forKey: .resourceIDs) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? now
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
            ?? container.decodeIfPresent(Date.self, forKey: .happenedAt)
            ?? createdAt
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(subject, forKey: .subject)
        try container.encode(communication, forKey: .communication)
        try container.encode(author, forKey: .author)
        try container.encode(distribution, forKey: .distribution)
        try container.encodeIfPresent(projectID, forKey: .projectID)
        try container.encode(resourceIDs, forKey: .resourceIDs)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(publishedAt, forKey: .publishedAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

extension ProjectEvent {
    var displayTitle: String {
        let value = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Event / news sans sujet" : value
    }

    var hasTextContent: Bool {
        communication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var hasAuthor: Bool {
        author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var hasDistribution: Bool {
        distribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
