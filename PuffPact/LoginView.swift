import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?
    
    var onNavigateToSignUp: () -> Void
    
    private enum Field: Hashable {
        case email
        case password
    }
    
    public init(authService: AuthServiceProtocol, onNavigateToSignUp: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(authService: authService))
        self.onNavigateToSignUp = onNavigateToSignUp
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
                    
                    Text("PuffPact")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Accountability is cheaper than cigarettes.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                
                // Form Fields
                VStack(spacing: 16) {
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
                        HStack {
                            Text("Password")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Forgot?") {
                                Task { await viewModel.sendPasswordReset() }
                            }
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                        }
                        
                        SecureField("••••••••", text: $viewModel.password)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit {
                                Task { await viewModel.login() }
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
                    Task { await viewModel.login() }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log In")
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
                
                // Switch to Sign Up
                HStack(spacing: 4) {
                    Text("Don't have a pact partner yet?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Sign Up") {
                        onNavigateToSignUp()
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
        .alert("Password Reset Sent", isPresented: $viewModel.resetEmailSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check your email inbox for instructions to reset your password.")
        }
    }
}