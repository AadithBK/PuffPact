import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

public enum PactError: LocalizedError {
    case invalidCode
    case noCurrentUser
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .invalidCode: return "The pact code you entered is invalid or does not exist."
        case .noCurrentUser: return "You must be signed in to perform this action."
        case .unknown: return "An unknown error occurred."
        }
    }
}

@MainActor
public final class FirebaseAuthService: ObservableObject, AuthServiceProtocol {
    @Published public private(set) var sessionState: AuthSessionState = .initializing
    
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    
    public init() {
        listenToAuthChanges()
    }
    
    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    private func listenToAuthChanges() {
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            guard let user = user else {
                self.sessionState = .unauthenticated
                return
            }
            Task {
                await self.resolveUserRouting(userId: user.uid)
            }
        }
    }
    
    public func resolveUserRouting(userId: String) async {
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            if let data = snapshot.data(), let groupId = data["groupId"] as? String, !groupId.isEmpty {
                self.sessionState = .authenticated(userId: userId, groupId: groupId)
            } else {
                self.sessionState = .needsGroupOnboarding(userId: userId)
            }
        } catch {
            // Default to onboarding if user document does not exist yet
            self.sessionState = .needsGroupOnboarding(userId: userId)
        }
    }
    
    public func signIn(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await resolveUserRouting(userId: result.user.uid)
        return result.user.uid
    }
    
    public func signUp(email: String, password: String, displayName: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        
        // Create user document in Firestore
        try await db.collection("users").document(result.user.uid).setData([
            "id": result.user.uid,
            "name": displayName,
            "email": email,
            "groupId": "",
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        self.sessionState = .needsGroupOnboarding(userId: result.user.uid)
        return result.user.uid
    }
    
    public func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    public func signOut() throws {
        try Auth.auth().signOut()
        self.sessionState = .unauthenticated
    }
    
    public func createPact(name: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { throw PactError.noCurrentUser }
        
        let code = String(UUID().uuidString.prefix(6)).uppercased()
        
        try await db.collection("pacts").document(code).setData([
            "id": code,
            "name": name,
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        try await db.collection("users").document(userId).updateData([
            "groupId": code
        ])
        
        await resolveUserRouting(userId: userId)
    }
    
    public func joinPact(code: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { throw PactError.noCurrentUser }
        
        let cleanedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanedCode.isEmpty else { throw PactError.invalidCode }
        
        // Let's verify the pact exists
        let doc = try await db.collection("pacts").document(cleanedCode).getDocument()
        guard doc.exists else {
            throw PactError.invalidCode
        }
        
        try await db.collection("users").document(userId).updateData([
            "groupId": cleanedCode
        ])
        
        await resolveUserRouting(userId: userId)
    }
}