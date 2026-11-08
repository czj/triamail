import CryptoKit
import Foundation
import Network

/// OAuth for an installed app (Google "Desktop app" client): browser sign-in, PKCE, loopback redirect.
/// The client ID and secret are typed in the app by the user and kept in the keychain, never in the code.
public struct GoogleOAuthClient: Sendable {
    public static let gmailScope = "https://www.googleapis.com/auth/gmail.modify"
    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    public var clientID: String
    public var clientSecret: String
    public var session: URLSession

    public init(clientID: String, clientSecret: String, session: URLSession = .shared) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.session = session
    }

    public func authorizationURL(redirectURI: String, pkce: PKCE, state: String, loginHint: String? = nil) -> URL {
        var components = URLComponents(url: Self.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.gmailScope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            // offline + consent: Google returns a refresh token, so the sign-in happens once.
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ] + (loginHint.map { [URLQueryItem(name: "login_hint", value: $0)] } ?? [])
        return components.url!
    }

    public func exchange(code: String, redirectURI: String, pkce: PKCE) async throws -> TokenResponse {
        try await postToken([
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": pkce.verifier,
        ])
    }

    public func refresh(refreshToken: String) async throws -> TokenResponse {
        try await postToken([
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
        ])
    }

    private func postToken(_ form: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.formEncode(form).utf8)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(OAuthError.self, from: data))?.description
            throw OAuthFailure.server(message ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    static func formEncode(_ form: [String: String]) -> String {
        form.sorted { $0.key < $1.key }
            .map { "\($0.key)=\(OutgoingMail.percentEncoded($0.value))" }
            .joined(separator: "&")
    }
}

public struct PKCE: Sendable {
    public let verifier: String
    public let challenge: String

    public init(verifier: String = PKCE.randomVerifier()) {
        self.verifier = verifier
        self.challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }

    public static func randomVerifier() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64URLEncoded
    }
}

public struct TokenResponse: Codable, Sendable {
    public var accessToken: String
    public var expiresIn: Int
    public var refreshToken: String?
    public var scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

public enum OAuthFailure: Error, LocalizedError, Equatable {
    case server(String)
    case denied(String)
    case stateMismatch
    case noRefreshToken

    public var errorDescription: String? {
        switch self {
        case let .server(message): "Google a refusé la demande : \(message)"
        case let .denied(reason): "Connexion refusée : \(reason)"
        case .stateMismatch: "Réponse inattendue du navigateur (state différent)."
        case .noRefreshToken: "Google n'a pas renvoyé de jeton durable : réessaie la connexion."
        }
    }
}

struct OAuthError: Decodable, CustomStringConvertible {
    var error: String
    var errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }

    var description: String { [error, errorDescription].compactMap { $0 }.joined(separator: " : ") }
}

/// What the browser sends back to the loopback address.
public struct OAuthCallback: Equatable, Sendable {
    public var code: String?
    public var state: String?
    public var error: String?

    /// Parses the first line of the HTTP request, e.g. "GET /?state=x&code=y HTTP/1.1".
    public init?(requestLine: String) {
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET", let components = URLComponents(string: String(parts[1])) else { return nil }
        let items = components.queryItems ?? []
        code = items.first { $0.name == "code" }?.value
        state = items.first { $0.name == "state" }?.value
        error = items.first { $0.name == "error" }?.value
        guard code != nil || error != nil else { return nil }
    }

    public func authorizationCode(expectedState: String) throws -> String {
        if let error { throw OAuthFailure.denied(error) }
        guard state == expectedState else { throw OAuthFailure.stateMismatch }
        guard let code else { throw OAuthFailure.denied("pas de code") }
        return code
    }
}

/// A one-shot HTTP listener on 127.0.0.1 that receives Google's redirect, then closes.
/// All its state is touched on `queue` only.
public final class LoopbackReceiver: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "Triamail.LoopbackReceiver")
    private var readyContinuation: CheckedContinuation<String, Error>?
    private var callbackContinuation: CheckedContinuation<OAuthCallback, Error>?
    private var pendingCallback: OAuthCallback?

    public init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    /// Starts listening and returns the redirect URI to give Google.
    public func start() async throws -> String {
        try await withCheckedThrowingContinuation { ready in
            queue.async {
                self.readyContinuation = ready
                self.listener.stateUpdateHandler = { [weak self] state in self?.stateChanged(state) }
                self.listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
                self.listener.start(queue: self.queue)
            }
        }
    }

    /// Waits for the browser to come back.
    public func callback() async throws -> OAuthCallback {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let pending = self.pendingCallback {
                    self.pendingCallback = nil
                    continuation.resume(returning: pending)
                } else {
                    self.callbackContinuation = continuation
                }
            }
        }
    }

    public func stop() {
        listener.cancel()
    }

    private func stateChanged(_ state: NWListener.State) {
        switch state {
        case .ready:
            readyContinuation?.resume(returning: "http://127.0.0.1:\(listener.port?.rawValue ?? 0)")
            readyContinuation = nil
        case let .failed(error):
            readyContinuation?.resume(throwing: error)
            readyContinuation = nil
            callbackContinuation?.resume(throwing: error)
            callbackContinuation = nil
        case .cancelled:
            readyContinuation?.resume(throwing: CancellationError())
            readyContinuation = nil
            callbackContinuation?.resume(throwing: CancellationError())
            callbackContinuation = nil
        default:
            break
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self else { return }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let firstLine = request.components(separatedBy: "\r\n").first ?? ""
            guard let callback = OAuthCallback(requestLine: firstLine) else {
                // favicon.ico and the like: answer and keep waiting.
                self.reply(connection, status: "404 Not Found", body: "")
                return
            }
            self.reply(connection, status: "200 OK", body: """
                <!doctype html><meta charset="utf-8"><title>Triamail</title>
                <body style="font: 15px -apple-system; text-align: center; margin-top: 20vh">
                <h1>\(callback.error == nil ? "C'est fait" : "Connexion refusée")</h1>
                <p>Tu peux fermer cet onglet et revenir dans Triamail.</p>
                """)
            if let continuation = self.callbackContinuation {
                self.callbackContinuation = nil
                continuation.resume(returning: callback)
            } else {
                self.pendingCallback = callback
            }
        }
    }

    private func reply(_ connection: NWConnection, status: String, body: String) {
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension CharacterSet {
    /// RFC 3986 unreserved characters: everything else is percent-encoded.
    static let urlUnreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
}
