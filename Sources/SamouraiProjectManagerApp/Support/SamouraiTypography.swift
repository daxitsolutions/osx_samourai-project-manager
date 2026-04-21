import SwiftUI
import AppKit

/// Système de typographie réactif. fontSizeOffset est synchronisé avec AppState.fontSizeOffset
/// au niveau de SamouraiProjectManagerApp, ce qui déclenche un re-rendu de toutes les vues
/// utilisant ces propriétés de police.
@MainActor
@Observable
final class SamouraiTypography {

    var fontSizeOffset: Double = 0.0

    // MARK: - Polices à taille explicite (scaled = base + fontSizeOffset)
    // Base body = 14 pt ("Standard Taille 14"), +1 step = +1 pt

    /// Valeur numérique affichée dans les tuiles métriques (ex. : 30 pt en standard)
    var metricLarge: Font {
        .system(size: 30 + CGFloat(fontSizeOffset), weight: .bold, design: .rounded)
    }

    /// Titre de page principal (largeTitle, ex. : 26 pt en standard)
    var titleDisplay: Font {
        .system(size: 26 + CGFloat(fontSizeOffset), weight: .bold)
    }

    /// Titre de section (title, ex. : 20 pt en standard)
    var titleLarge: Font {
        .system(size: 20 + CGFloat(fontSizeOffset), weight: .bold)
    }

    /// Sous-titre de section (title3, ex. : 17 pt en standard)
    var title: Font {
        .system(size: 17 + CGFloat(fontSizeOffset), weight: .semibold)
    }

    /// Texte de mise en emphase (headline, ex. : 14 pt en standard)
    var headline: Font {
        .system(size: 14 + CGFloat(fontSizeOffset), weight: .semibold)
    }

    /// Corps de texte principal (body, ex. : 14 pt en standard)
    var body: Font {
        .system(size: 14 + CGFloat(fontSizeOffset), weight: .regular)
    }

    /// Corps intermédiaire (callout, ex. : 13 pt en standard)
    var callout: Font {
        .system(size: 13 + CGFloat(fontSizeOffset), weight: .regular)
    }

    /// Callout en demi-gras
    var calloutMedium: Font {
        .system(size: 13 + CGFloat(fontSizeOffset), weight: .medium)
    }

    /// Note de bas de page (footnote, ex. : 12 pt en standard)
    var footnote: Font {
        .system(size: 12 + CGFloat(fontSizeOffset), weight: .regular)
    }

    /// Légende/étiquette secondaire (caption, ex. : 11 pt en standard)
    var caption: Font {
        .system(size: 11 + CGFloat(fontSizeOffset), weight: .regular)
    }

    /// Légende en demi-gras
    var captionEmphasized: Font {
        .system(size: 11 + CGFloat(fontSizeOffset), weight: .semibold)
    }

    // MARK: - Générique

    /// Retourne une police avec la taille de base augmentée de l'offset courant.
    func scaled(
        _ base: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        .system(size: base + CGFloat(fontSizeOffset), weight: weight, design: design)
    }

    // MARK: - AppKit

    func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size + CGFloat(fontSizeOffset), weight: weight)
    }
}
