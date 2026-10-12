//
//  StatsTabView.swift
//  PuffPact
//

import SwiftUI

struct StatsTabView: View {
    @EnvironmentObject var state: AppState

    private var myWeekCount: Int   { state.weekCount(for: state.currentUser.id) }
    private var theirWeekCount: Int { state.weekCount(for: state.friendUser.id) }
    private var myTodayCount: Int  { state.todayCount(for: state.currentUser.id) }
    private var myAllTime: Int     { state.logsFor(userId: state.currentUser.id).count }
    private var theirAllTime: Int  { state.logsFor(userId: state.friendUser.id).count }

    private var myMoneySaved: Double {
        let underLimit = max(0, state.pactConfig.individualWeeklyLimit - myWeekCount)
        return Double(underLimit) * state.pactConfig.costPerStick
    }

    private var myMoneySpent: Double {
        Double(myAllTime) * state.pactConfig.costPerStick
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Stats")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .padding(.horizontal)

                // This week summary
                sectionHeader("This Week")
                HStack(spacing: 14) {
                    statCard(
                        title: state.currentUser.name,
                        value: "\(myWeekCount)",
                        subtitle: "of \(state.pactConfig.individualWeeklyLimit) limit",
                        icon: state.currentUser.avatarEmoji,
                        color: myWeekCount > state.pactConfig.individualWeeklyLimit ? .red : .green
                    )
                    statCard(
                        title: state.friendUser.name,
                        value: "\(theirWeekCount)",
                        subtitle: "of \(state.pactConfig.individualWeeklyLimit) limit",
                        icon: state.friendUser.avatarEmoji,
                        color: theirWeekCount > state.pactConfig.individualWeeklyLimit ? .red : .green
                    )
                }
                .padding(.horizontal)

                // Today
                sectionHeader("Today")
                HStack(spacing: 14) {
                    statCard(title: "Smoked Today", value: "\(myTodayCount)", subtitle: state.currentUser.name, icon: "🚬", color: .orange)
                    statCard(title: "Last Smoke", value: state.timeSinceLastSmoke(for: state.currentUser.id), subtitle: "ago", icon: "⏱️", color: .blue)
                }
                .padding(.horizontal)

                // Money
                sectionHeader("Money")
                HStack(spacing: 14) {
                    statCard(
                        title: "Spent (All Time)",
                        value: "\(state.pactConfig.currencySymbol)\(String(format: "%.0f", myMoneySpent))",
                        subtitle: "\(myAllTime) cigarettes",
                        icon: "💸",
                        color: .red
                    )
                    statCard(
                        title: "Saved This Week",
                        value: "\(state.pactConfig.currencySymbol)\(String(format: "%.0f", myMoneySaved))",
                        subtitle: "vs limit",
                        icon: "💰",
                        color: .green
                    )
                }
                .padding(.horizontal)

                // All-time
                sectionHeader("All Time")
                HStack(spacing: 14) {
                    statCard(title: state.currentUser.name, value: "\(myAllTime)", subtitle: "total logged", icon: "📊", color: .purple)
                    statCard(title: state.friendUser.name, value: "\(theirAllTime)", subtitle: "total logged", icon: "📊", color: .indigo)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
    }

    @ViewBuilder
    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(icon).font(.title2)
                Spacer()
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            Text(title).font(.caption.bold())
            Text(subtitle).font(.caption2).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}
