import Foundation
import Testing
@testable import SamouraiProjectManagerApp

@MainActor
struct ResourceInlineEditTests {
    @Test
    func statusEditPreservesEmailChangedInTheEditor() throws {
        let original = resource()
        var draft = ResourceInlineDraft(resource: original)
        draft.status = .onLeave
        var latest = original
        latest.email = "fiche@example.test"
        let store = resourceStore(latest)

        try store.applyInlineEdit(draft)
        let saved = try #require(store.resource(with: original.id))
        #expect(saved.email == latest.email)
        #expect(saved.status == .onLeave)
    }

    @Test
    func userEditPreservesAllOtherCurrentResourceData() throws {
        let original = resource()
        var draft = ResourceInlineDraft(resource: original)
        draft.email = "  inline@example.test  "
        var latest = original
        latest.fullName = "Nom modifié par API"
        latest.phone = "Nouveau téléphone"
        latest.primaryResourceRole = "Architecte"
        latest.department = "Département API"
        latest.status = .partiallyAvailable
        latest.engagement = .freelancer
        latest.allocationPercent = 80
        latest.notes = "Notes à conserver"
        latest.memo.mainMission = "Mission API"
        latest.assignedProjectIDs = [UUID()]
        latest.favoriteProjectIDs = latest.assignedProjectIDs
        let store = resourceStore(latest)

        try store.applyInlineEdit(draft)
        let saved = try #require(store.resource(with: original.id))
        var expected = latest
        expected.email = "inline@example.test"
        expected.updatedAt = saved.updatedAt
        #expect(saved == expected)
    }

    @Test
    func conflictRejectsTheEntireEditWithoutPartialUpdates() throws {
        let original = resource()
        var draft = ResourceInlineDraft(resource: original)
        draft.nom = "Nom saisi"
        draft.email = "inline@example.test"
        var latest = original
        latest.email = "api@example.test"
        let store = resourceStore(latest)

        #expect(throws: ResourceInlineEditError.self) { try store.applyInlineEdit(draft) }
        #expect(store.resource(with: original.id) == latest)
    }

    @Test
    func convergingEditsDoNotCreateAFakeConflictOrUpdateTimestamp() throws {
        let original = resource()
        var draft = ResourceInlineDraft(resource: original)
        draft.email = "shared@example.test"
        var latest = original
        latest.email = draft.email
        let store = resourceStore(latest)

        let changed = try store.applyInlineEdit(draft)
        #expect(changed == false)
        #expect(store.resource(with: original.id) == latest)
    }

    @Test
    func displayReadsFollowExternalUpdatesWithoutChangingTheDraft() {
        let original = resource()
        var draft = ResourceInlineDraft(resource: original)
        draft.email = "En cours de saisie"
        let before = draft
        var latest = original
        latest.phone = "Téléphone API"
        latest.status = .offboarded

        #expect(draft.value(for: \.phone, current: latest) == latest.phone)
        #expect(draft.value(for: \.status, current: latest) == latest.status)
        #expect(draft.value(for: \.email, current: latest) == draft.email)
        #expect(draft == before)
    }

    @Test
    func savingUsesTheLatestVersionEvenAfterDisplay() throws {
        let original = resource()
        var draft = ResourceInlineDraft(resource: original)
        draft.engagement = .freelancer
        _ = draft.value(for: \.phone, current: original)
        var latest = original
        latest.phone = "Dernière modification API"
        let store = resourceStore(latest)
        try store.applyInlineEdit(draft)
        #expect(store.resource(with: original.id)?.phone == latest.phone)
        #expect(store.resource(with: original.id)?.engagement == .freelancer)
    }

    @Test
    func deletedResourcesAreNotRecreated() {
        var draft = ResourceInlineDraft(resource: resource())
        draft.phone = "123"
        let store = ResourceStore()
        #expect(throws: ResourceInlineEditError.self) { try store.applyInlineEdit(draft) }
        #expect(store.resources.isEmpty)
    }

    enum InvalidEdit: CaseIterable { case emptyName, nonNumericAllocation, negativeAllocation, excessiveAllocation }

    @Test(arguments: InvalidEdit.allCases)
    func invalidUserInputLeavesTheResourceUntouched(_ edit: InvalidEdit) {
        let original = resource()
        var draft = ResourceInlineDraft(resource: original)
        switch edit {
        case .emptyName: draft.nom = "   "
        case .nonNumericAllocation: draft.allocationPercentText = "abc"
        case .negativeAllocation: draft.allocationPercentText = "-1"
        case .excessiveAllocation: draft.allocationPercentText = "101"
        }
        let store = resourceStore(original)
        #expect(throws: ResourceInlineEditError.self) { try store.applyInlineEdit(draft) }
        #expect(store.resource(with: original.id) == original)
    }

    @Test
    func unrelatedExistingValuesAreNeitherValidatedNorRewritten() throws {
        var original = resource()
        original.allocationPercent = 250
        original.nom = nil
        var draft = ResourceInlineDraft(resource: original)
        draft.status = .onLeave
        let saved = try draft.applying(to: original)
        #expect(saved.allocationPercent == 250)
        #expect(saved.nom == nil)
        #expect(saved.status == .onLeave)
    }

    enum AliasField: CaseIterable { case name, role, department }

    @Test(arguments: AliasField.allCases)
    func changesToMirroredFieldsAreAlsoDetected(_ field: AliasField) {
        let original = resource()
        var latest = original
        var draft = ResourceInlineDraft(resource: original)
        switch field {
        case .name: draft.nom = "Saisie"; latest.fullName = "API"
        case .role: draft.primaryResourceRole = "Saisie"; latest.jobTitle = "API"
        case .department: draft.parentDescription = "Saisie"; latest.department = "API"
        }
        let store = resourceStore(latest)
        #expect(throws: ResourceInlineEditError.self) { try store.applyInlineEdit(draft) }
        #expect(store.resource(with: original.id) == latest)
    }

    @Test
    func facadeRejectsInlineEditsWhileRecoveryIsRequired() {
        let store = SamouraiStore()
        var draft = ResourceInlineDraft(resource: resource())
        draft.phone = "123"
        #expect(throws: RESTAPIError.self) { try store.applyResourceInlineEdit(draft) }
        #expect(store.resources.isEmpty)
    }

    private func resource() -> Resource {
        Resource(
            fullName: "Alice", jobTitle: "PM", department: "IT",
            nom: "Alice", parentDescription: "IT", primaryResourceRole: "PM",
            email: "alice@example.test", phone: "000", engagement: .internalEmployee,
            status: .active, allocationPercent: 50, notes: ""
        )
    }

    private func resourceStore(_ resource: Resource) -> ResourceStore {
        let store = ResourceStore()
        store.replaceResources([resource])
        return store
    }
}
