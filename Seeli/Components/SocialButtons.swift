import SwiftUI

/// "Continue with Apple / Google" buttons shared by the login and sign-up screens.
struct SocialButtons: View {
    @Environment(AppStore.self) private var store
    /// Called with `true` when a brand-new SEELI account was created.
    var onSignedIn: (Bool) -> Void
    @Binding var error: String?
    @State private var busy: String?
    @State private var apple = AppleSignIn()
    @State private var google = GoogleSignIn()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Rectangle().fill(Color.seeliLine).frame(height: 1)
                Text(t("auth.or")).font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
                Rectangle().fill(Color.seeliLine).frame(height: 1)
            }
            .padding(.vertical, 6)

            Button { run("apple") { try await apple.start() } } label: {
                label(t("auth.apple"), loading: busy == "apple") {
                    Image(systemName: "apple.logo").font(.system(size: 18, weight: .medium))
                }
                // Apple's button is black on light backgrounds and white on dark ones.
                .foregroundStyle(Color.dynamic(0xFFFFFF, 0x000000))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.dynamic(0x000000, 0xFFFFFF)))
            }
            .accessibilityLabel(t("auth.apple"))

            if GoogleSignIn.isConfigured {
                Button { run("google") { try await google.start() } } label: {
                    label(t("auth.google"), loading: busy == "google") { GoogleMark().frame(width: 18, height: 18) }
                        .foregroundStyle(Color.seeliInk)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.seeliSurface))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.seeliLine, lineWidth: 1))
                }
                .accessibilityLabel(t("auth.google"))
            }
        }
        .disabled(busy != nil)
    }

    private func label<Icon: View>(_ text: String, loading: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 10) {
            icon()
            Text(text).font(.system(size: 16, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .overlay(alignment: .trailing) {
            if loading { ProgressView().padding(.trailing, 18) }
        }
    }

    private func run(_ provider: String, _ obtain: @escaping () async throws -> SocialCredential) {
        busy = provider
        error = nil
        Task {
            do {
                let credential = try await obtain()
                let isNew = try await store.signIn(with: credential)
                onSignedIn(isNew)
            } catch SocialAuthError.cancelled {
                // User closed the sheet — nothing to show.
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? t("error.generic")
            }
            busy = nil
        }
    }
}

/// The four-colour Google "G", drawn so no image asset is needed.
struct GoogleMark: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = s * 0.36, w = s * 0.2
            func arc(_ from: Double, _ to: Double, _ color: Color) {
                var p = Path()
                p.addArc(center: c, radius: r, startAngle: .degrees(from), endAngle: .degrees(to), clockwise: false)
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .butt))
            }
            arc(-40, 45, Color(hex: 0x4285F4))   // blue (right)
            arc(45, 140, Color(hex: 0x34A853))   // green (bottom)
            arc(140, 215, Color(hex: 0xFBBC05))  // yellow (left)
            arc(215, 320, Color(hex: 0xEA4335))  // red (top)
            var bar = Path()
            bar.addRect(CGRect(x: c.x, y: c.y - w / 2, width: r + w / 2, height: w))
            ctx.fill(bar, with: .color(Color(hex: 0x4285F4)))
        }
        .accessibilityHidden(true)
    }
}
