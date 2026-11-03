import SwiftUI

struct ResourceProfilingSummaryCard: View {
    @Environment(AppState.self) private var appState

    let report: ResourceProfilingReport
    let scopeLabel: String

    @State private var isExpanded = false

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.localized("Gestion contextuelle des ressources"))
                        .font(.headline)
                    Text(scopeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(appState.localizedFormat("Profil complet à %d%%", report.completionPercent))
                    .font(.subheadline.weight(.semibold))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "minus.circle" : "plus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(appState.localized(isExpanded ? "Réduire les profils types" : "Afficher tous les profils types"))
            }

            ProgressView(value: report.completionRatio)
                .progressViewStyle(.linear)

            HStack(spacing: 16) {
                Label(appState.localizedFormat("%d/%d rôles pourvus", report.coveredCount, report.requiredRoles.count), systemImage: "checkmark.seal")
                Label(appState.localizedFormat("%d lacune(s)", report.missingRoles.count), systemImage: "exclamationmark.triangle")
                Label(appState.localizedFormat("%d ressource(s) active(s)", report.activeContributorCount), systemImage: "circle.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if isExpanded {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(report.roleCoverage) { coverage in
                        ResourceRoleCoverageRow(coverage: coverage)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ResourceRoleCoverageRow: View {
    @Environment(AppState.self) private var appState

    let coverage: ResourceRoleCoverage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(coverage.isCovered ? "✅" : "⚠️")
                Text(coverage.role.label.appLocalized(language: appState.interfaceLanguage))
                    .font(.subheadline)
                    .lineLimit(2)
            }

            if coverage.assignedResources.isEmpty {
                Text(appState.localized("À pourvoir - aucune ressource assignée"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let assignedNames = coverage.assignedResources.map(\.displayName).joined(separator: ", ")
                let activeNames = coverage.activeResources.map(\.displayName).joined(separator: ", ")
                Text(assignedNames)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(activeNames.isEmpty ? appState.localized("🔵 Actif: aucune contribution active") : appState.localizedFormat("🔵 Actif: %@", activeNames))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.windowBackgroundColor))
        )
    }
}

struct ResourceComparativePerformanceCard: View {
    @Environment(AppState.self) private var appState

    let snapshots: [ResourcePerformanceSnapshot]
    let onEvaluate: (UUID) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(appState.localized("Synthèse comparative de performance"))
                    .font(.headline)
                Spacer()
                let atRiskCount = snapshots.filter { $0.alerts.isEmpty == false }.count
                Text(appState.localizedFormat("%d profil(s) à risque", atRiskCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "minus.circle" : "plus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(appState.localized(isExpanded ? "Réduire la synthèse" : "Afficher la synthèse comparative"))
            }

            if isExpanded {
                Group {
                    if snapshots.isEmpty {
                        Text(appState.localized("Aucune ressource disponible."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(snapshots.prefix(6)), id: \.resourceID) { snapshot in
                            HStack(spacing: 10) {
                                Text(snapshot.alerts.isEmpty ? "✅" : "⚠️")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snapshot.resourceName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(performanceSubtitle(for: snapshot))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(localized("Évaluer")) {
                                    onEvaluate(snapshot.resourceID)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private func performanceSubtitle(for snapshot: ResourcePerformanceSnapshot) -> String {
        let scoreText = snapshot.latestScore.map { String(format: "%.2f/5", $0) } ?? appState.localized("Pas de note")
        let alertsText = snapshot.alerts.isEmpty
            ? appState.localized("Aucune alerte")
            : snapshot.alerts.map { $0.kind.label.appLocalized(language: appState.interfaceLanguage) }.joined(separator: " • ")
        return "\(scoreText) • \(snapshot.trend.label.appLocalized(language: appState.interfaceLanguage)) • \(alertsText)"
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

