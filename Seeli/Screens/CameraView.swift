import SwiftUI
import AVFoundation

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "seeli.camera")
    private var configured = false
    private var completion: ((Data?) -> Void)?

    @Published var state: State = .loading
    enum State { case loading, ready, denied, unavailable }

    @MainActor
    func start() async {
        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            status = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        }
        guard status == .authorized else { state = .denied; return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            state = .unavailable
            return
        }
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = .photo
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            configured = true
        }
        let session = self.session
        queue.async { session.startRunning() }
        state = .ready
    }

    func stop() {
        let session = self.session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    func capture(_ completion: @escaping (Data?) -> Void) {
        self.completion = completion
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        DispatchQueue.main.async {
            self.completion?(data)
            self.completion = nil
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

/// Camera: take the photo, then let it go. No preview of the result is ever shown.
struct CameraView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @State private var flash = false
    @State private var released = false
    @State private var busy = false

    var body: some View {
        ZStack {
            Color.seeliNight.ignoresSafeArea()

            switch camera.state {
            case .ready:
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 8)
                    .padding(.top, 70)
                    .padding(.bottom, 170)
                    .ignoresSafeArea(edges: .bottom)
            case .loading:
                ProgressView().tint(.white)
            case .denied:
                message(t("camera.denied"), action: t("camera.openSettings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            case .unavailable:
                VStack(spacing: 12) {
                    Image(systemName: "camera.metering.unknown").font(.system(size: 34, weight: .light))
                    Text(t("camera.unavailable")).multilineTextAlignment(.center)
                }
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .padding(40)
            }

            // Viewfinder corners
            if camera.state == .ready {
                ViewfinderCorners()
                    .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .padding(.horizontal, 40)
                    .padding(.top, 110)
                    .padding(.bottom, 210)
                    .allowsHitTesting(false)
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.12)))
                    }
                    .accessibilityLabel(t("common.close"))
                    Spacer()
                    Text("SEELI").font(.system(size: 13, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                Spacer()
                Text(t("camera.hint"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 18)
                Button(action: shoot) {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 3).frame(width: 78, height: 78)
                        Circle().fill(.white).frame(width: 64, height: 64)
                    }
                }
                .disabled(busy || camera.state == .loading || camera.state == .denied)
                .accessibilityLabel(t("camera.shutter"))
                .padding(.bottom, 40)
            }

            Color.white.opacity(flash ? 1 : 0).ignoresSafeArea().allowsHitTesting(false)

            if released {
                VStack(spacing: 14) {
                    EyeLogo(size: 40, closed: true, color: .white)
                    Text(t("camera.released")).font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.seeliNight.ignoresSafeArea())
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    private func shoot() {
        busy = true
        let finish: (Data?) -> Void = { data in
            store.startDraft(imageData: data ?? PlaceholderPhoto.make())
            withAnimation(.easeIn(duration: 0.3)) { released = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                camera.stop()
                var path = store.path
                if path.last == .camera { path.removeLast() }
                path.append(.post)
                store.path = path
            }
        }
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.35)) { flash = false }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if camera.state == .ready {
            camera.capture(finish)
        } else {
            finish(nil)
        }
    }

    private func message(_ text: String, action: String, perform: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text(text).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
            Button(action, action: perform).foregroundStyle(Color.seeliSun)
        }
        .font(.system(size: 14))
        .padding(40)
    }
}

private struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let l: CGFloat = 22
        var p = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0),
                                 (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0),
                                 (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
            p.move(to: CGPoint(x: corner.x, y: corner.y + l * dy))
            p.addLine(to: corner)
            p.addLine(to: CGPoint(x: corner.x + l * dx, y: corner.y))
        }
        return p
    }
}
