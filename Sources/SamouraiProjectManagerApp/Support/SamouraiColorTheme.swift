import SwiftUI

enum SamouraiColorToken: String, CaseIterable {
    // Core palette
    case brandGreen
    case brandPurple
    case brandBlue
    case warnYellow
    case dangerRed
    case textMuted

    // Status thresholds
    case healthGreen
    case healthGreenLight
    case healthAmber
    case healthOrange
    case healthRed

    // Loot rarity
    case rarityPoor
    case rarityCommon
    case rarityUncommon
    case rarityRare
    case rarityEpic
    case rarityLegendary
    case rarityArtifact
    case rarityHeirloom
}

enum SamouraiRarity: String, CaseIterable, Identifiable {
    case poor
    case common
    case uncommon
    case rare
    case epic
    case legendary
    case artifact
    case heirloom

    var id: String { rawValue }

    var colorToken: SamouraiColorToken {
        switch self {
        case .poor:
            .rarityPoor
        case .common:
            .rarityCommon
        case .uncommon:
            .rarityUncommon
        case .rare:
            .rarityRare
        case .epic:
            .rarityEpic
        case .legendary:
            .rarityLegendary
        case .artifact:
            .rarityArtifact
        case .heirloom:
            .rarityHeirloom
        }
    }

    var tintColor: Color {
        SamouraiColorTheme.color(colorToken)
    }
}

enum SamouraiColorTheme {
    static func color(_ token: SamouraiColorToken) -> Color {
        Color(hex: hexCode(for: token))
    }

    static func hexCode(for token: SamouraiColorToken) -> String {
        switch token {
        case .brandGreen:
            "#00AF5F"
        case .brandPurple:
            "#8A5CF5"
        case .brandBlue:
            "#2C7BE5"
        case .warnYellow:
            "#F5A623"
        case .dangerRed:
            "#E84141"
        case .textMuted:
            "#888888"
        case .healthGreen:
            "#00AF5F"
        case .healthGreenLight:
            "#4CAF50"
        case .healthAmber:
            "#F5A623"
        case .healthOrange:
            "#FF7F00"
        case .healthRed:
            "#E84141"
        case .rarityPoor:
            "#9D9D9D"
        case .rarityCommon:
            "#FFFFFF"
        case .rarityUncommon:
            "#1EFF00"
        case .rarityRare:
            "#0070DD"
        case .rarityEpic:
            "#A335EE"
        case .rarityLegendary:
            "#FF8000"
        case .rarityArtifact:
            "#E6CC80"
        case .rarityHeirloom:
            "#00CCFF"
        }
    }

    static func healthToken(for score: Int) -> SamouraiColorToken {
        switch score {
        case 90...100:
            .healthGreen
        case 75...89:
            .healthGreenLight
        case 60...74:
            .healthAmber
        case 40...59:
            .healthOrange
        default:
            .healthRed
        }
    }

    static func healthColor(for score: Int) -> Color {
        color(healthToken(for: max(0, min(score, 100))))
    }
}

extension ProjectTestingRAGStatus {
    var colorToken: SamouraiColorToken {
        switch self {
        case .green:
            .healthGreen
        case .amber:
            .healthAmber
        case .red:
            .healthRed
        }
    }

    var tintColor: Color {
        SamouraiColorTheme.color(colorToken)
    }
}

extension ProjectHealth {
    var colorToken: SamouraiColorToken {
        switch self {
        case .green:
            .healthGreen
        case .amber:
            .healthAmber
        case .red:
            .healthRed
        }
    }

    var tintColor: Color {
        SamouraiColorTheme.color(colorToken)
    }
}

extension ResourceStatus {
    var colorToken: SamouraiColorToken {
        switch self {
        case .active:
            .brandGreen
        case .partiallyAvailable:
            .healthAmber
        case .onLeave:
            .warnYellow
        case .offboarded:
            .rarityPoor
        }
    }

    var tintColor: Color {
        SamouraiColorTheme.color(colorToken)
    }
}

extension RiskSeverity {
    var colorToken: SamouraiColorToken {
        switch self {
        case .low:
            .healthGreenLight
        case .medium:
            .healthAmber
        case .high:
            .healthOrange
        case .critical:
            .healthRed
        }
    }

    var tintColor: Color {
        SamouraiColorTheme.color(colorToken)
    }
}

extension EventPriority {
    var colorToken: SamouraiColorToken {
        switch self {
        case .trivial:
            .textMuted
        case .minor:
            .brandBlue
        case .major:
            .healthAmber
        case .critical:
            .dangerRed
        }
    }

    var tintColor: Color {
        SamouraiColorTheme.color(colorToken)
    }
}

extension ActionPriority {
    var colorToken: SamouraiColorToken {
        switch self {
        case .trivial:
            .textMuted
        case .minor:
            .brandBlue
        case .major:
            .healthAmber
        case .critical:
            .dangerRed
        }
    }

    var tintColor: Color {
        SamouraiColorTheme.color(colorToken)
    }
}

extension DecisionStatus {
    var colorToken: SamouraiColorToken {
        switch self {
        case .proposedUnderReview:
            .brandPurple
        case .validated:
            .brandGreen
        case .abandoned:
            .textMuted
        }
    }

    var tintColor: Color {
        SamouraiColorTheme.color(colorToken)
    }
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let a, r, g, b: UInt64

        switch sanitized.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (
                255,
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17
            )
        case 6: // RGB (24-bit)
            (a, r, g, b) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
