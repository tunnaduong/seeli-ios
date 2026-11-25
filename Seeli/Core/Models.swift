import Foundation

enum Audience: String, Codable, CaseIterable, Identifiable {
    case onlyMe, circle, everyone
    var id: String { rawValue }

    var badge: String {
        switch self {
        case .onlyMe: return "ONLY ME"
        case .circle: return "MY CIRCLE"
        case .everyone: return "PUBLIC"
        }
    }

    var descriptionKey: String {
        switch self {
        case .onlyMe: return "audience.onlyMe.desc"
        case .circle: return "audience.circle.desc"
        case .everyone: return "audience.public.desc"
        }
    }
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

    var isRevealed: Bool { reunitedAt != nil }
}

struct Friend: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var handle: String
    var bio: String
    var memo: String
    var connectedAt: Date

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
    var scene: Int
    /// When I opened this photo. A friend's photo can be opened only once.
    var viewedAt: Date?
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
}

/// A photo waiting to be uploaded (kept on disk until the server has it).
struct PendingUpload: Codable, Hashable, Identifiable {
    var id: String
    var note: String
    var placeName: String?
    var audience: Audience
    var createdAt: Date
    var demo: Bool
}

enum Route: Hashable {
    case camera, post, audience, posted
    case connect, memories
    case profile, friends, friend(String), privacy, settings, verified
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
