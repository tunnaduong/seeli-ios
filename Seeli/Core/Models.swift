import Foundation

enum Audience: String, Codable, CaseIterable, Identifiable {
    case onlyMe, closeFriends, selected, circle, everyone
    var id: String { rawValue }

    /// Unknown values (from a newer server) read as circle rather than failing the whole list.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Audience(rawValue: raw) ?? .circle
    }

    var badge: String {
        switch self {
        case .onlyMe: return "ONLY ME"
        case .closeFriends: return "CLOSE FRIENDS"
        case .selected: return "CHOSEN"
        case .circle: return "MY CIRCLE"
        case .everyone: return "PUBLIC"
        }
    }

    var descriptionKey: String {
        switch self {
        case .onlyMe: return "audience.onlyMe.desc"
        case .closeFriends: return "audience.close.desc"
        case .selected: return "audience.selected.desc"
        case .circle: return "audience.circle.desc"
        case .everyone: return "audience.public.desc"
        }
    }

    var icon: String {
        switch self {
        case .onlyMe: return "lock"
        case .closeFriends: return "star"
        case .selected: return "person.crop.circle.badge.checkmark"
        case .circle: return "person.2"
        case .everyone: return "globe"
        }
    }
}

/// Who a moment is shared with (newer servers); `audience` alone is only onlyMe / circle.
struct ShareInfo: Codable, Hashable {
    var audience: Audience
    var recipientIds: [String]
}

struct PublicUser: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var handle: String

    var initial: String { String(name.prefix(1)).uppercased() }
}

struct Comment: Identifiable, Codable, Hashable {
    var id: String
    var text: String
    var createdAt: Date
    var author: PublicUser
    /// The photo owner's answer, seen only by this friend.
    var reply: String?
    var repliedAt: Date?
}

extension Comment {
    struct Reply: Codable, Hashable {
        var reply: String
        var repliedAt: Date
    }
}

/// One comment in a moment's shared thread (GET comments?v=2).
struct ThreadComment: Identifiable, Codable, Hashable {
    enum Visibility: String, Codable { case owner, circle }
    enum Status: String, Codable { case pending, approved, rejected }

    var id: String
    var parentId: String?
    var text: String
    var createdAt: Date
    var editedAt: Date?
    var author: PublicUser
    var visibility: Visibility
    var status: Status
    var mine: Bool

    var isPending: Bool { visibility == .circle && status == .pending }
}

struct CommentThread: Decodable {
    var isOwner: Bool
    var comments: [ThreadComment]
}

/// Something that happened that concerns me (GET activity?v=2).
struct ActivityItem: Identifiable, Codable, Hashable {
    var type: String
    var momentId: String?
    var at: Date
    var user: PublicUser
    var commentId: String?
    var text: String?
    var pending: Bool?

    var id: String { "\(type)-\(commentId ?? momentId ?? "")-\(user.id)-\(at.timeIntervalSince1970)" }
}

struct FriendRequest: Identifiable, Codable, Hashable {
    var user: PublicUser
    var createdAt: Date
    var id: String { user.id }
}

struct FriendRequests: Codable, Hashable {
    var incoming: [FriendRequest] = []
    var outgoing: [FriendRequest] = []
}

/// A photo the user took. The server only sends `photoUrl` once `revealAt` has passed.
struct Moment: Identifiable, Codable, Hashable {
    var id: String
    var note: String
    var placeName: String?
    var audience: Audience
    var createdAt: Date
    var revealAt: Date
    var reunitedAt: Date?
    var reflection: String?
    var commentCount: Int = 0
    var photoUrl: String?
    /// Waiting in the outbox (taken offline / upload failed).
    var isPending: Bool? = nil
    var share: ShareInfo? = nil
    /// Comments meant for the circle that wait for my approval.
    var pendingCount: Int? = nil
    var lastCommentAt: Date? = nil

    var isRevealed: Bool { reunitedAt != nil }
    var sharedWith: Audience { share?.audience ?? audience }
}

struct Friend: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var handle: String
    var bio: String
    var memo: String
    var connectedAt: Date
    var close: Bool? = false

    var isClose: Bool { close ?? false }
    var initial: String { String(name.prefix(1)).uppercased() }
}

/// A moment shared by a friend into "My Circle". Never includes the place.
struct FriendPost: Identifiable, Codable, Hashable {
    var id: String
    var author: PublicUser
    var note: String
    var createdAt: Date
    var revealed: Bool
    var photoUrl: String?
    var myComment: String?
    /// The author's answer to my perspective.
    var myCommentReply: String?
    var myCommentRepliedAt: Date?
    var scene: Int
    /// When I opened this photo. A friend's photo can be opened only once.
    var viewedAt: Date?
    /// Comments I can see, mine, and answers to mine.
    var commentCount: Int? = nil
    var myCommentCount: Int? = nil
    var repliesToMe: Int? = nil
    /// Last time something concerning me happened here (my comments, answers to them).
    var lastActivityAt: Date? = nil

    var hasMyActivity: Bool { (myCommentCount ?? 0) > 0 || (repliesToMe ?? 0) > 0 || myComment != nil }
}

struct UserAccount: Codable, Hashable {
    var id: String
    var name: String
    var handle: String
    var email: String
    var bio: String
    var inviteCode: String
    var hasPassword: Bool? = true
    var providers: [String]? = []

    var initial: String { String(name.prefix(1)).uppercased() }
}

/// What's being created between the camera and the audience screen.
struct Draft {
    var imageData: Data?
    var capturedAt = Date()
    var note = ""
    var recordPlace = true
    var placeName: String?
    var audience: Audience = .onlyMe
    var recipients: [String] = []
}

/// A photo waiting to be uploaded (kept on disk until the server has it).
struct PendingUpload: Codable, Hashable, Identifiable {
    var id: String
    var note: String
    var placeName: String?
    var audience: Audience
    var createdAt: Date
    var demo: Bool
    var recipients: [String]? = nil
}

enum Route: Hashable {
    case camera, post, audience, posted
    case connect, memories
    case profile, friends, friend(String), privacy, settings, verified, requests
    case scan, myQR
    case reunion(String), moment(String)
}

/// QR payload: seeli://add?c=<invite code>&n=<name>. The code is secret and
/// rotatable, so only people who actually met (and scanned it) can connect.
struct FriendInvite: Identifiable, Hashable {
    var id: String { code }
    var code: String
    var name: String

    var url: String {
        var c = URLComponents()
        c.scheme = "seeli"
        c.host = "add"
        c.queryItems = [URLQueryItem(name: "c", value: code), URLQueryItem(name: "n", value: name)]
        return c.string ?? "seeli://add?c=\(code)"
    }

    init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let c = URLComponents(string: trimmed), c.scheme == "seeli", c.host == "add",
           let code = c.queryItems?.first(where: { $0.name == "c" })?.value, !code.isEmpty {
            self.code = code.uppercased()
            name = c.queryItems?.first(where: { $0.name == "n" })?.value ?? ""
            return
        }
        // Manual entry of the 8-character code shown under the QR.
        let code = trimmed.uppercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        guard code.count == 8, code.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        self.code = code
        name = ""
    }
}
