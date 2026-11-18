//
//  CalendarTabView.swift
//  PuffPact
//

import SwiftUI

// MARK: - Design System Tokens

private let creamColor = Color(hex: "FCD5A4")
private let creamHeadingColor = Color(hex: "FDE8CC")
private let darkCardBackground = Color(hex: "161618")
private let darkPageBackground = Color(hex: "0A0A0B")
private let ringTrackColor = Color(hex: "242428")

private let heatFree = Color(hex: "3a3a42")
private let heatLow  = Color(hex: "2f7a56")
private let heatMid  = Color(hex: "9a6218")
private let heatHigh = Color(hex: "9a3030")
private let heatFuture = Color(hex: "1b1b1e")

// MARK: - Business Logic & Pure Calculations

public struct CalendarStatsCalculator {
    public static func startOfCurrentMonth() -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }

    public static func isCurrentOrFutureMonth(_ date: Date) -> Bool {
        Calendar.current.compare(date, to: Date(), toGranularity: .month) != .orderedAscending
    }

    public static func dailyLimit(from weeklyLimit: Int) -> Int {
        max(1, weeklyLimit / 7)
    }

    public static func ringColor(todayCount: Int, dailyLimit: Int) -> Color {
        guard dailyLimit > 0 else { return Color(hex: "4ade80") }
        let fraction = Double(todayCount) / Double(dailyLimit)
        if fraction > 0.90 {
            return Color(hex: "e5484d") // Red (> 90%)
        } else if fraction >= 0.50 {
            return Color(hex: "f5a524") // Orange (50–90%)
        } else {
            return Color(hex: "4ade80") // Green (< 50%)
        }
    }

    public static func pactStatusText(
        meWeekCount: Int,
        friendWeekCount: Int,
        limit: Int,
        friendName: String
    ) -> String {
        let meExceeded = meWeekCount > limit
        let friendExceeded = friendWeekCount > limit
        let trimmedName = friendName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveFriendName = trimmedName.isEmpty ? "Partner" : trimmedName

        if meExceeded && friendExceeded {
            return "You & \(effectiveFriendName) exceeded ⚠️"
        } else if meExceeded {
            return "You exceeded ⚠️"
        } else if friendExceeded {
            return "\(effectiveFriendName) exceeded ⚠️"
        } else {
            return "Both within the pact limit this week 🤝"
        }
    }

    public static func dailyAvg(totalCigarettes: Int, activeLoggedDays: Int) -> Double {
        guard activeLoggedDays > 0 else { return 0.0 }
        return Double(totalCigarettes) / Double(activeLoggedDays)
    }

    public static func financialImpact(
        dailyBaseline: Int,
        daysElapsed: Int,
        monthTotal: Int,
        costPerStick: Double
    ) -> (savings: Double, isSaved: Bool) {
        let expected = dailyBaseline * daysElapsed
        let diff = expected - monthTotal
        let savings = Double(diff) * costPerStick
        return (savings, savings >= 0)
    }

    public static func heatmapThresholds(dailyLimit: Int) -> (lowMax: Int, midMax: Int) {
        let lowMax = max(1, Int((Double(dailyLimit) * 0.4).rounded(.down)))
        let midMax = max(lowMax + 1, Int((Double(dailyLimit) * 0.8).rounded(.down)))
        return (lowMax, midMax)
    }

    public static func monthCells(
        for selectedMonth: Date,
        logs: [SmokeLog] = [],
        userId: String = "",
        today: Date = Date()
    ) -> [DayCellData] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: selectedMonth),
              let monthInterval = cal.dateInterval(of: .month, for: selectedMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        let weekday = cal.component(.weekday, from: firstDay)
        // Monday-first offset: Sunday (1) -> 6, Monday (2) -> 0, etc.
        let leadingBlanks = (weekday - 2 + 7) % 7

        let startOfToday = cal.startOfDay(for: today)
        let year = cal.component(.year, from: selectedMonth)
        let month = cal.component(.month, from: selectedMonth)

        // Precompute counts for userId for this month
        var countsByDay: [Int: Int] = [:]
        for log in logs where log.userId == userId {
            if cal.isDate(log.timestamp, equalTo: selectedMonth, toGranularity: .month) {
                let day = cal.component(.day, from: log.timestamp)
                countsByDay[day, default: 0] += 1
            }
        }

        var cells: [DayCellData] = []
        cells.reserveCapacity(leadingBlanks + range.count)

        // 1. Leading blanks
        for b in 0..<leadingBlanks {
            cells.append(DayCellData(
                id: "\(year)-\(month)-blank-\(b)",
                dayNumber: nil,
                date: nil,
                count: 0,
                isPast: false,
                isToday: false,
                isFuture: false
            ))
        }

        // 2. Day cells
        for d in 1...range.count {
            guard let dayDate = cal.date(byAdding: .day, value: d - 1, to: firstDay) else { continue }
            let startOfDay = cal.startOfDay(for: dayDate)
            let isToday = startOfDay == startOfToday
            let isPast = startOfDay < startOfToday
            let isFuture = startOfDay > startOfToday

            let count = (isPast || isToday) ? (countsByDay[d] ?? 0) : 0

            cells.append(DayCellData(
                id: "\(year)-\(month)-day-\(d)",
                dayNumber: d,
                date: dayDate,
                count: count,
                isPast: isPast,
                isToday: isToday,
                isFuture: isFuture
            ))
        }

        return cells
    }
}

