import SwiftUI

struct ConnectView: View {
    @Environment(AppStore.self) private var store
    @State private var commenting: FriendPost?
    @State private var viewing: FriendPost?
    @State private var ownThread: Moment?
    @State private var showOlder = false
    @State private var showAllActivity = false
    /// When this screen was last opened before now: newer things get a dot.
    @State private var seenBefore: Date?

    /// Posts that were unopened at some point during this visit. They stay in "New" until the
    /// next visit: if a post jumped out of the section the moment it was seen, the next one would
    /// slide into its place on screen and be counted as seen too.
    @State private var keptNew: Set<String> = []

    private var lastSeen: Date { seenBefore ?? store.connectSeenAt }

    private func isNew(_ p: FriendPost) -> Bool { p.viewedAt == nil || keptNew.contains(p.id) }

    /// Not opened yet (or opened during this visit), newest first.
    private var newPosts: [FriendPost] {
        store.friendPosts.filter(isNew).sorted { $0.createdAt > $1.createdAt }
    }

    /// Already opened, but I took part in the conversation.
    private var activePosts: [FriendPost] {
        store.friendPosts.filter { !isNew($0) && $0.hasMyActivity }
            .sorted { ($0.lastActivityAt ?? $0.createdAt) > ($1.lastActivityAt ?? $1.createdAt) }
    }

    private var olderPosts: [FriendPost] {
        store.friendPosts.filter { !isNew($0) && !$0.hasMyActivity }.sorted { $0.createdAt > $1.createdAt }
    }

    private func keepUnopened() {
        keptNew.formUnion(store.friendPosts.filter { $0.viewedAt == nil }.map(\.id))
    }

    private var recentActivity: [ActivityItem] {
        store.activity.filter { $0.type != "friend_added" || $0.at > Date().addingTimeInterval(-7 * 86_400) }
            .sorted { $0.at > $1.at }
    }

