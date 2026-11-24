import SwiftUI

/// Soft hill illustration used as the visual for friends' moments
/// (the real photo is never shown in the feed right away).
struct Landscape: View {
    var scene: Int = 0

    private var palette: (sky: Color, sun: Color, hills: [Color]) {
        switch scene % 3 {
        case 1:
            return (Color(hex: 0xE9E4D8), Color(hex: 0xF2C48D),
                    [Color(hex: 0xB9C4B6), Color(hex: 0x8FA394), Color(hex: 0x6B7F72)])
        case 2:
            return (Color(hex: 0xDDE3E6), Color(hex: 0xEBDDB8),
                    [Color(hex: 0xA7B3B5), Color(hex: 0x86969A), Color(hex: 0x5F6E72)])
        default:
            return (Color(hex: 0xDCE4DA), .seeliSun,
                    [Color(hex: 0xA9B99E), Color(hex: 0x86997A), Color(hex: 0x5F6E52)])
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                palette.sky
                Circle()
                    .fill(palette.sun)
                    .frame(width: w * 0.2, height: w * 0.2)
                    .position(x: w * (scene % 2 == 0 ? 0.74 : 0.26), y: h * 0.27)
                Hill(peak: 0.42, phase: 0.55).fill(palette.hills[0])
                Hill(peak: 0.58, phase: 0.25).fill(palette.hills[1])
                Hill(peak: 0.76, phase: 0.8).fill(palette.hills[2])
                // Wind strokes
                Path { p in
                    p.move(to: CGPoint(x: w * 0.1, y: h * 0.7))
                    p.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.52), control: CGPoint(x: w * 0.13, y: h * 0.57))
                    p.move(to: CGPoint(x: w * 0.17, y: h * 0.72))
                    p.addQuadCurve(to: CGPoint(x: w * 0.27, y: h * 0.56), control: CGPoint(x: w * 0.2, y: h * 0.6))
                }
                .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                Tree()
                    .stroke(palette.hills[2].opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: w * 0.08, height: h * 0.2)
                    .position(x: w * 0.78, y: h * 0.63)
            }
        }
        .clipped()
    }
}

private struct Hill: Shape {
    var peak: CGFloat
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let base = rect.height * peak
        p.move(to: CGPoint(x: 0, y: base + rect.height * 0.08))
        p.addCurve(to: CGPoint(x: rect.width, y: base),
                   control1: CGPoint(x: rect.width * phase * 0.6, y: base - rect.height * 0.22),
                   control2: CGPoint(x: rect.width * (0.4 + phase * 0.5), y: base + rect.height * 0.2))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

private struct Tree: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.25))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        let center = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.3)
        let r = rect.width * 0.45
        p.move(to: CGPoint(x: center.x - r, y: center.y + r * 0.35))
        p.addQuadCurve(to: CGPoint(x: center.x + r, y: center.y + r * 0.35),
                       control: CGPoint(x: center.x, y: center.y - r * 1.6))
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.55))
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.72))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.72))
        return p
    }
}
