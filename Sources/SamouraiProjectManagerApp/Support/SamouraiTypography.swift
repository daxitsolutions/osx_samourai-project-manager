import SwiftUI
import AppKit
import CoreText

@MainActor
final class SamouraiTypography {
    static let shared = SamouraiTypography()

    let fontName: String?

    var appFont: Font {
        guard let fontName else { return .body }
        return .custom(fontName, size: 14, relativeTo: .body)
    }

    private init() {
        let folderURL = Self.fontsFolderURL()
        self.fontName = Self.registerFontsAndResolvePrimaryName(in: folderURL)
    }

    func nsFont(size: CGFloat) -> NSFont {
        guard let fontName, let custom = NSFont(name: fontName, size: size) else {
            return NSFont.systemFont(ofSize: size)
        }
        return custom
    }

    private static func registerFontsAndResolvePrimaryName(in folderURL: URL) -> String? {
        let preferredFilenames = [
            "Fontspring-DEMO-clarikaprogrot-rg.otf",
            "Fontspring-DEMO-clarikaprogeo-rg.otf"
        ]

        let allFontFiles = ((try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["otf", "ttf"].contains($0.pathExtension.lowercased()) }

        for fontURL in allFontFiles {
            _ = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }

        let orderedCandidates = preferredFilenames.compactMap { preferred in
            allFontFiles.first { $0.lastPathComponent == preferred }
        } + allFontFiles

        for candidate in orderedCandidates {
            if let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(candidate as CFURL) as? [CTFontDescriptor])?.first,
               let postScriptName = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String,
               NSFont(name: postScriptName, size: 14) != nil {
                return postScriptName
            }
        }

        return nil
    }

    private static func fontsFolderURL() -> URL {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let pathComponents = sourceFileURL.pathComponents
        if let sourcesIndex = pathComponents.firstIndex(of: "Sources") {
            let rootComponents = pathComponents.prefix(sourcesIndex)
            let rootPath = NSString.path(withComponents: Array(rootComponents))
            return URL(fileURLWithPath: rootPath).appending(path: "others/UI_Fonts", directoryHint: .isDirectory)
        }

        return sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "others/UI_Fonts", directoryHint: .isDirectory)
    }
}
