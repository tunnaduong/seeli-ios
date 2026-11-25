import SwiftUI

struct ConnectView: View {
    @Environment(AppStore.self) private var store
    @State private var commenting: FriendPost?

    var body: some View {
        SeeliScreen(title: "LET'S CONNECT", subtitle: t("connect.subtitle")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button { store.path.append(.scan) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "qrcode").font(.system(size: 26, weight: .light)).foregroundStyle(Color.seeliGreen)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(t("connect.qr.title")).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.seeliInk)
                                Text(t("connect.qr.body")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .seeliCard(.seeliCard, radius: 16, border: false)
                    }

                    SectionTitle(title: t("connect.feed.title"), subtitle: t("connect.feed.subtitle"))
                        .padding(.top, 28)
                        .padding(.bottom, 16)

                    if store.visiblePosts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2").font(.system(size: 28, weight: .light)).foregroundStyle(Color.seeliMuted)
                            Text(t("connect.empty")).font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                        .seeliCard()
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(store.visiblePosts) { post in
                                FriendPostCard(post: post,
                                               onComment: { commenting = post },
                                               onProfile: {
                                                   if store.friend(post.author.id) != nil { store.path.append(.friend(post.author.id)) }
                                               })
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .refreshable { await store.refresh() }
        }
        .task { await store.refresh() }
        .sheet(item: $commenting) { post in
            PerspectiveSheet(post: post)
                .presentationDetents([.medium])
        }
    }
}

struct FriendPostCard: View {
    var post: FriendPost
    var onComment: () -> Void
    var onProfile: () -> Void

    private var ja: Bool { L10n.shared.language == .ja }

    var body: some View {
        VStack(spacing: 0) {
            OncePhotoTile(post: post)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topTrailing) { Chip(text: "MY CIRCLE").padding(10) }

            infoBox
                .padding(.top, 12)

            Divider().overlay(Color.seeliLine).padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 14) {
                if let mine = post.myComment {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "text.bubble").foregroundStyle(Color.seeliGreen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("connect.sent")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                            Text(mine).font(.system(size: 14)).foregroundStyle(Color.seeliInk)
                        }
                    }
                } else {
                    Label(t("connect.prompt"), systemImage: "bubble.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.seeliInk)
                }
                Button(post.myComment == nil ? t("connect.send") : t("connect.edit"), action: onComment)
                    .buttonStyle(SoftButtonStyle())
                Text(t("connect.privacy"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.seeliMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .seeliCard(radius: 26)
    }

    @ViewBuilder
    private var infoBox: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: onProfile) {
                    HStack(spacing: 8) {
                        Avatar(initial: post.author.initial, size: 30)
                        Text(post.author.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.seeliInk)
                    }
                }
                Text("@\(post.author.handle)").font(.system(size: 10)).foregroundStyle(Color.seeliMuted)
            }
            Spacer(minLength: 0)
            VStack(alignment: ja ? .center : .leading, spacing: 8) {
                Text("MEMORY NOTE").font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(Color.seeliMuted)
                NoteText(text: post.note, size: 15, perColumn: 7)
                if !ja {
                    Text(DateText.stamp(post.createdAt)).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                }
            }
            .frame(maxWidth: ja ? nil : 170, alignment: .leading)
            if ja {
                MetaText(text: DateText.stamp(post.createdAt), size: 11, perColumn: 30)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: ja ? 200 : nil, alignment: .topLeading)
        .seeliCard(.seeliCard, radius: 18, border: false)
    }
}

private struct PerspectiveSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var post: FriendPost
    @State private var text = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("connect.prompt")).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.seeliInk)
            Text(post.note).font(SeeliFont.mincho(14)).foregroundStyle(Color.seeliMuted)
            TextField(t("connect.comment.placeholder"), text: $text, axis: .vertical)
                .lineLimit(3...6)
                .padding(14)
                .seeliCard(radius: 14)
            Text(t("connect.privacy")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
            Spacer()
            if let error = store.lastError {
                Text(error).font(.system(size: 12)).foregroundStyle(Color(hex: 0xB0574A))
            }
            Button {
                busy = true
                Task {
                    if await store.sendPerspective(postID: post.id, text: text) { dismiss() }
                    busy = false
                }
            } label: {
                if busy { ProgressView().tint(.white) } else { Text(t("connect.send")) }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: !text.trimmingCharacters(in: .whitespaces).isEmpty))
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || busy)
        }
        .padding(24)
        .background(Color.seeliBG.ignoresSafeArea())
        .onAppear { text = post.myComment ?? "" }
    }
}

/// A friend's photo: closed until tapped, then gone for good once seen.
private struct OncePhotoTile: View {
    @Environment(AppStore.self) private var store
    var post: FriendPost
    @State private var confirming = false
    @State private var opening = false
    @State private var photoURL: URL?

    var body: some View {
        Button { confirming = true } label: {
            ZStack {
                Landscape(scene: post.scene)
                Color.seeliInk.opacity(post.viewedAt == nil ? 0.28 : 0.45)
                VStack(spacing: 8) {
                    if opening {
                        ProgressView().tint(.white)
                    } else if let seen = post.viewedAt {
                        Image(systemName: "eye.slash").font(.system(size: 24, weight: .light))
                        Text(t("connect.once.seen")).font(.system(size: 14, weight: .medium))
                        Text(tf("connect.once.seen.at", DateText.stamp(seen))).font(.system(size: 11)).opacity(0.85)
                    } else {
                        Image(systemName: "eye").font(.system(size: 24, weight: .light))
                        Text(t("connect.once.tap")).font(.system(size: 15, weight: .semibold))
                        Text(t("connect.once.hint")).font(.system(size: 11)).opacity(0.9)
                    }
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            }
        }
        .buttonStyle(.plain)
        .disabled(post.viewedAt != nil || opening)
        .alert(t("connect.once.confirm.title"), isPresented: $confirming) {
            Button(t("common.cancel.later"), role: .cancel) {}
            Button(t("connect.once.confirm.ok")) { open() }
        } message: {
            Text(t("connect.once.confirm.body"))
        }
        .fullScreenCover(item: $photoURL) { url in
            OncePhotoViewer(url: url, note: post.note)
        }
    }

    private func open() {
        opening = true
        Task {
            photoURL = await store.openOncePhoto(postID: post.id)
            opening = false
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Full-screen, one-time view. Nothing is cached; it hides when the app leaves the foreground.
private struct OncePhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var url: URL
    var note: String
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image, scenePhase == .active {
                Image(uiImage: image).resizable().scaledToFit()
            } else if failed {
                Text(t("error.generic")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            } else if image == nil {
                ProgressView().tint(.white)
            }
            VStack(spacing: 14) {
                Spacer()
                if !note.isEmpty {
                    Text(note).font(SeeliFont.mincho(15)).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                Text(t("connect.once.viewer")).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button(t("connect.once.close")) { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().stroke(.white.opacity(0.6)))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .statusBarHidden()
        .task { await load() }
    }

    private func load() async {
        // Ephemeral session: the photo is never written to the URL cache or disk.
        let session = URLSession(configuration: .ephemeral)
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        for _ in 0..<3 {
            if let (data, resp) = try? await session.data(for: req),
               (resp as? HTTPURLResponse)?.statusCode == 200, let img = UIImage(data: data) {
                image = img
                return
            }
            try? await Task.sleep(for: .seconds(1))
        }
        failed = true
    }
}
