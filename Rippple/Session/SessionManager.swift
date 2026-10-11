//
//  SessionManager.swift
//  Rippple
//
//  Created by Kevin Cador on 05/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import AuthenticationServices
import CryptoKit
import Foundation
import Moya
import Security

class SessionManager: NSObject {
    static let shared = SessionManager()

    private var authSession: ASWebAuthenticationSession!

    var token: Token? {
        didSet {
            guard let token = token else {
                TraktAPIProvider.source.token = nil
                KeychainStore.removeToken()
                UserManager.shared.logout()
                return
            }
            print("SessionManager - setting token (did set)")
            KeychainStore.setToken(token)
        }
    }

    var isLoggedIn: Bool {
        return token != nil
    }

    var isLoggedOut: Bool {
        return !isLoggedIn
    }

    override init() {
        if let retrievedToken = KeychainStore.token() {
            print("SessionManager - got token from keychain")
            token = retrievedToken
        } else {
            print("SessionManager - NO TOKEN FOUND!")
        }
    }

    func wakeUp(completion: @escaping (_ isLoggedIn: Bool) -> Void) {
        if let token = token {
            if token.createdAt.advanced(by: min(Double(token.expiresIn), 24 * 60 * 60)) < Date.now.timeIntervalSince1970 {
                refreshToken(refreshToken: token.refreshToken) { [weak self] newToken in
                    guard let self = self else { return }
                    self.token = newToken
                    TraktAPIProvider.source.token = newToken!.accessToken
                    UserManager.shared.reloadSettings()
                    completion(self.isLoggedIn)
                }
            } else {
                print("SessionManager - token didn't need a refresh, setting things up with the old token.")
                TraktAPIProvider.source.token = token.accessToken
                UserManager.shared.reloadSettings()
                completion(isLoggedIn)
            }
        } else {
            completion(false)
        }
    }

    func initiateTraktLogin(completion: @escaping (_ isLoggedIn: Bool) -> Void) {
        guard let callbackURL = URL(string: TraktAPIConfiguration.callbackURL),
              let authCallback = makeAuthCallback(for: callbackURL) else {
            completion(isLoggedIn)
            return
        }

        let codeVerifier: String?
        if TraktAPIConfiguration.secretId.isEmpty {
            guard let verifier = makeCodeVerifier() else {
                completion(isLoggedIn)
                return
            }
            codeVerifier = verifier
        } else {
            codeVerifier = nil
        }

        guard let authURL = makeAuthorizationURL(codeVerifier: codeVerifier) else {
            completion(isLoggedIn)
            return
        }

        authSession = ASWebAuthenticationSession(url: authURL,
                                                 callback: authCallback) { [weak self] callback, error in
            guard let self = self else { return }
            guard error == nil, let successURL = callback else {
                print("ASWebAuthenticationSession error \(String(describing: error))")
                completion(self.isLoggedIn)
                return
            }
            guard successURL.scheme == callbackURL.scheme,
                  successURL.host == callbackURL.host,
                  successURL.port == callbackURL.port,
                  successURL.path == callbackURL.path,
                  let code = URLComponents(url: successURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value,
                  !code.isEmpty else {
                completion(self.isLoggedIn)
                return
            }

            TraktAPIProvider.noRatingProvider.request(.token(code: code, codeVerifier: codeVerifier),
                                                      callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                var newToken: Token?
                switch result {
                case .success(let moyaResponse):
                    print("Token request status code \(moyaResponse.statusCode)")
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        newToken = try response.map(Token.self)
                    } catch {
                        print("Token request JSON mapping failed! \(error)")
                    }
                case .failure(let error):
                    print("Token request failure \(error)")
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if let newToken = newToken {
                        self.token = newToken
                        TraktAPIProvider.source.token = newToken.accessToken
                        UserManager.shared.reloadSettings()
                    }
                    completion(self.isLoggedIn)
                }
            }
        }
        authSession.presentationContextProvider = AppManager.shared
        authSession.prefersEphemeralWebBrowserSession = true
        if !authSession.start() {
            completion(isLoggedIn)
        }
    }

    func logout() {
        guard let token = token else { return }
        TraktAPIProvider.noRatingProvider.request(.revoke(token: token.accessToken),
                                                  callbackQueue: .global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                print("Revoke request status code \(moyaResponse.statusCode)")
            case .failure(let error):
                print("Revoke request failure \(error)")
            }
        }
        self.token = nil
    }
}

// MARK: - Trakt login configuration

extension SessionManager {
    private func makeAuthCallback(for callbackURL: URL) -> ASWebAuthenticationSession.Callback? {
        guard let host = callbackURL.host, !host.isEmpty else { return nil }

        #if DEBUG
        // Contributors can use their own Trakt client secret with the ripl:// callback.
        if !TraktAPIConfiguration.secretId.isEmpty {
            guard callbackURL.scheme == "ripl" else {
                print("SessionManager - Debug login with a client secret requires a ripl:// callback.")
                return nil
            }
            print("SessionManager - login with client secret and custom scheme 🧪")
            return .customScheme("ripl")
        }
        #endif

        // Team Debug builds and all Release builds use PKCE with an HTTPS callback.
        guard TraktAPIConfiguration.secretId.isEmpty,
              callbackURL.scheme == "https" else {
            print("SessionManager - PKCE login requires an empty client secret and an HTTPS callback.")
            return nil
        }
        print("SessionManager - login with PKCE and https:// callback ✅")
        return .https(host: host, path: callbackURL.path)
    }

    private func makeAuthorizationURL(codeVerifier: String?) -> URL? {
        var components = URLComponents(string: "\(TraktAPIConfiguration.authBaseURL)/oauth/authorize")
        var queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: TraktAPIConfiguration.clientId),
            URLQueryItem(name: "redirect_uri", value: TraktAPIConfiguration.callbackURL)
        ]
        if let codeVerifier = codeVerifier {
            let codeChallenge = base64URLEncoded(Data(SHA256.hash(data: Data(codeVerifier.utf8))))
            queryItems.append(URLQueryItem(name: "code_challenge", value: codeChallenge))
            queryItems.append(URLQueryItem(name: "code_challenge_method", value: "S256"))
        }
        components?.queryItems = queryItems
        return components?.url
    }
}

// MARK: Helpers

extension SessionManager {
    private func makeCodeVerifier() -> String? {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        return base64URLEncoded(Data(bytes))
    }

    private func base64URLEncoded(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func refreshToken(refreshToken: String, completion: @escaping (_ token: Token?) -> Void) {
        print("SessionManager - refreshing token (API call)")
        TraktAPIProvider.noRatingProvider.request(.refresh(refreshToken: refreshToken),
                                                  callbackQueue: .global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                print("Refresh token request status code \(moyaResponse.statusCode)")
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    let tokenResponse = try response.map(Token.self)
                    completion(tokenResponse)
                } catch {
                    print("Refresh token request JSON mapping failed! \(error)")
                    completion(self.token)
                }
            case .failure(let error):
                print("Refresh token request failure \(error)")
                completion(self.token)
            }
        }
    }
}
