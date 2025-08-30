import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var full_name: String
    var profile_url: String?
    var daily_goal_ml: Int
    var created_at: Date?
}

