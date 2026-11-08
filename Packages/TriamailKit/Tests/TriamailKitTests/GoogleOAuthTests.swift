import Foundation
import Testing
@testable import TriamailKit

@Suite struct GoogleOAuthTests {
    @Test func pkceChallengeMatchesRFC7636Example() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func randomVerifiersAreLongEnoughAndUnique() {
        let first = PKCE.randomVerifier()
        #expect(first.count >= 43)
        #expect(first != PKCE.randomVerifier())
        #expect(!first.contains("=") && !first.contains("+") && !first.contains("/"))
    }

    @Test func authorizationURLAsksForOfflineGmailAccess() throws {
        let client = GoogleOAuthClient(clientID: "client-exemple.apps.googleusercontent.com", clientSecret: "secret-exemple")
        let url = client.authorizationURL(redirectURI: "http://127.0.0.1:5555", pkce: PKCE(verifier: "v"), state: "s")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(url.host == "accounts.google.com")
        #expect(query["scope"] == GoogleOAuthClient.gmailScope)
        #expect(query["access_type"] == "offline")
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["redirect_uri"] == "http://127.0.0.1:5555")
        #expect(query["state"] == "s")
        #expect(query["client_secret"] == nil)
    }

    @Test func callbackParsesCodeAndChecksState() throws {
        let callback = try #require(OAuthCallback(requestLine: "GET /?state=abc&code=4%2F0Exemple&scope=x HTTP/1.1"))
        #expect(try callback.authorizationCode(expectedState: "abc") == "4/0Exemple")
        #expect(throws: OAuthFailure.stateMismatch) { try callback.authorizationCode(expectedState: "autre") }
    }

    @Test func callbackReportsDenial() throws {
        let callback = try #require(OAuthCallback(requestLine: "GET /?error=access_denied&state=abc HTTP/1.1"))
        #expect(throws: OAuthFailure.denied("access_denied")) { try callback.authorizationCode(expectedState: "abc") }
    }

    @Test func otherRequestsAreIgnored() {
        #expect(OAuthCallback(requestLine: "GET /favicon.ico HTTP/1.1") == nil)
        #expect(OAuthCallback(requestLine: "POST /?code=x HTTP/1.1") == nil)
    }

    @Test func formEncodingEscapesReservedCharacters() {
        #expect(GoogleOAuthClient.formEncode(["b": "a/b c", "a": "x+y"]) == "a=x%2By&b=a%2Fb%20c")
    }

    @Test func tokenResponseDecodes() throws {
        let json = #"{"access_token":"ya29.exemple","expires_in":3599,"refresh_token":"1//exemple","scope":"s","token_type":"Bearer"}"#
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: Data(json.utf8))
        #expect(tokens.accessToken == "ya29.exemple")
        #expect(tokens.refreshToken == "1//exemple")
        #expect(tokens.expiresIn == 3599)
    }
}

@Suite struct LoopbackReceiverTests {
    @Test func receivesTheBrowserRedirect() async throws {
        let receiver = try LoopbackReceiver()
        defer { receiver.stop() }
        let redirect = try await receiver.start()
        #expect(redirect.hasPrefix("http://127.0.0.1:"))

        let (body, response) = try await URLSession.shared.data(from: URL(string: "\(redirect)/?state=s&code=c")!)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(String(decoding: body, as: UTF8.self).contains("Triamail"))
        #expect(try await receiver.callback().authorizationCode(expectedState: "s") == "c")
    }
}

@Suite struct SignInTimeoutTests {
    @Test func abandonedSignInTimesOut() async throws {
        let receiver = try LoopbackReceiver()
        _ = try await receiver.start()
        await #expect(throws: OAuthFailure.self) {
            try await GmailAuthenticator.callback(from: receiver, timeout: .milliseconds(200))
        }
    }
}

@Suite struct AccessTokenCacheTests {
    actor Counter { var value = 0; func increment() -> Int { value += 1; return value } }

    @Test func refreshesOncePerAccountWhileValid() async throws {
        let cache = AccessTokenCache()
        let counter = Counter()
        let refresh: @Sendable () async throws -> TokenResponse = {
            let n = await counter.increment()
            return TokenResponse(accessToken: "jeton-\(n)", expiresIn: 3600, refreshToken: nil, scope: nil)
        }
        async let first = cache.token(for: "jeanne@exemple.com", refresh: refresh)
        async let second = cache.token(for: "jeanne@exemple.com", refresh: refresh)
        let tokens = try await [first, second, cache.token(for: "jeanne@exemple.com", refresh: refresh)]
        #expect(Set(tokens) == ["jeton-1"])
        #expect(await counter.value == 1)

        await cache.forget("jeanne@exemple.com")
        #expect(try await cache.token(for: "jeanne@exemple.com", refresh: refresh) == "jeton-2")
    }

    @Test func expiredTokenIsRefreshed() async throws {
        let cache = AccessTokenCache()
        let counter = Counter()
        let refresh: @Sendable () async throws -> TokenResponse = {
            let n = await counter.increment()
            return TokenResponse(accessToken: "jeton-\(n)", expiresIn: 30, refreshToken: nil, scope: nil)
        }
        _ = try await cache.token(for: "a", refresh: refresh)
        #expect(try await cache.token(for: "a", refresh: refresh) == "jeton-2")
    }
}
