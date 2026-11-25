import SwiftUI
import UIKit

/// Renders its content inside the canvas of a secure text field. iOS leaves that layer
/// blank in screenshots, screen recordings and AirPlay mirroring, so a friend's photo
/// can be seen on the screen but not captured.
struct ScreenshotShield<Content: View>: UIViewRepresentable {
    var content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    func makeUIView(context: Context) -> ShieldView {
        ShieldView(root: AnyView(content))
    }

    func updateUIView(_ view: ShieldView, context: Context) {
        view.host.rootView = AnyView(content)
    }

    final class ShieldView: UIView {
        let host: UIHostingController<AnyView>
        private let field = UITextField()

        init(root: AnyView) {
            host = UIHostingController(rootView: root)
            super.init(frame: .zero)
            backgroundColor = .clear
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false

            field.isSecureTextEntry = true
            // The secure field's first subview is the canvas iOS hides from captures.
            let canvas = field.subviews.first ?? UIView()
            canvas.subviews.forEach { $0.removeFromSuperview() }
            canvas.isUserInteractionEnabled = true
            canvas.translatesAutoresizingMaskIntoConstraints = false
            addSubview(canvas)
            canvas.addSubview(host.view)
            NSLayoutConstraint.activate([
                canvas.leadingAnchor.constraint(equalTo: leadingAnchor),
                canvas.trailingAnchor.constraint(equalTo: trailingAnchor),
                canvas.topAnchor.constraint(equalTo: topAnchor),
                canvas.bottomAnchor.constraint(equalTo: bottomAnchor),
                host.view.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: canvas.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
            ])
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}

/// Full-screen look at a friend's photo: pinch to zoom, drag to pan, double-tap to toggle.
/// It lives only as long as the in-memory image, so backgrounding the app closes it.
struct OncePhotoViewer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var post: FriendPost

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Hidden while inactive so the app-switcher snapshot never holds the photo.
            if let image = store.onceImages[post.id], scenePhase == .active {
                ScreenshotShield { ZoomableImage(image: image) }
                    .ignoresSafeArea()
            }
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.author.name).font(.system(size: 15, weight: .semibold))
                        Text(t("connect.once.protected")).font(.system(size: 11)).opacity(0.75)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.15)))
                    }
                    .accessibilityLabel(t("common.close"))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
            }
        }
        .statusBarHidden()
        .onChange(of: store.onceImages[post.id] == nil) { _, gone in if gone { dismiss() } }
    }
}

private struct ZoomableImage: View {
    var image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .contentShape(Rectangle())
                .gesture(
                    MagnifyGesture()
                        .onChanged { v in scale = min(max(lastScale * v.magnification, 1), 5) }
                        .onEnded { _ in
                            lastScale = scale
                            clamp(in: geo.size)
                        }
                        .simultaneously(with: DragGesture()
                            .onChanged { v in
                                guard scale > 1 else { return }
                                offset = CGSize(width: lastOffset.width + v.translation.width,
                                                height: lastOffset.height + v.translation.height)
                            }
                            .onEnded { _ in clamp(in: geo.size) })
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.3)) {
                        if scale > 1 { scale = 1; offset = .zero } else { scale = 2.5 }
                        lastScale = scale
                        lastOffset = offset
                    }
                }
        }
        .background(Color.black)
    }

    /// Keep the zoomed image covering the screen instead of drifting off it.
    private func clamp(in size: CGSize) {
        withAnimation(.easeOut(duration: 0.2)) {
            if scale <= 1 {
                scale = 1; lastScale = 1; offset = .zero
            } else {
                let maxX = size.width * (scale - 1) / 2
                let maxY = size.height * (scale - 1) / 2
                offset = CGSize(width: min(max(offset.width, -maxX), maxX),
                                height: min(max(offset.height, -maxY), maxY))
            }
            lastOffset = offset
        }
    }
}