// MARK: - Models

public struct DayCellData: Identifiable, Equatable {
    public let id: String
    public let dayNumber: Int?
    public let date: Date?
    public let count: Int
    public let isPast: Bool
    public let isToday: Bool
    public let isFuture: Bool
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Small Components

struct StatLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.4)
            .foregroundColor(Color.white.opacity(0.45))
    }
}

// MARK: - Main Tab View

public struct CalendarTabView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedMonth: Date = CalendarStatsCalculator.startOfCurrentMonth()

    private var isCurrentMonth: Bool {
        CalendarStatsCalculator.isCurrentOrFutureMonth(selectedMonth)
    }

    public init() {}

    public var body: some View {
        let cells = CalendarStatsCalculator.monthCells(
            for: selectedMonth,
            logs: state.logs,
            userId: state.currentUser.id,
            today: Date()
        )
        let validDays = cells.filter { $0.dayNumber != nil }
        let elapsedDays = validDays.filter { $0.isPast || $0.isToday }
        let smokeFreeDays = elapsedDays.filter { $0.count == 0 }.count
        let activeLoggedDays = elapsedDays.filter { $0.count > 0 }.count
        let monthTotal = elapsedDays.reduce(0) { $0 + $1.count }
        let dailyAvg = CalendarStatsCalculator.dailyAvg(totalCigarettes: monthTotal, activeLoggedDays: activeLoggedDays)

        let dailyBaseline = CalendarStatsCalculator.dailyLimit(from: state.pactConfig.individualWeeklyLimit)
        let financial = CalendarStatsCalculator.financialImpact(
            dailyBaseline: dailyBaseline,
            daysElapsed: elapsedDays.count,
            monthTotal: monthTotal,
            costPerStick: state.pactConfig.costPerStick
        )

        let todayCount = state.todayCount(for: state.currentUser.id)
        let weeklyLimit = state.pactConfig.individualWeeklyLimit
        let meWeekCount = state.weekCount(for: state.currentUser.id)
        let friendWeekCount = state.weekCount(for: state.friendUser.id)

        let pactMessage = CalendarStatsCalculator.pactStatusText(
            meWeekCount: meWeekCount,
            friendWeekCount: friendWeekCount,
            limit: weeklyLimit,
            friendName: state.friendUser.name
        )

        let thresholds = CalendarStatsCalculator.heatmapThresholds(dailyLimit: dailyBaseline)

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Month Header & Navigation
                MonthHeaderView(
                    selectedMonth: selectedMonth,
                    isCurrentMonth: isCurrentMonth,
                    onPrevious: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
                                let comps = Calendar.current.dateComponents([.year, .month], from: prev)
                                selectedMonth = Calendar.current.date(from: comps) ?? prev
                            }
                        }
                    },
                    onNext: {
                        guard !isCurrentMonth else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
                                let comps = Calendar.current.dateComponents([.year, .month], from: next)
                                selectedMonth = Calendar.current.date(from: comps) ?? next
                            }
                        }
                    }
                )

                // 2. Partner Pact Card
                PartnerPactCardView(
                    currentUserName: state.currentUser.name,
                    friendUserName: state.friendUser.name,
                    meWeekCount: meWeekCount,
                    friendWeekCount: friendWeekCount,
                    weeklyLimit: weeklyLimit,
                    captionText: pactMessage
                )

                // 3. Today's Ring Card + Smoke-Free Card
                HStack(spacing: 12) {
                    TodayRingCardView(todayCount: todayCount, dailyLimit: dailyBaseline)
                    SmokeFreeCardView(days: smokeFreeDays)
                }

                // 4. Monthly Heatmap Card
                MonthlyHeatmapCardView(
                    selectedMonth: selectedMonth,
                    cells: cells,
                    lowMax: thresholds.lowMax,
                    midMax: thresholds.midMax
                )

                // 5. Month Total & Daily Avg Card
                MonthTotalsCardView(
                    total: monthTotal,
                    dailyAvg: dailyAvg
                )

                // 6. Financial Impact Card
                FinancialImpactCardView(
                    savings: financial.savings,
                    isSaved: financial.isSaved,
                    currency: state.pactConfig.currencySymbol,
                    dailyBaseline: dailyBaseline
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(darkPageBackground.ignoresSafeArea())
    }
}

