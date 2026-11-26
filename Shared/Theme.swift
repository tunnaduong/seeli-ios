import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// A colour that follows light / dark mode.
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }

    // Warm paper by day, warm night by night.
    static let seeliBG = dynamic(0xF6F5F0, 0x161713)
    static let seeliCard = dynamic(0xECEBE4, 0x2A2C25)
    static let seeliSurface = dynamic(0xFFFFFE, 0x1F211C)
    static let seeliGreen = dynamic(0x5F6B4E, 0x7D8D65)
    static let seeliGreenSoft = dynamic(0xA9B79C, 0x4A5440)
    static let seeliGreenPale = dynamic(0xC9D3BE, 0x3B4433)
    static let seeliInk = dynamic(0x2F302B, 0xECEAE2)
    static let seeliMuted = dynamic(0x8B8C84, 0x9C9D94)
    static let seeliLine = dynamic(0xE2E1DA, 0x33352E)
    static let seeliSun = dynamic(0xF5D38A, 0xE0C07A)
    static let seeliNight = Color(hex: 0x1F211D)
}

enum SeeliFont {
    /// Mincho / serif font used for "words" — memory notes, vertical text.
    static func mincho(_ size: CGFloat) -> Font {
        if UIFont(name: "HiraMinProN-W3", size: size) != nil {
            return .custom("HiraMinProN-W3", size: size)
        }
        return .system(size: size, design: .serif)
    }

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
}

struct CardBackground: ViewModifier {
    var color: Color = .seeliSurface
    var radius: CGFloat = 20
    var border: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.seeliLine, lineWidth: border ? 1 : 0)
            )
    }
}

extension View {
    func seeliCard(_ color: Color = .seeliSurface, radius: CGFloat = 20, border: Bool = true) -> some View {
        modifier(CardBackground(color: color, radius: radius, border: border))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled ? Color.seeliGreen : Color.seeliGreenSoft)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.seeliGreen)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.seeliCard)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
