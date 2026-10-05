//
//  CalendarTabView.swift
//  PuffPact
//

import SwiftUI

struct CalendarTabView: View {
    @EnvironmentObject var state: AppState

    // Build a grid of the last 28 days
    private var last28Days: [Date] {
        let cal = Calendar.current
        return (0..<28).compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }.reversed()
    }

    private func logCount(for date: Date, userId: String) -> Int {
        let cal = Calendar.current
        return state.logs.filter { $0.userId == userId && cal.isDate($0.timestamp, inSameDayAs: date) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Calendar")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .padding(.horizontal)

                // Legend
                HStack(spacing: 20) {
                    legendDot(color: .green,  label: "Under limit")
                    legendDot(color: .orange, label: "Near limit")
                    legendDot(color: .red,    label: "Over limit")
                }
                .padding(.horizontal)

                // User cards side by side
                HStack(spacing: 12) {
                    userCalendarColumn(user: state.currentUser)
                    userCalendarColumn(user: state.friendUser)
                }
                .padding(.horizontal)

                // Full log list grouped by date
                VStack(alignment: .leading, spacing: 8) {
                    Text("All Logs")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(last28Days.reversed(), id: \.self) { date in
                        let dayLogs = state.logs.filter {
                            Calendar.current.isDate($0.timestamp, inSameDayAs: date)
                        }
                        if !dayLogs.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)

                                ForEach(dayLogs) { log in
                                    let isMe = log.userId == state.currentUser.id
                                    let name  = isMe ? state.currentUser.name : state.friendUser.name
                                    let emoji = isMe ? state.currentUser.avatarEmoji : state.friendUser.avatarEmoji
                                    HStack {
                                        Text(emoji)
                                        Text(name).font(.subheadline)
                                        Spacer()
                                        Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2).foregroundColor(.secondary)
                                        if log.cravingTimerUsed {
                                            Image(systemName: "timer")
                                                .font(.caption2).foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.cardBackground)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func userCalendarColumn(user: UserProfile) -> some View {
        VStack(spacing: 6) {
            Text(user.avatarEmoji + " " + user.name)
                .font(.caption.bold())

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(last28Days, id: \.self) { date in
                    let count = logCount(for: date, userId: user.id)
                    let limit = state.pactConfig.individualWeeklyLimit
                    let dailyApprox = max(1, limit / 7)
                    let color: Color = count == 0 ? Color.gray.opacity(0.15)
                        : count > dailyApprox     ? .red
                        : count == dailyApprox    ? .orange
                        : .green

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(height: 22)
                        .overlay(
                            count > 0 ?
                            Text("\(count)").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                            : nil
                        )
                }
            }
        }
        .padding(10)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    @ViewBuilder
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}
