import SwiftUI
import Combine

@MainActor
public final class SignUpViewModel: ObservableObject {
    @Published public var displayName = ""
    @Published public var email = ""
    @Published public var password = ""
    
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let authService: AuthServiceProtocol
    
    public init(authService: AuthServiceProtocol) {
        self.authService = authService
    }
    
    public var isInputValid: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return !trimmedName.isEmpty && !trimmedEmail.isEmpty && password.count >= 6
    }
    
    public func signUp() async {
        guard isInputValid else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await authService.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespaces)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}