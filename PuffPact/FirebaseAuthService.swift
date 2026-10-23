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
            let docRef = db.collection("users").document(userId)
            let snapshot = try await docRef.getDocument()
            if let data = snapshot.data() {
                let groupId = data["groupId"] as? String ?? ""
                let hasProfile = data["smokingProfile"] != nil

                if !groupId.isEmpty {
                    self.sessionState = .authenticated(userId: userId, groupId: groupId)
                } else if hasProfile {
                    self.sessionState = .needsGroupOnboarding(userId: userId)
                } else {
                    self.sessionState = .needsQuestionnaire(userId: userId)
                }
            } else {
                // If collections were deleted or document is missing, recreate user document from Auth
                if let currentUser = Auth.auth().currentUser {
                    try? await docRef.setData([
                        "id": userId,
                        "name": currentUser.displayName ?? "User",
                        "email": currentUser.email ?? "",
                        "groupId": "",
                        "createdAt": FieldValue.serverTimestamp()
                    ], merge: true)
                }
                self.sessionState = .needsQuestionnaire(userId: userId)
            }
        } catch {
            self.sessionState = .needsQuestionnaire(userId: userId)
        }
    }

    // MARK: - Authentication

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
        do {
            try await db.collection("users").document(result.user.uid).setData([
                "id": result.user.uid,
                "name": displayName,
                "email": email,
                "groupId": "",
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch {
            // Roll back Auth user if Firestore document creation fails to prevent orphaned auth accounts
            try? await result.user.delete()
            throw error
        }

        self.sessionState = .needsQuestionnaire(userId: result.user.uid)
        return result.user.uid
    }

    public func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    public func signOut() throws {
        try Auth.auth().signOut()
        self.sessionState = .unauthenticated
    }

    // MARK: - Smoking Profile

    public func saveSmokingProfile(_ profile: SmokingProfile) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { throw PactError.noCurrentUser }

        let data: [String: Any] = [
            "dailyLevel": profile.dailyLevel.rawValue,
            "costPerStick": profile.costPerStick,
            "goal": profile.goal.rawValue,
            "cravingTriggers": profile.cravingTriggers.map(\.rawValue),
            "pactIntent": profile.pactIntent.rawValue
        ]

        try await db.collection("users").document(userId).setData([
            "smokingProfile": data
        ], merge: true)

        await resolveUserRouting(userId: userId)
    }

    public func loadSmokingProfile() async throws -> SmokingProfile? {
        guard let userId = Auth.auth().currentUser?.uid else { throw PactError.noCurrentUser }
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data(),
              let profileData = data["smokingProfile"] as? [String: Any] else { return nil }

        let dailyLevel = DailySmokingLevel(rawValue: profileData["dailyLevel"] as? String ?? "") ?? .moderate
        let cost = profileData["costPerStick"] as? Double ?? 18.0
        let goal = SmokingGoal(rawValue: profileData["goal"] as? String ?? "") ?? .cutBack
        let triggerStrings = profileData["cravingTriggers"] as? [String] ?? []
        let triggers = triggerStrings.compactMap { CravingTrigger(rawValue: $0) }
        let intent = PactIntent(rawValue: profileData["pactIntent"] as? String ?? "") ?? .createNew

        return SmokingProfile(
            dailyLevel: dailyLevel,
            costPerStick: cost,
            goal: goal,
            cravingTriggers: triggers,
            pactIntent: intent
        )
    }

    // MARK: - Pact Management

    public func createPact(name: String, weeklyLimit: Int, costPerStick: Double, resetDay: Int) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { throw PactError.noCurrentUser }

        let code = String(UUID().uuidString.prefix(6)).uppercased()

        try await db.collection("pacts").document(code).setData([
            "id": code,
            "name": name,
            "createdAt": FieldValue.serverTimestamp(),
            "config": [
                "individualWeeklyLimit": weeklyLimit,
                "costPerStick": costPerStick,
                "resetDayOfWeek": resetDay
            ]
        ])

        try await db.collection("users").document(userId).setData([
            "groupId": code
        ], merge: true)

        await resolveUserRouting(userId: userId)
    }

    public func joinPact(code: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { throw PactError.noCurrentUser }

        let cleanedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanedCode.isEmpty else { throw PactError.invalidCode }

        // Verify the pact exists
        let doc = try await db.collection("pacts").document(cleanedCode).getDocument()
        guard doc.exists else {
            throw PactError.invalidCode
        }

        try await db.collection("users").document(userId).setData([
            "groupId": cleanedCode
        ], merge: true)

        await resolveUserRouting(userId: userId)
    }
}