//
//  DashboardView.swift
//  PuffPact
//  Dark charcoal + warm cream dashboard styling.
//

import SwiftUI

// MARK: - Design System Tokens

private enum PuffTheme {
    static let background = Color(hex: "000000")
    static let card = Color(hex: "242426")
    static let cardSoft = Color(hex: "2B2B2E")
    static let cream = Color(hex: "FFD9A8")
    static let creamSoft = Color(hex: "FDE8CC")
    static let orange = Color(hex: "FFAA1D")
    static let muted = Color.white.opacity(0.58)
    static let faint = Color.white.opacity(0.34)
    static let track = Color.white.opacity(0.22)
}

// MARK: - Tab Enum

enum DashboardTab: String, CaseIterable {
    case home, calendar, stats, journal, profile
}

// MARK: - Dashboard Root

public struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var authService: FirebaseAuthService

    let userId: String
    let groupId: String
    @State private var selectedTab: DashboardTab = .home

    public init(userId: String, groupId: String) {
        self.userId = userId
        self.groupId = groupId
    }

    public var body: some View {
        Group {
            #if os(macOS)
            tabContent.frame(minWidth: 400, minHeight: 650)
            #else
            NavigationView {
                tabContent.navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            #endif
        }
        .preferredColorScheme(.dark)
        .onAppear { state.configure(userId: userId, groupId: groupId) }
    }

    // MARK: - Tab Container

    private var tabContent: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:     homeTab
                case .calendar: CalendarTabView()
                case .stats:    StatsTabView()
                case .journal:  JournalTabView()
                case .profile:  ProfileTabView(groupId: groupId)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selected: $selectedTab) {
                state.isCravingTimerActive = true
            }
            .padding(.bottom, 12)
        }
        .background(PuffTheme.background.ignoresSafeArea())
        .sheet(isPresented: $state.isCravingTimerActive) {
            CravingPauseView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(26)
                .presentationBackground(PauseTheme.canvas)
        }
        .sheet(isPresented: $state.showingSettlementSheet) {
            SettlementView()
        }
        .onChange(of: state.logsFor(userId: state.currentUser.id).count) { oldCount, newCount in
            guard newCount > oldCount, state.isCravingTimerActive else { return }
            state.closeCravingTimer(smoothly: true)
        }
    }

    // MARK: - Home Tab Content

    private var homeTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header

                progressCard

                pactSummary

                if let debt = state.currentProjectedOwedSummary {
                    penaltyCard(debt: debt)
                }

                quickActions

                recentLogs
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 100)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 9) {
                Image(systemName: "wind")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(PuffTheme.cream)
                Text("PUFFPACT")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(PuffTheme.cream)
            }

            Spacer()

            // Static notification icon (notifications coming in a future update)
            Image(systemName: "bell.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 42, height: 42)
                .background(PuffTheme.card.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 13))
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        let limit = max(1, state.pactConfig.individualWeeklyLimit)
        let count = state.weekCount(for: state.currentUser.id)
        let progress = min(1, Double(count) / Double(limit))
        let percentage = Int(progress * 100)

        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Daily progress")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("A little progress, every day.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(PuffTheme.muted)
                }
                Spacer()
                HStack(spacing: -7) {
                    avatarBubble(state.currentUser.avatarEmoji)
                    avatarBubble(state.friendUser.avatarEmoji)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(percentage)%")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(count) of \(limit) this week")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(PuffTheme.faint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(PuffTheme.track)
                    Capsule()
                        .fill(PuffTheme.orange)
                        .frame(width: max(5, proxy.size.width * progress))
                }
            }
            .frame(height: 5)

            HStack {
                Text("PACT CODE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(PuffTheme.faint)
                Text(groupId)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(PuffTheme.creamSoft)
                    .lineLimit(1)
                Spacer()
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(groupId, forType: .string)
                    #else
                    UIPasteboard.general.string = groupId
                    #endif
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(PuffTheme.cream)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(17)
        .background(
            RoundedRectangle(cornerRadius: 19)
                .fill(PuffTheme.card.opacity(0.96))
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
    }

    // MARK: - Pact Summary

    private var pactSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your pact")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("THIS WEEK")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(PuffTheme.faint)
            }

            HStack(spacing: 10) {
                miniUserCard(
                    user: state.currentUser,
                    count: state.weekCount(for: state.currentUser.id),
                    today: state.todayCount(for: state.currentUser.id),
                    limit: state.pactConfig.individualWeeklyLimit
                )
                miniUserCard(
                    user: state.friendUser,
                    count: state.weekCount(for: state.friendUser.id),
                    today: state.todayCount(for: state.friendUser.id),
                    limit: state.pactConfig.individualWeeklyLimit
                )
            }
        }
    }

    private func miniUserCard(user: UserProfile, count: Int, today: Int, limit: Int) -> some View {
        let ratio = min(1, Double(count) / Double(max(1, limit)))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(user.avatarEmoji).font(.system(size: 15))
                Text(user.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(count)")
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundColor(PuffTheme.cream)
                Text("/ \(limit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(PuffTheme.faint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(PuffTheme.track)
                    Capsule().fill(PuffTheme.orange).frame(width: max(4, proxy.size.width * ratio))
                }
            }
            .frame(height: 4)
            Text("Today · \(today)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(PuffTheme.muted)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PuffTheme.card.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.045), lineWidth: 1))
    }

    // MARK: - Penalty Card

    private func penaltyCard(debt: (loserName: String, winnerName: String, amount: Double, penalizedSticks: Int)) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(PuffTheme.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("PENALTY IN EFFECT")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1)
                    .foregroundColor(PuffTheme.orange)
                Text("\(debt.loserName) owes \(debt.winnerName) \(state.pactConfig.currencySymbol)\(String(format: "%.2f", debt.amount))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text("\(debt.penalizedSticks) excess cigarettes")
                    .font(.system(size: 10))
                    .foregroundColor(PuffTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PuffTheme.card.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(PuffTheme.orange.opacity(0.28), lineWidth: 1))
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 10) {
            Button {
                state.isCravingTimerActive = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .heavy))
                    Text("Log a cigarette")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(Color(hex: "171719"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(PuffTheme.cream)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    state.isCravingTimerActive = true
                } label: {
                    Label("Craving pause", systemImage: "timer")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PuffTheme.card)
                        .foregroundColor(PuffTheme.creamSoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    state.undoLastLog(for: state.currentUser.id)
                } label: {
                    Label("Undo last", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PuffTheme.card)
                        .foregroundColor(PuffTheme.muted)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recent Logs

    private var recentLogs: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Recent logs")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button("View all") { selectedTab = .stats }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(PuffTheme.cream)
                    .buttonStyle(.plain)
            }

            if state.logs.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .foregroundColor(PuffTheme.faint)
                    Text("Your activity will appear here.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(PuffTheme.muted)
                    Spacer()
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PuffTheme.card.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: 15))
            } else {
                ForEach(state.logs.prefix(5)) { log in
                    let isMe = log.userId == state.currentUser.id
                    let name = isMe ? state.currentUser.name : state.friendUser.name
                    let emoji = isMe ? state.currentUser.avatarEmoji : state.friendUser.avatarEmoji

                    HStack(spacing: 11) {
                        Text(emoji).font(.system(size: 17))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(name) logged a cigarette")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(PuffTheme.faint)
                        }
                        Spacer()
                        if log.cravingTimerUsed {
                            Text("PAUSE USED")
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(0.5)
                                .foregroundColor(PuffTheme.cream)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(PuffTheme.orange.opacity(0.13))
                                .clipShape(Capsule())
                        } else {
                            Circle().fill(PuffTheme.orange.opacity(0.85)).frame(width: 5, height: 5)
                        }
                    }
                    .padding(12)
                    .background(PuffTheme.card.opacity(0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            Button {
                state.triggerSettlement()
            } label: {
                HStack {
                    Image(systemName: "scale.3d")
                    Text("Weekly pact settlement")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PuffTheme.muted)
                .padding(13)
                .background(Color.white.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func avatarBubble(_ emoji: String) -> some View {
        Text(emoji)
            .font(.system(size: 13))
            .frame(width: 27, height: 27)
            .background(Color(hex: "454548"))
            .clipShape(Circle())
            .overlay(Circle().stroke(PuffTheme.card, lineWidth: 2))
    }
}

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var selected: DashboardTab
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, icon: "house.fill")
            tabButton(.calendar, icon: "calendar")
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(Color(hex: "171719"))
                    .frame(width: 48, height: 48)
                    .background(PuffTheme.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .shadow(color: PuffTheme.orange.opacity(0.25), radius: 9, y: 4)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Start craving pause")
            tabButton(.journal, icon: "book.fill")
            tabButton(.profile, icon: "person.fill")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .padding(.horizontal, 22)
    }

    private func tabButton(_ tab: DashboardTab, icon: String) -> some View {
        Button { selected = tab } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(selected == tab ? PuffTheme.cream : Color.white.opacity(0.78))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue.capitalized)
    }
}
