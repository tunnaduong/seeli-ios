import WidgetKit
import SwiftUI

// MARK: - Timeline

struct SeeliEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    var wordIndex = 0

    var due: Int { snapshot.dueCount(at: date) }
    var sleeping: Int { snapshot.sleepingCount(at: date) }
    var word: WidgetSnapshot.Word? {
        snapshot.words.isEmpty ? nil : snapshot.words[wordIndex % snapshot.words.count]
    }

    static var sample: SeeliEntry {
        let ja = L10n.shared.language == .ja
        var s = WidgetSnapshot()
        s.loggedIn = true
        s.pendingReveals = [Date().addingTimeInterval(86_400 * 12), Date().addingTimeInterval(86_400 * 20)]
        s.words = [.init(note: ja ? "帰り道、雲の切れ間から光が差していた。" : "Trên đường về, ánh nắng xuyên qua khe mây.",
                         date: Date().addingTimeInterval(-86_400 * 6),
                         place: ja ? "神奈川県横浜市" : "Đà Lạt")]
        return SeeliEntry(date: Date(), snapshot: s)
    }
}

/// Status timeline: flips exactly when a sleeping photo becomes due, and at midnight for the date.
struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> SeeliEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (SeeliEntry) -> Void) {
        L10n.shared.syncFromSharedStore()
        let snap = SharedStore.load()
        completion(context.isPreview && !snap.loggedIn ? .sample : SeeliEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SeeliEntry>) -> Void) {
        L10n.shared.syncFromSharedStore()
        let snap = SharedStore.load()
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        var dates = [now, midnight]
        dates += snap.pendingReveals.filter { $0 > now && $0 < midnight.addingTimeInterval(86_400) }
        let entries = Set(dates).sorted().map { SeeliEntry(date: $0, snapshot: snap) }
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

/// Words timeline: a different note every three hours.
struct WordsProvider: TimelineProvider {
    func placeholder(in context: Context) -> SeeliEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (SeeliEntry) -> Void) {
        L10n.shared.syncFromSharedStore()
        let snap = SharedStore.load()
        completion(context.isPreview && snap.words.isEmpty ? .sample : SeeliEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SeeliEntry>) -> Void) {
        L10n.shared.syncFromSharedStore()
        let snap = SharedStore.load()
        let now = Date()
        let slot = Int(now.timeIntervalSince1970 / 10_800)
        let entries = (0..<8).map { i in
            SeeliEntry(date: now.addingTimeInterval(Double(i) * 10_800), snapshot: snap, wordIndex: slot + i)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widgets

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SeeliToday", provider: StatusProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName(t("widget.today.name"))
        .description(t("widget.today.desc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WordsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SeeliWords", provider: WordsProvider()) { entry in
            WordsWidgetView(entry: entry)
        }
        .configurationDisplayName(t("widget.words.name"))
        .description(t("widget.words.desc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SeeliLock", provider: StatusProvider()) { entry in
            LockWidgetView(entry: entry)
        }
        .configurationDisplayName("SEELI")
        .description(t("widget.lock.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct SeeliWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        WordsWidget()
        LockWidget()
    }
}
