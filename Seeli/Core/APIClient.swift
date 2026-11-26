import Foundation
import Security
import UIKit

struct APIError: LocalizedError {
    var code: String
    var status: Int

    var errorDescription: String? {
        let key = "error.\(code)"
        let text = t(key)
        return text == key ? t("error.generic") : text
    }

    static let network = APIError(code: "network", status: 0)
}

/// Talks to the SEELI backend (seeli-api). Token lives in the Keychain.
final class APIClient {
    static let shared = APIClient()

    private static let overrideKey = "seeli.apiURL"
    private let session: URLSession
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.waitsForConnectivity = false
        session = URLSession(configuration: cfg)
    }

    // MARK: Server URL

    static var defaultBaseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "SEELIAPIURL") as? String) ?? "http://localhost:8790"
    }

    /// Settings → Server can override the URL (handy for local testing).
    var baseURLString: String {
        get { UserDefaults.standard.string(forKey: Self.overrideKey) ?? Self.defaultBaseURL }
        set {
            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if clean.isEmpty || clean == Self.defaultBaseURL {
                UserDefaults.standard.removeObject(forKey: Self.overrideKey)
            } else {
                UserDefaults.standard.set(clean, forKey: Self.overrideKey)
            }
        }
    }

    private var baseURL: URL { URL(string: baseURLString + "/v1") ?? URL(string: "http://localhost:8790/v1")! }

    // MARK: Token (Keychain)

    private let tokenAccount = "seeli.token"

    var token: String? {
        get {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                        kSecAttrAccount as String: tokenAccount,
                                        kSecReturnData as String: true]
            var out: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
                  let data = out as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrAccount as String: tokenAccount]
            SecItemDelete(base as CFDictionary)
            guard let newValue else { return }
            var add = base
            add[kSecValueData as String] = Data(newValue.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    // MARK: Requests

    struct Empty: Decodable {}

    /// "moments/x/comments?v=2" → path plus query (appendingPathComponent would escape the "?").
    private func url(for path: String) -> URL {
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        let base = baseURL.appendingPathComponent(parts[0])
        guard parts.count == 2, var c = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return base }
        c.percentEncodedQuery = parts[1]
        return c.url ?? base
    }

    @discardableResult
    func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]? = nil,
                               as type: T.Type = Empty.self) async throws -> T {
        var req = URLRequest(url: url(for: path))
        req.httpMethod = method
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return try await send(req, as: type)
    }

    func uploadMoment(_ p: PendingUpload, jpeg: Data) async throws -> Moment {
        let boundary = "seeli-\(UUID().uuidString)"
        var req = URLRequest(url: baseURL.appendingPathComponent("moments"))
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        let iso = ISO8601DateFormatter().string(from: p.createdAt)
        field("note", p.note)
        if let place = p.placeName { field("placeName", place) }
        field("audience", p.audience.rawValue)
        if p.audience == .selected, let ids = p.recipients,
           let json = try? JSONSerialization.data(withJSONObject: ids), let text = String(data: json, encoding: .utf8) {
            field("recipients", text)
        }
        field("createdAt", iso)
        field("demo", p.demo ? "true" : "false")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpeg)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        return try await send(req, as: Moment.self)
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        var req = request
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let code = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            if status == 401 { NotificationCenter.default.post(name: .seeliUnauthorized, object: nil) }
            throw APIError(code: code ?? "generic", status: status)
        }
        if T.self == Empty.self { return Empty() as! T }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError(code: "generic", status: status)
        }
    }
}

extension Notification.Name {
    static let seeliUnauthorized = Notification.Name("seeli.unauthorized")
}

enum PhotoPrep {
    /// Resize to max 1600px and compress — keeps uploads small for the Pi.
    static func jpeg(_ data: Data, maxSide: CGFloat = 1600) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }
}
