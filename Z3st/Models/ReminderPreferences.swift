import Foundation

struct ReminderPreferences: Codable, Equatable {
    var enabled: Bool
    var times: [String] // HH:mm in 24h
    var inactivityHours: Int

    static var `default`: ReminderPreferences {
        .init(enabled: true, times: ["09:00","11:30","14:00","16:30","19:00"], inactivityHours: 2)
    }
}

