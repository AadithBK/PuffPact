import SwiftUI
import FirebaseCore

@main
struct PuffPactApp: App {
    @StateObject private var authService: FirebaseAuthService
    @StateObject private var appState = AppState()
    @State private var showingSignUp = false
    
    init() {
        FirebaseApp.configure()
        _authService = StateObject(wrappedValue: FirebaseAuthService())
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch authService.sessionState {
                case .initializing:
                    ProgressView("Connecting...")
                    
                case .unauthenticated:
                    if showingSignUp {
                        SignUpView(authService: authService) {
                            showingSignUp = false
                        }
                    } else {
                        LoginView(authService: authService) {
                            showingSignUp = true
                        }
                    }
                    
                case .needsGroupOnboarding:
                    OnboardingView(authService: authService)
                    
                case .authenticated:
                    DashboardView()
                        .environmentObject(appState)
                }
            }
            .animation(.easeInOut, value: authService.sessionState != .unauthenticated)
        }
    }
}