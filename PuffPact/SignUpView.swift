import SwiftUI

public struct SignUpView: View {
    @StateObject private var viewModel: SignUpViewModel
    @FocusState private var focusedField: Field?
    
    var onNavigateToLogin: () -> Void
    
    private enum Field: Hashable {
        case name
        case email
        case password
        case confirmPassword
    }
    
    public init(authService: AuthServiceProtocol, onNavigateToLogin: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SignUpViewModel(authService: authService))
        self.onNavigateToLogin = onNavigateToLogin
    }
    
    public var body: some View {
        ZStack {
            SmokeBackgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Top Navigation with Back Button
                    HStack {
                        Button(action: {
                            focusedField = nil
                            onNavigateToLogin()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Back")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color(hex: "1C1C20"))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color(hex: "2E2E34"), lineWidth: 1)
                            )
                        }
                        
                        Spacer()
                        
                        Text("PUFFPACT")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(3)
                            .foregroundColor(Color(hex: "FCD5A4").opacity(0.7))
                    }
                    .padding(.top, 12)
                    
                    // Title and Subtitle
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Create Account")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "FCE3C8"))
                        
                        Text("Start your journey to quitting cigarettes, together.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "A1A1AA"))
                            .lineSpacing(2)
                    }
                    .padding(.top, 6)
                    
                    // Form Fields
                    VStack(spacing: 13) {
                        // Display Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DISPLAY NAME")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(Color(hex: "8E8E93"))
                            
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "71717A"))
                                
                                TextField("Alex M.", text: $viewModel.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .textContentType(.name)
                                    .focused($focusedField, equals: .name)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .email }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(Color(hex: "161618"))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(focusedField == .name ? Color(hex: "FCD5A4") : Color(hex: "27272A"), lineWidth: 1)
                            )
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EMAIL ADDRESS")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(Color(hex: "8E8E93"))
                            
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "71717A"))
                                
                                TextField("name@example.com", text: $viewModel.email)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(Color(hex: "161618"))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(focusedField == .email ? Color(hex: "FCD5A4") : Color(hex: "27272A"), lineWidth: 1)
                            )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("PASSWORD")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Color(hex: "8E8E93"))
                                Spacer()
                                Text("6+ characters")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "71717A"))
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "71717A"))
                                
                                SecureField("••••••••", text: $viewModel.password)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .textContentType(.newPassword)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .confirmPassword }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(Color(hex: "161618"))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(focusedField == .password ? Color(hex: "FCD5A4") : Color(hex: "27272A"), lineWidth: 1)
                            )
                        }
                        
                        // Confirm Password Field (Enter Password Again)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("CONFIRM PASSWORD")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Color(hex: "8E8E93"))
                                Spacer()
                                if !viewModel.confirmPassword.isEmpty {
                                    if viewModel.passwordsMatch {
                                        Text("✓ Matches")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color(hex: "10B981"))
                                    } else {
                                        Text("✕ Doesn't match")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color(hex: "EF4444"))
                                    }
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "71717A"))
                                
                                SecureField("Re-enter password", text: $viewModel.confirmPassword)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .textContentType(.newPassword)
                                    .focused($focusedField, equals: .confirmPassword)
                                    .submitLabel(.go)
                                    .onSubmit {
                                        Task { await viewModel.signUp() }
                                    }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(Color(hex: "161618"))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        !viewModel.confirmPassword.isEmpty && !viewModel.passwordsMatch
                                        ? Color(hex: "EF4444")
                                        : (focusedField == .confirmPassword ? Color(hex: "FCD5A4") : Color(hex: "27272A")),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                    
                    // Error Display
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "EF4444"))
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 4)
                    }
                    
                    // Primary Action Button
                    Button(action: {
                        focusedField = nil
                        Task { await viewModel.signUp() }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("Create Account")
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundColor(Color(hex: "111111"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.isInputValid ? Color(hex: "FCD5A4") : Color(hex: "3F3F46"))
                        .clipShape(Capsule())
                        .shadow(color: viewModel.isInputValid ? Color(hex: "FCD5A4").opacity(0.25) : .clear, radius: 14, y: 3)
                    }
                    .disabled(!viewModel.isInputValid || viewModel.isLoading)
                    .padding(.top, 4)
                    
                    // Switch to Log In (Option B style)
                    HStack(spacing: 4) {
                        Spacer()
                        Text("Already have an account?")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8E8E93"))
                        Button("Log In") {
                            onNavigateToLogin()
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "FCD5A4"))
                        Spacer()
                    }
                    .padding(.top, 2)
                    
                    // Terms footnote
                    Text("By continuing you agree to the Terms and Conditions")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "71717A"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
