import Foundation

enum MeetingMode: String, Codable, CaseIterable, Identifiable {
    case physical
    case virtual
    case hybrid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .physical:
            "Physique"
        case .virtual:
            "Virtuelle"
        case .hybrid:
            "Hybride"
        }
    }

    var systemImage: String {
        switch self {
        case .physical:
            "person.2.fill"
        case .virtual:
            "video.fill"
        case .hybrid:
            "person.2.wave.2.fill"
        }
    }
}

struct ProjectMeeting: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var projectID: UUID?
    var meetingAt: Date
    var durationMinutes: Int
    var mode: MeetingMode
    var organizer: String
    var participants: String
    var locationOrLink: String
    var notes: String
    var transcript: String
    var aiSummary: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        projectID: UUID? = nil,
        meetingAt: Date,
        durationMinutes: Int = 60,
        mode: MeetingMode = .virtual,
        organizer: String = "",
        participants: String = "",
        locationOrLink: String = "",
        notes: String = "",
        transcript: String,
        aiSummary: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.projectID = projectID
        self.meetingAt = meetingAt
        self.durationMinutes = max(durationMinutes, 1)
        self.mode = mode
        self.organizer = organizer
        self.participants = participants
        self.locationOrLink = locationOrLink
        self.notes = notes
        self.transcript = transcript
        self.aiSummary = aiSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ProjectMeeting {
    var displayTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Réunion sans titre" : cleaned
    }
}
