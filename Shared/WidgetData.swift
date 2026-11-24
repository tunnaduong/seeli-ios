import Foundation

/// Data the app shares with its widgets through the App Group container.
/// Only words, dates and counts are shared — never the photos themselves.
struct WidgetSnapshot: Codable {
    struct Word: Codable, Hashable {
        var note: String
        var date: Date
        var place: String?
    }

    var loggedIn = false
    /// `revealAt` of every photo that hasn't been reunited yet.
    var pendingReveals: [Date] = []
    /// Notes the user left, newest first.
    var words: [Word] = []

    func dueCount(at date: Date) -> Int { pendingReveals.filter { $0 <= date }.count }
    func sleepingCount(at date: Date) -> Int { pendingReveals.filter { $0 > date }.count }
}

enum SharedStore {
    static let appGroup = "group.com.tunnaduong.seeli"
    private static let snapshotKey = "seeli.widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func save(_ snapshot: WidgetSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: snapshotKey),
              let s = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return s
    }
}

/// Deep links used by widgets.
enum DeepLink {
    static let camera = URL(string: "seeli://camera")!
    static let memories = URL(string: "seeli://memories")!
    static let reunion = URL(string: "seeli://reunion")!
    static let home = URL(string: "seeli://home")!
}
