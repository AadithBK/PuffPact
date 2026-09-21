import SwiftUI
import Combine

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public var pactName = ""
    @Published public var pactCode = ""
    
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let authService: AuthServiceProtocol
    
    public init(authService: AuthServiceProtocol) {
        self.authService = authService
    }
    
    public var isCreateValid: Bool {
        !pactName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    public var isJoinValid: Bool {
        pactCode.trimmingCharacters(in: .whitespaces).count >= 6
    }
    
    public func createPact() async {
        guard isCreateValid else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.createPact(name: pactName.trimmingCharacters(in: .whitespaces))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func joinPact() async {
        guard isJoinValid else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.joinPact(code: pactCode)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func logOut() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
}