import SwiftUI
import Combine

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public var pactName = ""
    @Published public var pactCode = ""
    @Published public var weeklyLimit: Int = 20
    @Published public var costPerStick: Double = 18.0
    @Published public var resetDay: Int = 2  // 1 = Sunday, 2 = Monday

    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var smokingProfile: SmokingProfile?
    @Published public var selectedTab: Int = 1  // 0 = Join, 1 = Create

    private let authService: AuthServiceProtocol

    public init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    public func loadProfile() async {
        do {
            if let profile = try await authService.loadSmokingProfile() {
                self.smokingProfile = profile
                self.weeklyLimit = profile.suggestedWeeklyLimit
                self.costPerStick = profile.costPerStick
                self.selectedTab = profile.pactIntent == .joinExisting ? 0 : 1
            }
        } catch {
            // Use defaults if loading fails
        }
    }

    public var isCreateValid: Bool {
        !pactName.trimmingCharacters(in: .whitespaces).isEmpty && weeklyLimit > 0 && costPerStick > 0
    }

    public var isJoinValid: Bool {
        pactCode.trimmingCharacters(in: .whitespaces).count >= 6
    }

    public var suggestedLimitText: String {
        guard let profile = smokingProfile else { return "" }
        let baseline = profile.dailyLevel.estimatedDaily * 7
        return "Based on ~\(profile.dailyLevel.estimatedDaily)/day (\(baseline)/week), we suggest \(profile.suggestedWeeklyLimit) as your weekly target."
    }

    public var penaltyPreviewText: String {
        "Every extra stick beyond \(weeklyLimit) costs ₹\(String(format: "%.1f", costPerStick))"
    }

    public var maxPenaltyText: String {
        let maxPenalty = Double(weeklyLimit) * costPerStick
        return "Potential max penalty: ₹\(String(format: "%.0f", maxPenalty))"
    }

    public func createPact() async {
        guard isCreateValid else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await authService.createPact(
                name: pactName.trimmingCharacters(in: .whitespaces),
                weeklyLimit: weeklyLimit,
                costPerStick: costPerStick,
                resetDay: resetDay
            )
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