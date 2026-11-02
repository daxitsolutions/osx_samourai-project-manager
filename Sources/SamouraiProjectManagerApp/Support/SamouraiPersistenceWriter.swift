import Foundation

/// Toutes les écritures d'une instance passent par cette file, y compris le flush
/// de fermeture. L'état mutable est exclusivement accédé sur `queue`.
final class SamouraiPersistenceWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Samourai.persistence", qos: .utility)
    private let fileURL: URL
    private let debounceInterval: TimeInterval
    private let backupInterval: TimeInterval
    private var revision: UInt64 = 0
    private var pending: DispatchWorkItem?
    private var lastBackupAt: Date?
    private var writeCount = 0

    init(fileURL: URL, debounceInterval: TimeInterval = 0.15, backupInterval: TimeInterval = 300) {
        self.fileURL = fileURL
        self.debounceInterval = debounceInterval
        self.backupInterval = backupInterval
    }

    var completedWriteCount: Int { queue.sync { writeCount } }

    func schedule(_ database: SamouraiDatabase, onError: @escaping @Sendable (Error) -> Void) {
        queue.async { [self] in
            revision &+= 1
            let scheduledRevision = revision
            pending?.cancel()
            let work = DispatchWorkItem { [self] in
                guard scheduledRevision == revision else { return }
                pending = nil
                do { try write(database) } catch { onError(error) }
            }
            pending = work
            queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
        }
    }

    /// Attend les écritures en cours, invalide les anciennes captures et écrit
    /// l'état courant avant de rendre la main, même si le debounce n'est pas écoulé.
    func flush(_ database: SamouraiDatabase, preservingCurrentFile: Bool = false, createAutoBackup: Bool = true) throws {
        try queue.sync {
            revision &+= 1
            pending?.cancel()
            pending = nil
            if preservingCurrentFile {
                try SamouraiPersistence.preserveFileBeforeRecovery(at: fileURL)
            }
            try write(database, createAutoBackup: createAutoBackup)
        }
    }

    private func write(_ database: SamouraiDatabase, createAutoBackup: Bool = true) throws {
        let data = try SamouraiPersistence.makeEncoder().encode(database)
        let manager = FileManager.default
        try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        writeCount += 1
        guard createAutoBackup else { return }

        // Un burst d'éditions ne produit plus un backup par mutation. Le premier
        // état écrit est protégé, puis au plus un backup toutes les cinq minutes.
        let now = Date.now
        guard lastBackupAt.map({ now.timeIntervalSince($0) >= backupInterval }) ?? true else { return }
        let directory = fileURL.deletingLastPathComponent().appending(path: "auto-backups", directoryHint: .isDirectory)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let backup = directory.appending(path: "projects-\(formatter.string(from: now))-\(UUID()).json")
        try data.write(to: backup, options: .atomic)
        lastBackupAt = now
        let backups = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lhs > rhs
            }
        for stale in backups.dropFirst(120) { try? manager.removeItem(at: stale) }
    }
}
