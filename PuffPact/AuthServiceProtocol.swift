import Foundation
import FirebaseAuth

public enum AuthSessionState: Equatable {
    case initializing
    case unauthenticated
    case needsGroupOnboarding(userId: String)
    case authenticated(userId: String, groupId: String)
}

public protocol AuthServiceProtocol {
    var sessionState: AuthSessionState { get }
    func signIn(email: String, password: String) async throws -> String
    func signUp(email: String, password: String, displayName: String) async throws -> String
    func sendPasswordReset(email: String) async throws
    func signOut() throws
    
    // Group / Pact Onboarding
    func createPact(name: String) async throws
    func joinPact(code: String) async throws
}