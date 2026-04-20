import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    private enum StorageKeys {
        static let selectedSection = "app.selectedSection"
        static let primaryProjectID = "app.primaryProjectID"
        static let fontSizeOffset = "app.fontSizeOffset"
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
    var fontSizeOffset: Double = 0.0 {
        didSet {
            UserDefaults.standard.set(fontSizeOffset, forKey: StorageKeys.fontSizeOffset)
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch Int(fontSizeOffset.rounded()) {
        case ..<(-1): return .xSmall
        case -1: return .small
        case 0: return .medium
        case 1: return .large
        case 2: return .xLarge
        case 3: return .xxLarge
        default: return .xxxLarge
        }
    }

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

        fontSizeOffset = UserDefaults.standard.double(forKey: StorageKeys.fontSizeOffset)
    }

    func openProject(_ projectID: UUID) {
        primaryProjectID = projectID
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
        selectedProjectID = projectID
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
    case resourceDirectory
    case configuration
    case backups
    case testing
    case risks
    case deliverables
    case events
    case actions
    case meetings
    case decisions
    case planning

    var id: String { rawValue }

    var group: AppSectionGroup {
        switch self {
        case .projects:
            .portfolio
        case .dashboard, .actions, .events, .meetings, .deliverables, .resources, .risks, .decisions, .reporting, .planning:
            .project
        case .resourceDirectory:
            .directory
        case .configuration:
            .configuration
        case .backups:
            .backups
        case .testing:
            .hidden
        }
    }

    var showsProjectPicker: Bool {
        switch self {
        case .dashboard, .reporting, .resources, .risks, .deliverables, .events, .actions, .meetings, .decisions, .planning:
            true
        case .projects, .resourceDirectory, .configuration, .backups, .testing:
            false
        }
    }

    var title: String {
        switch self {
        case .dashboard:
            "Pilotage"
        case .projects:
            "Portfolio des projets"
        case .reporting:
            "Reporting"
        case .resources:
            "Ressources"
        case .resourceDirectory:
            "Annuaire des ressources général"
        case .configuration:
            "Configuration"
        case .backups:
            "Sauvegardes / restaurations"
        case .testing:
            "Testing"
        case .risks:
            "Risques"
        case .deliverables:
            "Livrables & Périmètre"
        case .events:
            "Événements"
        case .actions:
            "Actions PM"
        case .meetings:
            "Réunions"
        case .decisions:
            "Décisions"
        case .planning:
            "Planning"
        }
    }

    var summary: String {
        switch self {
        case .dashboard:
            "Vue synthétique du projet actif, de ses tensions et de ses priorités."
        case .reporting:
            "Synthèses de gouvernance du projet actif ou du portefeuille."
        case .projects:
            "Sélection et gestion du portefeuille avant navigation dans les sous-sections."
        case .resources:
            "Ressources rattachées au projet actif, capacité et affectations."
        case .resourceDirectory:
            "Référentiel global des ressources, indépendant du projet en cours."
        case .configuration:
            "Réglages fonctionnels et rappels de structure de l'espace de travail."
        case .backups:
            "Sauvegarde manuelle et restauration de l'état complet de l'application."
        case .testing:
            "Suivi qualité, couverture et progression des campagnes de tests."
        case .risks:
            "Registre des risques du projet actif et suivi de criticité."
        case .deliverables:
            "Périmètre, livrables du projet actif."
        case .events:
            "Journal des événements rattachés au projet actif."
        case .actions:
            "Backlog opérationnel du chef de projet pour le projet actif."
        case .meetings:
            "Réunions, transcripts et préparation des instances du projet actif."
        case .decisions:
            "Décisions formelles du projet actif et historique de révision."
        case .planning:
            "Scénarios, jalons et planification temporelle du projet actif."
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
        case .resourceDirectory:
            "person.crop.rectangle.stack"
        case .configuration:
            "slider.horizontal.3"
        case .backups:
            "externaldrive.badge.timemachine"
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
        case .planning:
            "calendar.badge.checkmark"
        }
    }
}

enum AppSectionGroup: String, CaseIterable, Identifiable {
    case portfolio
    case project
    case directory
    case configuration
    case backups
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portfolio:
            "A. Portfolio des projets"
        case .project:
            "B. Projets"
        case .directory:
            "C. Annuaire des ressources général"
        case .configuration:
            "D. Configuration"
        case .backups:
            "E. Sauvegardes restaurations"
        case .hidden:
            "Masqué"
        }
    }

    var sections: [AppSection] {
        AppSection.allCases.filter { $0.group == self }
    }
}
