import Foundation

extension SamouraiBackupEnvelope {
    /// Les exports manuels sont enveloppés ; les sauvegardes automatiques contiennent la base brute.
    static func decodeBackup(_ data: Data, using decoder: JSONDecoder) throws -> SamouraiBackupEnvelope {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SamouraiBackupError.invalidFormat
        }
        // Une enveloppe invalide ne doit jamais être réinterprétée comme une base brute.
        if object["format"] != nil || object["database"] != nil || object["schemaVersion"] != nil {
            guard let envelope = try? decoder.decode(Self.self, from: data) else {
                throw SamouraiBackupError.invalidFormat
            }
            return envelope
        }
        guard let database = try? decoder.decode(SamouraiDatabase.self, from: data) else {
            throw SamouraiBackupError.invalidFormat
        }
        return Self(appVersion: "unknown", database: database)
    }
}
