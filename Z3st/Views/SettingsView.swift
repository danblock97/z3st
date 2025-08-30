import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var profile: UserProfile?
    @State private var loadingProfile = false
    @AppStorage("quiet_enabled") private var quietEnabled: Bool = false
    @AppStorage("quiet_start") private var quietStart: String = "22:00"
    @AppStorage("quiet_end") private var quietEnd: String = "07:00"
    @AppStorage("health_read_enabled") private var healthReadEnabled: Bool = false

    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var importing = false
    @State private var importMessage: String?
    @State private var showingResetConfirm = false
    @State private var resetting = false

    var body: some View {
        Form {
            Section(header: Text("Profile")) {
                HStack(spacing: 12) {
                    ZStack {
                        if let urlStr = profile?.profile_url, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty: ProgressView()
                                case .success(let img): img.resizable().scaledToFill()
                                case .failure: Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(6)
                                @unknown default: Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(6)
                                }
                            }
                        } else {
                            Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(6)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile?.full_name ?? "").font(.headline)
                        if let goal = profile?.daily_goal_ml {
                            Text("Daily goal: \(goal) ml").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    NavigationLink("Edit") { EditProfileView() }
                }
            }
            Section(header: Text("Quiet Hours"), footer: Text("Notifications won't be scheduled inside this window.")) {
                Toggle("Enable quiet hours", isOn: $quietEnabled)
                DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                    .disabled(!quietEnabled)
                DatePicker("End", selection: $endDate, displayedComponents: .hourAndMinute)
                    .disabled(!quietEnabled)
            }
            Section(header: Text("Health"), footer: Text("Sync water with Apple Health. You can import your last 30 days now.")) {
                Toggle("Sync with Apple Health", isOn: $healthReadEnabled)
                    .onChange(of: healthReadEnabled) { _, on in
                        if on { Task { await HealthService.shared.requestAuthorizationIfNeeded() } }
                    }
                Button {
                    Task { await importHealth() }
                } label: {
                    HStack { if importing { ProgressView() }; Text("Import last 30 days") }
                }
                .disabled(!healthReadEnabled || importing)
                if let importMessage { Text(importMessage).font(.footnote).foregroundStyle(.secondary) }
            }

            #if DEBUG
            Section(header: Text("Developer"), footer: Text("Signs out, clears onboarding flag, and resets local preferences. Use for testing only.")) {
                Button(role: .destructive) {
                    showingResetConfirm = true
                } label: {
                    HStack {
                        if resetting { ProgressView() }
                        Text("Reset app data")
                    }
                }
            }
            #endif
        }
        .navigationTitle("Settings")
        .task { await loadProfile() }
        .onAppear { Task { await loadProfile() } }
        .onAppear {
            startDate = Self.hhmmToDate(quietStart)
            endDate = Self.hhmmToDate(quietEnd)
        }
        .onChange(of: startDate) { _, newValue in
            quietStart = Self.dateToHHmm(newValue)
        }
        .onChange(of: endDate) { _, newValue in
            quietEnd = Self.dateToHHmm(newValue)
        }
        #if DEBUG
        .alert("Reset app data?", isPresented: $showingResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { Task { await resetAppData() } }
        } message: {
            Text("This will sign you out, clear onboarding state and local preferences used by the app.")
        }
        #endif
    }

    static func hhmmToDate(_ hhmm: String) -> Date {
        let comps = hhmm.split(separator: ":")
        let cal = Calendar.current
        let now = Date()
        let h = (comps.count > 0 ? Int(comps[0]) : nil) ?? 0
        let m = (comps.count > 1 ? Int(comps[1]) : nil) ?? 0
        return cal.date(bySettingHour: h, minute: m, second: 0, of: now) ?? now
    }
    static func dateToHHmm(_ date: Date) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return String(format: "%02d:%02d", h, m)
    }
}

extension SettingsView {
    private func loadProfile() async {
        guard loadingProfile == false else { return }
        loadingProfile = true
        defer { loadingProfile = false }
        profile = try? await UserService.shared.fetchMyProfile()
    }
    private func importHealth() async {
        importing = true
        defer { importing = false }
        await HealthService.shared.importLastNDays(30)
        importMessage = "Imported from Health"
    }

    #if DEBUG
    private func resetAppData() async {
        resetting = true
        defer { resetting = false }
        // Sign out (also clears cached auth)
        await session.signOut()
        // Clear known defaults
        let defaults = UserDefaults.standard
        [
            "didFinishOnboarding",
            "pending_logs",
            "quiet_enabled",
            "quiet_start",
            "quiet_end",
            "health_read_enabled",
        ].forEach { defaults.removeObject(forKey: $0) }
        // Reset widget shared today total if available
        AppGroupManager.setTodayTotal(0)
        // Reset in-memory toggles
        quietEnabled = false
        quietStart = "22:00"
        quietEnd = "07:00"
        healthReadEnabled = false
        importMessage = nil
    }
    #endif
}
