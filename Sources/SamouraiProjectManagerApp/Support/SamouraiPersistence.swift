import Foundation

actor SamouraiPersistence {
    static let appDirectoryName = "SamouraiProjectManager"
    static let primaryFileName = "projects.json"

    private let fileManager = FileManager.default
    nonisolated let fileURL: URL
    private let migrationSourceURL: URL?
    nonisolated let writer: SamouraiPersistenceWriter

    init(fileURL: URL = SamouraiPersistence.primaryFileURL, migrationSourceURL: URL? = SamouraiPersistence.legacyFileURL) {
        self.fileURL = fileURL
        self.migrationSourceURL = migrationSourceURL
        self.writer = SamouraiPersistenceWriter(fileURL: fileURL)
    }

    nonisolated static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    nonisolated static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Emplacement principal de sauvegarde : dossier Documents de l'utilisateur.
    /// Ce dossier est synchronisé automatiquement par iCloud Drive lorsque
    /// « Bureau & Documents » est activé dans les réglages iCloud de macOS.
    nonisolated static var primaryFileURL: URL {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appending(path: appDirectoryName, directoryHint: .isDirectory)
            .appending(path: primaryFileName)
    }

    /// Ancien emplacement (`~/Library/Application Support/...`) conservé uniquement
    /// pour la migration automatique au premier démarrage sur cette version.
    nonisolated static var legacyFileURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appending(path: appDirectoryName, directoryHint: .isDirectory)
            .appending(path: primaryFileName)
    }

    /// Sauvegarde synchrone utilisée à la fermeture de l'application pour garantir
    /// l'écriture complète des données avant la terminaison du processus.
    nonisolated static func saveSynchronously(_ database: SamouraiDatabase, to url: URL = primaryFileURL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try makeEncoder().encode(database)
        try data.write(to: url, options: [.atomic])
    }

    private let decoder: JSONDecoder = SamouraiPersistence.makeDecoder()

    func load() throws -> SamouraiPersistenceLoadResult {
        let url = fileURL
        if fileManager.fileExists(atPath: url.path()) == false {
            try migrateLegacyFileIfNeeded(to: url)
        }

        guard fileManager.fileExists(atPath: url.path()) else {
            return SamouraiPersistenceLoadResult(
                database: .empty,
                structureWarnings: []
            )
        }

        let data = try Data(contentsOf: url)
        let structureWarnings = dataStructureWarnings(in: data)
        if let database = try? decoder.decode(SamouraiDatabase.self, from: data) {
            return SamouraiPersistenceLoadResult(
                database: database,
                structureWarnings: structureWarnings
            )
        }

        let legacyProjects = try decoder.decode([Project].self, from: data)
        return SamouraiPersistenceLoadResult(
            database: SamouraiDatabase(projects: legacyProjects, resources: []),
            structureWarnings: structureWarnings
        )
    }

    func save(_ database: SamouraiDatabase) throws {
        try writer.flush(database)
    }

    private func migrateLegacyFileIfNeeded(to destinationURL: URL) throws {
        guard let legacyURL = migrationSourceURL,
              fileManager.fileExists(atPath: legacyURL.path()) else { return }
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: legacyURL, to: destinationURL)
    }

    private func dataStructureWarnings(in data: Data) -> [String] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return [
                "Le fichier de données existant n'utilise pas la structure objet attendue par le modèle actuel."
            ]
        }

        let currentKeys = SamouraiDatabase.currentStructureKeys
        let existingKeys = Set(dictionary.keys)
        let missingKeys = currentKeys.subtracting(existingKeys).sorted()
        let unknownKeys = existingKeys.subtracting(currentKeys).sorted()
        var warnings: [String] = []

        if missingKeys.isEmpty == false {
            warnings.append("Champs absents du modèle actuel : \(missingKeys.joined(separator: ", ")).")
        }

        if unknownKeys.isEmpty == false {
            warnings.append("Champs inconnus dans le fichier existant : \(unknownKeys.joined(separator: ", ")).")
        }

        return warnings
    }
}

