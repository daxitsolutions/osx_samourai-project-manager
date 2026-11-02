import Foundation

enum SamouraiLoadState: Equatable {
    case notLoaded, loading, ready, failed
}

extension SamouraiStore {
    var hasLoaded: Bool { loadState == .ready }
    var canEdit: Bool { loadState == .ready }

    var mutationBlockedMessage: String {
        AppLocalizer.localized("Les modifications sont bloquées tant que les données ne sont pas chargées. Réessaie le chargement ou restaure une sauvegarde.")
    }

    func requireEditableState() throws {
        guard canEdit else {
            throw RESTAPIError.serviceUnavailable(mutationBlockedMessage)
        }
    }

    func allowMutation() -> Bool {
        guard canEdit else {
            lastErrorMessage = mutationBlockedMessage
            return false
        }
        return true
    }
}
