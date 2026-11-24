import Foundation

/// Date formatting with a Japanese "newspaper" flavour (kanji numerals, wareki)
/// and natural Vietnamese formats.
enum DateText {
    private static let kanjiDigits = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// 0...99 → kanji (e.g. 42 → 四十二, 18 → 十八)
    static func kanji(_ n: Int) -> String {
        guard n >= 0 else { return "\(n)" }
        if n < 10 { return kanjiDigits[n] }
        if n < 100 {
            let tens = n / 10, ones = n % 10
            let tensPart = tens == 1 ? "十" : kanjiDigits[tens] + "十"
            return tensPart + (ones == 0 ? "" : kanjiDigits[ones])
        }
        return String(n).map { kanjiDigits[Int(String($0)) ?? 0] }.joined()
    }

    private static var lang: AppLanguage { L10n.shared.language }

    /// Header date on the home screen. ja: 令和八年十一月十八日 / vi: Thứ Ba, 24 tháng 11, 2026
    static func header(_ date: Date) -> String {
        switch lang {
        case .ja:
            var cal = Calendar(identifier: .japanese)
            cal.locale = Locale(identifier: "ja_JP")
            let era = DateFormatter()
            era.calendar = cal
            era.locale = Locale(identifier: "ja_JP")
            era.dateFormat = "GGGG"
            let c = cal.dateComponents([.year, .month, .day], from: date)
            let year = c.year ?? 1
            let yearText = year == 1 ? "元" : kanji(year)
            return "\(era.string(from: date))\(yearText)年\(kanji(c.month ?? 1))月\(kanji(c.day ?? 1))日"
        case .vi:
            let f = DateFormatter()
            f.locale = lang.locale
            f.dateFormat = "EEEE, d 'tháng' M, yyyy"
            return f.string(from: date).capitalizedFirst
        }
    }

    /// Stamp used beside notes. ja: 十一月十八日 午後四時四十二分 / vi: 18 tháng 11 · 16:42
    static func stamp(_ date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.month, .day, .hour, .minute], from: date)
        switch lang {
        case .ja:
            let hour = c.hour ?? 0
            let ampm = hour < 12 ? "午前" : "午後"
            let h12 = hour % 12
            let minute = c.minute ?? 0
            let minuteText = minute == 0 ? "" : "\(kanji(minute))分"
            return "\(kanji(c.month ?? 1))月\(kanji(c.day ?? 1))日 \(ampm)\(kanji(h12))時\(minuteText)"
        case .vi:
            return String(format: "%d tháng %d · %02d:%02d", c.day ?? 1, c.month ?? 1, c.hour ?? 0, c.minute ?? 0)
        }
    }

    /// Long date for reunion screen.
    static func long(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = lang.locale
        switch lang {
        case .ja: f.dateFormat = "yyyy年M月d日"
        case .vi: f.dateFormat = "d 'tháng' M, yyyy"
        }
        return f.string(from: date)
    }

    static func monthTitle(year: Int, month: Int) -> String {
        switch lang {
        case .ja: return "\(year)年 \(month)月"
        case .vi: return "Tháng \(month), \(year)"
        }
    }

    static func daysAgo(_ date: Date, now: Date = Date()) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }

    /// True when the text is mostly CJK — used to decide vertical (tategaki) layout.
    var isMostlyCJK: Bool {
        let letters = unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) && !CharacterSet.punctuationCharacters.contains($0) }
        guard !letters.isEmpty else { return false }
        let cjk = letters.filter { s in
            (0x3040...0x30FF).contains(s.value) || // kana
            (0x4E00...0x9FFF).contains(s.value) || // kanji
            (0x3400...0x4DBF).contains(s.value) ||
            (0xFF66...0xFF9F).contains(s.value)
        }
        return Double(cjk.count) / Double(letters.count) > 0.5
    }
}
