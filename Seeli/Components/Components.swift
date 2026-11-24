import SwiftUI

/// Page header used across screens: leading icon (home / back), English title, localized subtitle.
struct SeeliHeader: View {
    enum Leading { case home, back, none }
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var title: String
    var subtitle: String
    var leading: Leading = .home

    var body: some View {
        ZStack {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.seeliInk)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.seeliMuted)
            }
            HStack {
                switch leading {
                case .home:
                    Button { store.path = [] } label: {
                        Image(systemName: "house")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.seeliGreen)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(t("common.home"))
                case .back:
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.seeliInk)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(t("common.back"))
                case .none:
                    EmptyView()
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

/// Screen scaffold with the warm paper background and hidden nav bar.
struct SeeliScreen<Content: View>: View {
    var title: String
    var subtitle: String
    var leading: SeeliHeader.Leading = .home
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            SeeliHeader(title: title, subtitle: subtitle, leading: leading)
            content()
        }
        .background(Color.seeliBG.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct EyeLogo: View {
    var size: CGFloat = 36
    var closed = false
    var color: Color = .seeliInk

    var body: some View {
        Image(systemName: closed ? "eye.slash" : "eye")
            .font(.system(size: size, weight: .light))
            .foregroundStyle(color)
    }
}

struct Avatar: View {
    var initial: String
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(Color.seeliGreen)
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

struct Chip: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Color.seeliGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.85)))
    }
}

struct SectionTitle: View {
    var title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.seeliInk)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.seeliMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Row with a round icon, title, subtitle and chevron (profile / safety lists).
struct MenuRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var chevron = true
    var tint: Color = .seeliInk

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.seeliCard)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Color.seeliGreen))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(tint)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
            }
            Spacer()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.seeliMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .seeliCard()
        .contentShape(Rectangle())
    }
}

struct LabeledField: View {
    var label: String
    var placeholder: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.seeliMuted)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 16))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .seeliCard(radius: 14)
        }
    }
}

/// Small language switcher (used on auth screens).
struct LanguageSwitch: View {
    var body: some View {
        let current = L10n.shared.language
        HStack(spacing: 4) {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { L10n.shared.setLanguage(lang) }
                } label: {
                    Text(lang == .vi ? "VI" : "日本")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(current == lang ? .white : Color.seeliMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(current == lang ? Color.seeliGreen : Color.clear))
                }
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.seeliCard))
    }
}
