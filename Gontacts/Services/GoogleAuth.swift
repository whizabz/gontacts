import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum AuthError: LocalizedError {
    case notConfigured, cancelled, badResponse, signedOut
    /// Signed in, but the contacts permission was unticked on Google's screen.
    case contactsAccessMissing

    var errorDescription: String? {
        switch self {
        case .contactsAccessMissing: "Gontacts needs access to your contacts. Try again and keep “See, edit, download and permanently delete your contacts” ticked on Google's screen."
        case .notConfigured: "Google sign-in isn't configured. Add GOOGLE_CLIENT_ID to Config/Secrets.xcconfig."
        case .cancelled: "Sign-in was cancelled."
        case .badResponse: "Google returned an unexpected response."
        case .signedOut: "You're signed out. Sign in again to continue."
        }
    }
}

/// OAuth 2.0 with PKCE for an "iOS" client type. No client secret and no third-party SDK.
@MainActor
final class GoogleAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct Tokens: Codable {
        var accessToken: String
        var refreshToken: String?
        var expiry: Date
        var email: String?
    }

    private static let keychainKey = "google.tokens"
    private static let contactsScope = "https://www.googleapis.com/auth/contacts"
    private static let scope = "\(contactsScope) openid email"

    static var clientID: String {
        let id = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
        return id.contains("$(") ? "" : id
    }
    static var isConfigured: Bool { !clientID.isEmpty }

    private var callbackScheme: String { "com.googleusercontent.apps." + Self.clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "") }
    private var redirectURI: String { "\(callbackScheme):/oauth2redirect" }

    private(set) var tokens: Tokens? = {
        Keychain.load(keychainKey).flatMap { try? JSONDecoder().decode(Tokens.self, from: $0) }
    }()
    var email: String? { tokens?.email }
    var isSignedIn: Bool { tokens != nil }

    func signIn() async throws {
        guard Self.isConfigured else { throw AuthError.notConfigured }
        let verifier = Self.randomString(byteCount: 48)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: Self.clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: Self.scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
        ]

        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: comps.url!, callback: .customScheme(callbackScheme)) { url, error in
                if let url { cont.resume(returning: url) }
                else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { cont.resume(throwing: AuthError.cancelled) }
                else { cont.resume(throwing: error ?? AuthError.badResponse) }
            }
            session.presentationContextProvider = self
            session.start()
        }

        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.badResponse
        }
        let response = try await tokenRequest([
            "client_id": Self.clientID, "code": code, "code_verifier": verifier,
            "redirect_uri": redirectURI, "grant_type": "authorization_code",
        ])
        // Google lets people untick individual permissions, so check what was actually granted.
        // Nothing is stored unless the contacts permission is there.
        guard Self.grantsContactsAccess(response.scope) else { throw AuthError.contactsAccessMissing }
        store(Tokens(accessToken: response.access_token, refreshToken: response.refresh_token,
                     expiry: .now.addingTimeInterval(TimeInterval(response.expires_in - 60)),
                     email: response.id_token.flatMap(Self.email(fromIDToken:))))
    }

    /// Whether the space-separated scopes Google reports include full contacts access.
    static func grantsContactsAccess(_ scope: String?) -> Bool {
        (scope ?? "").split(separator: " ").contains { $0 == contactsScope[...] }
    }

    func validAccessToken() async throws -> String {
        guard var current = tokens else { throw AuthError.signedOut }
        if current.expiry > .now { return current.accessToken }
        guard let refresh = current.refreshToken else { throw AuthError.signedOut }
        let response = try await tokenRequest([
            "client_id": Self.clientID, "refresh_token": refresh, "grant_type": "refresh_token",
        ])
        current.accessToken = response.access_token
        current.expiry = .now.addingTimeInterval(TimeInterval(response.expires_in - 60))
        store(current)
        return current.accessToken
    }

    /// Forces the next call to refresh (used after a 401).
    func invalidateAccessToken() {
        guard var t = tokens else { return }
        t.expiry = .distantPast
        store(t)
    }

    func signOut() {
        tokens = nil
        Keychain.delete(Self.keychainKey)
    }

    // MARK: - Internals

    private func store(_ t: Tokens) {
        tokens = t
        if let data = try? JSONEncoder().encode(t) { Keychain.save(data, for: Self.keychainKey) }
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int
        let id_token: String?
        let scope: String?
    }

    private func tokenRequest(_ params: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AuthError.badResponse }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            return scene?.keyWindow ?? ASPresentationAnchor()
        }
    }

    private static func randomString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private static func email(fromIDToken token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count > 1 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["email"] as? String
    }
}
