import Foundation
import Combine

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var loading: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    // When email confirmation is required
    @Published var awaitingEmailConfirmation: Bool = false
    @Published var pendingEmail: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        Task { await restore() }
    }

    func restore() async {
        loading = true
        defer { loading = false }
        await AuthService.shared.restoreSession()
        isAuthenticated = AuthService.shared.currentUser != nil
        if isAuthenticated {
            // Derive onboarding state from server profile presence and sign out if invalid
            do {
                if let profile = try await UserService.shared.fetchMyProfile(), profile != nil {
                    AppState.shared.markOnboardingComplete()
                } else {
                    AppState.shared.didFinishOnboarding = false
                    UserDefaults.standard.set(false, forKey: "didFinishOnboarding")
                }
                awaitingEmailConfirmation = false
                infoMessage = nil
                errorMessage = nil
            } catch {
                // Likely invalid/stale session: sign out and reset state
                await signOut()
            }
        } else {
            AppState.shared.didFinishOnboarding = false
            UserDefaults.standard.set(false, forKey: "didFinishOnboarding")
        }
    }

    func signIn(email: String, password: String) async {
        loading = true
        errorMessage = nil
        infoMessage = nil
        defer { loading = false }
        do {
            try await AuthService.shared.signIn(email: email, password: password)
            isAuthenticated = AuthService.shared.currentUser != nil
            if isAuthenticated {
                if let profile = try? await UserService.shared.fetchMyProfile(), profile != nil {
                    AppState.shared.markOnboardingComplete()
                } else {
                    AppState.shared.didFinishOnboarding = false
                    UserDefaults.standard.set(false, forKey: "didFinishOnboarding")
                }
            }
            awaitingEmailConfirmation = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        loading = true
        errorMessage = nil
        infoMessage = nil
        defer { loading = false }
        do {
            try await AuthService.shared.signUp(email: email, password: password)
            // If confirmation is disabled (dev), Supabase returns a session.
            // If confirmation is enabled (prod), no session is returned.
            await AuthService.shared.restoreSession()
            if AuthService.shared.currentUser == nil {
                // Try immediate sign-in. In prod, this will typically fail with "email not confirmed".
                do {
                    try await AuthService.shared.signIn(email: email, password: password)
                } catch {
                    // Provide a clearer UX when confirmation is required.
                    awaitingEmailConfirmation = true
                    pendingEmail = email
                    infoMessage = "We sent a confirmation link to \(email). Please confirm to continue, then sign in."
                }
            }
            isAuthenticated = AuthService.shared.currentUser != nil
            if isAuthenticated {
                if let profile = try? await UserService.shared.fetchMyProfile(), profile != nil {
                    AppState.shared.markOnboardingComplete()
                } else {
                    AppState.shared.didFinishOnboarding = false
                    UserDefaults.standard.set(false, forKey: "didFinishOnboarding")
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resendConfirmation() async {
        guard let email = pendingEmail else { return }
        loading = true
        defer { loading = false }
        do {
            try await AuthService.shared.resendConfirmation(email: email)
            infoMessage = "Confirmation email resent to \(email)."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do { try await AuthService.shared.signOut() } catch { }
        isAuthenticated = false
        AppState.shared.didFinishOnboarding = false
        UserDefaults.standard.set(false, forKey: "didFinishOnboarding")
        awaitingEmailConfirmation = false
        pendingEmail = nil
        infoMessage = nil
        errorMessage = nil
    }
}
