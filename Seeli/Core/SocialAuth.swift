import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// The identity token the server verifies, plus what only the device knows.
struct SocialCredential {
    var provider: String   // "apple" | "google"
    var idToken: String
    var nonce: String      // value expected in the token's `nonce` claim
    var name: String?      // Apple sends the name only on the very first sign-in
}

enum SocialAuthError: LocalizedError {
    case cancelled, failed, notConfigured
    var errorDescription: String? {
        switch self {
        case .cancelled: return nil
        case .notConfigured: return t("error.provider_disabled")
        case .failed: return t("error.generic")
        }
    }
}

private func randomString(_ bytes: Int = 32) -> String {
    var data = Data(count: bytes)
    _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!) }
    return data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

private func sha256(_ s: String) -> String {
    SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
}

private func base64url(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

private final class PresentationAnchor: NSObject, ASAuthorizationControllerPresentationContextProviding, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationAnchor()
    private var window: ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { window }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { window }
}

// MARK: - Sign in with Apple

@MainActor
final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<SocialCredential, Error>?
    private var hashedNonce = ""

    func start() async throws -> SocialCredential {
        let raw = randomString()
        hashedNonce = sha256(raw)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce // Apple puts this value in the token's nonce claim
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = PresentationAnchor.shared
        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = cred.identityToken, let token = String(data: data, encoding: .utf8) else {
            finish(.failure(SocialAuthError.failed)); return
        }
        let name = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
        finish(.success(SocialCredential(provider: "apple", idToken: token, nonce: hashedNonce, name: name.isEmpty ? nil : name)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        finish(.failure(cancelled ? SocialAuthError.cancelled : SocialAuthError.failed))
    }

    private func finish(_ result: Result<SocialCredential, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

// MARK: - Google (OAuth 2.0 + PKCE through the system browser sheet, no SDK)

@MainActor
final class GoogleSignIn {
    /// iOS OAuth client ID from Google Cloud Console, set via the GOOGLE_CLIENT_ID build setting.
    static var clientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    static var isConfigured: Bool { clientID.hasSuffix(".apps.googleusercontent.com") }

    /// "com.googleusercontent.apps.<id>" — the redirect scheme Google assigns to iOS clients.
    private static var redirectScheme: String {
        "com.googleusercontent.apps." + clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
    }

    private var session: ASWebAuthenticationSession?

    func start() async throws -> SocialCredential {
        guard Self.isConfigured else { throw SocialAuthError.notConfigured }
        let verifier = randomString(48)
        let challenge = base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
        let nonce = randomString()
        let state = randomString(16)
        let redirect = "\(Self.redirectScheme):/oauth2redirect"

        var auth = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        auth.queryItems = [
            .init(name: "client_id", value: Self.clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "nonce", value: nonce),
            .init(name: "prompt", value: "select_account"),
        ]

        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: auth.url!, callbackURLScheme: Self.redirectScheme) { url, error in
                if let url { cont.resume(returning: url) }
                else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { cont.resume(throwing: SocialAuthError.cancelled) }
                else { cont.resume(throwing: SocialAuthError.failed) }
            }
            s.presentationContextProvider = PresentationAnchor.shared
            s.prefersEphemeralWebBrowserSession = false
            session = s
            if !s.start() { cont.resume(throwing: SocialAuthError.failed) }
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            throw items.contains(where: { $0.name == "error" }) ? SocialAuthError.cancelled : SocialAuthError.failed
        }

        // Exchange the one-time code for tokens (public client: PKCE instead of a secret).
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            .init(name: "code", value: code),
            .init(name: "client_id", value: Self.clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "code_verifier", value: verifier),
        ]
        req.httpBody = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String else { throw SocialAuthError.failed }
        return SocialCredential(provider: "google", idToken: idToken, nonce: nonce, name: nil)
    }
}
