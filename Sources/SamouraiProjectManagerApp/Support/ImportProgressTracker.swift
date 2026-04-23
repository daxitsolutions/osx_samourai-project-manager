import Foundation
import Observation
import SwiftUI

enum ImportProgressStage: String, Sendable {
    case reading
    case parsing
    case analyzing
    case importing
    case finalizing

    var label: String {
        switch self {
        case .reading: "Lecture du fichier…"
        case .parsing: "Analyse des lignes…"
        case .analyzing: "Rapprochement avec l'existant…"
        case .importing: "Intégration dans l'annuaire…"
        case .finalizing: "Finalisation…"
        }
    }
}

@MainActor
@Observable
final class ImportProgressTracker: Identifiable {
    let id = UUID()
    var title: String
    var fileName: String
    var stage: ImportProgressStage = .reading
    var totalRecords: Int = 0
    var processedRecords: Int = 0
    var importedRecords: Int = 0
    var task: Task<Void, Never>?

    init(title: String, fileName: String = "") {
        self.title = title
        self.fileName = fileName
    }

    var progress: Double {
        guard totalRecords > 0 else { return 0 }
        return min(1, Double(processedRecords) / Double(totalRecords))
    }

    var isIndeterminate: Bool { totalRecords == 0 }

    func cancel() { task?.cancel() }

    func setStage(_ stage: ImportProgressStage) { self.stage = stage }
    func setTotal(_ value: Int) { totalRecords = max(0, value) }
    func setProcessed(_ value: Int) { processedRecords = max(0, min(value, totalRecords == 0 ? value : totalRecords)) }
    func setImported(_ value: Int) { importedRecords = max(0, min(value, totalRecords == 0 ? value : totalRecords)) }
}

/// Sendable bridge that forwards progress updates from a background task to the
/// MainActor-isolated `ImportProgressTracker`.
struct ImportProgressReporter: Sendable {
    let setStage: @Sendable (ImportProgressStage) -> Void
    let setTotal: @Sendable (Int) -> Void
    let setProcessed: @Sendable (Int) -> Void
    let setImported: @Sendable (Int) -> Void

    static func forwarding(to tracker: ImportProgressTracker) -> ImportProgressReporter {
        ImportProgressReporter(
            setStage: { stage in
                Task { @MainActor in tracker.setStage(stage) }
            },
            setTotal: { total in
                Task { @MainActor in tracker.setTotal(total) }
            },
            setProcessed: { processed in
                Task { @MainActor in tracker.setProcessed(processed) }
            },
            setImported: { imported in
                Task { @MainActor in tracker.setImported(imported) }
            }
        )
    }

    static let noop = ImportProgressReporter(
        setStage: { _ in },
        setTotal: { _ in },
        setProcessed: { _ in },
        setImported: { _ in }
    )
}

struct SamouraiImportProgressSheet: View {
    @Bindable var tracker: ImportProgressTracker
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tracker.title)
                    .font(.title3.weight(.semibold))
                if tracker.fileName.isEmpty == false {
                    Text(tracker.fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(tracker.stage.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if tracker.isIndeterminate {
                    ProgressView()
                        .progressViewStyle(.linear)
                } else {
                    ProgressView(value: tracker.progress)
                        .progressViewStyle(.linear)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(totalLabel)
                            .font(.callout.monospacedDigit())
                        Text(progressLabel)
                            .font(.callout.monospacedDigit())
                        Text(importedLabel)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if tracker.isIndeterminate == false {
                        Text(percentLabel)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button(role: .cancel) {
                    onCancel()
                } label: {
                    Text("Annuler l'import")
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(minWidth: 420, idealWidth: 460)
    }

    private var totalLabel: String {
        if tracker.totalRecords == 0 {
            return "Total détecté : calcul en cours"
        }
        return "Total détecté : \(tracker.totalRecords)"
    }

    private var progressLabel: String {
        let verb: String

        switch tracker.stage {
        case .reading:
            verb = "lus"
        case .parsing:
            verb = "analysés"
        case .analyzing:
            verb = "préparés"
        case .importing:
            verb = "traités"
        case .finalizing:
            verb = "finalisés"
        }

        if tracker.totalRecords == 0 {
            return "\(tracker.processedRecords) enregistrement(s) \(verb)"
        }

        return "\(tracker.processedRecords) / \(tracker.totalRecords) enregistrement(s) \(verb)"
    }

    private var importedLabel: String {
        if tracker.importedRecords == 0 {
            return "Déjà intégrés : 0"
        }
        return "Déjà intégrés : \(tracker.importedRecords)"
    }

    private var percentLabel: String {
        let percent = Int((tracker.progress * 100).rounded())
        return "\(percent) %"
    }
}
