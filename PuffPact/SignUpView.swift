import SwiftUI

public struct SignUpView: View {
    @StateObject private var viewModel: SignUpViewModel
    @FocusState private var focusedField: Field?
    
    var onNavigateToLogin: () -> Void
    
    private enum Field: Hashable {
        case name
        case email
        case password
    }
    
    public init(authService: AuthServiceProtocol, onNavigateToLogin: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SignUpViewModel(authService: authService))
        self.onNavigateToLogin = onNavigateToLogin
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Branding
                VStack(spacing: 8) {
                    Image(systemName: "flame.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                        .padding(.top, 40)
                    
                    Text("Join PuffPact")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Start your journey to quitting, together.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                
                // Form Fields
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display Name")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        TextField("Alex M.", text: $viewModel.displayName)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .textContentType(.name)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        TextField("name@example.com", text: $viewModel.email)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password (6+ characters)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        SecureField("••••••••", text: $viewModel.password)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit {
                                Task { await viewModel.signUp() }
                            }
                    }
                }
                
                // Error Display
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Primary Action Button
                Button(action: {
                    focusedField = nil
                    Task { await viewModel.signUp() }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.isInputValid ? Color.blue : Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(!viewModel.isInputValid || viewModel.isLoading)
                .padding(.top, 8)
                
                // Switch to Log In
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Log In") {
                        onNavigateToLogin()
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.blue)
                }
                .padding(.top, 12)
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}