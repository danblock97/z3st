import SwiftUI

struct CheckEmailView: View {
    @EnvironmentObject var session: SessionViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("Check your email")
                .font(.title2).bold()

            Text("We sent a confirmation link to \(session.pendingEmail ?? "your email"). Tap the link to confirm, then return here and sign in.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let info = session.infoMessage { Text(info).foregroundColor(.secondary) }
            if let err = session.errorMessage { Text(err).foregroundColor(.red) }

            HStack {
                Button("Resend email") {
                    Task { await session.resendConfirmation() }
                }
                .buttonStyle(.borderedProminent)

                Button("Back to Sign In") {
                    session.awaitingEmailConfirmation = false
                    session.infoMessage = nil
                    session.errorMessage = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
