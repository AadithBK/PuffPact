import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?
    @State private var stage: AuthStage = .landing
    
    var onNavigateToSignUp: () -> Void
    
    private enum Field: Hashable {
        case email
        case password
    }
    
    public enum AuthStage {
        case landing
        case emailForm
    }
    
    public init(authService: AuthServiceProtocol, onNavigateToSignUp: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(authService: authService))
        self.onNavigateToSignUp = onNavigateToSignUp
    }
    
    public var body: some View {
        ZStack {
            SmokeBackgroundView()
            
            Group {
                switch stage {
                case .landing:
                    landingView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .emailForm:
                    emailFormView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: stage)
        .alert("Password Reset Sent", isPresented: $viewModel.resetEmailSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check your email inbox for instructions to reset your password.")
        }
    }
    
    // MARK: - Landing Stage (Matching UIWizard Design)
    
    private var landingView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Centered Brand Title
            Text("PUFFPACT")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .tracking(6)
                .foregroundColor(Color(hex: "FCE3C8"))
                .shadow(color: Color(hex: "FCE3C8").opacity(0.18), radius: 16)
            
            Spacer()
            
            // Action Stack
            VStack(spacing: 14) {
                // Primary: Sign in via Email
                Button(action: {
                    withAnimation { stage = .emailForm }
                }) {
                    Text("Sign in via Email")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Color(hex: "111111"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "FCD5A4"))
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "FCD5A4").opacity(0.25), radius: 16, y: 4)
                }
                
                // Google
                Button(action: {
                    // Placeholder for future Google Sign-In SDK hook
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        Text("Google")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(hex: "18181B"))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "27272A"), lineWidth: 1)
                    )
                }
                
                // Apple ID
                Button(action: {
                    // Placeholder for future Apple Sign-In SDK hook
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        Text("Apple ID")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(hex: "18181B"))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "27272A"), lineWidth: 1)
                    )
                }
                
                // Option B Sub-link: Don't have an account? Sign Up
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8E8E93"))
                    Button("Sign Up") {
                        onNavigateToSignUp()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "FCD5A4"))
                }
                .padding(.top, 4)
                
                // Terms & Conditions footnote
                Text("By Continuing you agree to the Terms and Conditions")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "71717A"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Email Form Stage
    
    private var emailFormView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Top Bar with Back Button
                HStack {
                    Button(action: {
                        withAnimation {
                            focusedField = nil
                            stage = .landing
                        }
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
                    Text("Welcome back.")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "FCE3C8"))
                    
                    Text("Sign in with your email to track your pact and sync progress.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "A1A1AA"))
                        .lineSpacing(2)
                }
                .padding(.top, 8)
                
                // Form Inputs
                VStack(spacing: 14) {
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
                        .padding(.vertical, 14)
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
                            Button("Forgot?") {
                                Task { await viewModel.sendPasswordReset() }
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "FCD5A4"))
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "71717A"))
                            
                            SecureField("••••••••", text: $viewModel.password)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    Task { await viewModel.login() }
                                }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color(hex: "161618"))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(focusedField == .password ? Color(hex: "FCD5A4") : Color(hex: "27272A"), lineWidth: 1)
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
                    Task { await viewModel.login() }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("Log In")
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
                .padding(.top, 6)
                
                // Bottom Option B Switcher
                HStack(spacing: 4) {
                    Spacer()
                    Text("Don't have an account?")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8E8E93"))
                    Button("Sign Up") {
                        onNavigateToSignUp()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "FCD5A4"))
                    Spacer()
                }
                .padding(.top, 4)
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Reusable Smoke Background View

public struct SmokeBackgroundView: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            // Pitch-black base
            Color.black
                .ignoresSafeArea()
            
            // Layered atmospheric smoke radial gradients
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "FCE3C8").opacity(0.08),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.5, y: 0.25),
                startRadius: 20,
                endRadius: 260
            )
            .ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.045),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.35, y: 0.75),
                startRadius: 40,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.035),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.65, y: 0.55),
                startRadius: 30,
                endRadius: 280
            )
            .ignoresSafeArea()
        }
    }
}
