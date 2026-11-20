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
    @Published public var journalEntries: [JournalEntry] = []

    // UI Navigation & Active States
    @Published public var isCravingTimerActive: Bool = false
    @Published public var showingSettlementSheet: Bool = false
    @Published public var latestSettlement: SettlementBreakdown? = nil
    @Published public private(set) var isDismissingCravingTimer: Bool = false
    @Published public var settlements: [SettlementBreakdown] = []
    @Published public var pactCreatedAt: Date? = nil

    private var timerDismissalTask: Task<Void, Never>?
    private lazy var db = Firestore.firestore()
    private var pactListener: ListenerRegistration?
    private var usersListener: ListenerRegistration?
    private var logsListener: ListenerRegistration?
    private var journalListener: ListenerRegistration?
    private var hasReceivedFirstLogsSnapshot: Bool = false
    private var settlementsListener: ListenerRegistration?
    
    public var activeUserId: String = ""
    public var activeGroupId: String = ""
    
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

        listenToPact(groupId: groupId)
        listenToUsers(groupId: groupId, userId: userId)
        listenToLogs(groupId: groupId)
        listenToJournal(groupId: groupId)
        listenToSettlements(groupId: groupId)
    }

    private func listenToPact(groupId: String) {
        pactListener?.remove()
        pactListener = db.collection("pacts").document(groupId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data(), error == nil else { return }
            if let stamp = data["createdAt"] as? Timestamp {
                self.pactCreatedAt = stamp.dateValue()
            }
            if let configData = data["config"] as? [String: Any] {
                let limit = configData["individualWeeklyLimit"] as? Int ?? self.pactConfig.individualWeeklyLimit
                let cost = configData["costPerStick"] as? Double ?? self.pactConfig.costPerStick
                let reset = configData["resetDayOfWeek"] as? Int ?? self.pactConfig.resetDayOfWeek
                self.pactConfig = PactConfig(individualWeeklyLimit: limit, costPerStick: cost, currencySymbol: self.pactConfig.currencySymbol, resetDayOfWeek: reset)
            }
            self.checkAndAutoTriggerSettlement()
        }
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
        hasReceivedFirstLogsSnapshot = false
        logsListener = db.collection("pacts").document(groupId).collection("logs").order(by: "timestamp", descending: true).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let docs = snapshot?.documents, error == nil else { return }

            let isFirstSnapshot = !self.hasReceivedFirstLogsSnapshot
            self.hasReceivedFirstLogsSnapshot = true

            let mappedLogs = docs.compactMap { doc -> SmokeLog? in
                let data = doc.data()
                guard let userId = data["userId"] as? String else { return nil }
                let stamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                let craving = data["cravingTimerUsed"] as? Bool ?? false

                return SmokeLog(id: doc.documentID, userId: userId, timestamp: stamp, cravingTimerUsed: craving)
            }
            
            let applyLogs = {
                let prevCurrentUserLogCount = self.logsFor(userId: self.currentUser.id).count
                self.logs = mappedLogs
                let newCurrentUserLogCount = self.logsFor(userId: self.currentUser.id).count

                if !isFirstSnapshot, newCurrentUserLogCount > prevCurrentUserLogCount, self.isCravingTimerActive {
                    self.closeCravingTimer(smoothly: true)
                }
            }

            if Thread.isMainThread {
                applyLogs()
            } else {
                DispatchQueue.main.async {
                    applyLogs()
                }
            }
            self.checkAndAutoTriggerSettlement()
        }
    }

    private func listenToJournal(groupId: String) {
        journalListener?.remove()
        journalListener = db.collection("pacts").document(groupId).collection("journal")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents, error == nil else { return }
                self.journalEntries = docs.compactMap { doc -> JournalEntry? in
                    let data = doc.data()
                    guard let userId = data["userId"] as? String,
                          let text = data["text"] as? String,
                          let stamp = data["timestamp"] as? Timestamp else { return nil }
                    return JournalEntry(id: doc.documentID, userId: userId, text: text, timestamp: stamp.dateValue())
                }
            }
    }

    private func listenToSettlements(groupId: String) {
        settlementsListener?.remove()
        settlementsListener = db.collection("pacts").document(groupId).collection("settlements")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents, error == nil else { return }
                self.settlements = docs.compactMap { doc -> SettlementBreakdown? in
                    let data = doc.data()
                    guard let rawScenario = data["scenario"] as? String,
                          let scenario = SettlementScenario(rawValue: rawScenario),
                          let limit = data["limit"] as? Int,
                          let cost = data["costPerStick"] as? Double,
                          let currency = data["currency"] as? String,
                          let userAName = data["userAName"] as? String,
                          let userBName = data["userBName"] as? String,
                          let userACount = data["userACount"] as? Int,
                          let userBCount = data["userBCount"] as? Int,
                          let userAExcess = data["userAExcess"] as? Int,
                          let userBExcess = data["userBExcess"] as? Int,
                          let penalizedSticks = data["penalizedSticks"] as? Int,
                          let amountOwed = data["amountOwed"] as? Double,
                          let summaryMessage = data["summaryMessage"] as? String else {
                        return nil
                    }
                    let winner = data["winnerName"] as? String
                    let loser = data["loserName"] as? String
                    let isSettled = data["isSettled"] as? Bool ?? false
                    let stamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let cycleStart = (data["cycleStartDate"] as? Timestamp)?.dateValue()
                    let cycleEnd = (data["cycleEndDate"] as? Timestamp)?.dateValue()

                    return SettlementBreakdown(
                        id: doc.documentID,
                        scenario: scenario,
                        limit: limit,
                        costPerStick: cost,
                        currency: currency,
                        userAName: userAName,
                        userBName: userBName,
                        userACount: userACount,
                        userBCount: userBCount,
                        userAExcess: userAExcess,
                        userBExcess: userBExcess,
                        winnerName: winner,
                        loserName: loser,
                        penalizedSticks: penalizedSticks,
                        amountOwed: amountOwed,
                        summaryMessage: summaryMessage,
                        isSettled: isSettled,
                        timestamp: stamp,
                        cycleStartDate: cycleStart,
                        cycleEndDate: cycleEnd
                    )
                }
                self.checkAndAutoTriggerSettlement()
            }
    }

    public func saveJournalEntry(text: String) {
        guard !activeGroupId.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let entryId = UUID().uuidString
        db.collection("pacts").document(activeGroupId).collection("journal").document(entryId).setData([
            "id": entryId,
            "userId": activeUserId,
            "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
            "timestamp": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Query Metrics
    
    public func logsFor(userId: String) -> [SmokeLog] {
        logs.filter { $0.userId == userId }
    }
    
    public func todayCount(for userId: String) -> Int {
        let calendar = Calendar.current
        return logs.filter { $0.userId == userId && calendar.isDateInToday($0.timestamp) }.count
    }
    
    // MARK: - Weekly Cycle & Date Math

    public func currentCycleStartDate(from referenceDate: Date = Date(), resetDayOfWeek: Int? = nil) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let currentWeekday = calendar.component(.weekday, from: startOfToday) // 1 = Sunday, 2 = Monday, ...
        let targetWeekday = resetDayOfWeek ?? pactConfig.resetDayOfWeek
        let daysToSubtract = (currentWeekday - targetWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfToday) ?? startOfToday
    }

    public func previousCycleDateInterval(from referenceDate: Date = Date(), resetDayOfWeek: Int? = nil) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let currentStart = currentCycleStartDate(from: referenceDate, resetDayOfWeek: resetDayOfWeek)
        let prevStart = calendar.date(byAdding: .day, value: -7, to: currentStart) ?? currentStart.addingTimeInterval(-7 * 86400)
        return (prevStart, currentStart)
    }

    public func weekCount(for userId: String, on date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let cycleStart = currentCycleStartDate(from: date)
        let cycleEnd = calendar.date(byAdding: .day, value: 7, to: cycleStart) ?? cycleStart.addingTimeInterval(7 * 86400)
        return logs.filter { $0.userId == userId && $0.timestamp >= cycleStart && $0.timestamp < cycleEnd }.count
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
        let breakdown = PuffPactEngine.evaluateSettlement(
            userAName: currentUser.name,
            userACount: aWeek,
            userBName: friendUser.name,
            userBCount: bWeek,
            limit: pactConfig.individualWeeklyLimit,
            costPerStick: pactConfig.costPerStick,
            currencySymbol: pactConfig.currencySymbol
        )
        guard breakdown.amountOwed > 0,
              let loser = breakdown.loserName,
              let winner = breakdown.winnerName else {
            return nil
        }
        return (loser, winner, breakdown.amountOwed, breakdown.penalizedSticks)
    }
    
    // MARK: - Actions

    @MainActor
    public func closeCravingTimer(smoothly: Bool = true, delayMs: Int = 450) {
        guard isCravingTimerActive, !isDismissingCravingTimer else { return }

        timerDismissalTask?.cancel()

        if smoothly {
            isDismissingCravingTimer = true
            timerDismissalTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(delayMs))
                guard !Task.isCancelled, self.isCravingTimerActive else {
                    self.isDismissingCravingTimer = false
                    return
                }
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.isCravingTimerActive = false
                }
                self.isDismissingCravingTimer = false
                self.timerDismissalTask = nil
            }
        } else {
            timerDismissalTask = nil
            isDismissingCravingTimer = false
            withAnimation(.easeInOut(duration: 0.25)) {
                self.isCravingTimerActive = false
            }
        }
    }
    
    public func logSmoke(for userId: String, cravingUsed: Bool = false) {
        let logId = UUID().uuidString
        let optimisticLog = SmokeLog(id: logId, userId: userId, timestamp: Date(), cravingTimerUsed: cravingUsed)
        
        // Optimistically insert log so UI immediately reflects the new cigarette
        if !logs.contains(where: { $0.id == logId }) {
            logs.insert(optimisticLog, at: 0)
        }

        // When the current user logs a cigarette and it reflects in the UI/state, close the craving timer smoothly
        if (userId == currentUser.id || userId == activeUserId) && isCravingTimerActive {
            Task { @MainActor in
                self.closeCravingTimer(smoothly: true)
            }
        }

        guard !activeGroupId.isEmpty else { return }
        
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
        if userId == currentUser.id || userId == activeUserId {
            timerDismissalTask?.cancel()
            timerDismissalTask = nil
            isDismissingCravingTimer = false
        }
        if let index = logs.firstIndex(where: { $0.userId == userId }) {
            let logToRemove = logs[index]
            logs.remove(at: index)
            if !activeGroupId.isEmpty {
                db.collection("pacts").document(activeGroupId).collection("logs").document(logToRemove.id).delete()
            }
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
        
        latestSettlement = PuffPactEngine.evaluateSettlement(
            userAName: currentUser.name,
            userACount: aCount,
            userBName: friendUser.name,
            userBCount: bCount,
            limit: limit,
            costPerStick: cost,
            currencySymbol: sym
        )
        
        showingSettlementSheet = true
    }

    public func archiveSettlement(_ settlement: SettlementBreakdown? = nil, isSettled: Bool = true) {
        guard !activeGroupId.isEmpty else { return }
        guard var target = settlement ?? latestSettlement else { return }

        target.isSettled = isSettled
        latestSettlement = target

        let docRef = db.collection("pacts").document(activeGroupId).collection("settlements").document(target.id)

        var data: [String: Any] = [
            "id": target.id,
            "scenario": target.scenario.rawValue,
            "limit": target.limit,
            "costPerStick": target.costPerStick,
            "currency": target.currency,
            "userAName": target.userAName,
            "userBName": target.userBName,
            "userACount": target.userACount,
            "userBCount": target.userBCount,
            "userAExcess": target.userAExcess,
            "userBExcess": target.userBExcess,
            "penalizedSticks": target.penalizedSticks,
            "amountOwed": target.amountOwed,
            "summaryMessage": target.summaryMessage,
            "isSettled": isSettled,
            "timestamp": Timestamp(date: target.timestamp)
        ]
        if let winner = target.winnerName { data["winnerName"] = winner }
        if let loser = target.loserName { data["loserName"] = loser }
        if let start = target.cycleStartDate { data["cycleStartDate"] = Timestamp(date: start) }
        if let end = target.cycleEndDate { data["cycleEndDate"] = Timestamp(date: end) }

        docRef.setData(data)
    }

    public func checkAndAutoTriggerSettlement(now: Date = Date()) {
        guard !activeGroupId.isEmpty else { return }
        let (prevStart, prevEnd) = previousCycleDateInterval(from: now)

        // Only trigger if the pact was active during the previous cycle:
        // Either the pact was created before prevEnd, OR there are logs prior to prevEnd
        let pactWasActive = (pactCreatedAt != nil && pactCreatedAt! < prevEnd) ||
                            logs.contains(where: { $0.timestamp < prevEnd })
        guard pactWasActive else { return }

        // A previous cycle is considered settled if:
        // 1. A settlement exists explicitly recorded for this cycleEndDate, OR
        // 2. A settlement was recorded on or after prevEnd
        let alreadySettled = settlements.contains { settlement in
            if let cycleEnd = settlement.cycleEndDate {
                return cycleEnd == prevEnd
            }
            return settlement.timestamp >= prevEnd
        }

        if !alreadySettled && !showingSettlementSheet {
            let prevLogs = logs.filter { $0.timestamp >= prevStart && $0.timestamp < prevEnd }
            let aCount = prevLogs.filter { $0.userId == currentUser.id }.count
            let bCount = prevLogs.filter { $0.userId == friendUser.id }.count
            var settlement = PuffPactEngine.evaluateSettlement(
                userAName: currentUser.name,
                userACount: aCount,
                userBName: friendUser.name,
                userBCount: bCount,
                limit: pactConfig.individualWeeklyLimit,
                costPerStick: pactConfig.costPerStick,
                currencySymbol: pactConfig.currencySymbol
            )
            settlement.cycleStartDate = prevStart
            settlement.cycleEndDate = prevEnd
            latestSettlement = settlement
            showingSettlementSheet = true
        }
    }
}
