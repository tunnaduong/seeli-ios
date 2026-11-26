import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var editing = false

    var body: some View {
        SeeliScreen(title: "PROFILE", subtitle: t("profile.subtitle")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let account = store.account {
                        HStack(spacing: 16) {
                            Avatar(initial: account.initial, size: 72)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(account.name).font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.seeliInk)
                                Text("@\(account.handle)").font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                                Button { editing = true } label: {
                                    Label(t("profile.edit"), systemImage: "pencil")
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                        .fixedSize()
                                        .foregroundStyle(Color.seeliInk)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(Color.seeliSurface))
                                }
                            }
                            Spacer(minLength: 0)
                            Button { store.path.append(.myQR) } label: {
                                RoundedRectangle(cornerRadius: 14).fill(Color.seeliSurface).frame(width: 56, height: 56)
                                    .overlay(Image(systemName: "qrcode").font(.system(size: 26, weight: .light)).foregroundStyle(Color.seeliInk))
                            }
                            .accessibilityLabel(t("myqr.title"))
                        }
                        .padding(20)
                        .seeliCard(.seeliCard, radius: 24, border: false)

                        if !account.bio.isEmpty {
                            Text(account.bio).font(.system(size: 14)).foregroundStyle(Color.seeliInk)
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading).seeliCard()
                        }
                    }

                    Text(t("profile.section")).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.seeliInk)
                        .padding(.top, 16).padding(.bottom, 4)

                    Button { store.path.append(.friends) } label: {
                        MenuRow(icon: "person.2", title: t("profile.friends"), subtitle: t("profile.friends.sub"))
                    }
                    Button { store.path.append(.privacy) } label: {
                        MenuRow(icon: "checkmark.shield", title: t("profile.privacy"), subtitle: t("profile.privacy.sub"))
                    }
                    Button { store.path.append(.settings) } label: {
                        MenuRow(icon: "gearshape", title: t("profile.settings"), subtitle: t("profile.settings.sub"))
                    }
                    Button { store.path.append(.verified) } label: {
                        MenuRow(icon: "checkmark.seal", title: "Verified Account", subtitle: t("profile.verified.sub"))
                    }

                    VStack(spacing: 8) {
                        Text(t("profile.footer")).font(.system(size: 14)).foregroundStyle(Color.seeliInk)
                        Text("SEE MORE. LIVE MORE.").font(.system(size: 10)).tracking(2).foregroundStyle(Color.seeliMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .seeliCard(.seeliCard, border: false)
                    .padding(.top, 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $editing) { EditProfileSheet() }
    }
}

private struct EditProfileSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var bio = ""
    @State private var handle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(t("profile.edit")).font(.system(size: 20, weight: .semibold))
            LabeledField(label: t("field.name"), placeholder: t("field.name.placeholder"), text: $name)
            LabeledField(label: t("field.handle"), placeholder: "seeli_user", text: $handle, contentType: .username)
            VStack(alignment: .leading, spacing: 8) {
                Text(t("field.bio")).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.seeliMuted)
                TextField(t("field.bio.placeholder"), text: $bio, axis: .vertical)
                    .lineLimit(3...5).padding(14).seeliCard(radius: 14)
            }
            Spacer()
            if let error = store.lastError {
                Text(error).font(.system(size: 12)).foregroundStyle(Color(hex: 0xB0574A))
            }
            Button(t("common.save")) {
                Task {
                    let h = handle.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "@", with: "")
                    if await store.updateProfile(name: name.trimmingCharacters(in: .whitespaces), bio: bio, handle: h) { dismiss() }
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty))
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(24)
        .background(Color.seeliBG.ignoresSafeArea())
        .onAppear {
            name = store.account?.name ?? ""
            handle = store.account?.handle ?? ""
            bio = store.account?.bio ?? ""
        }
    }
}

