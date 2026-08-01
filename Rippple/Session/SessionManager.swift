//
//  SessionManager.swift
//  Rippple
//
//  Created by Kevin Cador on 05/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import AuthenticationServices
import Foundation
import Moya

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
        guard let authURL = URL(string: "\(TraktAPIConfiguration.authBaseURL)/oauth/authorize?response_type=code&client_id=\(TraktAPIConfiguration.clientId)&redirect_uri=\(TraktAPIConfiguration.callbackURL)") else {
            completion(isLoggedIn)
            return
        }

        authSession = ASWebAuthenticationSession(url: authURL,
                                                 callbackURLScheme: "ripl") { callback, error in
            guard error == nil, let successURL = callback else {
                print("ASWebAuthenticationSession error \(String(describing: error))")
                print("ASWebAuthenticationSession callback \(String(describing: callback))")
                completion(self.isLoggedIn)
                return
            }
            guard let code = NSURLComponents(string: successURL.absoluteString)?.queryItems?.filter({ $0.name == "code" }).first?.value else {
                completion(self.isLoggedIn)
                return
            }

            TraktAPIProvider.noRatingProvider.request(.token(code: code),
                                                      callbackQueue: .global(qos: .userInitiated)) { result in
                defer {
                    completion(self.isLoggedIn)
                }

                switch result {
                case .success(let moyaResponse):
                    print("Token request status code \(moyaResponse.statusCode)")
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let tokenResponse = try response.map(Token.self)
                        self.token = tokenResponse
                        TraktAPIProvider.source.token = tokenResponse.accessToken
                        UserManager.shared.reloadSettings()
                    } catch {
                        print("Token request JSON mapping failed! \(error)")
                    }
                case .failure(let error):
                    print("Token request failure \(error)")
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

// MARK: Helpers

extension SessionManager {
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
