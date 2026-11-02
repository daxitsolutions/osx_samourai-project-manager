import Foundation

extension SamouraiPersistence {
    /// Une copie brute et unique permet de récupérer aussi un JSON illisible.
    nonisolated static func preserveFileBeforeRecovery(at fileURL: URL) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else { return }
        let directory = fileURL.deletingLastPathComponent()
            .appending(path: "recovery-backups", directoryHint: .isDirectory)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let backupURL = directory.appending(path: "projects-\(UUID().uuidString).json")
        try manager.copyItem(at: fileURL, to: backupURL)
    }
}
