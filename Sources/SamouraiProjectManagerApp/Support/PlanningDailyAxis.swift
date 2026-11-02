import Foundation

/// Prepared once for an activity scope, never rebuilt by individual rows or scroll events.
struct PlanningDailyAxis {
    struct Day {
        let date: Date
        let number: Int
        let isWeekend: Bool
    }
    struct Month: Identifiable {
        let date: Date
        let range: Range<Int>
        var id: Date { date }
    }
    let days: [Day]
    let months: [Month]

    init(activities: [ProjectActivity], calendar: Calendar = .current) {
        let dated = activities.filter { !$0.isDateless }
        guard let first = dated.map(\.estimatedStartDate).min(),
              let last = dated.map(\.estimatedEndDate).max() else {
            days = []; months = []; return
        }
        var result: [Day] = []
        var groups: [Month] = []
        var current = calendar.startOfDay(for: first)
        let end = calendar.startOfDay(for: last)
        var monthStart = current
        var groupStart = 0
        while current <= end {
            if !calendar.isDate(current, equalTo: monthStart, toGranularity: .month) {
                groups.append(Month(date: monthStart, range: groupStart..<result.count))
                monthStart = current
                groupStart = result.count
            }
            result.append(Day(date: current, number: calendar.component(.day, from: current),
                              isWeekend: calendar.isDateInWeekend(current)))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current), next > current else { break }
            current = next
        }
        if !result.isEmpty { groups.append(Month(date: monthStart, range: groupStart..<result.count)) }
        days = result
        months = groups
    }

    /// One screen plus two guard columns on either side; omitted columns keep their width.
    static func visibleColumns(count: Int, offset: Double, viewportWidth: Double,
                               labelWidth: Double = 220, dayWidth: Double = 36) -> Range<Int> {
        guard count > 0, dayWidth > 0, offset.isFinite, viewportWidth.isFinite,
              viewportWidth > 0 else { return 0..<0 }
        let start = max(0, min(Double(count), floor((offset - labelWidth) / dayWidth) - 2))
        let end = max(start, min(Double(count), ceil((offset + viewportWidth - labelWidth) / dayWidth) + 2))
        return Int(start)..<Int(end)
    }
}

struct PlanningDailyWindow: Equatable {
    let rows: Range<Int>
    let columns: Range<Int>
}
