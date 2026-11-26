import Foundation
import UserNotifications
import Observation
import SwiftUI
import WidgetKit

/// App state. The server (seeli-api) is the source of truth; this keeps a local
/// cache so the app opens instantly and works offline, plus an outbox for photos.
@Observable
final class AppStore {
    // Auth
    var account: UserAccount?
    var isLoggedIn: Bool {
        _ = authGeneration // observable dependency; the token itself lives in the Keychain
        return account != nil && api.token != nil
    }

    // Content
    var moments: [Moment] = []
    var friends: [Friend] = []
    var friendPosts: [FriendPost] = []
    /// Friends' photos opened in this visit to Let's connect. Memory only, never saved.
    var onceImages: [String: UIImage] = [:]
    var blocked: [PublicUser] = []
    var outbox: [PendingUpload] = []
    /// Comments on my photos, answers to my comments, friend requests (last 30 days).
    var activity: [ActivityItem] = []
    var friendRequests = FriendRequests()
    /// When Let's connect was last opened; newer posts and activity count toward the badge.
    var connectSeenAt: Date = .distantPast

    // Preferences
    var defaultAudience: Audience = .onlyMe
    var demoMode = false
    /// Whether the server allows demo mode (ALLOW_DEMO). Hidden in Settings when false.
    var serverAllowsDemo = false
    var notificationsEnabled = true
    /// Push when a friend shares to the circle.
    var friendPushEnabled = true
    @ObservationIgnored private var deviceToken: String?

    // Session (not persisted)
    @ObservationIgnored var draft = Draft()
    @ObservationIgnored private let api = APIClient.shared
    var path: [Route] = []
    var now = Date()
    var pendingInvite: FriendInvite?
    /// A moment whose comments should open (tapped a "new perspective" notification).
    var pendingCommentsMoment: String?
    /// A friend's post whose comments should open in Let's connect.
    var pendingThreadPost: String?
    var isSyncing = false
    /// True right after sign-up, so the "account created" screen shows before entering.
    var welcomePending = false
    var lastError: String?
    /// Bumped on login/logout so views depending on `isLoggedIn` re-render.
    private var authGeneration = 0

    private struct Health: Decodable { var allowDemo: Bool? }
    private struct ActivityResponse: Decodable { var items: [ActivityItem] }

    private struct Snapshot: Codable {
        var account: UserAccount?
        var moments: [Moment]
        var friends: [Friend]
        var friendPosts: [FriendPost]
        var blocked: [PublicUser]
        var outbox: [PendingUpload]
        var defaultAudience: Audience
        var demoMode: Bool
        var notificationsEnabled: Bool
        var friendPushEnabled: Bool?
        var activity: [ActivityItem]?
        var friendRequests: FriendRequests?
        var connectSeenAt: Date?
    }

    private static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var fileURL: URL { Self.documents.appendingPathComponent("seeli-cache.json") }
    private static var outboxDir: URL {
        let dir = documents.appendingPathComponent("outbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() {
        load()
        updateWidgets()
        NotificationCenter.default.addObserver(forName: .seeliUnauthorized, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.account != nil else { return }
            self.clearSession()
        }
        NotificationCenter.default.addObserver(forName: .seeliDeviceToken, object: nil, queue: .main) { [weak self] note in
            guard let self, let token = note.object as? String else { return }
            self.deviceToken = token
            Task { await self.sendDeviceToken() }
        }
        NotificationCenter.default.addObserver(forName: .seeliOpenConnect, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.isLoggedIn else { return }
            self.path = [.connect]
        }
        NotificationCenter.default.addObserver(forName: .seeliOpenFriend, object: nil, queue: .main) { [weak self] note in
            guard let self, self.isLoggedIn else { return }
            let id = note.object as? String
            Task {
                // The new friend may not be in the local list yet.
                await self.refresh()
                if let id, self.friend(id) != nil { self.path = [.profile, .friends, .friend(id)] } else { self.path = [.profile, .friends] }
            }
        }
        NotificationCenter.default.addObserver(forName: .seeliOpenComments, object: nil, queue: .main) { [weak self] note in
            guard let self, self.isLoggedIn else { return }
            self.openComments(momentID: note.object as? String)
            Task { await self.refresh() }
        }
        NotificationCenter.default.addObserver(forName: .seeliOpenRequests, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.isLoggedIn else { return }
            self.path = [.connect, .requests]
            Task { await self.refresh() }
        }
    }

    // MARK: Push (friend shared a moment)

    /// Asks for permission once there is someone to hear from, then registers with APNs.
    func enableFriendPush() async {
        guard isLoggedIn, friendPushEnabled else { return }
        if friends.isEmpty {
            // No one to hear from yet: don't ask, but if notifications are already allowed,
            // register so "X added you" can still arrive.
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }
        } else {
            guard await NotificationService.requestPermission() else { return }
        }
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
    }

