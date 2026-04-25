import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case fr
    case en

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .fr:
            "fr"
        case .en:
            "en"
        }
    }

    var displayNameKey: String {
        switch self {
        case .fr:
            "Français (FR)"
        case .en:
            "English (EN)"
        }
    }

    func localizedDisplayName(in language: AppLanguage) -> String {
        AppLocalizer.localized(displayNameKey, language: language)
    }
}

enum AppLocalizer {
    static let tableName = "Localizable"

    static func localized(_ key: String, language: AppLanguage) -> String {
        if key.isEmpty {
            return key
        }

        let translatedValue = bundle(for: language)?
            .localizedString(forKey: key, value: nil, table: tableName)
        if let translatedValue, translatedValue != key {
            return translatedValue
        }

        let fallbackValue = bundle(for: .fr)?
            .localizedString(forKey: key, value: nil, table: tableName)
        if let fallbackValue, fallbackValue != key {
            return fallbackValue
        }

        return key
    }

    static func localizedFormat(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        localizedFormat(key, language: language, arguments: arguments)
    }

    static func localizedFormat(_ key: String, language: AppLanguage, arguments: [CVarArg]) -> String {
        let format = localized(key, language: language)
        return String(format: format, locale: Locale(identifier: language.localeIdentifier), arguments: arguments)
    }

    private static func bundle(for language: AppLanguage) -> Bundle? {
        guard let bundlePath = Bundle.module.path(forResource: language.rawValue, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: bundlePath)
    }
}

extension String {
    func appLocalized(language: AppLanguage) -> String {
        AppLocalizer.localized(self, language: language)
    }
}

extension AppState {
    func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: interfaceLanguage)
    }

    func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalizer.localizedFormat(key, language: interfaceLanguage, arguments: arguments)
    }
}

struct LocalizedText: View {
    @Environment(AppState.self) private var appState

    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(AppLocalizer.localized(key, language: appState.interfaceLanguage))
    }
}
