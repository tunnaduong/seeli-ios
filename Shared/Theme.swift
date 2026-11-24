import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    static let seeliBG = Color(hex: 0xF6F5F0)
    static let seeliCard = Color(hex: 0xECEBE4)
    static let seeliSurface = Color(hex: 0xFFFFFE)
    static let seeliGreen = Color(hex: 0x5F6B4E)
    static let seeliGreenSoft = Color(hex: 0xA9B79C)
    static let seeliGreenPale = Color(hex: 0xC9D3BE)
    static let seeliInk = Color(hex: 0x2F302B)
    static let seeliMuted = Color(hex: 0x8B8C84)
    static let seeliLine = Color(hex: 0xE2E1DA)
    static let seeliSun = Color(hex: 0xF5D38A)
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
