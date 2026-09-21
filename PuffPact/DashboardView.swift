//
//  DashboardView.swift
//  PuffPact
//

import SwiftUI

public struct DashboardView: View {
    @EnvironmentObject var state: AppState
    
    public var body: some View {
        #if os(macOS)
        mainContent
            .frame(minWidth: 400, minHeight: 650)
        #else
        NavigationView {
            mainContent
                .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Top Bar: Active Profile Switcher & Reset Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PuffPact")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Weekly limit: \(state.pactConfig.individualWeeklyLimit) each (Cost: \(state.pactConfig.currencySymbol)\(String(format: "%.1f", state.pactConfig.costPerStick))/stick)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        state.switchActiveUser()
                    }) {
                        HStack(spacing: 6) {
                            Text(state.currentUser.avatarEmoji)
                            Text(state.currentUser.name)
                                .font(.subheadline.bold())
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.surfaceBackground)
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                // Live Penalty Banner (if someone exceeded)
                if let debt = state.currentProjectedOwedSummary {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PENALTY IN EFFECT")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                            Text("\(debt.loserName) owes \(debt.winnerName) \(state.pactConfig.currencySymbol)\(String(format: "%.2f", debt.amount))")
                                .font(.subheadline.bold())
                            Text("(\(debt.penalizedSticks) excess sticks × \(state.pactConfig.currencySymbol)\(String(format: "%.1f", state.pactConfig.costPerStick)))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.3), lineWidth: 1.5))
                    .cornerRadius(14)
                    .padding(.horizontal)
                }
                
                // Dual Accountability Cards
                HStack(spacing: 14) {
                    UserWeeklyCard(
                        user: state.currentUser,
                        weekCount: state.weekCount(for: state.currentUser.id),
                        todayCount: state.todayCount(for: state.currentUser.id),
                        limit: state.pactConfig.individualWeeklyLimit,
                        lastSmoked: state.timeSinceLastSmoke(for: state.currentUser.id),
                        isCurrent: true
                    )
                    
                    UserWeeklyCard(
                        user: state.friendUser,
                        weekCount: state.weekCount(for: state.friendUser.id),
                        todayCount: state.todayCount(for: state.friendUser.id),
                        limit: state.pactConfig.individualWeeklyLimit,
                        lastSmoked: state.timeSinceLastSmoke(for: state.friendUser.id),
                        isCurrent: false
                    )
                }
                .padding(.horizontal)
                
                // Primary Action: Log Smoke & Craving Delay
                VStack(spacing: 12) {
                    Button(action: {
                        state.logSmoke(for: state.currentUser.id)
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "flame.fill")
                                .font(.title2)
                            Text("Log 1 Cigarette")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            state.isCravingTimerActive = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                Text("Craving? Wait 3 Min")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            state.undoLastLog(for: state.currentUser.id)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Undo Log")
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.surfaceBackground)
                            .foregroundColor(.secondary)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                // Quick Settlement Simulator & History Trigger
                Button(action: {
                    state.triggerSettlement()
                }) {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.orange)
                        Text("Simulate Sunday Settlement")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.surfaceBackground)
                    .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Recent Activity Feed
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Logs")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(state.logs.prefix(6)) { log in
                        let isMe = log.userId == state.currentUser.id
                        let name = isMe ? state.currentUser.name : state.friendUser.name
                        let emoji = isMe ? state.currentUser.avatarEmoji : state.friendUser.avatarEmoji
                        
                        HStack(spacing: 12) {
                            Text(emoji)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(name) smoked")
                                    .font(.subheadline.bold())
                                Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if log.cravingTimerUsed {
                                Text("Timer Resisted")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.pageBackground)
        .sheet(isPresented: $state.isCravingTimerActive) {
            CravingTimerView()
        }
        .sheet(isPresented: $state.showingSettlementSheet) {
            SettlementView()
        }
    }
}

// MARK: - Subviews

struct UserWeeklyCard: View {
    let user: UserProfile
    let weekCount: Int
    let todayCount: Int
    let limit: Int
    let lastSmoked: String
    let isCurrent: Bool
    
    var progress: Double {
        min(1.0, Double(weekCount) / Double(limit))
    }
    
    var statusColor: Color {
        if weekCount > limit {
            return .red
        } else if weekCount >= Int(Double(limit) * 0.8) {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(user.avatarEmoji)
                Text(user.name)
                    .font(.subheadline.bold())
                Spacer()
                if weekCount > limit {
                    Text("+\(weekCount - limit)")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(6)
                }
            }
            
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                
                VStack(spacing: 0) {
                    Text("\(weekCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(weekCount > limit ? .red : .primary)
                    Text("/\(limit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            
            VStack(spacing: 2) {
                Text("Today: \(todayCount)")
                    .font(.caption.bold())
                Text("Last: \(lastSmoked)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(18)
    }
}
