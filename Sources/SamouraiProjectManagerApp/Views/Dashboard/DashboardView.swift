import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cockpit Samourai")
                        .font(.largeTitle.weight(.semibold))
                    Text("Vue de contrôle pragmatique : santé portefeuille, tensions prioritaires et exécution delivery.")
                        .foregroundStyle(.secondary)
                }

                dashboardMetrics
                reportingSection
                upcomingProjectsSection
                criticalRisksSection
                nextDeliverablesSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var dashboardMetrics: some View {
        let projects = scopedProjects
        let allRisks = projects.flatMap(\.risks)
        let allDeliverables = projects.flatMap(\.deliverables)
        let completedDeliverables = allDeliverables.filter(\.isDone).count
        let criticalRisks = allRisks.filter { $0.severity == .critical }.count
        let underTensionProjects = projects.filter { $0.health != .green }.count
        let testingAverage = projects.isEmpty
            ? 0
            : Int((Double(projects.reduce(0) { $0 + $1.testingAverageProgressPercent }) / Double(projects.count)).rounded())
        let blockedTestingPhases = projects.reduce(0) { $0 + $1.blockedTestingPhaseCount }

        return Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                SummaryCard(
                    title: "Projets actifs",
                    value: "\(projects.count)",
                    subtitle: "\(underTensionProjects) sous surveillance",
                    systemImage: "square.grid.2x2"
                )

                SummaryCard(
                    title: "Risques critiques",
                    value: "\(criticalRisks)",
                    subtitle: "À arbitrer sans délai",
                    systemImage: "exclamationmark.triangle"
                )

                SummaryCard(
                    title: "Livrables sécurisés",
                    value: "\(completedDeliverables)/\(allDeliverables.count)",
                    subtitle: "Exécution pilotée par preuve",
                    systemImage: "checkmark.circle"
                )

                SummaryCard(
                    title: "Qualité Tests",
                    value: "\(testingAverage)%",
                    subtitle: "\(blockedTestingPhases) phase(s) bloquée(s)",
                    systemImage: "checklist.checked"
                )
            }
        }
    }

    private var upcomingProjectsSection: some View {
        let projects = scopedProjects

        return VStack(alignment: .leading, spacing: 12) {
            Text("Projets sous contrôle")
                .font(.title2.weight(.semibold))

            if projects.isEmpty {
                ContentUnavailableView(
                    "Aucun projet",
                    systemImage: "square.grid.2x2",
                    description: Text("Crée un premier projet pour démarrer le pilotage.")
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
    }

    private var reportingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reporting & Gouvernance")
                .font(.title2.weight(.semibold))

            HStack(spacing: 12) {
                Button("Reporting Hebdomadaire") {
                    appState.openReporting(.weekly)
                }
                .buttonStyle(.borderedProminent)

                Button("Reporting Mensuel") {
                    appState.openReporting(.monthly)
                }
                .buttonStyle(.bordered)
            }

            Text("Génération automatique à partir des modules Activités, Livrables, Risques, Tests, Décisions et Actions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var criticalRisksSection: some View {
        let criticalRisks = scopedRisks.filter { $0.risk.severity.sortWeight >= RiskSeverity.high.sortWeight }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Tensions à arbitrer")
                .font(.title2.weight(.semibold))

            if criticalRisks.isEmpty {
                ContentUnavailableView(
                    "Pas de tension critique",
                    systemImage: "checkmark.shield",
                    description: Text("Le registre des risques est actuellement sous contrôle.")
                )
            } else {
                ForEach(Array(criticalRisks.prefix(5))) { risk in
                    RiskHighlightRow(entry: risk)
                }
            }
        }
    }

    private var nextDeliverablesSection: some View {
        let nextDeliverables = scopedDeliverables.filter { $0.deliverable.isDone == false }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Prochains livrables")
                .font(.title2.weight(.semibold))

            if nextDeliverables.isEmpty {
                ContentUnavailableView(
                    "Aucun livrable ouvert",
                    systemImage: "checkmark.circle",
                    description: Text("Tous les livrables ont été sécurisés.")
                )
            } else {
                ForEach(Array(nextDeliverables.prefix(5))) { deliverable in
                    DeliverableRow(entry: deliverable)
                }
            }
        }
    }

    private var scopedProjects: [Project] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.projects.filter { $0.id == primaryProjectID }
        }
        return store.projects
    }

    private var scopedRisks: [RiskEntry] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.risks.filter { $0.projectID == primaryProjectID }
        }
        return store.risks
    }

    private var scopedDeliverables: [DeliverableEntry] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.deliverables.filter { $0.projectID == primaryProjectID }
        }
        return store.deliverables
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(project.name)
                        .font(.headline)
                    Spacer()
                    Text(project.phase.label)
                        .foregroundStyle(.secondary)
                }

                Text(project.summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RiskHighlightRow: View {
    let entry: RiskEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(entry.risk.severity.tintColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.risk.displayTitle)
                    .font(.headline)
                Text(entry.projectName)
                    .foregroundStyle(.secondary)
                Text(entry.risk.displayMitigation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.risk.severity.label)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DeliverableRow: View {
    let entry: DeliverableEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.deliverable.title)
                    .font(.headline)
                Text(entry.projectName)
                    .foregroundStyle(.secondary)
                Text(entry.deliverable.details)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.deliverable.dueDate.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
