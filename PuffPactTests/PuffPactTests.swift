//
//  PuffPactTests.swift
//  PuffPactTests
//

import Testing
import SwiftUI
@testable import PuffPact

struct PuffPactTests {

    @Test func testDailyLimitCalculation() {
        #expect(CalendarStatsCalculator.dailyLimit(from: 56) == 8)
        #expect(CalendarStatsCalculator.dailyLimit(from: 20) == 2)
        #expect(CalendarStatsCalculator.dailyLimit(from: 7) == 1)
        #expect(CalendarStatsCalculator.dailyLimit(from: 3) == 1) // max(1, ...)
        #expect(CalendarStatsCalculator.dailyLimit(from: 0) == 1)
    }

    @Test func testRingColorThresholds() {
        let dailyLimit = 10

        // < 50% -> Green (#4ade80)
        let greenColor = Color(hex: "4ade80")
        let orangeColor = Color(hex: "f5a524")
        let redColor = Color(hex: "e5484d")

        #expect(CalendarStatsCalculator.ringColor(todayCount: 0, dailyLimit: dailyLimit) == greenColor)
        #expect(CalendarStatsCalculator.ringColor(todayCount: 4, dailyLimit: dailyLimit) == greenColor)

        // 50% - 90% -> Orange (#f5a524)
        #expect(CalendarStatsCalculator.ringColor(todayCount: 5, dailyLimit: dailyLimit) == orangeColor)
        #expect(CalendarStatsCalculator.ringColor(todayCount: 9, dailyLimit: dailyLimit) == orangeColor)

        // > 90% -> Red (#e5484d)
        #expect(CalendarStatsCalculator.ringColor(todayCount: 10, dailyLimit: dailyLimit) == redColor)
        #expect(CalendarStatsCalculator.ringColor(todayCount: 15, dailyLimit: dailyLimit) == redColor)
    }

