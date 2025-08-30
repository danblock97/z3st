import Foundation

struct WaterEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let user_id: UUID
    let volume_ml: Int
    let created_at: Date
}

struct WaterDayTotal: Identifiable, Equatable {
    var id: String { dateString }
    let dateString: String // YYYY-MM-DD
    let total_ml: Int
}

