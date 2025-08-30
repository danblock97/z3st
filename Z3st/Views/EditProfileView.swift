import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile?
    @State private var fullName: String = ""
    @State private var dailyGoal: Int = 2000
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showCamera = false
    @State private var saving = false
    @State private var error: String?
    @State private var presentPhotoPicker = false
    @State private var showPhotoPermissionAlert = false

    var body: some View {
        Form {
            Section(header: Text("Profile")) {
                TextField("Full name", text: $fullName)
                Stepper(value: $dailyGoal, in: 500...6000, step: 100) { Text("Daily goal: \(dailyGoal) ml") }
            }
            Section(header: Text("Photo")) {
                HStack(spacing: 16) {
                    ZStack {
                        if let data = imageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else if let urlStr = profile?.profile_url, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty: ProgressView()
                                case .success(let img): img.resizable().scaledToFill()
                                case .failure: Image(systemName: "person.crop.circle").resizable().scaledToFit().padding(8)
                                @unknown default: Image(systemName: "person.crop.circle").resizable().scaledToFit().padding(8)
                                }
                            }
                        } else {
                            Image(systemName: "person.crop.circle").resizable().scaledToFit().padding(8)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())

                    Button("Choose from Library") {
                        Task { await chooseFromLibrary() }
                    }
                    Button("Use Camera") { showCamera = true }
                }
            }
            if let error { Text(error).foregroundColor(.red) }
            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack { if saving { ProgressView() }; Text("Save Changes").bold() }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .task { await load() }
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task { imageData = try? await newValue.loadTransferable(type: Data.self) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(data: $imageData)
        }
        .photosPicker(isPresented: $presentPhotoPicker, selection: $selectedItem, matching: .images)
        .alert("Photo Access Needed", isPresented: $showPhotoPermissionAlert) {
            Button("Open Settings") { PhotoPermission.openSettings() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Allow Z3st to access your photos to pick a profile picture.")
        }
    }

    private func load() async {
        if let p = try? await UserService.shared.fetchMyProfile() {
            await MainActor.run {
                profile = p
                fullName = p.full_name
                dailyGoal = p.daily_goal_ml
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            var url: String? = profile?.profile_url
            if let data = imageData { url = try await UserService.shared.uploadProfileImage(data: data, fileExt: "jpg") }
            guard let uid = AuthService.shared.currentUser?.id else { return }
            let updated = UserProfile(id: uid, full_name: fullName, profile_url: url, daily_goal_ml: dailyGoal, created_at: profile?.created_at)
            try await UserService.shared.upsertProfile(updated)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func chooseFromLibrary() async {
        switch PhotoPermission.current() {
        case .authorized, .limited:
            presentPhotoPicker = true
        case .notDetermined:
            let status = await PhotoPermission.requestReadWriteAccess()
            switch status {
            case .authorized, .limited:
                await MainActor.run { presentPhotoPicker = true }
            case .denied, .notDetermined:
                await MainActor.run {
                    error = "Photo access denied. You can allow access in Settings."
                    showPhotoPermissionAlert = true
                }
            }
        case .denied:
            showPhotoPermissionAlert = true
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var data: Data?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let key: UIImagePickerController.InfoKey = .editedImage
            if let image = info[key] as? UIImage, let jpeg = image.jpegData(compressionQuality: 0.8) {
                parent.data = jpeg
            }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}
