//
//  SettlementView.swift
//  PuffPact
//

import SwiftUI

public struct SettlementView: View {
    @EnvironmentObject var state: AppState
    
    public var body: some View {
        #if os(macOS)
        settlementContent
            .frame(minWidth: 380, minHeight: 500)
            .padding()
        #else
        NavigationView {
            settlementContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            state.showingSettlementSheet = false
                        }
                    }
                }
        }
        #endif
    }
    
    private var settlementContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let settlement = state.latestSettlement {
                    
                    // Header Badge
                    VStack(spacing: 8) {
                        Image(systemName: settlement.scenario == .case3NeitherExceeded ? "checkmark.seal.fill" : "scalemass.fill")
                            .font(.system(size: 48))
                            .foregroundColor(settlement.scenario == .case3NeitherExceeded ? .green : .orange)
                        
                        Text(settlement.scenario.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                        
                        Text("Weekly Settlement")
                            .font(.title2.bold())
                    }
                    .padding(.top)
                    
                    // Comparison Box
                    HStack(spacing: 20) {
                        ScoreBlock(name: settlement.userAName, count: settlement.userACount, excess: settlement.userAExcess, limit: settlement.limit)
                        Divider().frame(height: 60)
                        ScoreBlock(name: settlement.userBName, count: settlement.userBCount, excess: settlement.userBExcess, limit: settlement.limit)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Settlement Financial Card
                    VStack(spacing: 12) {
                        Text("SETTLEMENT AMOUNT")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        Text("\(settlement.currency)\(String(format: "%.2f", settlement.amountOwed))")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(settlement.amountOwed > 0 ? .red : .primary)
                        
                        Text(settlement.summaryMessage)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Rule Calculation Explanation
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How This Was Calculated:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Weekly Limit: \(settlement.limit) cigarettes each")
                            Text("• Price per stick: \(settlement.currency)\(String(format: "%.2f", settlement.costPerStick))")
                            if settlement.scenario == .case1OneExceeded {
                                Text("• Rule: Only 1 person exceeded. Loser pays for all excess sticks above \(settlement.limit).")
                            } else if settlement.scenario == .case2BothExceeded {
                                Text("• Rule: Both exceeded. Loser pays for the net difference in excess sticks (\(settlement.penalizedSticks) sticks).")
                            } else if settlement.scenario == .case3NeitherExceeded {
                                Text("• Rule: Both stayed under \(settlement.limit). Zero financial penalty applies.")
                            } else {
                                Text("• Rule: Exact tie. Zero financial penalty applies.")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceBackground)
                    .cornerRadius(14)
                    .padding(.horizontal)
                    
                    // Actions
                    if settlement.amountOwed > 0 {
                        VStack(spacing: 10) {
                            Button(action: {
                                state.showingSettlementSheet = false
                            }) {
                                HStack {
                                    Image(systemName: "indianrupeesign.circle.fill")
                                    Text("Settle up with \(settlement.winnerName ?? "Friend")")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                state.showingSettlementSheet = false
                            }) {
                                Text("Dismiss")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                    } else {
                        Button(action: {
                            state.showingSettlementSheet = false
                        }) {
                            Text("Done")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.pageBackground)
    }
}

struct ScoreBlock: View {
    let name: String
    let count: Int
    let excess: Int
    let limit: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.headline)
            Text("\(count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(count > limit ? .red : .primary)
            if excess > 0 {
                Text("(+\(excess) over limit)")
                    .font(.caption2.bold())
                    .foregroundColor(.red)
            } else {
                Text("(Under limit)")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
