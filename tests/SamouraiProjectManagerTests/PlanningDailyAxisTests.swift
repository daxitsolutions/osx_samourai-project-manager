import Foundation
import Testing
@testable import SamouraiProjectManagerApp

struct PlanningDailyAxisTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    private func activity(start: Date, end: Date, dateless: Bool = false) -> ProjectActivity {
        ProjectActivity(projectID: UUID(), scenarioID: UUID(), title: "Synthetic", isDateless: dateless,
                        estimatedStartDate: start, estimatedEndDate: end)
    }

    @Test func axisPreservesInclusiveDatesLeapDaysAndDST() {
        let input = [activity(start: date(2024, 2, 28), end: date(2024, 4, 2))]
        let axis = PlanningDailyAxis(activities: input, calendar: calendar)
        #expect(axis.days.count == 35)
        #expect(axis.days.first?.date == date(2024, 2, 28, hour: 0))
        #expect(axis.days.last?.date == date(2024, 4, 2, hour: 0))
        #expect(axis.days[1].number == 29)
        #expect(axis.months.map(\.range) == [0..<2, 2..<33, 33..<35])
        for (index, day) in axis.days.enumerated() {
            #expect(day.date == calendar.date(byAdding: .day, value: index, to: axis.days[0].date))
            #expect(day.isWeekend == calendar.isDateInWeekend(day.date))
        }
        // The clock change is 23 hours, never a skipped or duplicate calendar date.
        #expect(axis.days[33].date.timeIntervalSince(axis.days[32].date) == 23 * 3600)
    }

    @Test func emptyDatelessAndMilestoneScopes() {
        #expect(PlanningDailyAxis(activities: [], calendar: calendar).days.isEmpty)
        let none = activity(start: date(2000, 1, 1), end: date(2099, 1, 1), dateless: true)
        #expect(PlanningDailyAxis(activities: [none], calendar: calendar).days.isEmpty)
        let day = activity(start: date(2026, 3, 1), end: date(2026, 3, 1))
        let axis = PlanningDailyAxis(activities: [none, day], calendar: calendar)
        #expect(axis.days.count == 1)
        #expect(axis.months[0].range == 0..<1)
    }

    @Test func viewportCoversEdgesAndKeepsFullScrollExtent() {
        for offset in stride(from: -100.0, through: 40000.0, by: 17) {
            let range = PlanningDailyAxis.visibleColumns(count: 1096, offset: offset, viewportWidth: 1000)
            #expect(range.lowerBound >= 0 && range.upperBound <= 1096)
            #expect(range.count <= 33)
            for column in 0..<1096 {
                let left = 220.0 + Double(column) * 36
                if left + 36 > offset && left < offset + 1000 {
                    #expect(range.contains(column))
                }
            }
            #expect(range.lowerBound + range.count + (1096 - range.upperBound) == 1096)
        }
        #expect(PlanningDailyAxis.visibleColumns(count: 0, offset: 0, viewportWidth: 1000).isEmpty)
        #expect(PlanningDailyAxis.visibleColumns(count: 10, offset: .infinity, viewportWidth: 1000).isEmpty)
        #expect(PlanningDailyAxis.visibleColumns(count: 10, offset: 0, viewportWidth: 0).isEmpty)
        #expect(PlanningDailyAxis.visibleColumns(count: 10, offset: 0, viewportWidth: 1000, dayWidth: 0).isEmpty)
    }

    @Test func threeThousandActivitiesThreeYearsAndEditsRebuildScope() {
        var activities = (0..<3000).map { n in
            activity(start: date(2024, 1, 1), end: date(2026, 12, 31), dateless: n % 10 == 0)
        }
        let start = ContinuousClock.now
        let axis = PlanningDailyAxis(activities: activities, calendar: calendar)
        let elapsed = start.duration(to: .now)
        #expect(axis.days.count == 1096)
        #expect(axis.months.count == 36)
        let columns = PlanningDailyAxis.visibleColumns(count: axis.days.count, offset: 18000, viewportWidth: 1000)
        let rows = PlanningDailyAxis.visibleColumns(count: activities.count, offset: 48000,
                                                  viewportWidth: 800, labelWidth: 52, dayWidth: 32)
        #expect(columns.count <= 33)
        #expect(rows.count <= 30)
        #expect(columns.count * rows.count < 1000)
        activities[1].estimatedEndDate = date(2027, 1, 2)
        let edited = PlanningDailyAxis(activities: activities, calendar: calendar)
        #expect(edited.days.count == 1098)
        #expect(axis.days.count == 1096)
        print("Daily grid: 3000 activities, 1096 days; axis=\(elapsed); viewport=\(rows.count) rows x \(columns.count) columns vs \(3000 * 1096) potential cells. This is a projection bound, not a GUI memory or frame-rate measurement.")
    }
}
