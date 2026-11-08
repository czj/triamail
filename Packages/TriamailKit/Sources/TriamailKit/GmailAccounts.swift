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
        let code = try await Self.callback(from: receiver, timeout: .seconds(300)).authorizationCode(expectedState: state)
        let tokens = try await client.exchange(code: code, redirectURI: redirectURI, pkce: pkce)
        guard let refreshToken = tokens.refreshToken else { throw OAuthFailure.noRefreshToken }
        let email = try await GmailAPI(accessToken: tokens.accessToken).profileEmail()
        let account = GmailAccount(email: email)
        try Keychain.set(refreshToken, for: account.refreshTokenKey)
        return account
    }

    /// The browser's answer, or a timeout when the user gave up (closed the tab, wrong account…).
    static func callback(from receiver: LoopbackReceiver, timeout: Duration) async throws -> OAuthCallback {
        try await withThrowingTaskGroup(of: OAuthCallback?.self) { group in
            group.addTask { try await receiver.callback() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = try await group.next() ?? nil
            group.cancelAll()
            // Ends a callback still pending, so the group can finish.
            receiver.stop()
            guard let callback = first else { throw OAuthFailure.denied("pas de réponse du navigateur, réessaie") }
            return callback
        }
    }

    /// An access token for the account: the cached one while it is valid (about an hour), else a fresh one.
    public func accessToken(for account: GmailAccount) async throws -> String {
        try await AccessTokenCache.shared.token(for: account.email) {
            guard let client else { throw OAuthFailure.server("identifiant client OAuth manquant") }
            guard let refreshToken = try Keychain.get(account.refreshTokenKey) else { throw OAuthFailure.noRefreshToken }
            return try await client.refresh(refreshToken: refreshToken)
        }
    }

    /// The Gmail API, signed in as the account.
    public func api(for account: GmailAccount) async throws -> GmailAPI {
        GmailAPI(accessToken: try await accessToken(for: account))
    }

    public func signOut(_ account: GmailAccount) async throws {
        try Keychain.delete(account.refreshTokenKey)
        await AccessTokenCache.shared.forget(account.email)
    }
}

/// Access tokens last about an hour: one refresh per account and per hour, not one per click.
/// Callers asking at the same time share the same refresh.
actor AccessTokenCache {
    static let shared = AccessTokenCache()

    private var tokens: [String: (value: String, expires: Date)] = [:]
    private var refreshing: [String: Task<TokenResponse, Error>] = [:]

    func token(for key: String, refresh: @escaping @Sendable () async throws -> TokenResponse) async throws -> String {
        if let token = tokens[key], token.expires > .now { return token.value }
        let task = refreshing[key] ?? Task { try await refresh() }
        refreshing[key] = task
        defer { refreshing[key] = nil }
        let response = try await task.value
        // A minute of margin, so a token never expires mid-request.
        tokens[key] = (response.accessToken, .now.addingTimeInterval(TimeInterval(max(response.expiresIn - 60, 0))))
        return response.accessToken
    }

    func forget(_ key: String) {
        tokens[key] = nil
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

extension MailMessage {
    /// The connected account that received this mail.
    public var gmailAccount: GmailAccount { GmailAccount(email: account) }
}
