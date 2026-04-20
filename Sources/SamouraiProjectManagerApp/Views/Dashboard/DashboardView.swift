import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    private let metricsColumns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SamouraiLayout.sectionSpacing) {
                SamouraiPageHeader(
                    eyebrow: "Pilotage",
                    title: "Cockpit portefeuille",
                    subtitle: "Les signaux clés, les arbitrages urgents et les prochains engagements sont regroupés ici pour aider l’utilisateur à décider vite."
                ) {
                    HStack(spacing: 10) {
                        Button("Reporting hebdomadaire") {
                            appState.openReporting(.weekly)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Reporting mensuel") {
                            appState.openReporting(.monthly)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                LazyVGrid(columns: metricsColumns, alignment: .leading, spacing: 16) {
                    SamouraiMetricTile(
                        title: "Projets actifs",
                        value: "\(projects.count)",
                        subtitle: "\(underTensionProjects) sous surveillance",
                        systemImage: "square.grid.2x2",
                        accent: SamouraiColorTheme.color(.brandBlue)
                    )

                    SamouraiMetricTile(
                        title: "Risques critiques",
                        value: "\(criticalRisksCount)",
                        subtitle: "À arbitrer sans délai",
                        systemImage: "exclamationmark.triangle",
                        accent: SamouraiColorTheme.color(.dangerRed)
                    )

                    SamouraiMetricTile(
                        title: "Livrables sécurisés",
                        value: "\(completedDeliverablesCount)/\(deliverables.count)",
                        subtitle: "Exécution pilotée par preuve",
                        systemImage: "checkmark.circle",
                        accent: SamouraiColorTheme.color(.brandGreen)
                    )

                    SamouraiMetricTile(
                        title: "Qualité tests",
                        value: "\(testingAverage)%",
                        subtitle: "\(blockedTestingPhases) phase(s) bloquée(s)",
                        systemImage: "testtube.2",
                        accent: SamouraiColorTheme.color(.warnYellow)
                    )
                }

                SamouraiSectionCard(
                    title: "Projets sous contrôle",
                    subtitle: "Vue synthétique des initiatives en cours dans le périmètre actif."
                ) {
                    if projects.isEmpty {
                        SamouraiEmptyStateCard(
                            title: "Aucun projet",
                            systemImage: "square.grid.2x2",
                            description: "Crée un premier projet pour démarrer le pilotage."
                        )
                    } else {
                        ForEach(projects) { project in
                            Button {
                                appState.openProject(project.id)
                            } label: {
                                ProjectOverviewRow(project: project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SamouraiSectionCard(
                    title: "Tensions à arbitrer",
                    subtitle: "Les risques les plus exposés sont remontés en priorité pour limiter les surprises."
                ) {
                    if highlightedRisks.isEmpty {
                        SamouraiEmptyStateCard(
                            title: "Pas de tension critique",
                            systemImage: "checkmark.shield",
                            description: "Le registre des risques est actuellement sous contrôle."
                        )
                    } else {
                        ForEach(Array(highlightedRisks.prefix(5))) { risk in
                            RiskHighlightRow(entry: risk)
                        }
                    }
                }

                SamouraiSectionCard(
                    title: "Prochains livrables",
                    subtitle: "Les livrables ouverts à horizon proche restent visibles sans navigation supplémentaire."
                ) {
                    if openDeliverables.isEmpty {
                        SamouraiEmptyStateCard(
                            title: "Aucun livrable ouvert",
                            systemImage: "checkmark.circle",
                            description: "Tous les livrables du périmètre sont actuellement sécurisés."
                        )
                    } else {
                        ForEach(Array(openDeliverables.prefix(5))) { deliverable in
                            DeliverableRow(entry: deliverable)
                        }
                    }
                }
            }
            .padding(SamouraiLayout.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
        .samouraiCanvasBackground()
    }

    private var projects: [Project] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.projects.filter { $0.id == primaryProjectID }
        }
        return store.projects
    }

    private var highlightedRisks: [RiskEntry] {
        scopedRisks.filter { $0.risk.severity.sortWeight >= RiskSeverity.high.sortWeight }
    }

    private var deliverables: [DeliverableEntry] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.deliverables.filter { $0.projectID == primaryProjectID }
        }
        return store.deliverables
    }

    private var openDeliverables: [DeliverableEntry] {
        deliverables.filter { $0.deliverable.isDone == false }
    }

    private var scopedRisks: [RiskEntry] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.risks.filter { $0.projectID == primaryProjectID }
        }
        return store.risks
    }

    private var underTensionProjects: Int {
        projects.filter { $0.health != .green }.count
    }

    private var criticalRisksCount: Int {
        projects.flatMap(\.risks).filter { $0.severity == .critical }.count
    }

    private var completedDeliverablesCount: Int {
        deliverables.filter(\.deliverable.isDone).count
    }

    private var testingAverage: Int {
        guard projects.isEmpty == false else { return 0 }
        let total = projects.reduce(0) { $0 + $1.testingAverageProgressPercent }
        return Int((Double(total) / Double(projects.count)).rounded())
    }

    private var blockedTestingPhases: Int {
        projects.reduce(0) { $0 + $1.blockedTestingPhaseCount }
    }
}

private struct ProjectOverviewRow: View {
    let project: Project

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(project.health.tintColor)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        Text(project.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    SamouraiStatusPill(text: project.phase.label, tint: project.health.tintColor)
                }

                HStack {
                    Label(project.deliveryMode.label, systemImage: "point.3.connected.trianglepath.dotted")
                    Spacer()
                    Text("Échéance \(project.targetDate.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .samouraiCardSurface()
    }
}

private struct RiskHighlightRow: View {
    let entry: RiskEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(entry.risk.severity.tintColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.risk.displayTitle)
                            .font(.headline)
                        Text(entry.projectName)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    SamouraiStatusPill(text: entry.risk.severity.label, tint: entry.risk.severity.tintColor)
                }

                Text(entry.risk.displayMitigation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .samouraiCardSurface()
    }
}

private struct DeliverableRow: View {
    let entry: DeliverableEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(SamouraiSurface.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.deliverable.title)
                            .font(.headline)
                        Text(entry.projectName)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    SamouraiStatusPill(
                        text: entry.deliverable.dueDate.formatted(date: .abbreviated, time: .omitted),
                        tint: SamouraiSurface.accent
                    )
                }

                Text(entry.deliverable.details)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .samouraiCardSurface()
    }
}
