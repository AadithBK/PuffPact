import Foundation

// PuffPactEngine now depends on shared models from Models.swift
// It computes a SettlementBreakdown using the existing SettlementScenario enum.
public struct PuffPactEngine {
    public static func evaluateSettlement(
        userAName: String,
        userACount: Int,
        userBName: String,
        userBCount: Int,
        limit: Int,
        costPerStick: Double,
        currencySymbol: String = "₹"
    ) -> SettlementBreakdown {
        let excessA = max(0, userACount - limit)
        let excessB = max(0, userBCount - limit)

        // Perfect tie
        if userACount == userBCount {
            return SettlementBreakdown(
                scenario: .case4Tie,
                limit: limit,
                costPerStick: costPerStick,
                currency: currencySymbol,
                userAName: userAName,
                userBName: userBName,
                userACount: userACount,
                userBCount: userBCount,
                userAExcess: excessA,
                userBExcess: excessB,
                winnerName: nil,
                loserName: nil,
                penalizedSticks: 0,
                amountOwed: 0.0,
                summaryMessage: "Both smoked \(userACount) cigarettes. A perfect tie with \(currencySymbol)0.00 owed."
            )
        }

        // Neither exceeded the limit
        if userACount <= limit && userBCount <= limit {
            let winner = userACount < userBCount ? userAName : userBName
            let loser = userACount < userBCount ? userBName : userAName
            return SettlementBreakdown(
                scenario: .case3NeitherExceeded,
                limit: limit,
                costPerStick: costPerStick,
                currency: currencySymbol,
                userAName: userAName,
                userBName: userBName,
                userACount: userACount,
                userBCount: userBCount,
                userAExcess: 0,
                userBExcess: 0,
                winnerName: winner,
                loserName: loser,
                penalizedSticks: 0,
                amountOwed: 0.0,
                summaryMessage: "Both stayed under the limit of \(limit)! \(winner) takes the victory for discipline."
            )
        }

        // Only A exceeded
        if userACount > limit && userBCount <= limit {
            let owed = Double(excessA) * costPerStick
            return SettlementBreakdown(
                scenario: .case1OneExceeded,
                limit: limit,
                costPerStick: costPerStick,
                currency: currencySymbol,
                userAName: userAName,
                userBName: userBName,
                userACount: userACount,
                userBCount: userBCount,
                userAExcess: excessA,
                userBExcess: 0,
                winnerName: userBName,
                loserName: userAName,
                penalizedSticks: excessA,
                amountOwed: owed,
                summaryMessage: "\(userAName) exceeded the limit by \(excessA) sticks and owes \(userBName) \(currencySymbol)\(String(format: "%.2f", owed))."
            )
        }

        // Only B exceeded
        if userACount <= limit && userBCount > limit {
            let owed = Double(excessB) * costPerStick
            return SettlementBreakdown(
                scenario: .case1OneExceeded,
                limit: limit,
                costPerStick: costPerStick,
                currency: currencySymbol,
                userAName: userAName,
                userBName: userBName,
                userACount: userACount,
                userBCount: userBCount,
                userAExcess: 0,
                userBExcess: excessB,
                winnerName: userAName,
                loserName: userBName,
                penalizedSticks: excessB,
                amountOwed: owed,
                summaryMessage: "\(userBName) exceeded the limit by \(excessB) sticks and owes \(userAName) \(currencySymbol)\(String(format: "%.2f", owed))."
            )
        }

        // Both exceeded
        let diff = abs(userACount - userBCount)
        let winner = userACount < userBCount ? userAName : userBName
        let loser = userACount < userBCount ? userBName : userAName
        let owed = Double(diff) * costPerStick

        return SettlementBreakdown(
            scenario: .case2BothExceeded,
            limit: limit,
            costPerStick: costPerStick,
            currency: currencySymbol,
            userAName: userAName,
            userBName: userBName,
            userACount: userACount,
            userBCount: userBCount,
            userAExcess: excessA,
            userBExcess: excessB,
            winnerName: winner,
            loserName: loser,
            penalizedSticks: diff,
            amountOwed: owed,
            summaryMessage: "Both exceeded the limit. \(loser) smoked \(diff) more than \(winner), owing \(currencySymbol)\(String(format: "%.2f", owed))."
        )
    }
}