struct FriendsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        SeeliScreen(title: "MY CIRCLE", subtitle: t("friends.subtitle"), leading: .back) {
            ScrollView {
                VStack(spacing: 12) {
                    Button { store.path.append(.scan) } label: {
                        MenuRow(icon: "qrcode.viewfinder", title: t("connect.qr.title"), subtitle: t("connect.qr.body"))
                    }
                    let pending = store.friendRequests.incoming.count + store.friendRequests.outgoing.count
                    if pending > 0 {
                        Button { store.path.append(.requests) } label: {
                            HStack(spacing: 0) {
                                MenuRow(icon: "person.badge.plus", title: t("requests.title"),
                                        subtitle: store.friendRequests.incoming.isEmpty
                                            ? tf("requests.sent.count", store.friendRequests.outgoing.count)
                                            : tf("requests.incoming.count", store.friendRequests.incoming.count))
                            }
                            .overlay(alignment: .topTrailing) {
                                CountBadge(count: store.friendRequests.incoming.count).padding(8)
                            }
                        }
                    }
                    if !store.friends.isEmpty {
                        Text(t("friends.close.hint")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                    }
                    if store.friends.isEmpty {
                        Text(t("connect.empty")).font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                            .multilineTextAlignment(.center).padding(.top, 40)
                    }
                    ForEach(store.friends) { friend in
                        Button { store.path.append(.friend(friend.id)) } label: {
                            HStack(spacing: 14) {
                                Avatar(initial: friend.initial, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(friend.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.seeliInk)
                                    Text("@\(friend.handle)").font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
                                }
                                Spacer()
                                Button { Task { await store.setClose(friend.id, !friend.isClose) } } label: {
                                    Image(systemName: friend.isClose ? "star.fill" : "star")
                                        .font(.system(size: 17))
                                        .foregroundStyle(friend.isClose ? Color(hex: 0xD9A93E) : Color.seeliMuted)
                                        .frame(width: 40, height: 40)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(friend.isClose ? t("close.remove") : t("close.add"))
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                            }
                            .padding(14)
                            .seeliCard()
                        }
                    }
                    Text(tf("friends.count", store.friends.count))
                        .font(.system(size: 12)).foregroundStyle(Color.seeliMuted).padding(.top, 12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}

struct FriendProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var friendID: String
    @State private var memo = ""
    @State private var confirm: Action?
    @State private var reported = false

    enum Action: Identifiable { case report, block, remove; var id: Self { self } }

    var body: some View {
        SeeliScreen(title: "PROFILE", subtitle: t("friend.subtitle"), leading: .back) {
            if let friend = store.friend(friendID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 18) {
                            Avatar(initial: friend.initial, size: 84)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(friend.name).font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.seeliInk)
                                Text("@\(friend.handle)").font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                                Chip(text: friend.isClose ? "CLOSE FRIEND" : "MY CIRCLE")
                            }
                            Spacer()
                        }
                        .padding(20)
                        .seeliCard(.seeliCard, radius: 24, border: false)

                        Toggle(isOn: Binding(get: { friend.isClose },
                                             set: { on in Task { await store.setClose(friendID, on) } })) {
                            VStack(alignment: .leading, spacing: 3) {
                                Label(t("close.toggle"), systemImage: "star").font(.system(size: 14, weight: .medium))
                                Text(t("close.toggle.hint")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                            }
                        }
                        .tint(.seeliGreen)
                        .padding(18)
                        .seeliCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Text(t("friend.bio")).font(.system(size: 14, weight: .semibold))
                            Text(friend.bio.isEmpty ? t("friend.bio.empty") : friend.bio)
                                .font(.system(size: 14))
                                .foregroundStyle(friend.bio.isEmpty ? Color.seeliMuted : Color.seeliInk)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                        .seeliCard()

                        VStack(alignment: .leading, spacing: 8) {
                            Label(t("friend.memo"), systemImage: "pencil.line").font(.system(size: 14, weight: .medium))
                            Text(t("friend.memo.hint")).font(.system(size: 10)).foregroundStyle(Color.seeliMuted)
                            TextField(t("friend.memo.placeholder"), text: $memo, axis: .vertical)
                                .lineLimit(2...5)
                                .font(.system(size: 13))
                                .padding(14)
                                .seeliCard(radius: 12)
                                .onSubmit { Task { await store.updateMemo(friendID, memo: memo) } }
                                .task(id: memo) {
                                    // Save shortly after typing stops.
                                    try? await Task.sleep(for: .milliseconds(800))
                                    guard !Task.isCancelled, memo != store.friend(friendID)?.memo else { return }
                                    await store.updateMemo(friendID, memo: memo)
                                }
                        }
                        .padding(18)
                        .seeliCard(.seeliCard, border: false)

                        Text(t("friend.safety")).font(.system(size: 17, weight: .semibold)).padding(.top, 10)

                        Button { confirm = .report } label: {
                            MenuRow(icon: "flag", title: t("friend.report"), subtitle: t("friend.report.sub"), chevron: false)
                        }
                        Button { confirm = .block } label: {
                            MenuRow(icon: "nosign", title: t("friend.block"), subtitle: t("friend.block.sub"), chevron: false)
                        }
                        Button { confirm = .remove } label: {
                            MenuRow(icon: "person.badge.minus", title: t("friend.remove"), subtitle: t("friend.remove.sub"), chevron: false)
                        }

                        Text(t("friend.footer")).font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
                            .frame(maxWidth: .infinity).padding(.top, 14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
                .onAppear { memo = friend.memo }
            } else {
                Spacer()
                Text(t("friend.gone")).foregroundStyle(Color.seeliMuted)
                Spacer()
            }
        }
        .confirmationDialog(confirmTitle, isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), titleVisibility: .visible) {
            switch confirm {
            case .report:
                Button(t("friend.report"), role: .destructive) {
                    Task { reported = await store.report(friendID) }
                }
            case .block:
                Button(t("friend.block"), role: .destructive) { Task { await store.block(friendID); dismiss() } }
            case .remove:
                Button(t("friend.remove"), role: .destructive) { Task { await store.removeFriend(friendID); dismiss() } }
            case nil:
                EmptyView()
            }
            Button(t("common.cancel"), role: .cancel) {}
        }
        .alert(t("friend.reported"), isPresented: $reported) {
            Button("OK", role: .cancel) {}
        }
    }

    private var confirmTitle: String {
        switch confirm {
        case .report: return t("friend.report.confirm")
        case .block: return t("friend.block.confirm")
        case .remove: return t("friend.remove.confirm")
        case nil: return ""
        }
    }
}

struct PrivacyView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        SeeliScreen(title: "PRIVACY", subtitle: t("profile.privacy"), leading: .back) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(t("privacy.default")).font(.system(size: 15, weight: .semibold))
                    Picker("", selection: $store.defaultAudience) {
                        Text("ONLY ME").tag(Audience.onlyMe)
                        Text("CLOSE").tag(Audience.closeFriends)
                        Text("MY CIRCLE").tag(Audience.circle)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.defaultAudience) { _, _ in store.save() }

                    VStack(alignment: .leading, spacing: 10) {
                        bullet("eye.slash", t("privacy.p1"))
                        bullet("mappin.slash", t("privacy.p2"))
                        bullet("bubble.left", t("privacy.p3"))
                        bullet("chart.bar.xaxis", t("privacy.p4"))
                    }
                    .padding(18)
                    .seeliCard(.seeliCard, border: false)

                    Text(t("privacy.blocked")).font(.system(size: 15, weight: .semibold)).padding(.top, 10)
                    if store.blocked.isEmpty {
                        Text(t("privacy.blocked.empty")).font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                    }
                    ForEach(store.blocked) { f in
                        HStack {
                            Avatar(initial: f.initial, size: 36)
                            Text(f.name).font(.system(size: 15))
                            Spacer()
                            Button(t("privacy.unblock")) { Task { await store.unblock(f.id) } }
                                .font(.system(size: 13)).foregroundStyle(Color.seeliGreen)
                        }
                        .padding(12).seeliCard()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.seeliGreen).frame(width: 22)
            Text(text).font(.system(size: 13)).foregroundStyle(Color.seeliInk)
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var serverURL = APIClient.shared.baseURLString

    var body: some View {
        @Bindable var store = store
        SeeliScreen(title: "SETTINGS", subtitle: t("profile.settings.sub"), leading: .back) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    group(t("settings.language")) {
                        ForEach(AppLanguage.allCases) { lang in
                            Button {
                                withAnimation { L10n.shared.setLanguage(lang) }
                            } label: {
                                HStack {
                                    Text(lang.displayName).foregroundStyle(Color.seeliInk)
                                    Spacer()
                                    if L10n.shared.language == lang {
                                        Image(systemName: "checkmark").foregroundStyle(Color.seeliGreen)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }

                    group(t("settings.appearance")) {
                        Picker("", selection: $store.appearance) {
                            Text(t("settings.appearance.system")).tag("system")
                            Text(t("settings.appearance.light")).tag("light")
                            Text(t("settings.appearance.dark")).tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }

                    group(t("settings.notifications")) {
                        Toggle(t("settings.notifications.reunion"), isOn: $store.notificationsEnabled)
                            .tint(.seeliGreen)
                            .onChange(of: store.notificationsEnabled) { _, on in
                                if !on { NotificationService.cancelAll() }
                                store.save()
                            }
                        Text(t("settings.notifications.hint")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                        Toggle(t("settings.notifications.friends"), isOn: Binding(
                            get: { store.friendPushEnabled },
                            set: { on in Task { await store.setFriendPush(on) } }))
                            .tint(.seeliGreen)
                            .padding(.top, 6)
                        Text(t("settings.notifications.friends.hint")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                    }

                    if store.serverAllowsDemo {
                    group(t("settings.demo")) {
                        Toggle(t("settings.demo.toggle"), isOn: $store.demoMode)
                            .tint(.seeliGreen)
                            .onChange(of: store.demoMode) { _, _ in store.save() }
                        Text(t("settings.demo.hint")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                    }
                    }

                    group(t("settings.server")) {
                        TextField(APIClient.defaultBaseURL, text: $serverURL)
                            .font(.system(size: 13, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .onSubmit { APIClient.shared.baseURLString = serverURL }
                        Text(t("settings.server.hint")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                    }

                    group(t("settings.legal")) {
                        let ja = L10n.shared.language == .ja ? "?lang=ja" : ""
                        Link(destination: URL(string: "https://seeli.cam/terms\(ja)")!) {
                            HStack { Text(t("settings.terms")); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 12)) }
                                .foregroundStyle(Color.seeliInk).padding(.vertical, 4)
                        }
                        Link(destination: URL(string: "https://seeli.cam/privacy\(ja)")!) {
                            HStack { Text(t("settings.privacyPolicy")); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 12)) }
                                .foregroundStyle(Color.seeliInk).padding(.vertical, 4)
                        }
                    }

                    group(t("settings.account")) {
                        if let a = store.account {
                            HStack {
                                Text(t("field.email")).foregroundStyle(Color.seeliMuted)
                                Spacer()
                                Text(a.email).foregroundStyle(Color.seeliInk)
                            }
                            .font(.system(size: 14))
                        }
                        Button(t("settings.logout")) { confirmLogout = true }
                            .foregroundStyle(Color.seeliInk)
                            .padding(.vertical, 6)
                        Button(t("settings.delete")) { confirmDelete = true }
                            .foregroundStyle(Color(hex: 0xB0574A))
                            .padding(.vertical, 6)
                        if let error = store.lastError {
                            Text(error).font(.system(size: 12)).foregroundStyle(Color(hex: 0xB0574A))
                        }
                    }

                    Text("SEELI \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                        .font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                        .frame(maxWidth: .infinity).padding(.top, 10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .task { await store.refresh() }
        .confirmationDialog(t("settings.logout.confirm"), isPresented: $confirmLogout, titleVisibility: .visible) {
            Button(t("settings.logout")) { Task { await store.logout() } }
            Button(t("common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(t("settings.delete.confirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(t("settings.delete"), role: .destructive) { Task { await store.deleteAccount() } }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t("settings.delete.body"))
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.seeliMuted)
            VStack(alignment: .leading, spacing: 8) { content() }
                .font(.system(size: 15))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .seeliCard()
        }
    }
}

struct VerifiedView: View {
    var body: some View {
        SeeliScreen(title: "VERIFIED", subtitle: t("profile.verified.sub"), leading: .back) {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "checkmark.seal").font(.system(size: 48, weight: .light)).foregroundStyle(Color.seeliGreen)
                Text(t("verified.title")).font(.system(size: 20, weight: .semibold))
                Text(t("verified.body")).font(.system(size: 14)).foregroundStyle(Color.seeliMuted)
                    .multilineTextAlignment(.center).lineSpacing(4)
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}

/// Friend requests: people who scanned my code (accept or decline) and ones I sent.
struct FriendRequestsView: View {
    @Environment(AppStore.self) private var store
    @State private var busy: String?

    var body: some View {
        SeeliScreen(title: "REQUESTS", subtitle: t("requests.subtitle"), leading: .back) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("requests.incoming")).font(.system(size: 15, weight: .semibold))
                    if store.friendRequests.incoming.isEmpty {
                        Text(t("requests.incoming.empty")).font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                    }
                    ForEach(store.friendRequests.incoming) { r in
                        HStack(spacing: 12) {
                            Avatar(initial: r.user.initial, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.user.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.seeliInk)
                                Text("@\(r.user.handle) · \(DateText.stamp(r.createdAt))").font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                            }
                            Spacer()
                            if busy == r.id {
                                ProgressView()
                            } else {
                                Button {
                                    busy = r.id
                                    Task { _ = await store.acceptRequest(r.user.id); busy = nil }
                                } label: {
                                    Text(t("requests.accept")).font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(Color.seeliGreen)).foregroundStyle(.white)
                                }
                                Button {
                                    busy = r.id
                                    Task { await store.dropRequest(r.user.id); busy = nil }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(Color.seeliCard)).foregroundStyle(Color.seeliInk)
                                }
                                .accessibilityLabel(t("requests.decline"))
                            }
                        }
                        .padding(14)
                        .seeliCard()
                    }

                    if !store.friendRequests.outgoing.isEmpty {
                        Text(t("requests.sent")).font(.system(size: 15, weight: .semibold)).padding(.top, 16)
                        ForEach(store.friendRequests.outgoing) { r in
                            HStack(spacing: 12) {
                                Avatar(initial: r.user.initial, size: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(r.user.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.seeliInk)
                                    Text(t("requests.waiting")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                                }
                                Spacer()
                                Button(t("requests.cancel")) { Task { await store.dropRequest(r.user.id) } }
                                    .font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
                            }
                            .padding(12)
                            .seeliCard()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .refreshable { await store.pullRefresh() }
        }
        .task { await store.refresh() }
    }
}
