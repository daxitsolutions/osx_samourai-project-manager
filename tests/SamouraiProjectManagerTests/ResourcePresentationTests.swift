import Foundation
import Testing
@testable import SamouraiProjectManagerApp

struct ResourcePresentationTests {
    @Test func replacingEditorWithPreviewAndEvaluationKeepsOnlyTheCurrentResource() throws {
        var state = ResourceWorkspacePresentationState()
        let first = UUID(), second = UUID()
        state.show(.create)
        let creationID = try #require(state.current?.id)
        state.show(.edit(first))
        let editionID = try #require(state.current?.id)
        state.show(.memo(second))
        state.dismiss(id: creationID)
        state.dismiss(id: editionID)
        guard case .memo(let id) = state.current?.destination else {
            Issue.record("Delayed editor dismissal erased the preview")
            return
        }
        #expect(id == second)
        #expect(state.current?.kind == .sheet)
        state.show(.evaluation(first))
        let evaluationID = try #require(state.current?.id)
        state.dismiss(id: evaluationID)
        #expect(state.current == nil)
    }

    @Test func savingEvaluationFeedbackSurvivesTheSheetDismissal() throws {
        var state = ResourceWorkspacePresentationState()
        state.show(.evaluation(UUID()))
        let sheetID = try #require(state.current?.id)
        state.show(.feedback(title: "Évaluation", message: "Fixture enregistrée"))
        state.dismiss(id: sheetID)
        guard case .feedback(_, let message) = state.current?.destination else {
            Issue.record("Sheet dismissal discarded the save result")
            return
        }
        #expect(message == "Fixture enregistrée")
        #expect(state.current?.kind == .alert)
        #expect(state.presented(for: .sheet) == nil)
        #expect(state.presented(for: .alert)?.id == state.current?.id)
        state.dismiss(id: try #require(state.current?.id))
        #expect(state.current == nil)
    }

    @Test func cancellingImportConfirmationReleasesItsRowsBeforeAnotherImport() throws {
        var state = ResourceWorkspacePresentationState()
        let drafts = [ResourceImportDraft(
            nom: "Fixture", prenom: nil, nomDeFamille: nil, parentDescription: nil,
            primaryResourceRole: nil, resourceRoles: nil, organizationalResource: nil, competence1: nil,
            resourceCalendar: nil, resourceStartDate: nil, resourceFinishDate: nil, responsableOperationnel: nil,
            responsableInterne: nil, localisation: nil, typeDeRessource: nil, journeesTempsPartiel: nil,
            email: "fixture@example.invalid", phone: nil, engagement: .internalEmployee, status: .active,
            allocationPercent: 100, notes: "", sourceRowNumber: 2
        )]
        #expect(drafts.count == 1)
        state.show(.confirmImport(drafts))
        let confirmationID = try #require(state.current?.id)
        state.dismiss(id: confirmationID)
        #expect(state.current == nil)
        state.show(.importFile)
        state.dismiss(id: confirmationID)
        #expect(state.current?.kind == .importFile)
        state.show(.review)
        #expect(state.current?.kind == .sheet)
        state.dismissAll()
        #expect(state.current == nil)
    }

    @Test func leavingWorkspaceSuppressesLateImportAndFeedbackPresentations() {
        var state = ResourceWorkspacePresentationState()
        state.show(.review)
        state.deactivate()
        #expect(state.current == nil)
        state.show(.review)
        state.show(.feedback(title: "Import", message: "Résultat tardif"))
        #expect(state.current == nil)
        state.activate()
        #expect(state.current == nil)
        state.show(.create)
        #expect(state.presented(for: .sheet) != nil)
        #expect(state.presented(for: .alert) == nil)
    }

    @Test func deleteConfirmationCapturesItsTargetsAndCancelNeverDeletes() throws {
        var state = ResourceWorkspacePresentationState()
        var selected = SamouraiSeedFactory.makeDemoResources(projects: [])
        #expect(!selected.isEmpty)
        let ids = selected.map(\.id)
        state.show(.delete(selected))
        selected.removeAll()
        guard case .delete(let targets) = state.current?.destination else {
            Issue.record("Missing delete confirmation")
            return
        }
        #expect(targets.map(\.id) == ids)
        #expect(state.current?.kind == .alert)
        state.dismissAll()
        #expect(state.current == nil)
        // Presentation transitions do not mutate the captured resources or a store.
        #expect(targets.map(\.id) == ids)
    }

    @Test func closingDirectoryTemplatesAndFileDialogsLeavesNoDestination() throws {
        let routes: [ResourceWorkspacePresentation.Destination] = [
            .directory, .templates(UUID()), .importFile, .exportFile, .review
        ]
        var state = ResourceWorkspacePresentationState()
        for route in routes {
            state.show(route)
            let id = try #require(state.current?.id)
            state.dismiss(id: id)
            #expect(state.current == nil)
            state.show(route)
            let replacementID = try #require(state.current?.id)
            #expect(replacementID != id)
            state.dismiss(id: id)
            #expect(state.current?.id == replacementID)
            state.dismissAll()
            #expect(state.current == nil)
        }
    }
}
