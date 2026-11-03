import SwiftUI

// MARK: - Daily Grid View

struct ProjectPlanningDailyGridView: View {
    let activities: [ProjectActivity]
    let axis: PlanningDailyAxis
    let sortedActivities: [ProjectActivity]
    var onShowMonthly: (() -> Void)? = nil
    @State private var window = PlanningDailyWindow(rows: 0..<32, columns: 0..<32)
    var onEditActivity: ((ProjectActivity) -> Void)? = nil
    var onMoveActivity: ((UUID, UUID) -> Void)? = nil

    private static let calendar = Calendar.current
    private static let dayWidth: CGFloat = 36
    private static let rowHeight: CGFloat = 32
    private static let labelWidth: CGFloat = 220

    init(activities: [ProjectActivity], onShowMonthly: (() -> Void)? = nil,
         onEditActivity: ((ProjectActivity) -> Void)? = nil,
         onMoveActivity: ((UUID, UUID) -> Void)? = nil) {
        self.activities = activities
        self.axis = PlanningDailyAxis(activities: activities, calendar: Self.calendar)
        self.sortedActivities = activities.sorted(by: ProjectActivity.planningDisplayOrderPrecedes)
        self.onShowMonthly = onShowMonthly
        self.onEditActivity = onEditActivity
        self.onMoveActivity = onMoveActivity
    }

    private var columns: Range<Int> {
        min(window.columns.lowerBound, axis.days.count)..<min(window.columns.upperBound, axis.days.count)
    }

    private var rows: Range<Int> {
        min(window.rows.lowerBound, sortedActivities.count)..<min(window.rows.upperBound, sortedActivities.count)
    }

    private var gridWidth: CGFloat { Self.labelWidth + CGFloat(axis.days.count) * Self.dayWidth }

    private func isCompleted(_ activity: ProjectActivity) -> Bool {
        activity.actualEndDate != nil
    }

