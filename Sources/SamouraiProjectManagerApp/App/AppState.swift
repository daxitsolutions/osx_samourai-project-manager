import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private enum StorageKeys {
        static let primaryProjectID = "app.primaryProjectID"
    }

    var selectedSection: AppSection? = .dashboard
    var selectedProjectID: UUID?
    var selectedResourceID: UUID?
    var selectedRiskID: UUID?
    var selectedEventID: UUID?
    var selectedActionID: UUID?
    var selectedMeetingID: UUID?
    var selectedDecisionID: UUID?
    var reportingCadence: ReportingCadence = .weekly
    var primaryProjectID: UUID? {
        didSet {
            if let primaryProjectID {
                UserDefaults.standard.set(primaryProjectID.uuidString, forKey: StorageKeys.primaryProjectID)
            } else {
                UserDefaults.standard.removeObject(forKey: StorageKeys.primaryProjectID)
            }
        }
    }
    var isShowingProjectEditor = false

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: StorageKeys.primaryProjectID) {
            primaryProjectID = UUID(uuidString: rawValue)
        } else {
            primaryProjectID = nil
        }
    }

    func openProject(_ projectID: UUID) {
        selectedSection = .projects
        selectedProjectID = projectID
    }

    func openResource(_ resourceID: UUID) {
        selectedSection = .resources
        selectedResourceID = resourceID
    }

    func openRisk(_ riskID: UUID) {
        selectedSection = .risks
        selectedRiskID = riskID
    }

    func openEvent(_ eventID: UUID) {
        selectedSection = .events
        selectedEventID = eventID
    }

    func openAction(_ actionID: UUID) {
        selectedSection = .actions
        selectedActionID = actionID
    }

    func openMeeting(_ meetingID: UUID) {
        selectedSection = .meetings
        selectedMeetingID = meetingID
    }

    func openDecision(_ decisionID: UUID) {
        selectedSection = .decisions
        selectedDecisionID = decisionID
    }

    func openReporting(_ cadence: ReportingCadence) {
        selectedSection = .reporting
        reportingCadence = cadence
    }

    func setPrimaryProject(_ projectID: UUID?) {
        primaryProjectID = projectID
    }

    func resolvedPrimaryProjectID(in store: SamouraiStore) -> UUID? {
        guard let primaryProjectID else { return nil }
        return store.projects.contains(where: { $0.id == primaryProjectID }) ? primaryProjectID : nil
    }
}

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case dashboard
    case reporting
    case projects
    case resources
    case risks
    case deliverables
    case events
    case actions
    case meetings
    case decisions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Pilotage"
        case .projects:
            "Projets"
        case .reporting:
            "Reporting"
        case .resources:
            "Ressources"
        case .risks:
            "Risques"
        case .deliverables:
            "Livrables"
        case .events:
            "Événements"
        case .actions:
            "Actions PM"
        case .meetings:
            "Réunions"
        case .decisions:
            "Décisions"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "gauge.with.dots.needle.50percent"
        case .projects:
            "square.grid.2x2"
        case .reporting:
            "doc.text.magnifyingglass"
        case .resources:
            "person.3"
        case .risks:
            "exclamationmark.shield"
        case .deliverables:
            "checklist"
        case .events:
            "bell.badge"
        case .actions:
            "list.clipboard"
        case .meetings:
            "person.2.badge.gearshape"
        case .decisions:
            "scale.3d"
        }
    }
}
