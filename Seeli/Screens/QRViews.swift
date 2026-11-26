import SwiftUI
import AVFoundation

final class QRScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "seeli.qr")
    private var configured = false
    var onCode: ((String) -> Void)?

    @Published var available = true

    @MainActor
    func start() async {
        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            status = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        }
        guard status == .authorized,
              let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            available = false
            return
        }
        if !configured {
            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr]
            }
            session.commitConfiguration()
            configured = true
        }
        let session = self.session
        queue.async { session.startRunning() }
    }

    func stop() {
        let session = self.session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let value = obj.stringValue else { return }
        onCode?(value)
    }
}

struct QRScanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = QRScanner()
    @State private var manual = ""
    @State private var invalid = false
    @State private var handled = false

    var body: some View {
        ZStack {
            Color.seeliNight.ignoresSafeArea()
            if scanner.available {
                CameraPreview(session: scanner.session).ignoresSafeArea()
            }
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(Circle().fill(.white.opacity(0.12)))
                    }
                    Spacer()
                    Text("QR SCAN").font(.system(size: 14, weight: .semibold)).tracking(1.5).foregroundStyle(.white)
                    Spacer()
                    Button { store.path.removeLast(); store.path.append(.myQR) } label: {
                        Image(systemName: "qrcode").foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(Circle().fill(.white.opacity(0.12)))
                    }
                    .accessibilityLabel(t("myqr.title"))
                }
                .padding(.horizontal, 20)

                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.85), lineWidth: 2)
                    if !scanner.available {
                        VStack(spacing: 10) {
                            Image(systemName: "qrcode.viewfinder").font(.system(size: 40, weight: .light))
                            Text(t("scan.unavailable")).font(.system(size: 12)).multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(24)
                    }
                }
                .frame(width: 250, height: 250)
                Text(t("scan.hint"))
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text(t("scan.manual")).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    HStack {
                        TextField("", text: $manual, prompt: Text("ABCD 1234").foregroundStyle(.white.opacity(0.4)))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.1)))
                        Button(t("scan.add")) { handle(manual) }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.seeliNight)
                            .padding(.horizontal, 16).frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.seeliGreenPale))
                    }
                    if invalid {
                        Text(t("scan.invalid")).font(.system(size: 12)).foregroundStyle(Color.seeliSun)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            scanner.onCode = { code in handle(code) }
            await scanner.start()
        }
        .onDisappear { scanner.stop() }
    }

    private func handle(_ code: String) {
        guard !handled else { return }
        guard let invite = FriendInvite(string: code) else { invalid = true; return }
        handled = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        scanner.stop()
        store.pendingInvite = invite
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { handled = false }
    }
}

struct MyQRView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        SeeliScreen(title: "MY QR", subtitle: t("myqr.subtitle"), leading: .back) {
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 14) {
                    Avatar(initial: store.account?.initial ?? "", size: 56)
                    Text(store.account?.name ?? "").font(.system(size: 20, weight: .semibold))
                    Text("@\(store.account?.handle ?? "")").font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                    if let img = QRCode.image(for: store.myInvite.url) {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18).fill(.white))
                    }
                    Text(spaced(store.myInvite.code))
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Color.seeliInk)
                        .textSelection(.enabled)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .seeliCard(.seeliCard, radius: 28, border: false)
                .padding(.horizontal, 24)

                Text(t("myqr.hint"))
                    .font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 18)
                Button(t("myqr.rotate")) { Task { await store.rotateInviteCode() } }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.seeliGreen)
                    .padding(.top, 10)
                Spacer()
                Button { store.path.removeLast(); store.path.append(.scan) } label: {
                    Label(t("myqr.scan"), systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .task { await store.refresh() }
    }

    private func spaced(_ code: String) -> String {
        code.count == 8 ? "\(code.prefix(4)) \(code.suffix(4))" : code
    }
}

struct AddFriendView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var invite: FriendInvite
    @State private var preview: AppStore.InvitePreview?
    @State private var failed = false
    @State private var busy = false
    @State private var added: Friend?
    @State private var requested = false

    var body: some View {
        VStack(spacing: 0) {
            Text("ADD FRIEND").font(.system(size: 14, weight: .semibold)).tracking(1.5)
                .padding(.top, 28)
            Spacer()
            if let user = preview?.user {
                Avatar(initial: user.initial, size: 84)
                Text(user.name).font(.system(size: 22, weight: .semibold)).padding(.top, 14)
                Text("@\(user.handle)").font(.system(size: 13)).foregroundStyle(Color.seeliMuted).padding(.top, 4)
            } else if failed {
                Image(systemName: "questionmark.circle").font(.system(size: 44, weight: .light)).foregroundStyle(Color.seeliMuted)
            } else {
                ProgressView()
            }
            Text(statusText)
                .font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 30)
            Spacer()
            if let preview, !preview.isSelf, !preview.isFriend, added == nil, !requested, preview.requested != true {
                Button {
                    busy = true
                    Task {
                        switch await store.addFriend(invite) {
                        case .friends(let f): added = f
                        case .requested: requested = true
                        case nil: break
                        }
                        busy = false
                    }
                } label: {
                    if busy { ProgressView().tint(.white) }
                    else { Text(preview.requestedMe == true ? t("requests.accept") : t("addFriend.request")) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy)
                if let error = store.lastError, !busy {
                    Text(error).font(.system(size: 12)).foregroundStyle(Color(hex: 0xB0574A)).padding(.top, 8)
                }
                Button(t("common.cancel")) { dismiss() }
                    .font(.system(size: 13)).foregroundStyle(Color.seeliMuted).padding(.top, 12)
            } else {
                Button(t("common.close")) { finish() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .background(Color.seeliBG.ignoresSafeArea())
        .task {
            do { preview = try await store.preview(invite) } catch { failed = true }
        }
    }

    private var statusText: String {
        if failed { return t("addFriend.notFound") }
        guard let preview else { return "" }
        if added != nil { return t("addFriend.done") }
        if requested || preview.requested == true { return tf("addFriend.requested", preview.user.name) }
        if preview.isSelf { return t("addFriend.self") }
        if preview.isFriend { return t("addFriend.already") }
        if preview.requestedMe == true { return tf("addFriend.requestedMe", preview.user.name) }
        return t("addFriend.question")
    }

    private func finish() {
        dismiss()
        if let f = added { store.path = [.connect, .friend(f.id)] }
    }
}
