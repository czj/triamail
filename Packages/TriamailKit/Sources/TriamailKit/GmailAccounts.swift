import Foundation

/// A connected Gmail account. Its refresh token lives in the keychain of this Mac.
public struct GmailAccount: Codable, Hashable, Identifiable, Sendable {
    public var email: String
    public var id: String { email }

    public init(email: String) {
        self.email = email
    }

    var refreshTokenKey: String { "gmail.refresh.\(email)" }
}

/// Keychain entries and the OAuth dance for Gmail accounts.
public struct GmailAuthenticator: Sendable {
    static let clientIDKey = "google.oauth.client-id"
    static let clientSecretKey = "google.oauth.client-secret"

    public init() {}

    public var clientID: String? { try? Keychain.get(Self.clientIDKey) }
    public var clientSecret: String? { try? Keychain.get(Self.clientSecretKey) }

    public func saveClient(id: String, secret: String) throws {
        try Keychain.set(id.trimmingCharacters(in: .whitespacesAndNewlines), for: Self.clientIDKey)
        try Keychain.set(secret.trimmingCharacters(in: .whitespacesAndNewlines), for: Self.clientSecretKey)
    }

    public var client: GoogleOAuthClient? {
        guard let id = clientID, !id.isEmpty, let secret = clientSecret, !secret.isEmpty else { return nil }
        return GoogleOAuthClient(clientID: id, clientSecret: secret)
    }

    /// Opens the browser through `open`, waits for the redirect, stores the refresh token.
    public func signIn(open: @Sendable (URL) async -> Void) async throws -> GmailAccount {
        guard let client else { throw OAuthFailure.server("identifiant client OAuth manquant") }
        let receiver = try LoopbackReceiver()
        defer { receiver.stop() }
        let redirectURI = try await receiver.start()
        let pkce = PKCE()
        let state = PKCE.randomVerifier()
        await open(client.authorizationURL(redirectURI: redirectURI, pkce: pkce, state: state))
        let code = try await receiver.callback().authorizationCode(expectedState: state)
        let tokens = try await client.exchange(code: code, redirectURI: redirectURI, pkce: pkce)
        guard let refreshToken = tokens.refreshToken else { throw OAuthFailure.noRefreshToken }
        let email = try await GmailAPI(accessToken: tokens.accessToken).profileEmail()
        let account = GmailAccount(email: email)
        try Keychain.set(refreshToken, for: account.refreshTokenKey)
        return account
    }

    /// A fresh access token for the account (valid about an hour).
    public func accessToken(for account: GmailAccount) async throws -> String {
        guard let client else { throw OAuthFailure.server("identifiant client OAuth manquant") }
        guard let refreshToken = try Keychain.get(account.refreshTokenKey) else { throw OAuthFailure.noRefreshToken }
        return try await client.refresh(refreshToken: refreshToken).accessToken
    }

    public func signOut(_ account: GmailAccount) throws {
        try Keychain.delete(account.refreshTokenKey)
    }
}

/// The few Gmail REST calls Triamail needs.
public struct GmailAPI: Sendable {
    static let base = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/")!

    public var accessToken: String
    public var session: URLSession

    public init(accessToken: String, session: URLSession = .shared) {
        self.accessToken = accessToken
        self.session = session
    }

    public func profileEmail() async throws -> String {
        struct Profile: Decodable { var emailAddress: String }
        return try await get("profile", as: Profile.self).emailAddress
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        var components = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OAuthFailure.server("Gmail HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
