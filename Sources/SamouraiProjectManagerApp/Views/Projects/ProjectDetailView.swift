import SwiftUI

struct ProjectDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let projectID: UUID

    @State private var isShowingRiskEditor = false
    @State private var isShowingDeliverableEditor = false

    var body: some View {
        Group {
            if let project = store.project(with: projectID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(project: project)
                        metrics(project: project)
                        resourcesSection(project: project)
                        risksSection(project: project)
                        deliverablesSection(project: project)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "Projet introuvable",
                    systemImage: "exclamationmark.circle",
                    description: Text("Le projet sélectionné n'existe plus dans le stockage local.")
                )
            }
        }
        .sheet(isPresented: $isShowingRiskEditor) {
            RiskEditorSheet(projectID: projectID)
        }
        .sheet(isPresented: $isShowingDeliverableEditor) {
            DeliverableEditorSheet(projectID: projectID)
        }
    }

    private func header(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.largeTitle.weight(.semibold))
                    Text(project.summary)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(project.health.label)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(project.health.tintName).opacity(0.15), in: Capsule())
            }

            HStack(spacing: 18) {
                Label(project.phase.label, systemImage: "flag.pattern.checkered")
                Label(project.deliveryMode.label, systemImage: "arrow.trianglehead.branch")
                Label("Sponsor: \(project.sponsor)", systemImage: "person.2")
                Label("Pilote: \(project.manager)", systemImage: "person.crop.circle")
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Label("Démarrage \(project.startDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Label("Cible \(project.targetDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar.badge.clock")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private func metrics(project: Project) -> some View {
        HStack(spacing: 16) {
            detailMetric(title: "Avancement livrables", value: project.completionRatio.formatted(.percent.precision(.fractionLength(0))))
            detailMetric(title: "Risques ouverts", value: "\(project.risks.count)")
            detailMetric(title: "Critiques", value: "\(project.criticalRiskCount)")
        }
    }

    private func detailMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func resourcesSection(project: Project) -> some View {
        let assignedResources = store.resources(for: project.id)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ressources affectées")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Gérer les ressources") {
                    appState.selectedSection = .resources
                }
            }

            if assignedResources.isEmpty {
                ContentUnavailableView(
                    "Aucune ressource affectée",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Assigne des ressources à ce projet pour matérialiser la capacité réellement disponible.")
                )
            } else {
                ForEach(assignedResources) { resource in
                    Button {
                        appState.openResource(resource.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color(resource.status.tintName))
                                .frame(width: 10, height: 10)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(resource.displayName)
                                        .font(.headline)
                                    Spacer()
                                    Text(resource.allocationLabel)
                                        .foregroundStyle(.secondary)
                                }

                                Text(resource.displayPrimaryRole.isEmpty ? "Rôle non renseigné" : resource.displayPrimaryRole)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 16) {
                                    Text(resource.engagement.label)
                                    Text(resource.status.label)
                                }
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func risksSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Registre des risques")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Ajouter un risque") {
                    isShowingRiskEditor = true
                }
            }

            if project.sortedRisks.isEmpty {
                ContentUnavailableView(
                    "Aucun risque",
                    systemImage: "checkmark.shield",
                    description: Text("Ajoute les points de tension pour garder une vision réaliste de l'exécution.")
                )
            } else {
                ForEach(project.sortedRisks) { risk in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(risk.displayTitle)
                                .font(.headline)
                            Spacer()
                            Text(risk.severity.label)
                                .foregroundStyle(.secondary)
                        }

                        Text("Owner: \(risk.displayOwner.isEmpty ? "-" : risk.displayOwner)")
                            .foregroundStyle(.secondary)

                        Text(risk.displayMitigation)
                            .font(.callout)

                        if let dueDate = risk.dueDate {
                            Text("Action attendue pour le \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func deliverablesSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Livrables")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Ajouter un livrable") {
                    isShowingDeliverableEditor = true
                }
            }

            if project.sortedDeliverables.isEmpty {
                ContentUnavailableView(
                    "Aucun livrable",
                    systemImage: "doc.badge.plus",
                    description: Text("Crée les livrables de contrôle et de delivery pour matérialiser l'avancement.")
                )
            } else {
                ForEach(project.sortedDeliverables) { deliverable in
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            store.toggleDeliverable(projectID: project.id, deliverableID: deliverable.id)
                        } label: {
                            Image(systemName: deliverable.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(deliverable.title)
                                    .font(.headline)
                                Spacer()
                                Text(deliverable.dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }

                            Text("Owner: \(deliverable.owner)")
                                .foregroundStyle(.secondary)
                            Text(deliverable.details)
                                .font(.callout)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}
