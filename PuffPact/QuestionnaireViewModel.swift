import SwiftUI
import Combine

@MainActor
public final class QuestionnaireViewModel: ObservableObject {
    @Published var currentStep = 0
    @Published var dailyLevel: DailySmokingLevel?
    @Published var costPerStick: Double = 18.0
    @Published var goal: SmokingGoal?
    @Published var selectedTriggers: Set<CravingTrigger> = []
    @Published var pactIntent: PactIntent?

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    var canProceed: Bool {
        switch currentStep {
        case 0: return dailyLevel != nil
        case 1: return costPerStick > 0
        case 2: return goal != nil
        case 3: return !selectedTriggers.isEmpty
        case 4: return pactIntent != nil
        default: return false
        }
    }

    func goNext() {
        guard canProceed, currentStep < 4 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
    }

    func goBack() {
        guard currentStep > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep -= 1
        }
    }

    func toggleTrigger(_ trigger: CravingTrigger) {
        if selectedTriggers.contains(trigger) {
            selectedTriggers.remove(trigger)
        } else {
            selectedTriggers.insert(trigger)
        }
    }

    func complete() async {
        guard canProceed,
              let dailyLevel, let goal, let pactIntent else { return }

        isLoading = true
        errorMessage = nil

        let profile = SmokingProfile(
            dailyLevel: dailyLevel,
            costPerStick: costPerStick,
            goal: goal,
            cravingTriggers: Array(selectedTriggers),
            pactIntent: pactIntent
        )

        do {
            try await authService.saveSmokingProfile(profile)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logOut() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
}
