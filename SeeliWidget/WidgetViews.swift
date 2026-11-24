import WidgetKit
import SwiftUI

private struct PaperBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.containerBackground(for: .widget) { Color.seeliBG }
    }
}

private extension View {
    func paper() -> some View { modifier(PaperBackground()) }
}

private struct CameraButton: View {
    var size: CGFloat = 40
    var body: some View {
        Circle()
            .fill(Color.seeliGreen)
            .frame(width: size, height: size)
            .overlay(Image(systemName: "camera").font(.system(size: size * 0.38)).foregroundStyle(.white))
    }
}

private struct SignedOutView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye").font(.system(size: 22, weight: .light)).foregroundStyle(Color.seeliInk)
            Text("SEELI").font(.system(size: 16, weight: .bold)).tracking(1.5).foregroundStyle(Color.seeliInk)
            Text(t("widget.signedOut")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                .multilineTextAlignment(.center)
        }
        .widgetURL(DeepLink.home)
    }
}

// MARK: Today (home screen)

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SeeliEntry

    var body: some View {
        Group {
            if !entry.snapshot.loggedIn {
                SignedOutView()
            } else if family == .systemMedium {
                medium
            } else {
                small
            }
        }
        .paper()
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(DateText.header(entry.date))
                .font(.system(size: 10))
                .foregroundStyle(Color.seeliMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            if entry.due > 0 {
                Image(systemName: "sparkles").font(.system(size: 16)).foregroundStyle(Color.seeliGreen)
                Text(t("widget.reunion.title"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.seeliInk)
                    .padding(.top, 4)
            } else {
                Text(t("home.question"))
                    .font(SeeliFont.mincho(15))
                    .foregroundStyle(Color.seeliInk)
                    .lineSpacing(2)
            }
            Spacer(minLength: 6)
            HStack(alignment: .bottom) {
                if entry.due > 0 {
                    Text(t("widget.reunion.tap")).font(.system(size: 10)).foregroundStyle(Color.seeliMuted)
                } else {
                    CameraButton(size: 38)
                }
                Spacer()
                if entry.sleeping > 0 {
                    Label("\(entry.sleeping)", systemImage: "moon.zzz")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.seeliMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(entry.due > 0 ? DeepLink.reunion : DeepLink.camera)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            Link(destination: DeepLink.camera) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        Image(systemName: "eye").font(.system(size: 11))
                        Text("SEELI").font(.system(size: 12, weight: .bold)).tracking(1.2)
                    }
                    .foregroundStyle(Color.seeliInk)
                    Text(DateText.header(entry.date))
                        .font(.system(size: 10)).foregroundStyle(Color.seeliMuted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.top, 2)
                    Spacer(minLength: 6)
                    Text(t("home.question"))
                        .font(SeeliFont.mincho(15))
                        .foregroundStyle(Color.seeliInk)
                    Spacer(minLength: 6)
                    CameraButton(size: 38)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            Link(destination: entry.due > 0 ? DeepLink.reunion : DeepLink.memories) {
                VStack(alignment: .leading, spacing: 6) {
                    if entry.due > 0 {
                        Image(systemName: "sparkles").foregroundStyle(Color.seeliGreen)
                        Text(t("widget.reunion.title"))
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.seeliInk)
                        Text(entry.due > 1 ? tf("widget.reunion.count", entry.due) : t("widget.reunion.tap"))
                            .font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                    } else if entry.sleeping > 0 {
                        Image(systemName: "moon.zzz").foregroundStyle(Color.seeliGreen)
                        Text(tf("widget.sleeping", entry.sleeping))
                            .font(.system(size: 12)).foregroundStyle(Color.seeliInk)
                        Text(t("widget.sleeping.hint"))
                            .font(.system(size: 10)).foregroundStyle(Color.seeliMuted)
                    } else {
                        Image(systemName: "leaf").foregroundStyle(Color.seeliGreen)
                        Text(t("widget.calm"))
                            .font(.system(size: 12)).foregroundStyle(Color.seeliInk)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.seeliCard))
            }
        }
    }
}

// MARK: Words (home screen)

struct WordsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SeeliEntry

    var body: some View {
        Group {
            if !entry.snapshot.loggedIn {
                SignedOutView()
            } else if let word = entry.word {
                content(word)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("widget.wordsOfDay")).font(.system(size: 10)).foregroundStyle(Color.seeliMuted)
                    Spacer()
                    Text(t("widget.words.empty"))
                        .font(SeeliFont.mincho(13)).foregroundStyle(Color.seeliInk)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .widgetURL(DeepLink.camera)
            }
        }
        .paper()
    }

    @ViewBuilder
    private func content(_ word: WidgetSnapshot.Word) -> some View {
        let vertical = word.note.isMostlyCJK
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("widget.wordsOfDay")).font(.system(size: 10)).foregroundStyle(Color.seeliMuted)
                if !vertical {
                    Spacer(minLength: 4)
                    Text(word.note)
                        .font(.system(size: family == .systemSmall ? 14 : 16, design: .serif))
                        .italic()
                        .foregroundStyle(Color.seeliInk)
                        .lineLimit(family == .systemSmall ? 5 : 4)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                if family == .systemMedium || !vertical {
                    Text(stampLine(word))
                        .font(.system(size: 9)).foregroundStyle(Color.seeliMuted)
                        .lineLimit(2)
                }
            }
            if vertical {
                Spacer(minLength: 0)
                VerticalText(text: word.note,
                             size: family == .systemSmall ? 13 : 15,
                             perColumn: family == .systemSmall ? 8 : 8)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(DeepLink.memories)
    }

    private func stampLine(_ word: WidgetSnapshot.Word) -> String {
        [DateText.long(word.date), word.place].compactMap { $0 }.joined(separator: " · ")
    }
}

// MARK: Lock screen

struct LockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SeeliEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(entry.due > 0 ? DeepLink.reunion : DeepLink.camera)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: entry.due > 0 ? "sparkles" : "eye")
                        .font(.system(size: 16, weight: .medium))
                        .widgetAccentable()
                    if entry.due > 0 {
                        Text("\(entry.due)").font(.system(size: 12, weight: .semibold))
                    } else if entry.sleeping > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "moon.zzz").font(.system(size: 8))
                            Text("\(entry.sleeping)").font(.system(size: 11, weight: .medium))
                        }
                    }
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: entry.due > 0 ? "sparkles" : "eye")
                    Text("SEELI").font(.system(size: 13, weight: .bold)).tracking(1)
                }
                .widgetAccentable()
                if !entry.snapshot.loggedIn {
                    Text(t("widget.signedOut")).font(.system(size: 13)).lineLimit(2)
                } else if entry.due > 0 {
                    Text(t("widget.reunion.title")).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                } else {
                    Text(t("widget.inline")).font(.system(size: 13)).lineLimit(1)
                    if entry.sleeping > 0 {
                        Text(tf("widget.sleeping", entry.sleeping)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            if entry.due > 0 {
                Label(t("widget.reunion.title"), systemImage: "sparkles")
            } else {
                Label(t("widget.inline"), systemImage: "eye")
            }
        }
    }
}
