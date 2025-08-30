import SwiftUI
import UIKit
import PhotosUI

struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedItem: PhotosPickerItem?
    @State private var presentPhotoPicker = false
    @State private var showPhotoPermissionAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let ui = UIImage(named: "AppLogo") {
                    Image(uiImage: ui)
                        .resizable().scaledToFit().frame(height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityLabel("Z3st Logo")
                }
                Text("Let’s set up your profile")
                    .font(.title2).bold()

                Z3stAvatar(imageData: vm.imageData)
                    .onTapGesture { Task { await chooseFromLibrary() } }

                Button("Choose from Library") { Task { await chooseFromLibrary() } }

                TextField("Full name", text: $vm.name)
                    .padding().background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily goal (ml)")
                    Stepper(value: $vm.dailyGoalML, in: 500...6000, step: 100) {
                        Text("\(vm.dailyGoalML) ml")
                    }
                }

                if let err = vm.errorMessage { Text(err).foregroundColor(.red) }

                Button {
                    Task { await vm.save() }
                } label: {
                    HStack { if vm.saving { ProgressView() }; Text("Continue").bold() }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.name.isEmpty)
            }
            .padding()
        }
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    vm.imageData = data
                }
            }
        }
        .photosPicker(isPresented: $presentPhotoPicker, selection: $selectedItem, matching: .images)
        .alert("Photo Access Needed", isPresented: $showPhotoPermissionAlert) {
            Button("Open Settings") { PhotoPermission.openSettings() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Allow Z3st to access your photos to pick a profile picture.")
        }
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
                await MainActor.run { showPhotoPermissionAlert = true }
            }
        case .denied:
            showPhotoPermissionAlert = true
        }
    }
}

private struct Z3stAvatar: View {
    let imageData: Data?
    var body: some View {
        ZStack {
            if let data = imageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable().scaledToFit().foregroundStyle(.secondary)
                    .padding(24)
            }
        }
        .frame(width: 120, height: 120)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Circle())
        .accessibilityLabel("Profile photo")
        .accessibilityHint("Double tap to choose from your library")
    }
}
