import Foundation

enum AppGroupManager {
    static var suiteName: String? {
        if let env = ProcessInfo.processInfo.environment["APP_GROUP_ID"], !env.isEmpty { return env }
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String, !fromInfo.isEmpty { return fromInfo }
        return nil
    }

    static func defaults() -> UserDefaults? {
        guard let suite = suiteName else { return nil }
        return UserDefaults(suiteName: suite)
    }

    static func setTodayTotal(_ ml: Int) {
        defaults()?.set(ml, forKey: "today_total_ml")
    }
}
