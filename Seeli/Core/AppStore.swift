import Foundation
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
    var blocked: [PublicUser] = []
    var outbox: [PendingUpload] = []

    // Preferences
    var defaultAudience: Audience = .onlyMe
    var demoMode = false
    /// Whether the server allows demo mode (ALLOW_DEMO). Hidden in Settings when false.
    var serverAllowsDemo = false
    var notificationsEnabled = true

    // Session (not persisted)
    @ObservationIgnored var draft = Draft()
    @ObservationIgnored private let api = APIClient.shared
    var path: [Route] = []
    var now = Date()
    var pendingInvite: FriendInvite?
    var isSyncing = false
    /// True right after sign-up, so the "account created" screen shows before entering.
    var welcomePending = false
    var lastError: String?
    /// Bumped on login/logout so views depending on `isLoggedIn` re-render.
    private var authGeneration = 0

    private struct Health: Decodable { var allowDemo: Bool? }

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
    }

    func save() {
        let s = Snapshot(account: account, moments: moments, friends: friends, friendPosts: friendPosts,
                         blocked: blocked, outbox: outbox, defaultAudience: defaultAudience,
                         demoMode: demoMode, notificationsEnabled: notificationsEnabled)
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

    private struct AuthResponse: Decodable { var token: String; var user: UserAccount }

    func signUp(name: String, handle: String, email: String, password: String) async throws {
        let res = try await api.request("POST", "auth/signup", body: [
            "name": name, "handle": handle, "email": email, "password": password,
        ], as: AuthResponse.self)
        welcomePending = true
        startSession(res)
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
        clearOutbox()
        path = []
        authGeneration += 1
        try? FileManager.default.removeItem(at: fileURL)
        updateWidgets()
    }

    func deleteAccount() async -> Bool {
        guard await attempt({ try await api.request("DELETE", "me") }) != nil else { return false }
        clearSession()
        return true
    }

    func updateProfile(name: String, bio: String) async -> Bool {
        guard let user = await attempt({
            try await api.request("PATCH", "me", body: ["name": name, "bio": bio], as: UserAccount.self)
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
        let (me, ms, fs, feed, bl, health) = await (meReq, momentsReq, friendsReq, feedReq, blocksReq, healthReq)
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
        refreshClock()
        save()
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
    }

    /// Save to the outbox first (so nothing is lost offline), then upload.
    func commitDraft() {
        guard let data = draft.imageData else { return }
        let p = PendingUpload(id: "local-\(UUID().uuidString)",
                              note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
                              placeName: draft.recordPlace ? draft.placeName : nil,
                              audience: draft.audience,
                              createdAt: draft.capturedAt,
                              demo: demoMode && serverAllowsDemo)
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
            guard let moment = try? await api.uploadMoment(p, jpeg: jpeg) else { break } // offline: try later
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

    func comments(for id: String) async -> [Comment] {
        await attempt({ try await api.request("GET", "moments/\(id)/comments", as: [Comment].self) }) ?? []
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
    }

    func friend(_ id: String) -> Friend? { friends.first { $0.id == id } }

    var visiblePosts: [FriendPost] { friendPosts.sorted { $0.createdAt > $1.createdAt } }

    func preview(_ invite: FriendInvite) async throws -> InvitePreview {
        try await api.request("GET", "invites/\(invite.code)", as: InvitePreview.self)
    }

    func addFriend(_ invite: FriendInvite) async -> Friend? {
        guard let f = await attempt({
            try await api.request("POST", "friends", body: ["code": invite.code], as: Friend.self)
        }) else { return nil }
        friends.removeAll { $0.id == f.id }
        friends.insert(f, at: 0)
        save()
        Task { await refresh() }
        return f
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
