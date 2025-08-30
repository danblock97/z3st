import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var profile: UserProfile?
    @State private var showDeleteConfirm = false
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Z3stAvatarThumb(urlString: profile?.profile_url)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile?.full_name ?? "").font(.headline)
                            if let goal = profile?.daily_goal_ml {
                                Text("Daily goal: \(goal) ml").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        NavigationLink("Edit") { EditProfileView() }
                    }
                }
                if let p = profile {
                    Section(header: Text("Profile")) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(p.full_name).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Daily goal")
                            Spacer()
                            Text("\(p.daily_goal_ml) ml").foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        Task { await session.signOut() }
                    } label: { Text("Sign Out") }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: { Text("Delete Account") }
                    .disabled(deleting)
                    if let deleteError { Text(deleteError).foregroundColor(.red).font(.footnote) }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: EditProfileView()) { Text("Edit") }
                }
            }
            .task { profile = try? await UserService.shared.fetchMyProfile() }
            .onAppear { Task { profile = try? await UserService.shared.fetchMyProfile() } }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("This will permanently remove your account and data.")
            }
        }
    }

    private func deleteAccount() async {
        deleting = true
        defer { deleting = false }
        do {
            try await AccountService.shared.deleteCurrentUser()
            await session.signOut()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

private struct Z3stAvatarThumb: View {
    let urlString: String?
    var body: some View {
        ZStack {
            if let urlStr = urlString, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty: ProgressView()
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(6)
                    @unknown default: Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(6)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(6)
            }
        }
        .frame(width: 56, height: 56)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
