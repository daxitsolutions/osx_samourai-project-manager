import SwiftUI

struct ProjectTimelineView: View {
    let activities: [ProjectActivity]
    let varianceReport: ProjectPlanningVarianceReport?
    let showGanttGrid: Bool

    var body: some View {
        let sortedActivities = activities.sorted { $0.estimatedStartDate < $1.estimatedStartDate }
        let datedActivities = sortedActivities.filter { !$0.isDateless }
        let minDate = datedActivities.map(\.estimatedStartDate).min() ?? .now
        let maxDate = datedActivities.map(\.estimatedEndDate).max() ?? .now
        let totalInterval = max(maxDate.timeIntervalSince(minDate), 1)

        VStack(alignment: .leading, spacing: 8) {
            Text(showGanttGrid ? "Vue Gantt Lite" : "Vue Timeline")
                .font(.headline)

            ForEach(sortedActivities) { activity in
                let startRatio = max(0, min(1, activity.estimatedStartDate.timeIntervalSince(minDate) / totalInterval))
                let endRatio = max(0, min(1, activity.estimatedEndDate.timeIntervalSince(minDate) / totalInterval))
                let widthRatio = max(endRatio - startRatio, 0.015)
                let variance = varianceReport?.activityVariances.first(where: { $0.activityID == activity.id })?.varianceDays ?? 0

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(activity.displayTitle)
                            .font(.subheadline.weight(.semibold))
                        if activity.isMilestone {
                            Text(localized("Jalon"))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.14), in: Capsule())
                        }
                        Spacer()
                        Text("Variance: \(variance == 0 ? "0j" : "\(variance > 0 ? "+" : "")\(variance)j")")
                            .font(.caption)
                            .foregroundStyle(variance > 0 ? .orange : (variance < 0 ? .green : .secondary))
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 14)

                            if showGanttGrid {
                                HStack(spacing: 0) {
                                    ForEach(0..<10, id: \.self) { _ in
                                        Rectangle()
                                            .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                                    }
                                }
                                .frame(height: 14)
                            }

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(activity.isMilestone ? Color.purple.opacity(0.8) : Color.accentColor.opacity(0.85))
                                .frame(width: proxy.size.width * widthRatio, height: 14)
                                .offset(x: proxy.size.width * startRatio)
                        }
                    }
                    .frame(height: 14)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
            }
        }
    }

    @Environment(AppState.self) private var appState

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
