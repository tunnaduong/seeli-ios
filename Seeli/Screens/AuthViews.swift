import SwiftUI

enum AuthRoute: Hashable { case signUp, created }

struct AuthFlow: View {
    @State private var path: [AuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            LoginView(path: $path)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .signUp: SignUpView(path: $path)
                    case .created: AccountCreatedView()
                    }
                }
        }
    }
}

struct LoginView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AuthRoute]
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack { Spacer(); LanguageSwitch() }
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    EyeLogo(size: 34)
                    Text("SEELI")
                        .font(.system(size: 40, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.seeliInk)
                    Text("See more. Live more.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.seeliMuted)
                }
                .padding(.top, 48)
                .padding(.bottom, 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text("LOGIN").font(.system(size: 13, weight: .semibold)).tracking(1.5).foregroundStyle(Color.seeliGreen)
                    Text(t("login.title")).font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.seeliInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 20)

                VStack(spacing: 16) {
                    LabeledField(label: t("field.email"), placeholder: "you@example.com", text: $email,
                                 keyboard: .emailAddress, contentType: .emailAddress)
                    LabeledField(label: t("field.password"), placeholder: "••••••••", text: $password,
                                 secure: true, contentType: .password)
                }

                if let error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: 0xB0574A))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                }

                Button { login() } label: {
                    if busy { ProgressView().tint(.white) } else { Text(t("login.button")) }
                }
                    .buttonStyle(PrimaryButtonStyle(enabled: canSubmit))
                    .disabled(!canSubmit || busy)
                    .padding(.top, 28)

                SocialButtons(onSignedIn: { isNew in if isNew { path.append(.created) } }, error: $error)
                    .padding(.top, 16)

                HStack(spacing: 6) {
                    Text(t("login.noAccount")).foregroundStyle(Color.seeliMuted)
                    Button(t("login.signUp")) { path.append(.signUp) }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.seeliGreen)
                }
                .font(.system(size: 14))
                .padding(.top, 20)

                Text(t("login.localNote"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.seeliMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.seeliBG.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var canSubmit: Bool { !email.isEmpty && !password.isEmpty }

    private func login() {
        busy = true
        error = nil
        Task {
            do {
                try await store.login(email: email, password: password)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? t("error.generic")
            }
            busy = false
        }
    }
}

struct SignUpView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AuthRoute]
    @State private var name = ""
    @State private var handle = ""
    @State private var email = ""
    @State private var password = ""
    @State private var agreed = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("signup.title")).font(.system(size: 24, weight: .semibold)).foregroundStyle(Color.seeliInk)
                    Text(t("signup.subtitle")).font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                }
                .padding(.bottom, 28)

                VStack(spacing: 16) {
                    LabeledField(label: t("field.name"), placeholder: t("field.name.placeholder"), text: $name, contentType: .name)
                    LabeledField(label: t("field.handle"), placeholder: "seeli_user", text: $handle, contentType: .username)
                    LabeledField(label: t("field.email"), placeholder: "you@example.com", text: $email,
                                 keyboard: .emailAddress, contentType: .emailAddress)
                    LabeledField(label: t("field.password"), placeholder: t("field.password.hint"), text: $password,
                                 secure: true, contentType: .newPassword)
                }

                Button { agreed.toggle() } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: agreed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(agreed ? Color.seeliGreen : Color.seeliMuted)
                            .font(.system(size: 18))
                        Text(t("signup.promise"))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.seeliInk)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.top, 22)

                if let error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: 0xB0574A))
                        .padding(.top, 16)
                }

                Button { submit() } label: {
                    if busy { ProgressView().tint(.white) } else { Text(t("signup.button")) }
                }
                .buttonStyle(PrimaryButtonStyle(enabled: valid))
                .disabled(!valid || busy)
                .padding(.top, 28)

                SocialButtons(onSignedIn: { isNew in
                    if isNew { path.append(.created) }
                }, error: $error)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top) {
            SeeliHeader(title: "SIGN UP", subtitle: t("signup.header"), leading: .back)
                .background(Color.seeliBG)
        }
        .background(Color.seeliBG.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func submit() {
        busy = true
        error = nil
        Task {
            do {
                try await store.signUp(name: name.trimmingCharacters(in: .whitespaces),
                                       handle: cleanHandle,
                                       email: email.trimmingCharacters(in: .whitespaces),
                                       password: password)
                path.append(.created)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? t("error.generic")
            }
            busy = false
        }
    }

    private var cleanHandle: String {
        handle.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "@", with: "")
    }

    private var valid: Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (2...30).contains(cleanHandle.count)
            && cleanHandle.unicodeScalars.allSatisfy { allowed.contains($0) }
            && email.contains("@") && email.contains(".")
            && password.count >= 8
            && agreed
    }
}

struct AccountCreatedView: View {
    @Environment(AppStore.self) private var store
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Color.seeliCard).frame(width: 120, height: 120)
                EyeLogo(size: 44, color: .seeliGreen)
            }
            .scaleEffect(appear ? 1 : 0.7)
            .opacity(appear ? 1 : 0)

            Text(t("created.title"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.seeliInk)
                .padding(.top, 32)
            Text(tf("created.welcome", store.account?.name ?? ""))
                .font(.system(size: 15))
                .foregroundStyle(Color.seeliMuted)
                .padding(.top, 8)
            if let account = store.account, account.hasPassword == false {
                Text(tf("created.handle", account.handle))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.seeliMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 14) {
                principle("eye", t("created.p1"))
                principle("hourglass", t("created.p2"))
                principle("person.2", t("created.p3"))
            }
            .padding(20)
            .seeliCard(.seeliCard, border: false)
            .padding(.top, 32)

            Spacer()
            Button(t("created.start")) {
                store.welcomePending = false
                Task { await store.refresh() }
            }
                .buttonStyle(PrimaryButtonStyle())
            Text("SEE MORE. LIVE MORE.")
                .font(.system(size: 10, weight: .medium))
                .tracking(2)
                .foregroundStyle(Color.seeliMuted)
                .padding(.top, 16)
        }
        .padding(24)
        .background(Color.seeliBG.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appear = true } }
    }

    private func principle(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.seeliGreen).frame(width: 22)
            Text(text).font(.system(size: 14)).foregroundStyle(Color.seeliInk)
            Spacer(minLength: 0)
        }
    }
}
