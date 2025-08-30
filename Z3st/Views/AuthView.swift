import SwiftUI
import UIKit

struct AuthView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var mode: Mode = .signIn

    enum Mode { case signIn, signUp }

    var body: some View {
        Group {
            if session.awaitingEmailConfirmation {
                CheckEmailView()
            } else {
                form
            }
        }
    }

    private var form: some View {
        VStack(spacing: 16) {
            if let ui = UIImage(named: "AppLogo") {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel("Z3st Logo")
            } else {
                Text("Z3st")
                    .font(.largeTitle).bold()
            }
            Text(mode == .signIn ? "Welcome back" : "Create your account")
                .foregroundStyle(.secondary)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))

            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))

            if let info = session.infoMessage { Text(info).foregroundColor(.secondary).font(.footnote) }
            if let err = session.errorMessage { Text(err).foregroundColor(.red).font(.footnote) }

            Button(action: action) {
                HStack { if session.loading { ProgressView() }; Text(mode == .signIn ? "Sign In" : "Sign Up").bold() }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(mode == .signIn ? "Need an account? Sign up" : "Have an account? Sign in") {
                mode = mode == .signIn ? .signUp : .signIn
            }
            .font(.footnote)
            .padding(.top, 8)
        }
        .padding()
    }

    private func action() {
        Task {
            switch mode {
            case .signIn: await session.signIn(email: email, password: password)
            case .signUp: await session.signUp(email: email, password: password)
            }
        }
    }
}
