import SwiftUI
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case vi, ja

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vi: return "Tiếng Việt"
        case .ja: return "日本語"
        }
    }

    var locale: Locale {
        switch self {
        case .vi: return Locale(identifier: "vi_VN")
        case .ja: return Locale(identifier: "ja_JP")
        }
    }
}

/// In-app language manager. Views that call `t(_:)` inside `body` automatically
/// re-render when the language changes, because `language` is observable.
@Observable
final class L10n {
    static let shared = L10n()
    private static let key = "seeli.language"

    private(set) var language: AppLanguage
    @ObservationIgnored private var bundles: [AppLanguage: Bundle] = [:]

    private init() {
        // Stored in the App Group so the widgets speak the same language as the app.
        if let raw = SharedStore.defaults.string(forKey: Self.key) ?? UserDefaults.standard.string(forKey: Self.key),
           let lang = AppLanguage(rawValue: raw) {
            language = lang
        } else {
            let preferred = Locale.preferredLanguages.first ?? ""
            language = preferred.hasPrefix("ja") ? .ja : .vi
        }
    }

    func setLanguage(_ lang: AppLanguage) {
        language = lang
        SharedStore.defaults.set(lang.rawValue, forKey: Self.key)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Widgets live in another process: re-read the language the app saved.
    func syncFromSharedStore() {
        if let raw = SharedStore.defaults.string(forKey: Self.key),
           let lang = AppLanguage(rawValue: raw), lang != language {
            language = lang
        }
    }

    func string(_ key: String) -> String {
        bundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    private func bundle(for lang: AppLanguage) -> Bundle {
        if let cached = bundles[lang] { return cached }
        if let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            bundles[lang] = bundle
            return bundle
        }
        return .main
    }
}

/// Translate a key into the current app language.
func t(_ key: String) -> String {
    L10n.shared.string(key)
}

/// Translate a key with format arguments.
func tf(_ key: String, _ args: CVarArg...) -> String {
    String(format: L10n.shared.string(key), locale: L10n.shared.language.locale, arguments: args)
}
