import Foundation
import UIKit
import CoreLocation
import UserNotifications
import CoreImage.CIFilterBuiltins

/// One-shot location → human readable place name (e.g. 神奈川県横浜市 / Hà Nội).
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    @MainActor
    func currentPlaceName() async -> String? {
        guard let location = await requestLocation() else { return nil }
        let geocoder = CLGeocoder()
        guard let mark = try? await geocoder.reverseGeocodeLocation(location, preferredLocale: L10n.shared.language.locale).first else {
            return nil
        }
        let parts = [mark.administrativeArea, mark.locality].compactMap { $0 }
        var seen = Set<String>()
        let unique = parts.filter { seen.insert($0).inserted }
        switch L10n.shared.language {
        case .ja: return unique.joined()
        case .vi: return unique.reversed().joined(separator: ", ")
        }
    }

    @MainActor
    private func requestLocation() async -> CLLocation? {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted { return nil }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted: finish(nil)
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }

    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }
}

extension Notification.Name {
    static let seeliDeviceToken = Notification.Name("seeli.deviceToken")
    static let seeliOpenConnect = Notification.Name("seeli.openConnect")
}

/// Receives the APNs device token and notification taps, and hands them to AppStore.
final class SeeliAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .seeliDeviceToken, object: hex)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    /// Show banners while the app is open too.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound, .list] }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if ["friend_post", "comment_reply"].contains(info["type"] as? String ?? "") {
            await MainActor.run { NotificationCenter.default.post(name: .seeliOpenConnect, object: nil) }
        }
    }
}

enum NotificationService {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func scheduleReunion(id: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "SEELI"
        content.body = t("notification.reunion")
        content.sound = .default
        content.userInfo = ["momentID": id]
        let interval = max(5, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

enum QRCode {
    static func image(for string: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Generates a soft placeholder "photo" when the device has no camera (Simulator).
enum PlaceholderPhoto {
    static func make() -> Data? {
        let size = CGSize(width: 1200, height: 1600)
        let palettes: [[UIColor]] = [
            [UIColor(red: 0.85, green: 0.89, blue: 0.84, alpha: 1), UIColor(red: 0.45, green: 0.53, blue: 0.40, alpha: 1)],
            [UIColor(red: 0.96, green: 0.88, blue: 0.75, alpha: 1), UIColor(red: 0.62, green: 0.55, blue: 0.48, alpha: 1)],
            [UIColor(red: 0.80, green: 0.86, blue: 0.92, alpha: 1), UIColor(red: 0.35, green: 0.42, blue: 0.52, alpha: 1)]
        ]
        let colors = palettes.randomElement()!
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors.map { $0.cgColor } as CFArray,
                                      locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            UIColor(red: 0.96, green: 0.83, blue: 0.54, alpha: 0.9).setFill()
            cg.fillEllipse(in: CGRect(x: CGFloat.random(in: 200...800), y: 300, width: 240, height: 240))
            for i in 0..<3 {
                let path = UIBezierPath()
                let base = size.height * (0.62 + CGFloat(i) * 0.1)
                path.move(to: CGPoint(x: 0, y: base))
                path.addCurve(to: CGPoint(x: size.width, y: base - 60),
                              controlPoint1: CGPoint(x: size.width * 0.3, y: base - 220),
                              controlPoint2: CGPoint(x: size.width * 0.6, y: base + 120))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.close()
                UIColor(white: 0.1, alpha: 0.12 + CGFloat(i) * 0.08).setFill()
                path.fill()
            }
        }
        return image.jpegData(compressionQuality: 0.85)
    }
}
