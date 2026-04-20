import SwiftUI
import AppKit

@MainActor
final class SamouraiTypography {
    static let shared = SamouraiTypography()

    var appFont: Font {
        .system(size: 14, weight: .regular, design: .default)
    }

    private init() {}

    func nsFont(size: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: .regular)
    }
}
