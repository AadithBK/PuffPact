import SwiftUI
import Combine

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showingResetAlert = false
    @Published public var resetEmailSent = false
    
    private let authService: AuthServiceProtocol
    
    public init(authService: AuthServiceProtocol) {
        self.authService = authService
    }
    
    public var isInputValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 6
    }
    
    public func login() async {
        guard isInputValid else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func sendPasswordReset() async {
        guard !email.isEmpty else {
            errorMessage = "Enter your email address first."
            return
        }
        do {
            try await authService.sendPasswordReset(email: email.trimmingCharacters(in: .whitespaces))
            resetEmailSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}