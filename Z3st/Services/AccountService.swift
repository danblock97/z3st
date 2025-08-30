import Foundation
#if canImport(Supabase) && !OFFLINE_TESTS
import Supabase

final class AccountService {
    static let shared = AccountService()
    func deleteCurrentUser() async throws {
        let client = SupabaseManager.shared.client
        _ = try await client.database.rpc("delete_current_user").execute()
    }
}

#else
final class AccountService {
    static let shared = AccountService()
    func deleteCurrentUser() async throws {}
}
#endif
