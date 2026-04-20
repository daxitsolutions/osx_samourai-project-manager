import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private enum StorageKeys {
        static let selectedSection = "app.selectedSection"
        static let primaryProjectID = "app.primaryProjectID"
    }

    var selectedSection: AppSection? = .dashboard {
        didSet {
            if let selectedSection {
                UserDefaults.standard.set(selectedSection.rawValue, forKey: StorageKeys.selectedSection)
            } else {
                UserDefaults.standard.removeObject(forKey: StorageKeys.selectedSection)
            }
        }
    }
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
        if let rawSection = UserDefaults.standard.string(forKey: StorageKeys.selectedSection),
           let storedSection = AppSection(rawValue: rawSection) {
            selectedSection = storedSection
        } else {
            selectedSection = .dashboard
        }

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
    case planning
    case reporting
    case projects
    case resources
    case testing
    case risks
    case deliverables
    case events
    case actions
    case meetings
    case decisions

    var id: String { rawValue }

    var group: AppSectionGroup {
        switch self {
        case .dashboard, .reporting:
            .pilotage
        case .projects, .planning, .deliverables, .risks, .actions:
            .execution
        case .resources, .testing:
            .delivery
        case .events, .meetings, .decisions:
            .governance
        }
    }

    var title: String {
        switch self {
        case .dashboard:
            "Pilotage"
        case .planning:
            "Planning"
        case .projects:
            "Projets"
        case .reporting:
            "Reporting"
        case .resources:
            "Ressources"
        case .testing:
            "Testing"
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

    var summary: String {
        switch self {
        case .dashboard:
            "Vue cockpit du portefeuille, des tensions et des priorités."
        case .planning:
            "Pilotage du macro-planning, des jalons et des activités projet."
        case .reporting:
            "Synthèses de gouvernance et fenêtres d’analyse décisionnelle."
        case .projects:
            "Portefeuille projet, santé, détail et structure d’exécution."
        case .resources:
            "Capacité, affectations, performance et disponibilité des ressources."
        case .testing:
            "Suivi qualité, couverture et progression des campagnes de tests."
        case .risks:
            "Registre transverse des risques, niveaux de criticité et suivi."
        case .deliverables:
            "Périmètre, livrables, scope et contrôle des changements."
        case .events:
            "Journal des événements projet et signaux de contexte."
        case .actions:
            "Backlog opérationnel du chef de projet et flux d’exécution."
        case .meetings:
            "Réunions, transcripts, résumés IA et décisions préparatoires."
        case .decisions:
            "Décisions formelles, historique de révision et traçabilité."
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "gauge.with.dots.needle.50percent"
        case .planning:
            "calendar.badge.clock"
        case .projects:
            "square.grid.2x2"
        case .reporting:
            "doc.text.magnifyingglass"
        case .resources:
            "person.3"
        case .testing:
            "testtube.2"
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

enum AppSectionGroup: String, CaseIterable, Identifiable {
    case pilotage
    case execution
    case delivery
    case governance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pilotage:
            "Pilotage"
        case .execution:
            "Exécution"
        case .delivery:
            "Capacité & Qualité"
        case .governance:
            "Gouvernance"
        }
    }

    var sections: [AppSection] {
        AppSection.allCases.filter { $0.group == self }
    }
}
