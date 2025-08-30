import Foundation
#if canImport(Supabase) && !OFFLINE_TESTS
import Supabase

struct AuthUser {
    let id: UUID
    let email: String?
}

final class AuthService {
    static let shared = AuthService()
    private let client = SupabaseManager.shared.client
    private var cachedUser: AuthUser?

    var currentUser: AuthUser? {
        cachedUser
    }

    func restoreSession() async {
        // supabase-swift persists session; fetching it restores if present
        if let session = try? await client.auth.session {
            cachedUser = AuthUser(id: session.user.id, email: session.user.email)
        } else {
            cachedUser = nil
        }
    }

    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(
            email: email,
            password: password,
            data: nil,
            redirectTo: SupabaseManager.shared.authRedirectURL
        )
        await restoreSession()
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
        await restoreSession()
    }

    func signOut() async throws {
        try await client.auth.signOut()
        cachedUser = nil
    }

    func resendConfirmation(email: String) async throws {
        // Resend the signup confirmation email. Include redirect target so the link returns to the app/site.
        try await client.auth.resend(
            email: email,
            type: .signup
        )
    }

    /// Handles an auth redirect URL (email confirmation, magic link, OAuth) and exchanges it for a session.
    /// Returns true if a session was created/restored from the URL.
    func handleAuthRedirect(url: URL) async -> Bool {
        do {
            _ = try await client.auth.session(from: url)
            // Refresh cache after exchanging the URL for a session
            await restoreSession()
            return true
        } catch {
            return false
        }
    }
}

#else
struct AuthUser { let id: UUID; let email: String? }
final class AuthService {
    static let shared = AuthService()
    var currentUser: AuthUser? { nil }
    func restoreSession() async {}
    func signUp(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func signOut() async throws {}
    func resendConfirmation(email: String) async throws {}
    func handleAuthRedirect(url: URL) async -> Bool { false }
}
#endif
