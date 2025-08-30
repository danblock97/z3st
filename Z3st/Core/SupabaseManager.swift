import Foundation
#if canImport(Supabase) && !OFFLINE_TESTS
import Supabase

enum SupabaseConfigError: Error, LocalizedError {
    case missingURL
    case missingAnonKey

    var errorDescription: String? {
        switch self {
        case .missingURL: return "SUPABASE_URL environment variable is missing."
        case .missingAnonKey: return "SUPABASE_ANON_KEY environment variable is missing."
        }
    }
}

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    let storageBucket: String
    let authRedirectURL: URL?

    private init() {
        let env = ProcessInfo.processInfo.environment
        guard let urlString = env["SUPABASE_URL"], let url = URL(string: urlString) else {
            fatalError(SupabaseConfigError.missingURL.localizedDescription)
        }
        guard let anonKey = env["SUPABASE_ANON_KEY"], !anonKey.isEmpty else {
            fatalError(SupabaseConfigError.missingAnonKey.localizedDescription)
        }
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
        self.storageBucket = env["SUPABASE_STORAGE_BUCKET"] ?? "profile-pictures"
        if let redirect = env["SUPABASE_AUTH_REDIRECT"], let rurl = URL(string: redirect) {
            self.authRedirectURL = rurl
        } else {
            // Default to custom URL scheme for dev
            self.authRedirectURL = URL(string: "z3st://auth-callback")
        }
    }
}

#else
final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: Any? = nil
    let storageBucket: String = "profile-pictures"
    let authRedirectURL: URL? = URL(string: "z3st://auth-callback")
    private init() {}
}
#endif