    private func sendDeviceToken() async {
        guard isLoggedIn, friendPushEnabled, let deviceToken else { return }
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        let lang = L10n.shared.language == .ja ? "ja" : "vi"
        try? await api.request("PUT", "me/device", body: ["token": deviceToken, "env": env, "lang": lang])
    }

    func setFriendPush(_ on: Bool) async {
        friendPushEnabled = on
        save()
        if on { await enableFriendPush() }
        else if let deviceToken { try? await api.request("DELETE", "me/device", body: ["token": deviceToken]) }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        account = s.account
        moments = s.moments
        friends = s.friends
        friendPosts = s.friendPosts
        blocked = s.blocked
        outbox = s.outbox
        defaultAudience = s.defaultAudience
        demoMode = s.demoMode
        notificationsEnabled = s.notificationsEnabled
        friendPushEnabled = s.friendPushEnabled ?? true
        activity = s.activity ?? []
        friendRequests = s.friendRequests ?? FriendRequests()
        connectSeenAt = s.connectSeenAt ?? .distantPast
    }

    func save() {
        let s = Snapshot(account: account, moments: moments, friends: friends, friendPosts: friendPosts,
                         blocked: blocked, outbox: outbox, defaultAudience: defaultAudience,
                         demoMode: demoMode, notificationsEnabled: notificationsEnabled,
                         friendPushEnabled: friendPushEnabled, activity: activity,
                         friendRequests: friendRequests, connectSeenAt: connectSeenAt)
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        }
        updateWidgets()
    }

    /// Push words, dates and counts (never photos) to the widgets.
    func updateWidgets() {
        var snap = WidgetSnapshot()
        snap.loggedIn = isLoggedIn
        if snap.loggedIn {
            snap.pendingReveals = allMoments.filter { $0.reunitedAt == nil }.map(\.revealAt)
            snap.words = allMoments
                .filter { !$0.note.isEmpty }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(30)
                .map { WidgetSnapshot.Word(note: $0.note, date: $0.createdAt, place: $0.placeName) }
        }
        SharedStore.save(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Errors

    /// Runs an API call, turning failures into a user-facing message.
    @discardableResult
    func attempt<T>(_ work: () async throws -> T) async -> T? {
        do {
            let value = try await work()
            lastError = nil
            return value
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? t("error.generic")
            return nil
        }
    }

    // MARK: Auth

    private struct AuthResponse: Decodable { var token: String; var user: UserAccount; var isNew: Bool? }

    func signUp(name: String, handle: String, email: String, password: String) async throws {
        let res = try await api.request("POST", "auth/signup", body: [
            "name": name, "handle": handle, "email": email, "password": password,
        ], as: AuthResponse.self)
        welcomePending = true
        startSession(res)
    }

    /// Sign in with Apple / Google. Returns true when a new SEELI account was created.
    @discardableResult
    func signIn(with c: SocialCredential) async throws -> Bool {
        var body: [String: Any] = ["idToken": c.idToken, "nonce": c.nonce]
        if let name = c.name { body["name"] = name }
        if let code = c.authorizationCode { body["authorizationCode"] = code }
        let res = try await api.request("POST", "auth/\(c.provider)", body: body, as: AuthResponse.self)
        let isNew = res.isNew ?? false
        welcomePending = isNew
        startSession(res)
        if !isNew { await refresh() }
        return isNew
    }

    func login(email: String, password: String) async throws {
        let res = try await api.request("POST", "auth/login", body: ["email": email, "password": password],
                                        as: AuthResponse.self)
        startSession(res)
        await refresh()
    }

    private func startSession(_ res: AuthResponse) {
        api.token = res.token
        // A different person on this phone: drop the previous cache.
        if account?.id != res.user.id {
            moments = []; friends = []; friendPosts = []; blocked = []; outbox = []
            activity = []; friendRequests = FriendRequests(); connectSeenAt = .distantPast
        }
        account = res.user
        path = []
        authGeneration += 1
        save()
    }

    func logout() async {
        try? await api.request("POST", "auth/logout")
        clearSession()
    }

    private func clearSession() {
        api.token = nil
        NotificationService.cancelAll()
        account = nil
        moments = []; friends = []; friendPosts = []; blocked = []
        activity = []; friendRequests = FriendRequests(); connectSeenAt = .distantPast
        clearOutbox()
        path = []
        authGeneration += 1
        try? FileManager.default.removeItem(at: fileURL)
        updateWidgets()
    }

    /// Deletes the account. If it is linked to Apple and the server holds no Apple token yet,
    /// the user confirms with Apple once so the server can revoke SEELI's access.
    func deleteAccount() async -> Bool {
        do {
            try await api.request("DELETE", "me")
        } catch let error as APIError where error.code == "apple_reauth_required" {
            do {
                let credential = try await AppleSignIn().start()
                guard let code = credential.authorizationCode else { lastError = t("error.generic"); return false }
                guard await attempt({ try await api.request("DELETE", "me", body: ["appleAuthorizationCode": code]) }) != nil else { return false }
            } catch SocialAuthError.cancelled {
                return false
            } catch {
                lastError = (error as? LocalizedError)?.errorDescription ?? t("error.generic")
                return false
            }
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? t("error.generic")
            return false
        }
        clearSession()
        return true
    }

    func updateProfile(name: String, bio: String, handle: String? = nil) async -> Bool {
        var body: [String: Any] = ["name": name, "bio": bio]
        if let handle { body["handle"] = handle }
        guard let user = await attempt({
            try await api.request("PATCH", "me", body: body, as: UserAccount.self)
        }) else { return false }
        account = user
        save()
        return true
    }

    func rotateInviteCode() async {
        if let user = await attempt({ try await api.request("POST", "me/invite/rotate", as: UserAccount.self) }) {
            account = user
            save()
        }
    }

    var myInvite: FriendInvite {
        FriendInvite(code: account?.inviteCode ?? "", name: account?.name ?? "")
    }

    // MARK: Sync

    /// Pull everything from the server and flush the outbox.
    func refresh() async {
        guard isLoggedIn, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        await flushOutbox()
        async let meReq = try? api.request("GET", "me", as: UserAccount.self)
        async let momentsReq = try? api.request("GET", "moments", as: [Moment].self)
        async let friendsReq = try? api.request("GET", "friends", as: [Friend].self)
        async let feedReq = try? api.request("GET", "feed", as: [FriendPost].self)
        async let blocksReq = try? api.request("GET", "blocks", as: [PublicUser].self)
        async let healthReq = try? api.request("GET", "health", as: Health.self)
        let since = Int(Date().addingTimeInterval(-30 * 86_400).timeIntervalSince1970 * 1000)
        async let activityReq = try? api.request("GET", "activity?v=2&since=\(since)", as: ActivityResponse.self)
        async let requestsReq = try? api.request("GET", "friend-requests", as: FriendRequests.self)
        let (me, ms, fs, feed, bl, health) = await (meReq, momentsReq, friendsReq, feedReq, blocksReq, healthReq)
        let (act, reqs) = await (activityReq, requestsReq)
        if let health {
            serverAllowsDemo = health.allowDemo ?? false
            if !serverAllowsDemo { demoMode = false }
        }
        guard isLoggedIn else { return }
        if let me { account = me }
        if let ms { moments = ms; rescheduleNotifications() }
        if let fs { friends = fs }
        if let feed { friendPosts = feed }
        if let bl { blocked = bl }
        if let act { activity = act.items }
        if let reqs { friendRequests = reqs }
        refreshClock()
        save()
        await enableFriendPush()
    }

    /// Pull-to-refresh. Waits for a sync already in flight, then fetches again, in a task
    /// the gesture can't cancel (a cancelled refresh used to drop every request).
    func pullRefresh() async {
        await Task { @MainActor in
            while isSyncing { try? await Task.sleep(for: .milliseconds(150)) }
            await refresh()
        }.value
    }

    private func rescheduleNotifications() {
        guard notificationsEnabled else { return }
        for m in moments where m.reunitedAt == nil && m.revealAt > Date() {
            NotificationService.scheduleReunion(id: m.id, at: m.revealAt)
        }
    }

    // MARK: Moments

    /// Server moments plus photos still waiting in the outbox.
    var allMoments: [Moment] {
        let pending = outbox.map { p in
            Moment(id: p.id, note: p.note, placeName: p.placeName, audience: p.audience, createdAt: p.createdAt,
                   revealAt: p.createdAt.addingTimeInterval(30 * 86_400), isPending: true)
        }
        return (pending + moments).sorted { $0.createdAt > $1.createdAt }
    }

    func startDraft(imageData: Data?) {
        draft = Draft()
        draft.imageData = imageData
        draft.capturedAt = Date()
        draft.audience = defaultAudience
        if draft.audience == .closeFriends && !friends.contains(where: \.isClose) { draft.audience = .circle }
    }

    /// Save to the outbox first (so nothing is lost offline), then upload.
    func commitDraft() {
        guard let data = draft.imageData else { return }
        let p = PendingUpload(id: "local-\(UUID().uuidString)",
                              note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
                              placeName: draft.recordPlace ? draft.placeName : nil,
                              audience: draft.audience,
                              createdAt: draft.capturedAt,
                              demo: demoMode && serverAllowsDemo,
                              recipients: draft.audience == .selected ? draft.recipients : nil)
        try? PhotoPrep.jpeg(data).write(to: Self.outboxDir.appendingPathComponent("\(p.id).jpg"), options: .atomic)
        outbox.append(p)
        draft = Draft()
        save()
        Task { await flushOutbox() }
        if notificationsEnabled {
            Task {
                // Ask once; reunions already uploaded get scheduled on the next refresh.
                if await NotificationService.requestPermission() { rescheduleNotifications() }
            }
        }
    }

    private var flushing = false

    func flushOutbox() async {
        guard isLoggedIn, !flushing else { return }
        flushing = true
        defer { flushing = false }
        for p in outbox {
            let file = Self.outboxDir.appendingPathComponent("\(p.id).jpg")
            guard let jpeg = try? Data(contentsOf: file) else {
                outbox.removeAll { $0.id == p.id }
                continue
            }
            let moment: Moment
            do {
                moment = try await api.uploadMoment(p, jpeg: jpeg)
            } catch let e as APIError where e.code == "recipients_required" {
                // The chosen people are no longer friends: keep the photo private instead of retrying forever.
                if let i = outbox.firstIndex(where: { $0.id == p.id }) {
                    outbox[i].audience = .onlyMe
                    outbox[i].recipients = nil
                }
                save()
                continue
            } catch {
                break // offline: try later
            }
            try? FileManager.default.removeItem(at: file)
            outbox.removeAll { $0.id == p.id }
            moments.insert(moment, at: 0)
            if notificationsEnabled { NotificationService.scheduleReunion(id: moment.id, at: moment.revealAt) }
            save()
        }
    }

    private func clearOutbox() {
        outbox = []
        try? FileManager.default.removeItem(at: Self.outboxDir)
    }

    var dueMoments: [Moment] {
        moments.filter { $0.reunitedAt == nil && $0.revealAt <= now }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var sleepingCount: Int {
        allMoments.filter { $0.reunitedAt == nil && $0.revealAt > now }.count
    }

    func moment(_ id: String) -> Moment? { allMoments.first { $0.id == id } }

    private func replace(_ m: Moment) {
        if let i = moments.firstIndex(where: { $0.id == m.id }) { moments[i] = m }
        save()
    }

    /// Marks the reunion on the server and returns the fresh moment (with a new photo URL).
    func reunite(_ id: String) async -> Moment? {
        guard let m = await attempt({ try await api.request("POST", "moments/\(id)/reunite", as: Moment.self) }) else {
            return nil
        }
        replace(m)
        return m
    }

    func saveReflection(_ id: String, text: String) async -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let m = await attempt({
            try await api.request("PATCH", "moments/\(id)", body: ["reflection": clean], as: Moment.self)
        }) else { return false }
        replace(m)
        return true
    }

    func deleteMoment(_ id: String) async {
        if id.hasPrefix("local-") {
            try? FileManager.default.removeItem(at: Self.outboxDir.appendingPathComponent("\(id).jpg"))
            outbox.removeAll { $0.id == id }
            save()
            return
        }
        guard await attempt({ try await api.request("DELETE", "moments/\(id)") }) != nil else { return }
        NotificationService.cancel(id)
        moments.removeAll { $0.id == id }
        save()
    }

    /// The owner answers a friend's perspective on their photo.
    func replyToComment(momentID: String, commentID: String, text: String) async -> Comment.Reply? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        return await attempt({
            try await api.request("PUT", "moments/\(momentID)/comments/\(commentID)/reply", body: ["text": clean], as: Comment.Reply.self)
        })
    }

    func comments(for id: String) async -> [Comment] {
        await attempt({ try await api.request("GET", "moments/\(id)/comments", as: [Comment].self) }) ?? []
    }

    // MARK: Comment threads

    func thread(for momentID: String) async -> CommentThread? {
        await attempt({ try await api.request("GET", "moments/\(momentID)/comments?v=2", as: CommentThread.self) })
    }

    func postComment(momentID: String, text: String, parentID: String?, visibility: ThreadComment.Visibility) async -> ThreadComment? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        var body: [String: Any] = ["text": clean, "visibility": visibility.rawValue]
        if let parentID { body["parentId"] = parentID }
        let c = await attempt({ try await api.request("POST", "moments/\(momentID)/comments", body: body, as: ThreadComment.self) })
        if c != nil { bumpCounts(momentID: momentID, delta: 1, text: parentID == nil ? clean : nil) }
        return c
    }

    func editComment(momentID: String, commentID: String, text: String) async -> ThreadComment? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        return await attempt({
            try await api.request("PATCH", "moments/\(momentID)/comments/\(commentID)", body: ["text": clean], as: ThreadComment.self)
        })
    }

    func deleteComment(momentID: String, commentID: String) async -> Bool {
        let ok = await attempt({ try await api.request("DELETE", "moments/\(momentID)/comments/\(commentID)") }) != nil
        if ok { Task { await refresh() } }
        return ok
    }

    func approveComment(momentID: String, commentID: String, approve: Bool) async -> Bool {
        let ok = await attempt({
            try await api.request("POST", "moments/\(momentID)/comments/\(commentID)/approve", body: ["approve": approve])
        }) != nil
        if ok, let i = moments.firstIndex(where: { $0.id == momentID }), let n = moments[i].pendingCount, n > 0 {
            moments[i].pendingCount = n - 1
            save()
        }
        return ok
    }

    /// Keeps the cards' counters right until the next refresh.
    private func bumpCounts(momentID: String, delta: Int, text: String?) {
        if let i = friendPosts.firstIndex(where: { $0.id == momentID }) {
            friendPosts[i].commentCount = (friendPosts[i].commentCount ?? 0) + delta
            friendPosts[i].myCommentCount = (friendPosts[i].myCommentCount ?? 0) + delta
            friendPosts[i].lastActivityAt = Date()
            if let text { friendPosts[i].myComment = text }
        }
        save()
    }

    /// Opens a moment's comments: my own photo in Memories, a friend's in Let's connect.
    func openComments(momentID: String?) {
        guard let momentID else { path = [.connect]; return }
        if moments.contains(where: { $0.id == momentID }) {
            pendingCommentsMoment = momentID
            path = [.memories]
        } else {
            pendingThreadPost = momentID
            path = [.connect]
        }
    }

    // MARK: Let's connect badge

    /// New friend posts plus activity since Let's connect was last opened.
    var connectBadge: Int {
        let posts = friendPosts.filter { $0.createdAt > connectSeenAt && $0.viewedAt == nil }.count
        // Friend requests are counted from the pending list instead (they stay until answered).
        let news = activity.filter { $0.at > connectSeenAt && $0.type != "friend_request" }.count
        return posts + news
    }

    func markConnectSeen() {
        connectSeenAt = Date()
        save()
    }

    func refreshClock() { now = Date() }

    func handle(_ url: URL) {
        guard url.scheme == "seeli" else { return }
        switch url.host {
        case "camera": path = [.camera]
        case "memories": path = [.memories]
        case "reunion":
            refreshClock()
            if let due = dueMoments.first { path = [.reunion(due.id)] } else { path = [] }
        case "home": path = []
        default:
            if let invite = FriendInvite(string: url.absoluteString) { pendingInvite = invite }
        }
    }

    // MARK: Friends

    struct InvitePreview: Decodable {
        var user: PublicUser
        var isSelf: Bool
        var isFriend: Bool
        var requested: Bool?
        var requestedMe: Bool?
    }

    enum AddResult { case requested, friends(Friend) }
    private struct AddResponse: Decodable { var status: String; var friend: Friend? }

    func friend(_ id: String) -> Friend? { friends.first { $0.id == id } }

    var visiblePosts: [FriendPost] { friendPosts.sorted { $0.createdAt > $1.createdAt } }

    func preview(_ invite: FriendInvite) async throws -> InvitePreview {
        try await api.request("GET", "invites/\(invite.code)", as: InvitePreview.self)
    }

    /// Sends a friend request (or connects right away if they had already asked).
    func addFriend(_ invite: FriendInvite) async -> AddResult? {
        guard let r = await attempt({
            try await api.request("POST", "friends", body: ["code": invite.code, "request": true], as: AddResponse.self)
        }) else { return nil }
        Task { await refresh() }
        if let f = r.friend, r.status == "friends" {
            friends.removeAll { $0.id == f.id }
            friends.insert(f, at: 0)
            save()
            return .friends(f)
        }
        return .requested
    }

    func acceptRequest(_ userID: String) async -> Bool {
        guard let f = await attempt({ try await api.request("POST", "friend-requests/\(userID)/accept", as: Friend.self) }) else {
            return false
        }
        friendRequests.incoming.removeAll { $0.user.id == userID }
        friends.removeAll { $0.id == f.id }
        friends.insert(f, at: 0)
        save()
        Task { await refresh() }
        return true
    }

    /// Declines an incoming request or cancels one I sent.
    func dropRequest(_ userID: String) async {
        guard await attempt({ try await api.request("DELETE", "friend-requests/\(userID)") }) != nil else { return }
        friendRequests.incoming.removeAll { $0.user.id == userID }
        friendRequests.outgoing.removeAll { $0.user.id == userID }
        save()
    }

    func setClose(_ id: String, _ close: Bool) async {
        guard let i = friends.firstIndex(where: { $0.id == id }) else { return }
        friends[i].close = close
        save()
        if let f = await attempt({ try await api.request("PATCH", "friends/\(id)", body: ["close": close], as: Friend.self) }),
           let j = friends.firstIndex(where: { $0.id == id }) {
            friends[j] = f
            save()
        }
    }

    func updateMemo(_ id: String, memo: String) async {
        guard let i = friends.firstIndex(where: { $0.id == id }) else { return }
        friends[i].memo = memo
        save()
        await attempt({ try await api.request("PATCH", "friends/\(id)", body: ["memo": memo], as: Friend.self) })
    }

    func removeFriend(_ id: String) async {
        guard await attempt({ try await api.request("DELETE", "friends/\(id)") }) != nil else { return }
        friends.removeAll { $0.id == id }
        friendPosts.removeAll { $0.author.id == id }
        save()
    }

    func block(_ id: String) async {
        guard await attempt({ try await api.request("POST", "friends/\(id)/block") }) != nil else { return }
        if let f = friend(id) { blocked.append(PublicUser(id: f.id, name: f.name, handle: f.handle)) }
        friends.removeAll { $0.id == id }
        friendPosts.removeAll { $0.author.id == id }
        save()
    }

    func unblock(_ id: String) async {
        guard await attempt({ try await api.request("DELETE", "blocks/\(id)") }) != nil else { return }
        blocked.removeAll { $0.id == id }
        save()
    }

    func report(_ id: String) async -> Bool {
        await attempt({ try await api.request("POST", "reports", body: ["userId": id, "reason": "user_report"]) }) != nil
    }

    private struct ViewResponse: Decodable { var photoUrl: String; var viewedAt: Date }

    /// Opens a friend's photo. The server records the view, so it works only once.
    func openOncePhoto(postID: String) async -> URL? {
        do {
            let r = try await api.request("POST", "moments/\(postID)/view", as: ViewResponse.self)
            lastError = nil
            markViewed(postID, at: r.viewedAt)
            return URL(string: r.photoUrl)
        } catch let e as APIError where e.code == "already_viewed" {
            markViewed(postID, at: Date())
            lastError = e.errorDescription
            return nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? t("error.generic")
            return nil
        }
    }

    /// Fetches a friend's photo once, straight into memory (no URL cache, no disk).
    func loadOncePhoto(postID: String) async {
        guard let url = await openOncePhoto(postID: postID) else { return }
        let session = URLSession(configuration: .ephemeral)
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        for attempt in 0..<3 {
            if let (data, resp) = try? await session.data(for: req),
               (resp as? HTTPURLResponse)?.statusCode == 200, let img = UIImage(data: data) {
                onceImages[postID] = img
                return
            }
            if attempt < 2 { try? await Task.sleep(for: .seconds(1)) }
        }
    }

    func forgetOncePhotos() { onceImages.removeAll() }

    private func markViewed(_ postID: String, at date: Date) {
        guard let i = friendPosts.firstIndex(where: { $0.id == postID }), friendPosts[i].viewedAt == nil else { return }
        friendPosts[i].viewedAt = date
        save()
    }

    /// (Older single-comment flow, still used by widgets/tests.)
    func sendPerspective(postID: String, text: String) async -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              await attempt({ try await api.request("PUT", "moments/\(postID)/comment", body: ["text": clean]) }) != nil
        else { return false }
        if let i = friendPosts.firstIndex(where: { $0.id == postID }) { friendPosts[i].myComment = clean }
        save()
        return true
    }
}
