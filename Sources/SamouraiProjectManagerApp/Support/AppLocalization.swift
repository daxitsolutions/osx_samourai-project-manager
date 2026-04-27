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

    /// Process-wide current language used by non-View contexts (errors, services, stores).
    /// Updated by AppState whenever the user changes language.
    nonisolated(unsafe) static var ambientLanguage: AppLanguage = .fr

    /// Localize using the ambient (process-wide) language. For use in error
    /// descriptions, service-layer logs, and other non-View contexts where an
    /// AppState environment is unavailable.
    static func localized(_ key: String) -> String {
        localized(key, language: ambientLanguage)
    }

    static func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        localizedFormat(key, language: ambientLanguage, arguments: arguments)
    }

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
        return String(
            format: format,
            locale: Locale(identifier: language.localeIdentifier),
            arguments: normalizedFoundationArguments(arguments, format: format)
        )
    }

    private static func bundle(for language: AppLanguage) -> Bundle? {
        guard let bundlePath = Bundle.module.path(forResource: language.rawValue, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: bundlePath)
    }

    private static func normalizedFoundationArguments(_ arguments: [CVarArg], format: String) -> [CVarArg] {
        var normalizedArguments = arguments
        var nextArgumentIndex = 0
        var index = format.startIndex

        while index < format.endIndex {
            guard format[index] == "%" else {
                index = format.index(after: index)
                continue
            }

            index = format.index(after: index)
            guard index < format.endIndex else { break }

            if format[index] == "%" {
                index = format.index(after: index)
                continue
            }

            let positionalStart = index
            var positionalDigits = ""
            while index < format.endIndex, let digit = format[index].wholeNumberValue {
                positionalDigits.append(String(digit))
                index = format.index(after: index)
            }

            let explicitArgumentIndex: Int?
            if index < format.endIndex,
               format[index] == "$",
               let position = Int(positionalDigits),
               position > 0 {
                explicitArgumentIndex = position - 1
                index = format.index(after: index)
            } else {
                explicitArgumentIndex = nil
                index = positionalStart
            }

            while index < format.endIndex {
                let character = format[index]
                let targetArgumentIndex = explicitArgumentIndex ?? nextArgumentIndex

                if character == "@" {
                    if normalizedArguments.indices.contains(targetArgumentIndex) {
                        normalizedArguments[targetArgumentIndex] = String(describing: normalizedArguments[targetArgumentIndex]) as NSString
                    }
                    if explicitArgumentIndex == nil {
                        nextArgumentIndex += 1
                    }
                    index = format.index(after: index)
                    break
                }

                if isFormatSpecifierTerminator(character) {
                    if explicitArgumentIndex == nil {
                        nextArgumentIndex += 1
                    }
                    index = format.index(after: index)
                    break
                }

                index = format.index(after: index)
            }
        }

        return normalizedArguments
    }

    private static func isFormatSpecifierTerminator(_ character: Character) -> Bool {
        switch character {
        case "A", "C", "D", "E", "F", "G", "O", "S", "U", "X", "a", "c", "d", "e", "f", "g", "i", "n", "o", "p", "s", "u", "x":
            true
        default:
            false
        }
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
