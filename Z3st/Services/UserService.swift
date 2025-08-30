import Foundation
#if canImport(Supabase) && !OFFLINE_TESTS
import Supabase

final class UserService {
    static let shared = UserService()
    private let client = SupabaseManager.shared.client
    private let table = "users"

    func upsertProfile(_ profile: UserProfile) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let _ = try await client.database.from(table)
            .upsert(profile, returning: .representation)
            .execute()
    }

    func fetchMyProfile() async throws -> UserProfile? {
        guard let uid = AuthService.shared.currentUser?.id.uuidString else { return nil }
        let response: PostgrestResponse<UserProfile> = try await client.database.from(table)
            .select()
            .eq("id", value: uid)
            .single()
            .execute()
        return response.value
    }

    func uploadProfileImage(data: Data, fileExt: String = "jpg") async throws -> String {
        guard let uid = AuthService.shared.currentUser?.id.uuidString else { throw NSError(domain: "Auth", code: 401) }
        // Use lowercase to match Postgres' lowercase UUID string representation in RLS policies
        let path = "\(uid.lowercased())/profile.\(fileExt)"
        _ = try await client.storage
            .from(SupabaseManager.shared.storageBucket)
            .upload(path: path, file: data, options: .init(contentType: "image/\(fileExt)", upsert: true))
        // Return public URL if bucket is public, otherwise signed URL should be generated server-side.
        let url = try client.storage.from(SupabaseManager.shared.storageBucket).getPublicURL(path: path)
        return url.absoluteString
    }
}

#else
final class UserService {
    static let shared = UserService()
    func upsertProfile(_ profile: UserProfile) async throws {}
    func fetchMyProfile() async throws -> UserProfile? { nil }
    func uploadProfileImage(data: Data, fileExt: String = "jpg") async throws -> String { "" }
}
#endif
