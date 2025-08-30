import Foundation
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var dailyGoalML: Int = 2000
    @Published var imageData: Data?
    @Published var saving: Bool = false
    @Published var errorMessage: String?

    func save() async {
        saving = true
        defer { saving = false }
        do {
            var urlString: String? = nil
            if let data = imageData {
                urlString = try await UserService.shared.uploadProfileImage(data: data, fileExt: "jpg")
            }
            guard let uid = AuthService.shared.currentUser?.id else { return }
            let profile = UserProfile(id: uid, full_name: name, profile_url: urlString, daily_goal_ml: dailyGoalML, created_at: nil)
            try await UserService.shared.upsertProfile(profile)
            AppState.shared.markOnboardingComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