    @Test func testPactStatusText() {
        let limit = 56
        let partnerName = "Alex"

        // Neither exceeded
        #expect(CalendarStatsCalculator.pactStatusText(
            meWeekCount: 14,
            friendWeekCount: 12,
            limit: limit,
            friendName: partnerName
        ) == "Both within the pact limit this week 🤝")

        // Exact boundary (limit is not exceeded)
        #expect(CalendarStatsCalculator.pactStatusText(
            meWeekCount: 56,
            friendWeekCount: 56,
            limit: limit,
            friendName: partnerName
        ) == "Both within the pact limit this week 🤝")

        // Current user exceeded
        #expect(CalendarStatsCalculator.pactStatusText(
            meWeekCount: 57,
            friendWeekCount: 40,
            limit: limit,
            friendName: partnerName
        ) == "You exceeded ⚠️")

        // Friend exceeded
        #expect(CalendarStatsCalculator.pactStatusText(
            meWeekCount: 30,
            friendWeekCount: 60,
            limit: limit,
            friendName: partnerName
        ) == "Alex exceeded ⚠️")

        // Both exceeded
        #expect(CalendarStatsCalculator.pactStatusText(
            meWeekCount: 60,
            friendWeekCount: 65,
            limit: limit,
            friendName: partnerName
        ) == "You & Alex exceeded ⚠️")
    }

    @Test func testDailyAvgCalculationOptionB() {
        // Zero active logged days -> 0.0
        #expect(CalendarStatsCalculator.dailyAvg(totalCigarettes: 0, activeLoggedDays: 0) == 0.0)

        // Normal active days
        let avg = CalendarStatsCalculator.dailyAvg(totalCigarettes: 47, activeLoggedDays: 15)
        #expect(abs(avg - 3.1333) < 0.01)

        // Total logged on 1 active day
        #expect(CalendarStatsCalculator.dailyAvg(totalCigarettes: 5, activeLoggedDays: 1) == 5.0)
    }

    @Test func testFinancialImpactCalculation() {
        let costPerStick = 18.0
        let dailyBaseline = 8
        let daysElapsed = 18

        // Expected cigarettes = 8 * 18 = 144
        // Smoked 47 cigarettes -> Saved 97 sticks
        let (savings1, isSaved1) = CalendarStatsCalculator.financialImpact(
            dailyBaseline: dailyBaseline,
            daysElapsed: daysElapsed,
            monthTotal: 47,
            costPerStick: costPerStick
        )
        #expect(isSaved1 == true)
        #expect(savings1 == (144 - 47) * 18.0) // 97 * 18 = 1746.0

        // Smoked more than baseline
        let (savings2, isSaved2) = CalendarStatsCalculator.financialImpact(
            dailyBaseline: dailyBaseline,
            daysElapsed: 10,
            monthTotal: 100, // baseline was 80
            costPerStick: costPerStick
        )
        #expect(isSaved2 == false)
        #expect(savings2 == -20 * 18.0) // -360.0
    }

    @Test func testHeatmapThresholds() {
        // Daily limit 8 -> lowMax = 3, midMax = 6
        let t8 = CalendarStatsCalculator.heatmapThresholds(dailyLimit: 8)
        #expect(t8.lowMax == 3)
        #expect(t8.midMax == 6)

        // Small daily limit 2 -> lowMax = 1, midMax = 2
        let t2 = CalendarStatsCalculator.heatmapThresholds(dailyLimit: 2)
        #expect(t2.lowMax == 1)
        #expect(t2.midMax == 2)
    }

    @Test func testMondayFirstWeekdayAlignment() {
        // Check Monday-first blank calculation logic:
        // Sunday (1 in Greg) -> 6 blanks
        // Monday (2 in Greg) -> 0 blanks
        // Tuesday (3 in Greg) -> 1 blank
        // Saturday (7 in Greg) -> 5 blanks
        func blanks(weekday: Int) -> Int {
            (weekday - 2 + 7) % 7
        }
        #expect(blanks(weekday: 2) == 0) // Monday
        #expect(blanks(weekday: 3) == 1) // Tuesday
        #expect(blanks(weekday: 7) == 5) // Saturday
        #expect(blanks(weekday: 1) == 6) // Sunday
    }

    @Test func testIsCurrentOrFutureMonth() {
        let cal = Calendar.current
        let today = Date()

        // Current month must return true (disables '>')
        #expect(CalendarStatsCalculator.isCurrentOrFutureMonth(today) == true)

        // Previous month must return false (enables '>')
        if let pastMonth = cal.date(byAdding: .month, value: -1, to: today) {
            #expect(CalendarStatsCalculator.isCurrentOrFutureMonth(pastMonth) == false)
        }

        // Previous year must return false (enables '>')
        if let pastYear = cal.date(byAdding: .year, value: -1, to: today) {
            #expect(CalendarStatsCalculator.isCurrentOrFutureMonth(pastYear) == false)
        }

        // Future month must return true (disables '>')
        if let futureMonth = cal.date(byAdding: .month, value: 1, to: today) {
            #expect(CalendarStatsCalculator.isCurrentOrFutureMonth(futureMonth) == true)
        }
    }

    @Test func testPactStatusTextWithBlankPartnerName() {
        let limit = 56

        // Empty partner name falls back to "Partner"
        #expect(CalendarStatsCalculator.pactStatusText(
            meWeekCount: 30,
            friendWeekCount: 60,
            limit: limit,
            friendName: ""
        ) == "Partner exceeded ⚠️")

        // Whitespace partner name falls back to "Partner"
        #expect(CalendarStatsCalculator.pactStatusText(
            meWeekCount: 60,
            friendWeekCount: 65,
            limit: limit,
            friendName: "   "
        ) == "You & Partner exceeded ⚠️")
    }

    @Test func testFinancialImpactZeroDaysElapsed() {
        let (savings, isSaved) = CalendarStatsCalculator.financialImpact(
            dailyBaseline: 8,
            daysElapsed: 0,
            monthTotal: 0,
            costPerStick: 18.0
        )
        #expect(isSaved == true)
        #expect(savings == 0.0)
    }

    @Test func testRingColorDailyLimit8Thresholds() {
        // Daily limit 8
        // 50% = 4.0 sticks
        // 90% = 7.2 sticks
        let limit = 8
        let green = Color(hex: "4ade80")
        let orange = Color(hex: "f5a524")
        let red = Color(hex: "e5484d")

        #expect(CalendarStatsCalculator.ringColor(todayCount: 0, dailyLimit: limit) == green)
        #expect(CalendarStatsCalculator.ringColor(todayCount: 3, dailyLimit: limit) == green) // 37.5% < 50%
        #expect(CalendarStatsCalculator.ringColor(todayCount: 4, dailyLimit: limit) == orange) // 50.0%
        #expect(CalendarStatsCalculator.ringColor(todayCount: 7, dailyLimit: limit) == orange) // 87.5% <= 90%
        #expect(CalendarStatsCalculator.ringColor(todayCount: 8, dailyLimit: limit) == red) // 100.0% > 90%
        #expect(CalendarStatsCalculator.ringColor(todayCount: 12, dailyLimit: limit) == red) // 150.0% > 90%
    }

    @Test func testAllDaysInEveryMonthGenerated() {
        let cal = Calendar.current
        for m in 1...12 {
            var comps = DateComponents()
            comps.year = 2026
            comps.month = m
            comps.day = 1
            guard let monthDate = cal.date(from: comps),
                  let expectedDays = cal.range(of: .day, in: .month, for: monthDate)?.count else {
                continue
            }

            let cells = CalendarStatsCalculator.monthCells(for: monthDate)
            let actualDays = cells.compactMap { $0.dayNumber }

            // Ensure no missing days in this month
            #expect(actualDays.count == expectedDays, "Month \(m) generated \(actualDays.count), expected \(expectedDays)")
            #expect(actualDays == Array(1...expectedDays), "Month \(m) day sequence mismatch")

            // Ensure all cell IDs are unique (zero collision in LazyVGrid)
            let uniqueIDs = Set(cells.map { $0.id })
            #expect(uniqueIDs.count == cells.count, "Duplicate IDs detected in month \(m)")
        }
    }

    @Test func testLogSmokeReflectsImmediatelyInAppState() {
        let state = AppState()
        let userId = state.currentUser.id

        #expect(state.logsFor(userId: userId).count == 0)
        #expect(state.todayCount(for: userId) == 0)
        #expect(state.weekCount(for: userId) == 0)

        state.logSmoke(for: userId, cravingUsed: true)

        #expect(state.logsFor(userId: userId).count == 1)
        #expect(state.todayCount(for: userId) == 1)
        #expect(state.weekCount(for: userId) == 1)
        #expect(state.logs.first?.cravingTimerUsed == true)
        #expect(state.logs.first?.userId == userId)

        // Undo removes it immediately
        state.undoLastLog(for: userId)
        #expect(state.logsFor(userId: userId).count == 0)
        #expect(state.todayCount(for: userId) == 0)
        #expect(state.weekCount(for: userId) == 0)
    }

    @Test func testFriendLogDoesNotAffectCurrentUserLogCount() {
        let state = AppState()
        let myId = state.currentUser.id
        let friendId = state.friendUser.id

        state.logSmoke(for: friendId, cravingUsed: false)

        #expect(state.logsFor(userId: myId).count == 0)
        #expect(state.logsFor(userId: friendId).count == 1)
        #expect(state.todayCount(for: myId) == 0)
        #expect(state.todayCount(for: friendId) == 1)
    }

    @Test func testLogSmokeClosesCravingTimerWhenActive() async throws {
        let state = await AppState()
        let myId = await state.currentUser.id

        await MainActor.run {
            state.isCravingTimerActive = true
        }

        #expect(await state.isCravingTimerActive == true)
        #expect(await state.logsFor(userId: myId).count == 0)

        // Log cigarette while timer is running
        await MainActor.run {
            state.logSmoke(for: myId, cravingUsed: true)
        }

        // Verify immediate UI reflection
        #expect(await state.logsFor(userId: myId).count == 1)
        #expect(await state.todayCount(for: myId) == 1)
        #expect(await state.isDismissingCravingTimer == true)

        // Wait for smooth dismissal
        try await Task.sleep(for: .milliseconds(550))

        #expect(await state.isCravingTimerActive == false)
        #expect(await state.isDismissingCravingTimer == false)
    }

    @Test func testFriendLogDoesNotCloseCravingTimer() async throws {
        let state = await AppState()
        let friendId = await state.friendUser.id

        await MainActor.run {
            state.isCravingTimerActive = true
        }

        #expect(await state.isCravingTimerActive == true)

        // Friend logs a cigarette
        await MainActor.run {
            state.logSmoke(for: friendId, cravingUsed: false)
        }

        // Current user craving timer dismissal should not be triggered
        #expect(await state.isDismissingCravingTimer == false)

        try await Task.sleep(for: .milliseconds(550))
        #expect(await state.isCravingTimerActive == true)
    }

    @Test func testUndoCancelsCravingTimerDismissal() async throws {
        let state = await AppState()
        let myId = await state.currentUser.id

        await MainActor.run {
            state.isCravingTimerActive = true
            state.logSmoke(for: myId, cravingUsed: true)
        }

        #expect(await state.isDismissingCravingTimer == true)

        // Undo immediately
        await MainActor.run {
            state.undoLastLog(for: myId)
        }

        #expect(await state.isDismissingCravingTimer == false)
        #expect(await state.logsFor(userId: myId).count == 0)

        try await Task.sleep(for: .milliseconds(550))
        // Timer should still be active because dismissal was cancelled by undo
        #expect(await state.isCravingTimerActive == true)
    }

    @Test func testManualCloseCravingTimerImmediatelyCloses() async {
        let state = await AppState()

        await MainActor.run {
            state.isCravingTimerActive = true
            state.closeCravingTimer(smoothly: false)
            #expect(state.isCravingTimerActive == false)
            #expect(state.isDismissingCravingTimer == false)
        }
    }
}
