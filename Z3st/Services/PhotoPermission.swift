import Foundation
import Photos
import UIKit

enum PhotoAuthorizationStatus {
    case authorized
    case limited
    case denied
    case notDetermined

    static func from(_ status: PHAuthorizationStatus) -> PhotoAuthorizationStatus {
        switch status {
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }
}

enum PhotoPermission {
    static func current() -> PhotoAuthorizationStatus {
        PhotoAuthorizationStatus.from(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    static func requestReadWriteAccess() async -> PhotoAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return PhotoAuthorizationStatus.from(status)
    }

    static func presentLimitedLibrary(from viewController: UIViewController) {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

