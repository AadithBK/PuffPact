//
//  AppState.swift
//  PuffPact
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseAnalytics

public class AppState: ObservableObject {
    @Published public var currentUser: UserProfile
    @Published public var friendUser: UserProfile
    @Published public var pactConfig: PactConfig
    @Published public var logs: [SmokeLog] = []
    
    // UI Navigation & Active States
    @Published public var isCravingTimerActive: Bool = false
    @Published public var showingSettlementSheet: Bool = false
    @Published public var latestSettlement: SettlementBreakdown? = nil
    
    private let db = Firestore.firestore()
    private var usersListener: ListenerRegistration?
    private var logsListener: ListenerRegistration?
    
    private var activeUserId: String = ""
    private var activeGroupId: String = ""
    
    public init() {
        // Safe dummy initialization to avoid crashes before configuration
        self.currentUser = UserProfile(id: "dummy1", name: "You")
        self.friendUser = UserProfile(id: "dummy2", name: "Friend")
        self.pactConfig = PactConfig()
    }
    
    public func configure(userId: String, groupId: String) {
        guard self.activeUserId != userId || self.activeGroupId != groupId else { return }
        self.activeUserId = userId
        self.activeGroupId = groupId
        
        listenToUsers(groupId: groupId, userId: userId)
        listenToLogs(groupId: groupId)
    }
    
    private func listenToUsers(groupId: String, userId: String) {
        usersListener?.remove()
        usersListener = db.collection("users").whereField("groupId", isEqualTo: groupId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let docs = snapshot?.documents, error == nil else { return }
            
            var me: UserProfile? = nil
            var them: UserProfile? = nil
            
            for doc in docs {
                let data = doc.data()
                let id = data["id"] as? String ?? doc.documentID
                let name = data["name"] as? String ?? "Unknown"
                // Extract emoji or use default
                
                let isMe = (id == userId)
                let user = UserProfile(id: id, name: name, avatarEmoji: isMe ? "😎" : "🤝", isCurrentUser: isMe)
                
                if isMe {
                    me = user
                } else {
                    them = user
                }
            }
            
            if let me = me { self.currentUser = me }
            if let them = them {
                self.friendUser = them
            } else {
                // Keep dummy friend if they haven't joined yet
                self.friendUser = UserProfile(id: "dummy2", name: "Waiting for partner...", avatarEmoji: "⏳")
            }
        }
    }
    