    var body: some View {
        SeeliScreen(title: "LET'S CONNECT", subtitle: t("connect.subtitle")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Button { store.path.append(.scan) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "qrcode").font(.system(size: 22, weight: .light)).foregroundStyle(Color.seeliGreen)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t("connect.qr.title")).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.seeliInk)
                                    Text(t("connect.qr.body")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                                        .lineLimit(2).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .seeliCard(.seeliCard, radius: 16, border: false)
                        }
                    }

                    if !store.friendRequests.incoming.isEmpty {
                        Button { store.path.append(.requests) } label: {
                            HStack(spacing: 12) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "person.badge.plus").font(.system(size: 20)).foregroundStyle(Color.seeliGreen)
                                    CountBadge(count: store.friendRequests.incoming.count).offset(x: 10, y: -8)
                                }
                                .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t("requests.banner.title")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.seeliInk)
                                    Text(store.friendRequests.incoming.map(\.user.name).prefix(3).joined(separator: ", "))
                                        .font(.system(size: 12)).foregroundStyle(Color.seeliMuted).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                            }
                            .padding(14)
                            .seeliCard(radius: 16)
                        }
                        .padding(.top, 12)
                    }

                    if !recentActivity.isEmpty { activitySection.padding(.top, 24) }

                    if store.friendPosts.isEmpty {
                        SectionTitle(title: t("connect.feed.title"), subtitle: t("connect.feed.subtitle"))
                            .padding(.top, 28).padding(.bottom, 16)
                        VStack(spacing: 12) {
                            Image(systemName: "person.2").font(.system(size: 28, weight: .light)).foregroundStyle(Color.seeliMuted)
                            Text(t("connect.empty")).font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                        .seeliCard()
                    } else {
                        postSection(t("connect.section.new"), subtitle: newPosts.isEmpty ? t("connect.section.new.empty") : nil,
                                    posts: newPosts)
                            .padding(.top, 28)
                        if !activePosts.isEmpty {
                            postSection(t("connect.section.active"), subtitle: nil, posts: activePosts).padding(.top, 28)
                        }
                        if !olderPosts.isEmpty {
                            Button { withAnimation(.easeInOut) { showOlder.toggle() } } label: {
                                HStack {
                                    Text(showOlder ? t("connect.older.hide") : tf("connect.older.show", olderPosts.count))
                                    Spacer()
                                    Image(systemName: showOlder ? "chevron.up" : "chevron.down")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.seeliInk)
                                .padding(16)
                                .seeliCard(.seeliCard, radius: 16, border: false)
                            }
                            .padding(.top, 24)
                            if showOlder {
                                LazyVStack(spacing: 20) {
                                    ForEach(olderPosts) { post in card(post) }
                                }
                                .padding(.top, 16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .refreshable { await store.pullRefresh() }
        }
        .onChange(of: store.friendPosts) { _, _ in keepUnopened() }
        .task {
            keepUnopened()
            if seenBefore == nil {
                seenBefore = store.connectSeenAt
                store.markConnectSeen()
            }
            await store.refresh()
            openPendingThread()
        }
        .onChange(of: store.pendingThreadPost) { _, _ in openPendingThread() }
        // Friends' photos are seen once: leaving this screen lets them go.
        // (The full-screen viewer covers this screen too; that is not leaving it.)
        .onDisappear { if viewing == nil { store.forgetOncePhotos() } }
        .fullScreenCover(item: $viewing) { post in
            OncePhotoViewer(post: post)
        }
        .sheet(item: $commenting) { post in
            CommentThreadSheet(momentID: post.id, ownerID: post.author.id, ownerName: post.author.name, note: post.note)
                .presentationDetents([.large])
        }
        .sheet(item: $ownThread) { m in
            CommentThreadSheet(momentID: m.id, ownerID: store.account?.id ?? "", ownerName: store.account?.name ?? "", note: m.note)
                .presentationDetents([.large])
        }
    }

    private func openPendingThread() {
        guard let id = store.pendingThreadPost, let post = store.friendPosts.first(where: { $0.id == id }) else { return }
        store.pendingThreadPost = nil
        commenting = post
    }

    // MARK: Sections

    private func postSection(_ title: String, subtitle: String?, posts: [FriendPost]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: title, subtitle: subtitle)
            LazyVStack(spacing: 20) {
                ForEach(posts) { post in card(post) }
            }
        }
    }

    private func card(_ post: FriendPost) -> some View {
        FriendPostCard(post: post,
                       isNew: post.createdAt > lastSeen && post.viewedAt == nil,
                       onOpen: { viewing = post },
                       onComment: { commenting = post },
                       onProfile: {
                           if store.friend(post.author.id) != nil { store.path.append(.friend(post.author.id)) }
                       })
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("connect.activity")).font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.seeliInk)
                Spacer()
                if recentActivity.count > 4 {
                    Button(showAllActivity ? t("connect.activity.less") : t("connect.activity.all")) {
                        withAnimation { showAllActivity.toggle() }
                    }
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.seeliGreen)
                }
            }
            VStack(spacing: 0) {
                let items = showAllActivity ? Array(recentActivity.prefix(30)) : Array(recentActivity.prefix(4))
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    Button { open(item) } label: { activityRow(item) }
                    if i < items.count - 1 { Divider().overlay(Color.seeliLine).padding(.leading, 56) }
                }
            }
            .seeliCard(radius: 18)
        }
    }

    private func activityRow(_ item: ActivityItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(initial: item.user.initial, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(activityTitle(item)).font(.system(size: 13)).foregroundStyle(Color.seeliInk)
                    .multilineTextAlignment(.leading)
                if let text = item.text, !text.isEmpty {
                    Text("“\(text)”").font(.system(size: 12)).foregroundStyle(Color.seeliMuted).lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Text(DateText.stamp(item.at)).font(.system(size: 10)).foregroundStyle(Color.seeliMuted)
            }
            Spacer(minLength: 0)
            if item.at > lastSeen {
                Circle().fill(Color.seeliGreen).frame(width: 8, height: 8).padding(.top, 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func activityTitle(_ item: ActivityItem) -> String {
        switch item.type {
        case "comment": return item.pending == true ? tf("activity.comment.pending", item.user.name) : tf("activity.comment", item.user.name)
        case "comment_reply": return tf("activity.reply", item.user.name)
        case "friend_request": return tf("activity.request", item.user.name)
        case "friend_added": return tf("activity.friend", item.user.name)
        default: return item.user.name
        }
    }

    private func open(_ item: ActivityItem) {
        switch item.type {
        case "friend_request": store.path.append(.requests)
        case "friend_added": if store.friend(item.user.id) != nil { store.path.append(.friend(item.user.id)) }
        default:
            guard let id = item.momentId else { return }
            if let m = store.moments.first(where: { $0.id == id }) { ownThread = m }
            else if let p = store.friendPosts.first(where: { $0.id == id }) { commenting = p }
        }
    }
}

struct CountBadge: View {
    var count: Int
    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 5 : 0)
                .frame(minWidth: 18, minHeight: 18)
                .background(Capsule().fill(Color(hex: 0xC4553F)))
                .accessibilityLabel("\(count)")
        }
    }
}

