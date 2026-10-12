//
//  QuestionnaireView.swift
//  PuffPact
//

import SwiftUI

public struct QuestionnaireView: View {
    @StateObject private var viewModel: QuestionnaireViewModel

    public init(authService: AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: QuestionnaireViewModel(authService: authService))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top: Progress + Sign Out
            HStack(alignment: .center) {
                progressBar
                Spacer()
                Button(action: { viewModel.logOut() }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .padding(8)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Question content
            ScrollView(showsIndicators: false) {
                Group {
                    switch viewModel.currentStep {
                    case 0: dailyLevelStep
                    case 1: costPerStickStep
                    case 2: goalStep
                    case 3: cravingTriggersStep
                    case 4: pactIntentStep
                    default: EmptyView()
                    }
                }
                .padding(.top, 48)
                .padding(.bottom, 24)
            }

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            // Navigation
            navigationButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { step in
                Capsule()
                    .fill(step <= viewModel.currentStep ? Color.blue : Color.gray.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if viewModel.currentStep > 0 {
                Button(action: { viewModel.goBack() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(Color.surfaceBackground)
                    .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            Button(action: {
                if viewModel.currentStep < 4 {
                    viewModel.goNext()
                } else {
                    Task { await viewModel.complete() }
                }
            }) {
                HStack(spacing: 6) {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(viewModel.currentStep < 4 ? "Continue" : "Let's Go")
                            .font(.headline)
                        if viewModel.currentStep < 4 {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 28)
                .background(viewModel.canProceed ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!viewModel.canProceed || viewModel.isLoading)
        }
    }

    // MARK: - Step 0: Daily Smoking Level

    private var dailyLevelStep: some View {
        VStack(spacing: 28) {
            Text("🚬").font(.system(size: 56))

            Text("How many cigarettes do you\nsmoke on a typical day?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(DailySmokingLevel.allCases) { level in
                    SelectableOptionCard(
                        emoji: level.emoji,
                        title: level.displayLabel,
                        subtitle: level.range,
                        isSelected: viewModel.dailyLevel == level
                    ) {
                        viewModel.dailyLevel = level
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 1: Cost Per Stick

    private var costPerStickStep: some View {
        VStack(spacing: 28) {
            Text("💰").font(.system(size: 56))

            Text("What's the price of a cigarette\nfrom your most-smoked pack?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                HStack {
                    Text("₹")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)

                    TextField("0", value: $viewModel.costPerStick, format: .number)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 120)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 32)
                .background(Color.cardBackground)
                .cornerRadius(16)

                // Quick presets
                HStack(spacing: 10) {
                    ForEach([10.0, 15.0, 18.0, 22.0, 25.0], id: \.self) { price in
                        Button(action: { viewModel.costPerStick = price }) {
                            Text("₹\(Int(price))")
                                .font(.caption.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(viewModel.costPerStick == price ? Color.blue.opacity(0.15) : Color.surfaceBackground)
                                .foregroundColor(viewModel.costPerStick == price ? .blue : .secondary)
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 2: Goal

    private var goalStep: some View {
        VStack(spacing: 28) {
            Text("🎯").font(.system(size: 56))

            Text("What's your goal\nwith PuffPact?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                ForEach(SmokingGoal.allCases) { goal in
                    SelectableOptionCard(
                        emoji: goal.emoji,
                        title: goal.displayLabel,
                        subtitle: goal.subtitle,
                        isSelected: viewModel.goal == goal
                    ) {
                        viewModel.goal = goal
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 3: Craving Triggers

    private var cravingTriggersStep: some View {
        VStack(spacing: 28) {
            Text("⚡").font(.system(size: 56))

            VStack(spacing: 8) {
                Text("When do cravings hit\nyou the hardest?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Select all that apply")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(CravingTrigger.allCases) { trigger in
                    SelectableOptionCard(
                        emoji: trigger.emoji,
                        title: trigger.displayLabel,
                        subtitle: nil,
                        isSelected: viewModel.selectedTriggers.contains(trigger)
                    ) {
                        viewModel.toggleTrigger(trigger)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 4: Pact Intent

    private var pactIntentStep: some View {
        VStack(spacing: 28) {
            Text("🤝").font(.system(size: 56))

            Text("Ready to start\nyour pact?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                SelectableOptionCard(
                    emoji: "👤",
                    title: "I'll invite my partner later",
                    subtitle: "Generate a pact code now, share when ready",
                    isSelected: viewModel.pactIntent == .createNew
                ) {
                    viewModel.pactIntent = .createNew
                }

                SelectableOptionCard(
                    emoji: "👫",
                    title: "My partner is ready",
                    subtitle: "I have a pact code to join",
                    isSelected: viewModel.pactIntent == .joinExisting
                ) {
                    viewModel.pactIntent = .joinExisting
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Selectable Option Card

struct SelectableOptionCard: View {
    let emoji: String
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji).font(.title2)
                Text(title)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
