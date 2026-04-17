import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var selectedSection: AppSection? = .dashboard
    var selectedProjectID: UUID?
    var selectedResourceID: UUID?
    var selectedRiskID: UUID?
    var isShowingProjectEditor = false

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
}

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case dashboard
    case projects
    case resources
    case risks
    case deliverables

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Pilotage"
        case .projects:
            "Projets"
        case .resources:
            "Ressources"
        case .risks:
            "Risques"
        case .deliverables:
            "Livrables"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "gauge.with.dots.needle.50percent"
        case .projects:
            "square.grid.2x2"
        case .resources:
            "person.3"
        case .risks:
            "exclamationmark.shield"
        case .deliverables:
            "checklist"
        }
    }
}
