import SwiftUI

struct ResourceGridCard: View {
    let resource: Resource
    let assignedProjectNames: [String]
    let scopedProjectID: UUID?
    let isSelected: Bool
    let isMarkedForExport: Bool
    let templateName: String?
    let linkedProjectResourceCount: Int
    let onToggleExportSelection: () -> Void
    let onToggleFavorite: (() -> Void)?
    let onShowMemo: () -> Void
    let onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(resource.displayName)
                    .font(.headline)
                    .onTapGesture(count: 2) { onEdit?() }
                Spacer()
                if linkedProjectResourceCount > 0 {
                    Label("\(linkedProjectResourceCount)", systemImage: "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help("Template utilisé par \(linkedProjectResourceCount) ressource(s) de projet")
                }
                if let scopedProjectID, resource.assignedProjectIDs.contains(scopedProjectID) {
                    Button(action: {
                        onToggleFavorite?()
                    }) {
                        Image(systemName: resource.isFavorite(in: scopedProjectID) ? "star.fill" : "star")
                            .foregroundStyle(resource.isFavorite(in: scopedProjectID) ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onShowMemo) {
                    Image(systemName: resource.memo.isEmpty ? "doc.text" : "doc.text.fill")
                        .foregroundStyle(resource.memo.isEmpty ? .secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Consulter le mémo")
                Button(action: onToggleExportSelection) {
                    Image(systemName: isMarkedForExport ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isMarkedForExport ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                Circle()
                    .fill(resource.status.tintColor)
                    .frame(width: 10, height: 10)
            }

            Text(resource.displayPrimaryRole.isEmpty ? "Rôle non renseigné" : resource.displayPrimaryRole)
                .foregroundStyle(.secondary)

            if let templateName {
                Label(templateName, systemImage: "doc.plaintext")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                Text(resource.allocationLabel)
                Spacer()
                Text(assignedProjectNames.isEmpty ? "Non affecté" : assignedProjectNames.joined(separator: ", "))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
    }
}