// MARK: - Subviews

// 1. Month Header
struct MonthHeaderView: View {
    let selectedMonth: Date
    let isCurrentMonth: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    private var monthName: String {
        selectedMonth.formatted(.dateTime.month(.wide))
    }

    private var subtitleText: String {
        let cal = Calendar.current
        let selectedYear = cal.component(.year, from: selectedMonth)
        let currentYear = cal.component(.year, from: Date())
        if selectedYear == currentYear {
            return "Your Progress"
        } else {
            return "\(selectedYear) • Your Progress"
        }
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(monthName)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(creamHeadingColor)
                Text(subtitleText)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.45))
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.70))
                        .frame(width: 32, height: 32)
                        .background(darkCardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Previous month")

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(isCurrentMonth ? 0.25 : 0.70))
                        .frame(width: 32, height: 32)
                        .background(darkCardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(isCurrentMonth ? 0.04 : 0.10), lineWidth: 1))
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .disabled(isCurrentMonth)
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Next month")
            }
        }
    }
}

// 2. Partner Pact Card
struct PartnerPactCardView: View {
    let currentUserName: String
    let friendUserName: String
    let meWeekCount: Int
    let friendWeekCount: Int
    let weeklyLimit: Int
    let captionText: String

    private var myDisplayName: String {
        currentUserName.trimmingCharacters(in: .whitespaces).lowercased() == "you"
            ? "You"
            : "\(currentUserName) (you)"
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(myDisplayName)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.55))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(meWeekCount)")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(creamColor)
                        Text("/ \(weeklyLimit)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.40))
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 1, height: 16)

                    ZStack {
                        Circle()
                            .fill(creamColor.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15))
                            .foregroundColor(creamColor)
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 1, height: 16)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(friendUserName)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.55))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(friendWeekCount)")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(creamColor)
                        Text("/ \(weeklyLimit)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.40))
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 72)
            .background(darkCardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(creamColor.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: creamColor.opacity(0.14), radius: 11, x: 0, y: 0)

            Text(captionText)
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
    }
}

// 3. Today's Ring Card
struct TodayRingCardView: View {
    let todayCount: Int
    let dailyLimit: Int

    private var fraction: Double {
        guard dailyLimit > 0 else { return 0 }
        return Double(todayCount) / Double(dailyLimit)
    }

    private var ringColor: Color {
        CalendarStatsCalculator.ringColor(todayCount: todayCount, dailyLimit: dailyLimit)
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(ringTrackColor, lineWidth: 9)

            // Progress stroke (only stroked when fraction > 0 to avoid round cap zero-length dot)
            if fraction > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, fraction))))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.35), radius: 6, x: 0, y: 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: fraction)
            }

            // Inner Text
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(todayCount)")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)
                    Text("/ \(dailyLimit)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                Text("today")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.45))
            }
        }
        .frame(width: 96, height: 96)
        .frame(maxWidth: .infinity)
        .frame(height: 124)
        .background(darkCardBackground)
        .cornerRadius(16)
    }
}

// Smoke-Free Card
struct SmokeFreeCardView: View {
    let days: Int

    private var unitLabel: String {
        days == 1 ? "day" : "days"
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                StatLabel(text: "Smoke-Free")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(days)")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(creamColor)
                    Text(unitLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.40))
                }
            }
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "7fc7a0"))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 124)
        .background(darkCardBackground)
        .cornerRadius(16)
    }
}

// 4. Monthly Heatmap Card
struct MonthlyHeatmapCardView: View {
    let selectedMonth: Date
    let cells: [DayCellData]
    let lowMax: Int
    let midMax: Int

    private var monthName: String {
        selectedMonth.formatted(.dateTime.month(.wide))
    }

    private var lowLabel: String {
        lowMax == 1 ? "Low (1)" : "Low (1-\(lowMax))"
    }

    private var midLabel: String {
        let start = lowMax + 1
        return start == midMax ? "Moderate (\(midMax))" : "Moderate (\(start)-\(midMax))"
    }

    private var highLabel: String {
        "High (\(midMax + 1)+)"
    }

    private var monthHeaderLabel: String {
        let cal = Calendar.current
        let selectedYear = cal.component(.year, from: selectedMonth)
        let currentYear = cal.component(.year, from: Date())
        if selectedYear == currentYear {
            return monthName
        } else {
            return "\(monthName) \(selectedYear)"
        }
    }

    private let weekdaySymbols: [(id: Int, label: String)] = [
        (0, "M"), (1, "T"), (2, "W"), (3, "T"), (4, "F"), (5, "S"), (6, "S")
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Monthly Overview")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(monthHeaderLabel)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.45))
            }

