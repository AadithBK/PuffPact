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

// MARK: - Smoking Profile Types

public enum DailySmokingLevel: String, Codable, CaseIterable, Identifiable {
    case light = "light"
    case moderate = "moderate"
    case heavy = "heavy"
    case veryHeavy = "very_heavy"

    public var id: String { rawValue }

    public var estimatedDaily: Int {
        switch self {
        case .light: return 3
        case .moderate: return 7
        case .heavy: return 15
        case .veryHeavy: return 25
        }
    }

    public var displayLabel: String {
        switch self {
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .veryHeavy: return "Very Heavy"
        }
    }

    public var range: String {
        switch self {
        case .light: return "Less than 5"
        case .moderate: return "5 – 10"
        case .heavy: return "10 – 20"
        case .veryHeavy: return "More than 20"
        }
    }

    public var emoji: String {
        switch self {
        case .light: return "☁️"
        case .moderate: return "🔥"
        case .heavy: return "💨"
        case .veryHeavy: return "🌋"
        }
    }
}

public enum SmokingGoal: String, Codable, CaseIterable, Identifiable {
    case cutBack = "cut_back"
    case quitCompletely = "quit_completely"
    case justTrack = "just_track"

    public var id: String { rawValue }

    public var displayLabel: String {
        switch self {
        case .cutBack: return "Cut back gradually"
        case .quitCompletely: return "Quit completely"
        case .justTrack: return "Just track & stay aware"
        }
    }

    public var emoji: String {
        switch self {
        case .cutBack: return "🔽"
        case .quitCompletely: return "🚫"
        case .justTrack: return "📊"
        }
    }

    public var subtitle: String {
        switch self {
        case .cutBack: return "Reduce at your own pace"
        case .quitCompletely: return "Work towards stopping for good"
        case .justTrack: return "No pressure, just awareness"
        }
    }

    public var reductionMultiplier: Double {
        switch self {
        case .cutBack: return 0.75
        case .quitCompletely: return 0.50
        case .justTrack: return 0.90
        }
    }
}

public enum CravingTrigger: String, Codable, CaseIterable, Identifiable {
    case afterMeals = "after_meals"
    case stress = "stress"
    case social = "social"
    case evening = "evening"
    case commute = "commute"

    public var id: String { rawValue }

    public var displayLabel: String {
        switch self {
        case .afterMeals: return "After meals"
        case .stress: return "Under stress / work"
        case .social: return "Social situations"
        case .evening: return "Evening / night"
        case .commute: return "Commute / downtime"
        }
    }

    public var emoji: String {
        switch self {
        case .afterMeals: return "☕"
        case .stress: return "😓"
        case .social: return "🍻"
        case .evening: return "🌙"
        case .commute: return "🚗"
        }
    }
}

public enum PactIntent: String, Codable {
    case createNew = "create_new"
    case joinExisting = "join_existing"
}

public struct SmokingProfile: Codable, Equatable {
    public var dailyLevel: DailySmokingLevel
    public var costPerStick: Double
    public var goal: SmokingGoal
    public var cravingTriggers: [CravingTrigger]
    public var pactIntent: PactIntent

    public var suggestedWeeklyLimit: Int {
        let baseline = dailyLevel.estimatedDaily * 7
        return max(1, Int(Double(baseline) * goal.reductionMultiplier))
    }
}

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

public struct JournalEntry: Identifiable, Codable, Equatable {
    public var id: String
    public var userId: String
    public var text: String
    public var timestamp: Date

    public init(id: String = UUID().uuidString, userId: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.userId = userId
        self.text = text
        self.timestamp = timestamp
    }
}
