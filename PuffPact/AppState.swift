//
//  AppState.swift
//  PuffPact
//

import SwiftUI
import Combine

public class AppState: ObservableObject {
    @Published public var currentUser: UserProfile
    @Published public var friendUser: UserProfile
    @Published public var pactConfig: PactConfig
    @Published public var logs: [SmokeLog] = []
    
    // UI Navigation & Active States
    @Published public var isCravingTimerActive: Bool = false
    @Published public var showingSettlementSheet: Bool = false
    @Published public var latestSettlement: SettlementBreakdown? = nil
    
    public init() {
        let userA = UserProfile(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "You", avatarEmoji: "😎", isCurrentUser: true)
        let userB = UserProfile(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Sam", avatarEmoji: "🤝", isCurrentUser: false)
        
        self.currentUser = userA
        self.friendUser = userB
        self.pactConfig = PactConfig(individualWeeklyLimit: 20, costPerStick: 18.0, currencySymbol: "₹", resetDayOfWeek: 2)
        
        // Seed initial demo data
        seedDemoLogs(userAId: userA.id, userBId: userB.id)
    }
    
    private func seedDemoLogs(userAId: UUID, userBId: UUID) {
        let now = Date()
        var mockLogs: [SmokeLog] = []
        
        // Seed 14 logs for current user (within limit 20)
        for i in 1...14 {
            let logDate = Calendar.current.date(byAdding: .hour, value: -i * 8, to: now) ?? now
            mockLogs.append(SmokeLog(userId: userAId, timestamp: logDate))
        }
        
        // Seed 18 logs for friend (close to limit)
        for i in 1...18 {
            let logDate = Calendar.current.date(byAdding: .hour, value: -i * 6, to: now) ?? now
            mockLogs.append(SmokeLog(userId: userBId, timestamp: logDate))
        }
        
        self.logs = mockLogs
    }
    
    // MARK: - Query Metrics
    
    public func logsFor(userId: UUID) -> [SmokeLog] {
        logs.filter { $0.userId == userId }
    }
    
    public func todayCount(for userId: UUID) -> Int {
        let calendar = Calendar.current
        return logs.filter { $0.userId == userId && calendar.isDateInToday($0.timestamp) }.count
    }
    
    public func weekCount(for userId: UUID) -> Int {
        // Simple current calendar week check
        let calendar = Calendar.current
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return logs.filter { $0.userId == userId }.count
        }
        return logs.filter { $0.userId == userId && $0.timestamp >= startOfWeek }.count
    }
    
    public func excessCount(for userId: UUID) -> Int {
        max(0, weekCount(for: userId) - pactConfig.individualWeeklyLimit)
    }
    
