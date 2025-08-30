//
//  Z3stApp.swift
//  Z3st
//
//  Created by Daniel Block on 30/08/2025.
//

import SwiftUI
import UserNotifications
import BackgroundTasks

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var isAuthenticated: Bool = false
    @Published var didFinishOnboarding: Bool = false
    enum MainTab: Hashable { case home, log, reminders, profile }
    @Published var selectedTab: MainTab = .home

    init() {
        // Load persisted flags (auth/session handled by Supabase, this covers onboarding flag)
        didFinishOnboarding = UserDefaults.standard.bool(forKey: "didFinishOnboarding")
    }

    func markOnboardingComplete() {
        didFinishOnboarding = true
        UserDefaults.standard.set(true, forKey: "didFinishOnboarding")
    }
}

@main
struct Z3stApp: App {
    @StateObject private var sessionVM = SessionViewModel()
    @StateObject private var appState = AppState.shared
    init() {
        BackgroundTaskService.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionVM)
                .environmentObject(appState)
                .onAppear {
                    // Ask for notification permission early (can be prompted later again in UI)
                    NotificationService.shared.requestAuthorizationIfNeeded()
                    BackgroundTaskService.shared.schedule()
                    Task { await HealthService.shared.requestAuthorizationIfNeeded() }
                    Task { await WaterService.shared.syncPending() }
                }
                .onOpenURL { url in
                    // Handle both custom scheme and universal link redirects.
                    Task {
                        if await AuthService.shared.handleAuthRedirect(url: url) {
                            await sessionVM.restore()
                            return
                        }
                        // Quick log deep link only applies to custom scheme z3st://log?ml=...
                        if url.scheme == "z3st" {
                            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                            if url.host == "log",
                               let q = comps?.queryItems,
                               let mlStr = q.first(where: { $0.name == "ml" })?.value,
                               let ml = Int(mlStr) {
                                try? await WaterService.shared.logWater(volumeML: ml)
                            }
                        }
                    }
                }
        }
    }
}
