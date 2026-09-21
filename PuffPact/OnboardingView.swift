import SwiftUI

public struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @State private var selection = 0 // 0 = Join, 1 = Create
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case pactCode
        case pactName
    }
    
    public init(authService: AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(authService: authService))
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                    
                    Text("Your Pact")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Join an existing pact or start a new one to hold each other accountable.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.bottom, 12)
                
                Picker("Options", selection: $selection) {
                    Text("Join Pact").tag(0)
                    Text("Create Pact").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                
                if selection == 0 {
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
                
                Button(action: {
                    viewModel.logOut()
                }) {
                    Text("Sign Out")
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                }
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
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
                        Text("Join Pact")
                            .font(.headline)
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
    
    private var createPactSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pact Name")
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
            
            Button(action: {
                focusedField = nil
                Task { await viewModel.createPact() }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create Pact")
                            .font(.headline)
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
            .padding(.top, 8)
        }
        .transition(.opacity)
    }
}