    public func timeSinceLastSmoke(for userId: UUID) -> String {
        guard let lastLog = logs.filter({ $0.userId == userId }).max(by: { $0.timestamp < $1.timestamp }) else {
            return "No logs yet"
        }
        let diff = Date().timeIntervalSince(lastLog.timestamp)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m ago"
        } else {
            return "\(max(1, minutes))m ago"
        }
    }
    
    // MARK: - Live Accrued Debt Calculation
    
    public var currentProjectedOwedSummary: (loserName: String, winnerName: String, amount: Double, penalizedSticks: Int)? {
        let aWeek = weekCount(for: currentUser.id)
        let bWeek = weekCount(for: friendUser.id)
        let limit = pactConfig.individualWeeklyLimit
        let cost = pactConfig.costPerStick
        
        let aExceeded = aWeek > limit
        let bExceeded = bWeek > limit
        
        if !aExceeded && !bExceeded {
            return nil
        }
        
        if aExceeded && !bExceeded {
            let excess = aWeek - limit
            return (currentUser.name, friendUser.name, Double(excess) * cost, excess)
        }
        
        if !aExceeded && bExceeded {
            let excess = bWeek - limit
            return (friendUser.name, currentUser.name, Double(excess) * cost, excess)
        }
        
        // Both exceeded
        if aWeek == bWeek {
            return nil
        }
        let diff = abs(aWeek - bWeek)
        let loser = aWeek > bWeek ? currentUser.name : friendUser.name
        let winner = aWeek > bWeek ? friendUser.name : currentUser.name
        return (loser, winner, Double(diff) * cost, diff)
    }
    
    // MARK: - Actions
    
    public func logSmoke(for userId: UUID, cravingUsed: Bool = false) {
        let newLog = SmokeLog(userId: userId, timestamp: Date(), cravingTimerUsed: cravingUsed)
        logs.insert(newLog, at: 0)
    }
    
    public func undoLastLog(for userId: UUID) {
        if let index = logs.firstIndex(where: { $0.userId == userId }) {
            logs.remove(at: index)
        }
    }
    
    public func switchActiveUser() {
        currentUser.isCurrentUser.toggle()
        friendUser.isCurrentUser.toggle()
        let temp = currentUser
        currentUser = friendUser
        friendUser = temp
    }
    
    public func triggerSettlement() {
        let aCount = weekCount(for: currentUser.id)
        let bCount = weekCount(for: friendUser.id)
        let limit = pactConfig.individualWeeklyLimit
        let cost = pactConfig.costPerStick
        let sym = pactConfig.currencySymbol
        
        let excessA = max(0, aCount - limit)
        let excessB = max(0, bCount - limit)
        
        if aCount == bCount {
            latestSettlement = SettlementBreakdown(
                scenario: .case4Tie,
                limit: limit,
                costPerStick: cost,
                currency: sym,
                userAName: currentUser.name,
                userBName: friendUser.name,
                userACount: aCount,
                userBCount: bCount,
                userAExcess: excessA,
                userBExcess: excessB,
                winnerName: nil,
                loserName: nil,
                penalizedSticks: 0,
                amountOwed: 0.0,
                summaryMessage: "Both smoked \(aCount) cigarettes. A perfect tie with \(sym)0.00 owed."
            )
        } else if aCount <= limit && bCount <= limit {
            let winner = aCount < bCount ? currentUser.name : friendUser.name
            let loser = aCount < bCount ? friendUser.name : currentUser.name
            latestSettlement = SettlementBreakdown(
                scenario: .case3NeitherExceeded,
                limit: limit,
                costPerStick: cost,
                currency: sym,
                userAName: currentUser.name,
                userBName: friendUser.name,
                userACount: aCount,
                userBCount: bCount,
                userAExcess: 0,
                userBExcess: 0,
                winnerName: winner,
                loserName: loser,
                penalizedSticks: 0,
                amountOwed: 0.0,
                summaryMessage: "Both users stayed under the limit of \(limit)! \(winner) takes the victory for discipline."
            )
        } else if aCount > limit && bCount <= limit {
            let owed = Double(excessA) * cost
            latestSettlement = SettlementBreakdown(
                scenario: .case1OneExceeded,
                limit: limit,
                costPerStick: cost,
                currency: sym,
                userAName: currentUser.name,
                userBName: friendUser.name,
                userACount: aCount,
                userBCount: bCount,
                userAExcess: excessA,
                userBExcess: 0,
                winnerName: friendUser.name,
                loserName: currentUser.name,
                penalizedSticks: excessA,
                amountOwed: owed,
                summaryMessage: "\(currentUser.name) exceeded the limit by \(excessA) sticks and owes \(friendUser.name) \(sym)\(String(format: "%.2f", owed))."
            )
        } else if aCount <= limit && bCount > limit {
            let owed = Double(excessB) * cost
            latestSettlement = SettlementBreakdown(
                scenario: .case1OneExceeded,
                limit: limit,
                costPerStick: cost,
                currency: sym,
                userAName: currentUser.name,
                userBName: friendUser.name,
                userACount: aCount,
                userBCount: bCount,
                userAExcess: 0,
                userBExcess: excessB,
                winnerName: currentUser.name,
                loserName: friendUser.name,
                penalizedSticks: excessB,
                amountOwed: owed,
                summaryMessage: "\(friendUser.name) exceeded the limit by \(excessB) sticks and owes \(currentUser.name) \(sym)\(String(format: "%.2f", owed))."
            )
        } else {
            // Both exceeded
            let diff = abs(aCount - bCount)
            let winner = aCount < bCount ? currentUser.name : friendUser.name
            let loser = aCount < bCount ? friendUser.name : currentUser.name
            let owed = Double(diff) * cost
            latestSettlement = SettlementBreakdown(
                scenario: .case2BothExceeded,
                limit: limit,
                costPerStick: cost,
                currency: sym,
                userAName: currentUser.name,
                userBName: friendUser.name,
                userACount: aCount,
                userBCount: bCount,
                userAExcess: excessA,
                userBExcess: excessB,
                winnerName: winner,
                loserName: loser,
                penalizedSticks: diff,
                amountOwed: owed,
                summaryMessage: "Both exceeded the limit. \(loser) smoked \(diff) more than \(winner), owing \(sym)\(String(format: "%.2f", owed))."
            )
        }
        
        showingSettlementSheet = true
    }
}