struct FriendPostCard: View {
    var post: FriendPost
    var isNew = false
    var onOpen: () -> Void
    var onComment: () -> Void
    var onProfile: () -> Void

    private var ja: Bool { L10n.shared.language == .ja }

    var body: some View {
        VStack(spacing: 0) {
            OncePhotoTile(post: post, onOpen: onOpen)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topTrailing) {
                    if isNew { Chip(text: "NEW").padding(10) }
                }

            infoBox
                .padding(.top, 12)

            Divider().overlay(Color.seeliLine).padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 14) {
                if let mine = post.myComment {
                    // Tap the conversation to keep it going.
                    Button(action: onComment) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "text.bubble").foregroundStyle(Color.seeliGreen)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("connect.sent")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                                    Text(mine).font(.system(size: 14)).foregroundStyle(Color.seeliInk)
                                        .multilineTextAlignment(.leading).lineLimit(3)
                                }
                                Spacer(minLength: 0)
                            }
                            if let answer = post.myCommentReply {
                                HStack(alignment: .top, spacing: 10) {
                                    Avatar(initial: post.author.initial, size: 22)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tf("connect.reply.from", post.author.name)).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                                        Text(answer).font(.system(size: 14)).foregroundStyle(Color.seeliInk)
                                            .multilineTextAlignment(.leading).lineLimit(3)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .seeliCard(.seeliCard, radius: 14, border: false)
                                .padding(.leading, 30)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Label(t("connect.prompt"), systemImage: "bubble.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.seeliInk)
                }
                Button(action: onComment) {
                    Label((post.commentCount ?? 0) > 0 ? tf("connect.comments.open", post.commentCount ?? 0) : t("connect.send"),
                          systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(SoftButtonStyle())
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

/// A friend's photo shows right in the card — but only once the card is really on screen
/// (most of it, for a moment), so photos you scroll past or that are preloaded below the
/// fold are not counted as seen. It stays while you are on this screen; leave and it is gone.
private struct OncePhotoTile: View {
    @Environment(AppStore.self) private var store
    var post: FriendPost
    var onOpen: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var loading = false
    @State private var onScreen = false

    var body: some View {
        ZStack {
            Landscape(scene: post.scene)
            // Not active = the app switcher is about to snapshot the screen; show the landscape instead.
            if let image = store.onceImages[post.id], scenePhase == .active {
                GeometryReader { geo in
                    ScreenshotShield {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                }
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onOpen)
                    .overlay(alignment: .bottomLeading) {
                        Label(t("connect.once.now"), systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(.black.opacity(0.35)))
                            .padding(10)
                    }
                    .transition(.opacity)
            } else if loading {
                ProgressView().tint(.white)
            } else if let seen = post.viewedAt {
                Color.black.opacity(0.42)
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash").font(.system(size: 24, weight: .light))
                    Text(t("connect.once.seen")).font(.system(size: 14, weight: .medium))
                    Text(tf("connect.once.seen.at", DateText.stamp(seen))).font(.system(size: 11)).opacity(0.85)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { onScreen = Self.mostlyVisible(geo.frame(in: .global)) }
                    .onChange(of: geo.frame(in: .global)) { _, frame in
                        let v = Self.mostlyVisible(frame)
                        if v != onScreen { onScreen = v }
                    }
            }
        }
        .onDisappear { onScreen = false }
        .animation(.easeOut(duration: 0.35), value: store.onceImages[post.id] != nil)
        // Open once the photo has been in view for a moment; scrolling past cancels it.
        .task(id: onScreen && scenePhase == .active) {
            guard onScreen, scenePhase == .active, post.viewedAt == nil, store.onceImages[post.id] == nil else { return }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, onScreen, post.viewedAt == nil, store.onceImages[post.id] == nil else { return }
            loading = true
            await store.loadOncePhoto(postID: post.id)
            loading = false
        }
    }

    /// At least 60% of the tile is inside the screen.
    private static func mostlyVisible(_ frame: CGRect) -> Bool {
        guard frame.height > 0 else { return false }
        let screen = UIScreen.main.bounds
        let visible = frame.intersection(screen)
        return !visible.isNull && visible.height / frame.height >= 0.6
    }
}
