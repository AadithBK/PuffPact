import SwiftUI

@main
struct PuffPactApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(appState)
        }
    }
}
