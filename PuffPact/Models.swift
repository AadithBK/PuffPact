//
//  Models.swift
//  PuffPact
//

import SwiftUI

#if canImport(UIKit)
import UIKit
public extension Color {
    static let cardBackground = Color(UIColor.systemBackground)
    static let surfaceBackground = Color(UIColor.secondarySystemBackground)
    static let pageBackground = Color(UIColor.systemGroupedBackground)
}
#elseif canImport(AppKit)
import AppKit
public extension Color {
    static let cardBackground = Color(NSColor.windowBackgroundColor)
    static let surfaceBackground = Color(NSColor.controlBackgroundColor)
    static let pageBackground = Color(NSColor.underPageBackgroundColor)
}
#endif

public struct UserProfile: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var avatarEmoji: String
    public var isCurrentUser: Bool
    
    public init(id: String = UUID().uuidString, name: String, avatarEmoji: String = "👤", isCurrentUser: Bool = false) {
        self.id = id
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.isCurrentUser = isCurrentUser
    }
}

public struct SmokeLog: Identifiable, Codable, Equatable {
    public var id: String
    public var userId: String
    public var timestamp: Date
    public var cravingTimerUsed: Bool
    
    public init(id: String = UUID().uuidString, userId: String, timestamp: Date = Date(), cravingTimerUsed: Bool = false) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.cravingTimerUsed = cravingTimerUsed
    }
}

public struct PactConfig: Codable, Equatable {
    public var individualWeeklyLimit: Int
    public var costPerStick: Double
    public var currencySymbol: String
    public var resetDayOfWeek: Int // 1 = Sunday, 2 = Monday
    
    public init(
        individualWeeklyLimit: Int = 20,
        costPerStick: Double = 18.0,
        currencySymbol: String = "₹",
        resetDayOfWeek: Int = 2
    ) {
        self.individualWeeklyLimit = individualWeeklyLimit
        self.costPerStick = costPerStick
        self.currencySymbol = currencySymbol
        self.resetDayOfWeek = resetDayOfWeek
    }
}

public enum SettlementScenario: String, Codable {
    case case1OneExceeded = "One Person Exceeded"
    case case2BothExceeded = "Both Exceeded Limit"
    case case3NeitherExceeded = "Both Under Limit"
    case case4Tie = "Perfect Tie"
}

public struct SettlementBreakdown: Identifiable, Codable {
    public var id: String = UUID().uuidString
    public var scenario: SettlementScenario
    public var limit: Int
    public var costPerStick: Double
    public var currency: String
    public var userAName: String
    public var userBName: String
    public var userACount: Int
    public var userBCount: Int
    public var userAExcess: Int
    public var userBExcess: Int
    public var winnerName: String?
    public var loserName: String?
    public var penalizedSticks: Int
    public var amountOwed: Double
    public var summaryMessage: String
    public var isSettled: Bool = false
}
