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

    // MARK: - Settlement Engine Tests (Bug 2)

    @Test func testPuffPactEngineSettlementScenarios() {
        let limit = 20
        let cost = 18.0

        // Case 4: Perfect Tie
        let tie = PuffPactEngine.evaluateSettlement(
            userAName: "Alice", userACount: 15,
            userBName: "Bob", userBCount: 15,
            limit: limit, costPerStick: cost
        )
        #expect(tie.scenario == .case4Tie)
        #expect(tie.amountOwed == 0.0)
        #expect(tie.penalizedSticks == 0)
        #expect(tie.winnerName == nil)
        #expect(tie.loserName == nil)

        // Case 3: Both Under Limit
        let neither = PuffPactEngine.evaluateSettlement(
            userAName: "Alice", userACount: 12,
            userBName: "Bob", userBCount: 16,
            limit: limit, costPerStick: cost
        )
        #expect(neither.scenario == .case3NeitherExceeded)
        #expect(neither.amountOwed == 0.0)
        #expect(neither.penalizedSticks == 0)
        #expect(neither.winnerName == "Alice")
        #expect(neither.loserName == "Bob")

        // Case 1: Alice Exceeded, Bob Under
        let aliceExceeded = PuffPactEngine.evaluateSettlement(
            userAName: "Alice", userACount: 25,
            userBName: "Bob", userBCount: 18,
            limit: limit, costPerStick: cost
        )
        #expect(aliceExceeded.scenario == .case1OneExceeded)
        #expect(aliceExceeded.userAExcess == 5)
        #expect(aliceExceeded.userBExcess == 0)
        #expect(aliceExceeded.penalizedSticks == 5)
        #expect(aliceExceeded.amountOwed == 5.0 * cost)
        #expect(aliceExceeded.winnerName == "Bob")
        #expect(aliceExceeded.loserName == "Alice")

        // Case 1: Bob Exceeded, Alice Under
        let bobExceeded = PuffPactEngine.evaluateSettlement(
            userAName: "Alice", userACount: 10,
            userBName: "Bob", userBCount: 23,
            limit: limit, costPerStick: cost
        )
        #expect(bobExceeded.scenario == .case1OneExceeded)
        #expect(bobExceeded.userAExcess == 0)
        #expect(bobExceeded.userBExcess == 3)
        #expect(bobExceeded.penalizedSticks == 3)
        #expect(bobExceeded.amountOwed == 3.0 * cost)
        #expect(bobExceeded.winnerName == "Alice")
        #expect(bobExceeded.loserName == "Bob")

        // Case 2: Both Exceeded Limit
        let bothExceeded = PuffPactEngine.evaluateSettlement(
            userAName: "Alice", userACount: 30,
            userBName: "Bob", userBCount: 22,
            limit: limit, costPerStick: cost
        )
        #expect(bothExceeded.scenario == .case2BothExceeded)
        #expect(bothExceeded.userAExcess == 10)
        #expect(bothExceeded.userBExcess == 2)
        #expect(bothExceeded.penalizedSticks == 8)
        #expect(bothExceeded.amountOwed == 8.0 * cost)
        #expect(bothExceeded.winnerName == "Bob")
        #expect(bothExceeded.loserName == "Alice")
    }

    // MARK: - Weekly Cycle & Reset Tests (Bug 3)

    @Test func testCurrentCycleStartDateMondayReset() {
        let appState = AppState()
        appState.pactConfig = PactConfig(individualWeeklyLimit: 20, costPerStick: 18.0, currencySymbol: "₹", resetDayOfWeek: 2) // Monday

        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.hour = 14
        comps.minute = 30

        // Nov 16, 2026 is a Monday (weekday 2)
        comps.day = 16
        if let mondayDate = cal.date(from: comps) {
            let cycleStart = appState.currentCycleStartDate(from: mondayDate)
            #expect(cal.component(.weekday, from: cycleStart) == 2)
            #expect(cal.component(.day, from: cycleStart) == 16)
        }

        // Nov 18, 2026 is a Wednesday (weekday 4) -> cycle start should still be Monday Nov 16
        comps.day = 18
        if let wedDate = cal.date(from: comps) {
            let cycleStart = appState.currentCycleStartDate(from: wedDate)
            #expect(cal.component(.weekday, from: cycleStart) == 2)
            #expect(cal.component(.day, from: cycleStart) == 16)
        }

        // Nov 22, 2026 is a Sunday (weekday 1) -> cycle start should still be Monday Nov 16
        comps.day = 22
        if let sunDate = cal.date(from: comps) {
            let cycleStart = appState.currentCycleStartDate(from: sunDate)
            #expect(cal.component(.weekday, from: cycleStart) == 2)
            #expect(cal.component(.day, from: cycleStart) == 16)
        }

        // Nov 23, 2026 is next Monday -> cycle start should reset to Monday Nov 23
        comps.day = 23
        if let nextMonDate = cal.date(from: comps) {
            let cycleStart = appState.currentCycleStartDate(from: nextMonDate)
            #expect(cal.component(.weekday, from: cycleStart) == 2)
            #expect(cal.component(.day, from: cycleStart) == 23)
        }
    }

    @Test func testCurrentCycleStartDateSundayReset() {
        let appState = AppState()
        appState.pactConfig = PactConfig(individualWeeklyLimit: 20, costPerStick: 18.0, currencySymbol: "₹", resetDayOfWeek: 1) // Sunday

        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.hour = 10
        comps.minute = 0

        // Nov 15, 2026 is Sunday (weekday 1)
        comps.day = 15
        if let sunDate = cal.date(from: comps) {
            let cycleStart = appState.currentCycleStartDate(from: sunDate)
            #expect(cal.component(.weekday, from: cycleStart) == 1)
            #expect(cal.component(.day, from: cycleStart) == 15)
        }

        // Nov 20, 2026 is Friday (weekday 6) -> cycle start should still be Sunday Nov 15
        comps.day = 20
        if let friDate = cal.date(from: comps) {
            let cycleStart = appState.currentCycleStartDate(from: friDate)
            #expect(cal.component(.weekday, from: cycleStart) == 1)
            #expect(cal.component(.day, from: cycleStart) == 15)
        }
    }

    @Test func testPreviousCycleDateInterval() {
        let appState = AppState()
        appState.pactConfig = PactConfig(individualWeeklyLimit: 20, costPerStick: 18.0, currencySymbol: "₹", resetDayOfWeek: 2)

        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 18 // Wednesday Nov 18
        guard let refDate = cal.date(from: comps) else { return }

        let (prevStart, prevEnd) = appState.previousCycleDateInterval(from: refDate)
        let diffDays = cal.dateComponents([.day], from: prevStart, to: prevEnd).day
        #expect(diffDays == 7)
        #expect(cal.component(.day, from: prevEnd) == 16) // Nov 16 (Monday)
        #expect(cal.component(.day, from: prevStart) == 9) // Nov 9 (previous Monday)
    }

    @Test func testWeekCountFiltersByCycleReset() {
        let appState = AppState()
        appState.currentUser = UserProfile(id: "userA", name: "Alice")
        appState.pactConfig = PactConfig(individualWeeklyLimit: 20, costPerStick: 18.0, currencySymbol: "₹", resetDayOfWeek: 2) // Monday

        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11

        // Cycle start is Monday Nov 16 00:00:00
        // Log 1: Sunday Nov 15 (previous cycle)
        comps.day = 15
        comps.hour = 22
        let oldDate = cal.date(from: comps)!

        // Log 2: Tuesday Nov 17 (current cycle)
        comps.day = 17
        comps.hour = 12
        let currentDate1 = cal.date(from: comps)!

        // Log 3: Thursday Nov 19 (current cycle)
        comps.day = 19
        comps.hour = 15
        let currentDate2 = cal.date(from: comps)!

        appState.logs = [
            SmokeLog(id: "1", userId: "userA", timestamp: oldDate),
            SmokeLog(id: "2", userId: "userA", timestamp: currentDate1),
            SmokeLog(id: "3", userId: "userA", timestamp: currentDate2),
            SmokeLog(id: "4", userId: "userB", timestamp: currentDate1) // other user
        ]

        // As of Friday Nov 20, userA should have exactly 2 logs in the current cycle
        comps.day = 20
        let refDate = cal.date(from: comps)!
        #expect(appState.weekCount(for: "userA", on: refDate) == 2)
    }

    @Test func testSettlementBreakdownCodable() throws {
        let breakdown = SettlementBreakdown(
            id: "settlement-123",
            scenario: .case1OneExceeded,
            limit: 20,
            costPerStick: 18.0,
            currency: "₹",
            userAName: "Alice",
            userBName: "Bob",
            userACount: 25,
            userBCount: 15,
            userAExcess: 5,
            userBExcess: 0,
            winnerName: "Bob",
            loserName: "Alice",
            penalizedSticks: 5,
            amountOwed: 90.0,
            summaryMessage: "Alice owes Bob ₹90.00",
            isSettled: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(breakdown)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SettlementBreakdown.self, from: data)

        #expect(decoded.id == breakdown.id)
        #expect(decoded.scenario == breakdown.scenario)
        #expect(decoded.amountOwed == breakdown.amountOwed)
        #expect(decoded.winnerName == breakdown.winnerName)
        #expect(decoded.loserName == breakdown.loserName)
        #expect(decoded.isSettled == breakdown.isSettled)
    }

    // MARK: - Auto Settlement & Multi-Week Cycle Verification

    @Test func testAutoSettlementTriggersEvenWithZeroLogs() {
        let appState = AppState()
        appState.activeGroupId = "testPact"
        appState.currentUser = UserProfile(id: "userA", name: "Alice")
        appState.friendUser = UserProfile(id: "userB", name: "Bob")
        appState.pactConfig = PactConfig(individualWeeklyLimit: 20, costPerStick: 18.0, currencySymbol: "₹", resetDayOfWeek: 2) // Monday

        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 1 // 2 weeks before test
        appState.pactCreatedAt = cal.date(from: comps)!

        // Reference date: Wednesday Nov 18, 2026
        comps.day = 18
        comps.hour = 12
        let testNow = cal.date(from: comps)!

        // Zero smoke logs recorded for previous week (Nov 9 - Nov 16)
        appState.logs = []
        appState.settlements = []

        appState.checkAndAutoTriggerSettlement(now: testNow)

        #expect(appState.showingSettlementSheet == true)
        #expect(appState.latestSettlement != nil)
        #expect(appState.latestSettlement?.userACount == 0)
        #expect(appState.latestSettlement?.userBCount == 0)
        #expect(appState.latestSettlement?.amountOwed == 0.0)
        #expect(appState.latestSettlement?.scenario == .case4Tie)
    }

    @Test func testAutoSettlementDoesNotTriggerForPactCreatedInCurrentCycle() {
        let appState = AppState()
        appState.activeGroupId = "testPact"
        appState.currentUser = UserProfile(id: "userA", name: "Alice")
        appState.friendUser = UserProfile(id: "userB", name: "Bob")
        appState.pactConfig = PactConfig(individualWeeklyLimit: 20, costPerStick: 18.0, currencySymbol: "₹", resetDayOfWeek: 2) // Monday

        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        // Pact created on Tuesday Nov 17 (after current cycle start Nov 16)
        comps.day = 17
        appState.pactCreatedAt = cal.date(from: comps)!

        // Reference date: Wednesday Nov 18
        comps.day = 18
        let testNow = cal.date(from: comps)!

        appState.logs = []
        appState.settlements = []

        appState.checkAndAutoTriggerSettlement(now: testNow)

        #expect(appState.showingSettlementSheet == false)
        #expect(appState.latestSettlement == nil)
    }

    @Test func testAutoSettlementMultiWeekProgression() {
        let appState = AppState()
        appState.activeGroupId = "testPact"
        appState.currentUser = UserProfile(id: "userA", name: "Alice")
        appState.friendUser = UserProfile(id: "userB", name: "Bob")
        appState.pactConfig = PactConfig(individualWeeklyLimit: 20, costPerStick: 18.0, currencySymbol: "₹", resetDayOfWeek: 2) // Monday

        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 1
        appState.pactCreatedAt = cal.date(from: comps)!

        // --- WEEK 1: Nov 16 ---
        comps.day = 16
        comps.hour = 10
        let monNov16 = cal.date(from: comps)!

        // Log 25 sticks for Alice in Week 1 (Nov 11)
        comps.day = 11
        let logDateWeek1 = cal.date(from: comps)!
        for i in 1...25 {
            appState.logs.append(SmokeLog(id: "log1_\(i)", userId: "userA", timestamp: logDateWeek1))
        }

        // Trigger on Nov 16 (settling Nov 9 - Nov 16)
        appState.checkAndAutoTriggerSettlement(now: monNov16)
        #expect(appState.showingSettlementSheet == true)
        #expect(appState.latestSettlement?.userACount == 25)
        #expect(appState.latestSettlement?.scenario == .case1OneExceeded)

        // Archive Week 1 settlement
        let week1Settlement = appState.latestSettlement!
        appState.settlements.append(week1Settlement)
        appState.showingSettlementSheet = false

        // Mid-week Nov 18: should not re-trigger
        comps.day = 18
        let wedNov18 = cal.date(from: comps)!
        appState.checkAndAutoTriggerSettlement(now: wedNov18)
        #expect(appState.showingSettlementSheet == false)

        // --- WEEK 2: Nov 23 ---
        // Log 22 sticks for Bob in Week 2 (Nov 19)
        comps.day = 19
        let logDateWeek2 = cal.date(from: comps)!
        for i in 1...22 {
            appState.logs.append(SmokeLog(id: "log2_\(i)", userId: "userB", timestamp: logDateWeek2))
        }

        comps.day = 23
        comps.hour = 9
        let monNov23 = cal.date(from: comps)!

        // Trigger on Nov 23: MUST trigger settlement for Week 2 (Nov 16 - Nov 23)
        // (This verifies the bug where prior week settlement in [prevStart, now] blocked auto-trigger is resolved)
        appState.checkAndAutoTriggerSettlement(now: monNov23)
        #expect(appState.showingSettlementSheet == true)
        #expect(appState.latestSettlement?.userBCount == 22)
        #expect(appState.latestSettlement?.winnerName == "Alice")
        #expect(appState.latestSettlement?.loserName == "Bob")
    }

    @Test func testHistoricalWeekCountDoesNotLeakFutureLogs() {
        let appState = AppState()
        appState.pactConfig = PactConfig(individualWeeklyLimit: 20, costPerStick: 18.0, currencySymbol: "₹", resetDayOfWeek: 2) // Monday

        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11

        // Week 1: Mon Nov 9 - Mon Nov 16
        comps.day = 11
        let logW1 = cal.date(from: comps)!

        // Week 2: Mon Nov 16 - Mon Nov 23
        comps.day = 18
        let logW2 = cal.date(from: comps)!

        // Week 3: Mon Nov 23 - Mon Nov 30
        comps.day = 25
        let logW3 = cal.date(from: comps)!

        appState.logs = [
            SmokeLog(id: "1", userId: "userA", timestamp: logW1),
            SmokeLog(id: "2", userId: "userA", timestamp: logW2),
            SmokeLog(id: "3", userId: "userA", timestamp: logW3)
        ]

        // Querying weekCount for a date in Week 1 should count ONLY Week 1 log
        comps.day = 12
        let dateInW1 = cal.date(from: comps)!
        #expect(appState.weekCount(for: "userA", on: dateInW1) == 1)

        // Querying weekCount for a date in Week 2 should count ONLY Week 2 log
        comps.day = 20
        let dateInW2 = cal.date(from: comps)!
        #expect(appState.weekCount(for: "userA", on: dateInW2) == 1)
    }

    @Test func testSettlementBreakdownCodableWithCycleDates() throws {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 9
        let start = cal.date(from: comps)!
        comps.day = 16
        let end = cal.date(from: comps)!

        let breakdown = SettlementBreakdown(
            id: "s-cycle-1",
            scenario: .case2BothExceeded,
            limit: 20,
            costPerStick: 18.0,
            currency: "₹",
            userAName: "Alice",
            userBName: "Bob",
            userACount: 26,
            userBCount: 22,
            userAExcess: 6,
            userBExcess: 2,
            winnerName: "Bob",
            loserName: "Alice",
            penalizedSticks: 4,
            amountOwed: 72.0,
            summaryMessage: "Alice owes Bob ₹72.00",
            isSettled: true,
            cycleStartDate: start,
            cycleEndDate: end
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(breakdown)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SettlementBreakdown.self, from: data)

        #expect(decoded.id == breakdown.id)
        #expect(decoded.cycleStartDate == breakdown.cycleStartDate)
        #expect(decoded.cycleEndDate == breakdown.cycleEndDate)
        #expect(decoded.amountOwed == 72.0)
    }
}