    var body: some View {
        if activities.isEmpty {
            ContentUnavailableView(
                "Aucune activité",
                systemImage: "calendar.badge.exclamationmark",
                description: Text(localized("Ajoutez des activités pour afficher la grille journalière."))
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if axis.days.count > 180, let onShowMonthly {
                    Button(localized("Afficher la grille mensuelle pour cette longue période"), action: onShowMonthly)
                        .buttonStyle(.link)
                }
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow
                        Color.clear.frame(height: CGFloat(rows.lowerBound) * Self.rowHeight)
                        ForEach(rows, id: \.self) { index in
                            let activity = sortedActivities[index]
                            activityRow(activity: activity, isEven: index.isMultiple(of: 2))
                                .frame(height: Self.rowHeight)
                                .overlay(alignment: .bottom) { Divider().opacity(0.25) }
                        }
                        Color.clear.frame(height: CGFloat(sortedActivities.count - rows.upperBound) * Self.rowHeight)
                    }
                    .frame(width: gridWidth, alignment: .leading)
                }
                .onScrollGeometryChange(for: PlanningDailyWindow.self) { geometry in
                    PlanningDailyWindow(
                        rows: PlanningDailyAxis.visibleColumns(count: sortedActivities.count,
                            offset: geometry.visibleRect.minY, viewportWidth: geometry.visibleRect.height,
                            labelWidth: 52, dayWidth: Self.rowHeight),
                        columns: PlanningDailyAxis.visibleColumns(count: axis.days.count,
                            offset: geometry.visibleRect.minX, viewportWidth: geometry.visibleRect.width,
                            labelWidth: Self.labelWidth, dayWidth: Self.dayWidth))
                } action: { _, newValue in
                    window = newValue
                }
                .scrollIndicators(.visible)
            }
            .padding(16)
        }
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.labelWidth, height: 20)
                Color.clear.frame(width: CGFloat(columns.lowerBound) * Self.dayWidth)
                ForEach(axis.months.filter { $0.range.overlaps(columns) }) { month in
                    let count = min(month.range.upperBound, columns.upperBound) - max(month.range.lowerBound, columns.lowerBound)
                    Text(month.date, format: .dateTime.month(.abbreviated).year())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                        .frame(width: CGFloat(count) * Self.dayWidth, height: 20, alignment: .leading)
                        .clipped()
                }
                trailingSpace
            }
            HStack(spacing: 0) {
                Text(localized("Activité"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(width: Self.labelWidth, height: Self.rowHeight, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                Color.clear.frame(width: CGFloat(columns.lowerBound) * Self.dayWidth)
                ForEach(columns, id: \.self) { index in
                    let day = axis.days[index]
                    Text("\(day.number)")
                        .font(.caption2.weight(day.isWeekend ? .bold : .regular))
                        .foregroundStyle(day.isWeekend ? Color.samouraiWarn : Color.secondary)
                        .frame(width: Self.dayWidth, height: Self.rowHeight)
                        .background(Color.secondary.opacity(day.isWeekend ? 0.06 : 0.08))
                }
                trailingSpace
            }
        }
    }

    private var trailingSpace: some View {
        Color.clear.frame(width: CGFloat(axis.days.count - columns.upperBound) * Self.dayWidth)
    }

    private func activityRow(activity: ProjectActivity, isEven: Bool) -> some View {
        let start = Self.calendar.startOfDay(for: activity.estimatedStartDate)
        let end = Self.calendar.startOfDay(for: activity.estimatedEndDate)
        return HStack(spacing: 0) {
            // Activity label
            HStack(spacing: 6) {
                if activity.isDateless {
                    Image(systemName: "calendar.badge.minus")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if activity.isMilestone {
                    Image(systemName: "diamond.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.samouraiAccent)
                } else {
                    Circle()
                        .fill(activity.hierarchyLevel.tintColor.opacity(0.85))
                        .frame(width: 8, height: 8)
                }
                Text(activity.displayTitle)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isCompleted(activity) ? Color.secondary : Color.primary)
                if activity.isDateless {
                    Text(localized("Pas de date"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if isCompleted(activity) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.samouraiSuccess)
                }
            }
            .padding(.horizontal, 8)
            .frame(width: Self.labelWidth, height: Self.rowHeight, alignment: .leading)
            .background(Color.secondary.opacity(isEven ? 0.04 : 0.0))
            .onTapGesture(count: 2) {
                onEditActivity?(activity)
            }

            // Day cells (skipped for dateless activities)
            if !activity.isDateless {
                Color.clear.frame(width: CGFloat(columns.lowerBound) * Self.dayWidth)
                ForEach(columns, id: \.self) { index in
                    let day = axis.days[index]
                    let active = day.date >= start && day.date <= end
                    let weekend = day.isWeekend
                    ZStack {
                        if weekend {
                            Color.samouraiWarn.opacity(0.04)
                        } else if isEven {
                            Color.secondary.opacity(0.03)
                        }
                        if active {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(activity.isMilestone
                                    ? Color.samouraiAccent.opacity(0.75)
                                    : activity.hierarchyLevel.tintColor.opacity(isCompleted(activity) ? 0.35 : 0.70))
                                .padding(.horizontal, 2)
                                .padding(.vertical, 8)
                        }
                    }
                    .frame(width: Self.dayWidth, height: Self.rowHeight)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.10))
                            .frame(width: 0.5)
                    }
                }
                trailingSpace
            } else {
                Color.clear.frame(width: CGFloat(axis.days.count) * Self.dayWidth, height: Self.rowHeight)
            } // end if !activity.isDateless
        }
        .planningActivityDragSource(activityID: activity.id)
        .planningActivityDropTarget(activityID: activity.id) { sourceID, targetID in
            onMoveActivity?(sourceID, targetID)
        }
    }

    @Environment(AppState.self) private var appState

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

