import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !session.isAuthenticated {
                AuthView()
            } else if !appState.didFinishOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .onAppear {
            Task { await session.restore() }
        }
    }
}

