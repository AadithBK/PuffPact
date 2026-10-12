//
//  OnboardingView.swift
//  PuffPact
//

import SwiftUI

public struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case pactCode
        case pactName
        case costPerStick
    }

    public init(authService: AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(authService: authService))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                        .padding(.top, 40)

                    Text("Set Up Your Pact")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Configure your weekly limits and start holding each other accountable.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.bottom, 8)

                Picker("Options", selection: $viewModel.selectedTab) {
                    Text("Join Pact").tag(0)
                    Text("Create Pact").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)

                if viewModel.selectedTab == 0 {
                    joinPactSection
                } else {
                    createPactSection
                }

                // Error Display
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button(action: { viewModel.logOut() }) {
                    Text("Sign Out")
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                }
                .padding(.top, 16)

                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            await viewModel.loadProfile()
        }
    }

    // MARK: - Join Pact

    private var joinPactSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pact Code")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                TextField("Enter 6-character code", text: $viewModel.pactCode)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .pactCode)
                    .submitLabel(.join)
                    .onSubmit {
                        Task { await viewModel.joinPact() }
                    }
            }
            .padding(.horizontal, 24)

            Button(action: {
                focusedField = nil
                Task { await viewModel.joinPact() }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Join Pact").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isJoinValid ? Color.blue : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!viewModel.isJoinValid || viewModel.isLoading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .transition(.opacity)
    }

    // MARK: - Create Pact (with Set Limits)

    private var createPactSection: some View {
        VStack(spacing: 20) {
            // Suggested limit banner
            if viewModel.smokingProfile != nil {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    Text(viewModel.suggestedLimitText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.08))
                .cornerRadius(14)
                .padding(.horizontal, 24)
            }

            // Weekly Limit Stepper
            VStack(spacing: 12) {
                Text("WEEKLY CIGARETTE LIMIT")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    Button(action: {
                        if viewModel.weeklyLimit > 1 { viewModel.weeklyLimit -= 1 }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("\(viewModel.weeklyLimit)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .frame(minWidth: 80)

                    Button(action: { viewModel.weeklyLimit += 1 }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text("cigarettes per week, each")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 24)

            // Cost per stick
            VStack(alignment: .leading, spacing: 8) {
                Text("COST PER STICK")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack {
                    Text("₹")
                        .font(.title2.bold())
                        .foregroundColor(.secondary)
                    TextField("0", value: $viewModel.costPerStick, format: .number)
                        .font(.title2.bold())
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .costPerStick)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            // Reset day picker
            VStack(alignment: .leading, spacing: 8) {
                Text("WEEK RESETS ON")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Picker("Reset Day", selection: $viewModel.resetDay) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 24)

            // Live penalty preview
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(viewModel.penaltyPreviewText)
                        .font(.caption.bold())
                }
                Text(viewModel.maxPenaltyText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            // Pact Name
            VStack(alignment: .leading, spacing: 6) {
                Text("PACT NAME")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                TextField("e.g. Quitting Crew", text: $viewModel.pactName)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .focused($focusedField, equals: .pactName)
                    .submitLabel(.go)
                    .onSubmit {
                        Task { await viewModel.createPact() }
                    }
            }
            .padding(.horizontal, 24)

            // Create Button
            Button(action: {
                focusedField = nil
                Task { await viewModel.createPact() }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "lock.fill")
                        Text("Lock In Our Pact").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isCreateValid ? Color.blue : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!viewModel.isCreateValid || viewModel.isLoading)
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
        .transition(.opacity)
    }
}