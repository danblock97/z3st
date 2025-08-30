import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "drop.fill") }
                .tag(AppState.MainTab.home)
            LogWaterView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                .tag(AppState.MainTab.log)
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.badge.fill") }
                .tag(AppState.MainTab.reminders)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppState.MainTab.profile)
        }
    }
}