            // Weekday Headers
            HStack(spacing: 6) {
                ForEach(weekdaySymbols, id: \.id) { item in
                    Text(item.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.40))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)
                }
            }

            // Days Grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(cells) { cell in
                    if cell.dayNumber != nil {
                        DayTileView(
                            day: cell,
                            lowMax: lowMax,
                            midMax: midMax
                        )
                    } else {
                        Color.clear
                            .frame(height: 38)
                    }
                }
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
                .padding(.top, 4)

            // Legend
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    legendItem(color: heatFree, label: "Smoke-free", showLeaf: true)
                    Spacer(minLength: 2)
                    legendItem(color: heatLow, label: lowLabel, showLeaf: false)
                    Spacer(minLength: 2)
                    legendItem(color: heatMid, label: midLabel, showLeaf: false)
                    Spacer(minLength: 2)
                    legendItem(color: heatHigh, label: highLabel, showLeaf: false)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    legendItem(color: heatFree, label: "Smoke-free", showLeaf: true)
                    legendItem(color: heatLow, label: lowLabel, showLeaf: false)
                    legendItem(color: heatMid, label: midLabel, showLeaf: false)
                    legendItem(color: heatHigh, label: highLabel, showLeaf: false)
                }
            }
        }
        .padding(14)
        .background(darkCardBackground)
        .cornerRadius(16)
    }

    @ViewBuilder
    private func legendItem(color: Color, label: String, showLeaf: Bool) -> some View {
        HStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(color)
                    .frame(width: 12, height: 12)
                if showLeaf {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Color(hex: "a8e6c4"))
                }
            }
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(Color.white.opacity(0.55))
        }
    }
}

// Heatmap Day Tile
struct DayTileView: View {
    let day: DayCellData
    let lowMax: Int
    let midMax: Int

    private var tileBackground: Color {
        if day.isFuture {
            return heatFuture
        }
        if day.count == 0 {
            return heatFree
        } else if day.count <= lowMax {
            return heatLow
        } else if day.count <= midMax {
            return heatMid
        } else {
            return heatHigh
        }
    }

    private var textColor: Color {
        if day.isPast || day.isToday {
            return Color.white.opacity(0.92)
        } else {
            return Color.white.opacity(0.30)
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let d = day.dayNumber {
                Text("\(d)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if (day.isPast || day.isToday) && day.count == 0 {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 7))
                    .foregroundColor(Color(hex: "a8e6c4"))
                    .padding(4)
            }
        }
        .frame(height: 38)
        .background(tileBackground)
        .cornerRadius(10)
        .overlay(
            Group {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(creamColor, lineWidth: 2)
                        .padding(-2)
                }
            }
        )
    }
}

// 5. Month Totals Card
struct MonthTotalsCardView: View {
    let total: Int
    let dailyAvg: Double

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                StatLabel(text: "Month Total")
                Text("\(total)")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundColor(creamColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: 48)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 4) {
                StatLabel(text: "Daily Avg")
                Text(String(format: "%.1f", dailyAvg))
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundColor(creamColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(darkCardBackground)
        .cornerRadius(16)
    }
}

// 6. Financial Impact Card
struct FinancialImpactCardView: View {
    let savings: Double
    let isSaved: Bool
    let currency: String
    let dailyBaseline: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        StatLabel(text: "Financial Impact")
                        Text(isSaved ? "ON TRACK" : "OVER BUDGET")
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(0.8)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(isSaved ? Color(hex: "2f7a56").opacity(0.35) : Color(hex: "9a3030").opacity(0.35))
                            .foregroundColor(isSaved ? Color(hex: "a8e6c4") : Color(hex: "f87171"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSaved ? Color(hex: "2f7a56").opacity(0.5) : Color(hex: "9a3030").opacity(0.5), lineWidth: 0.8)
                            )
                    }

                    Text("\(currency) \(Int(abs(savings).rounded()))")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(creamColor)
                        .padding(.top, 4)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(creamColor.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: "wallet.bifold")
                        .font(.system(size: 18))
                        .foregroundColor(creamColor)
                }
            }

            Text(isSaved ? "saved this month" : "over baseline this month")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.90))
                .padding(.top, 4)

            Text("vs. your baseline of \(dailyBaseline) \(dailyBaseline == 1 ? "cigarette" : "cigarettes")/day")
                .font(.system(size: 11.5))
                .foregroundColor(Color.white.opacity(0.45))
                .padding(.top, 8)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    creamColor.opacity(0.16),
                    creamColor.opacity(0.04),
                    darkCardBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(darkCardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(creamColor.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: creamColor.opacity(0.15), radius: 14, x: 0, y: 0)
    }
}
