import AppKit
import SwiftUI
import Testing
@testable import SamouraiProjectManagerApp

/// Plantage dans Risques (2 novembre 2026) : les cellules de Table et le label du Menu de statut sont
/// hébergés par AppKit sans les objets d'environnement. Ces vues doivent se rendre sans AppState.
@MainActor
struct RiskStatusMenuRenderingTests {
    @Test(arguments: RiskStatus.allCases)
    func statusMenuRendersWithoutEnvironmentObjects(status: RiskStatus) {
        let host = NSHostingView(rootView: RiskStatusMenu(status: status, language: .en, onChange: { _ in }))
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 30)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.width > 0)
    }

    @Test func badgeUsesTheGivenLanguage() {
        let renderer = ImageRenderer(content: RiskStatusBadge(status: .toDo, language: .fr))
        #expect(renderer.nsImage != nil)
    }
}
