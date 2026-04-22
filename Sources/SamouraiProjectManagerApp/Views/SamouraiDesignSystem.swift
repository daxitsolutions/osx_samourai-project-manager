import SwiftUI

enum SamouraiLayout {
    static let pagePadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let cardCornerRadius: CGFloat = 18
}

enum SamouraiSurface {
    static let canvasTop = Color(nsColor: .windowBackgroundColor)
    static let canvasBottom = Color(nsColor: .underPageBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let panelStrong = Color(nsColor: .textBackgroundColor).opacity(0.78)
    static let sidebar = Color(nsColor: .underPageBackgroundColor).opacity(0.78)
    static let border = Color.primary.opacity(0.08)
    static let borderStrong = Color.primary.opacity(0.14)
    static let mutedText = Color.secondary
    static let accent = SamouraiColorTheme.color(.brandBlue)
}

struct SamouraiPageHeader<Trailing: View>: View {
    @Environment(SamouraiTypography.self) private var typography

    let eyebrow: String?
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                if let eyebrow, eyebrow.isEmpty == false {
                    Text(eyebrow.uppercased())
                        .font(typography.captionEmphasized)
                        .foregroundStyle(SamouraiSurface.accent)
                        .tracking(0.8)
                }

                Text(title)
                    .font(typography.titleDisplay)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(typography.body)
                    .foregroundStyle(SamouraiSurface.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            trailing()
        }
    }
}

struct SamouraiSectionCard<Content: View, Trailing: View>: View {
    @Environment(SamouraiTypography.self) private var typography

    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(typography.title)

                    if let subtitle, subtitle.isEmpty == false {
                        Text(subtitle)
                            .font(typography.callout)
                            .foregroundStyle(SamouraiSurface.mutedText)
                    }
                }

                Spacer(minLength: 12)
                trailing()
            }

            content()
        }
        .padding(20)
        .samouraiCardSurface()
    }
}

struct SamouraiMetricTile: View {
    @Environment(SamouraiTypography.self) private var typography

    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    init(title: String, value: String, subtitle: String, systemImage: String, accent: Color = SamouraiSurface.accent) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accent = accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(typography.calloutMedium)
                .foregroundStyle(SamouraiSurface.mutedText)

            Text(value)
                .font(typography.metricLarge)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(typography.callout)
                .foregroundStyle(SamouraiSurface.mutedText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SamouraiLayout.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.14),
                            SamouraiSurface.panelStrong
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: SamouraiLayout.cardCornerRadius, style: .continuous)
                .stroke(SamouraiSurface.borderStrong, lineWidth: 1)
        )
    }
}

struct SamouraiEmptyStateCard: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
        .samouraiCardSurface()
    }
}

struct SamouraiStatusPill: View {
    @Environment(SamouraiTypography.self) private var typography

    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(typography.captionEmphasized)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct SamouraiDebugPanel: View {
    @Environment(SamouraiTypography.self) private var typography

    let context: SamouraiDebugContext
    let isHistoryEnabled: Bool
    let historyFilePath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "ladybug.fill")
                    .foregroundStyle(Color.orange)
                Text("Debug — \(context.section.title)")
                    .font(typography.headline)
                Spacer()
                if isHistoryEnabled, let historyFilePath {
                    Label(historyFilePath, systemImage: "square.and.arrow.down")
                        .labelStyle(.titleAndIcon)
                        .font(typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(historyFilePath)
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 160), alignment: .topLeading),
                    GridItem(.flexible(minimum: 160), alignment: .topLeading),
                    GridItem(.flexible(minimum: 160), alignment: .topLeading),
                    GridItem(.flexible(minimum: 200), alignment: .topLeading)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                debugColumn(title: "Vues", items: context.views, systemImage: "rectangle.3.group")
                debugColumn(title: "Entités", items: context.entities, systemImage: "cube.box")
                debugColumn(title: "Énumérations", items: context.enumerations, systemImage: "list.bullet.rectangle")
                debugColumn(title: "Données", items: context.data, systemImage: "chart.bar.doc.horizontal")
            }

            if let action = context.action, action.isEmpty == false {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").foregroundStyle(Color.orange)
                    Text("Action en cours :")
                        .font(typography.captionEmphasized)
                    Text(action)
                        .font(typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, SamouraiLayout.pagePadding)
        .padding(.vertical, 10)
        .background(SamouraiSurface.panelStrong)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SamouraiSurface.borderStrong)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func debugColumn(title: String, items: [String], systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(typography.captionEmphasized)
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text("—")
                    .font(typography.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(typography.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
    }
}

extension View {
    func samouraiCardSurface() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: SamouraiLayout.cardCornerRadius, style: .continuous)
                    .fill(SamouraiSurface.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SamouraiLayout.cardCornerRadius, style: .continuous)
                    .stroke(SamouraiSurface.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
    }

    func samouraiEditorSurface(minHeight: CGFloat? = nil) -> some View {
        self
            .padding(10)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SamouraiSurface.panelStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SamouraiSurface.borderStrong, lineWidth: 1)
            )
    }

    func samouraiCanvasBackground() -> some View {
        self.background(
            LinearGradient(
                colors: [SamouraiSurface.canvasTop, SamouraiSurface.canvasBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
