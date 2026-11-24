import SwiftUI

/// Japanese vertical writing (tategaki): columns flow top→bottom, right→left.
struct VerticalText: View {
    var text: String
    var size: CGFloat = 16
    var perColumn: Int = 8
    var font: Font? = nil
    var color: Color = .seeliInk
    var columnSpacing: CGFloat? = nil

    private static let rotated: Set<Character> = ["ー", "―", "—", "…", "〜", "~", "-", "（", "）", "(", ")", "「", "」", "『", "』", "【", "】", "：", ":", "・"]
    private static let smallPunct: Set<Character> = ["、", "。", "，", "．", ",", "."]
    private static let smallKana: Set<Character> = ["ゃ", "ゅ", "ょ", "っ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ャ", "ュ", "ョ", "ッ", "ァ", "ィ", "ゥ", "ェ", "ォ"]

    private var columns: [[Character]] {
        var result: [[Character]] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let chars = Array(line.filter { $0 != " " && $0 != "　" })
            if chars.isEmpty { result.append([]); continue }
            var i = 0
            while i < chars.count {
                var end = min(i + max(1, perColumn), chars.count)
                // Kinsoku: keep punctuation from starting a column.
                if end < chars.count, Self.smallPunct.contains(chars[end]) { end += 1 }
                result.append(Array(chars[i..<end]))
                i = end
            }
        }
        return result
    }

    var body: some View {
        HStack(alignment: .top, spacing: columnSpacing ?? size * 0.7) {
            ForEach(Array(columns.enumerated().reversed()), id: \.offset) { _, column in
                VStack(spacing: size * 0.12) {
                    ForEach(Array(column.enumerated()), id: \.offset) { _, ch in
                        glyph(ch)
                    }
                }
                .frame(width: size * 1.1, alignment: .top)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    @ViewBuilder
    private func glyph(_ ch: Character) -> some View {
        let base = Text(String(ch))
            .font(font ?? SeeliFont.mincho(size))
            .foregroundStyle(color)
            .frame(width: size * 1.1, height: size * 1.1)
        if Self.rotated.contains(ch) {
            base.rotationEffect(.degrees(90))
        } else if Self.smallPunct.contains(ch) {
            base.offset(x: size * 0.35, y: -size * 0.35)
        } else if Self.smallKana.contains(ch) {
            base.offset(x: size * 0.1, y: -size * 0.1)
        } else {
            base
        }
    }
}

/// Renders a note vertically when it's Japanese, otherwise as a quiet serif paragraph.
struct NoteText: View {
    var text: String
    var size: CGFloat = 16
    var perColumn: Int = 8
    var alignment: TextAlignment = .leading

    var body: some View {
        if text.isMostlyCJK {
            VerticalText(text: text, size: size, perColumn: perColumn)
        } else {
            Text(text)
                .font(.system(size: size + 1, design: .serif))
                .italic()
                .lineSpacing(5)
                .multilineTextAlignment(alignment)
                .foregroundStyle(Color.seeliInk)
        }
    }
}

/// Small metadata (date, place) — vertical in Japanese, horizontal in Vietnamese.
struct MetaText: View {
    var text: String
    var size: CGFloat = 11
    var perColumn: Int = 40

    var body: some View {
        if L10n.shared.language == .ja && text.isMostlyCJK {
            VerticalText(text: text, size: size, perColumn: perColumn, font: .system(size: size), color: .seeliMuted)
        } else {
            Text(text)
                .font(.system(size: size + 1))
                .foregroundStyle(Color.seeliMuted)
        }
    }
}