    private func listenToLogs(groupId: String) {
        logsListener?.remove()
        logsListener = db.collection("pacts").document(groupId).collection("logs").order(by: "timestamp", descending: true).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let docs = snapshot?.documents, error == nil else { return }
            
            self.logs = docs.compactMap { doc -> SmokeLog? in
                let data = doc.data()
                guard let userId = data["userId"] as? String,
                      let stamp = data["timestamp"] as? Timestamp else { return nil }
                let craving = data["cravingTimerUsed"] as? Bool ?? false
                
                return SmokeLog(id: doc.documentID, userId: userId, timestamp: stamp.dateValue(), cravingTimerUsed: craving)
            }
        }
    }
    
    // MARK: - Query Metrics
    
    public func logsFor(userId: String) -> [SmokeLog] {
        logs.filter { $0.userId == userId }
    }
    
    public func todayCount(for userId: String) -> Int {
        let calendar = Calendar.current
        return logs.filter { $0.userId == userId && calendar.isDateInToday($0.timestamp) }.count
    }
    
    public func weekCount(for userId: String) -> Int {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return logs.filter { $0.userId == userId }.count
        }
        return logs.filter { $0.userId == userId && $0.timestamp >= startOfWeek }.count
    }
    
    public func excessCount(for userId: String) -> Int {
        max(0, weekCount(for: userId) - pactConfig.individualWeeklyLimit)
    }
    
    public func timeSinceLastSmoke(for userId: String) -> String {
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
        
        if !aExceeded && !bExceeded { return nil }
        
        if aExceeded && !bExceeded {
            let excess = aWeek - limit
            return (currentUser.name, friendUser.name, Double(excess) * cost, excess)
        }
        if !aExceeded && bExceeded {
            let excess = bWeek - limit
            return (friendUser.name, currentUser.name, Double(excess) * cost, excess)
        }
        
        if aWeek == bWeek { return nil }
        let diff = abs(aWeek - bWeek)
        let loser = aWeek > bWeek ? currentUser.name : friendUser.name
        let winner = aWeek > bWeek ? friendUser.name : currentUser.name
        return (loser, winner, Double(diff) * cost, diff)
    }
    
    // MARK: - Actions
    
    public func logSmoke(for userId: String, cravingUsed: Bool = false) {
        guard !activeGroupId.isEmpty else { return }
        
        let logId = UUID().uuidString
        db.collection("pacts").document(activeGroupId).collection("logs").document(logId).setData([
            "id": logId,
            "userId": userId,
            "timestamp": FieldValue.serverTimestamp(),
            "cravingTimerUsed": cravingUsed
        ])
        
        // Log event to Firebase Analytics
        Analytics.logEvent("smoke_logged", parameters: [
            "user_id": userId,
            "craving_timer_used": cravingUsed
        ])
    }
    
    public func undoLastLog(for userId: String) {
        guard !activeGroupId.isEmpty else { return }
        if let lastLog = logs.first(where: { $0.userId == userId }) {
            db.collection("pacts").document(activeGroupId).collection("logs").document(lastLog.id).delete()
        }
    }
    
    public func switchActiveUser() {
        // Deprecated mock method, no-op now
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
                scenario: .case4Tie, limit: limit, costPerStick: cost, currency: sym,
                userAName: currentUser.name, userBName: friendUser.name, userACount: aCount, userBCount: bCount,
                userAExcess: excessA, userBExcess: excessB, winnerName: nil, loserName: nil,
                penalizedSticks: 0, amountOwed: 0.0,
                summaryMessage: "Both smoked \(aCount) cigarettes. A perfect tie with \(sym)0.00 owed."
            )
        } else if aCount <= limit && bCount <= limit {
            let winner = aCount < bCount ? currentUser.name : friendUser.name
            let loser = aCount < bCount ? friendUser.name : currentUser.name
            latestSettlement = SettlementBreakdown(
                scenario: .case3NeitherExceeded, limit: limit, costPerStick: cost, currency: sym,
                userAName: currentUser.name, userBName: friendUser.name, userACount: aCount, userBCount: bCount,
                userAExcess: 0, userBExcess: 0, winnerName: winner, loserName: loser,
                penalizedSticks: 0, amountOwed: 0.0,
                summaryMessage: "Both stay under \(limit)! \(winner) takes the victory for discipline."
            )
        } else if aCount > limit && bCount <= limit {
            let owed = Double(excessA) * cost
            latestSettlement = SettlementBreakdown(
                scenario: .case1OneExceeded, limit: limit, costPerStick: cost, currency: sym,
                userAName: currentUser.name, userBName: friendUser.name, userACount: aCount, userBCount: bCount,
                userAExcess: excessA, userBExcess: 0, winnerName: friendUser.name, loserName: currentUser.name,
                penalizedSticks: excessA, amountOwed: owed,
                summaryMessage: "\(currentUser.name) exceeded limit by \(excessA) sticks and owes \(sym)\(String(format: "%.2f", owed))."
            )
        } else if aCount <= limit && bCount > limit {
            let owed = Double(excessB) * cost
            latestSettlement = SettlementBreakdown(
                scenario: .case1OneExceeded, limit: limit, costPerStick: cost, currency: sym,
                userAName: currentUser.name, userBName: friendUser.name, userACount: aCount, userBCount: bCount,
                userAExcess: 0, userBExcess: excessB, winnerName: currentUser.name, loserName: friendUser.name,
                penalizedSticks: excessB, amountOwed: owed,
                summaryMessage: "\(friendUser.name) exceeded limit by \(excessB) sticks and owes \(sym)\(String(format: "%.2f", owed))."
            )
        } else {
            let diff = abs(aCount - bCount)
            let winner = aCount < bCount ? currentUser.name : friendUser.name
            let loser = aCount < bCount ? friendUser.name : currentUser.name
            let owed = Double(diff) * cost
            latestSettlement = SettlementBreakdown(
                scenario: .case2BothExceeded, limit: limit, costPerStick: cost, currency: sym,
                userAName: currentUser.name, userBName: friendUser.name, userACount: aCount, userBCount: bCount,
                userAExcess: excessA, userBExcess: excessB, winnerName: winner, loserName: loser,
                penalizedSticks: diff, amountOwed: owed,
                summaryMessage: "Both exceeded limit. \(loser) owes \(sym)\(String(format: "%.2f", owed))."
            )
        }
        
        showingSettlementSheet = true
    }
}
