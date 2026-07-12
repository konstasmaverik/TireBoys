import SwiftUI

struct AuthView: View {
    let backend: Backend

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Log In"
        case signUp = "Sign Up"
        var id: Self { self }
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6
            && (mode == .signIn || isValidUsername)
    }

    private var isValidUsername: Bool {
        username.wholeMatch(of: /[a-z0-9_]{3,20}/) != nil
    }

    var body: some View {
        Form {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            Section {
                if mode == .signUp {
                    TextField("Username (a-z, 0-9, _)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: username) { _, new in
                            username = new.lowercased()
                        }
                }
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password (6+ characters)", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
            } footer: {
                if mode == .signUp, !username.isEmpty, !isValidUsername {
                    Text("Username must be 3–20 characters: lowercase letters, digits, underscore.")
                        .foregroundStyle(.red)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .listRowBackground(Color.clear)
            }

            Button {
                submit()
            } label: {
                if isWorking {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text(mode.rawValue).bold().frame(maxWidth: .infinity)
                }
            }
            .disabled(!canSubmit || isWorking)
        }
        .navigationTitle("DriveStats Account")
    }

    private func submit() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                switch mode {
                case .signIn:
                    try await backend.signIn(email: email, password: password)
                case .signUp:
                    try await backend.signUp(email: email, password: password, username: username)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack { AuthView(backend: Backend()) }
}
