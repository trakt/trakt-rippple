//
//  FilterManager.swift
//  Rippple
//
//  Created by Kevin Cador on 07/02/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Foundation
import Receiver

final class FilterManager {
    static let shared = FilterManager()

    private let disposeBag = DisposeBag()

    private init() {}

    func setup() {
        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if SessionManager.shared.isLoggedIn {
                // migration from old way Rippple was doing it (locally)
                // this should only be done once, if it doesn't work it's not that bad since it has been local for 7 years and nobody complained
                let decoder = JSONDecoder()
                if let data = UserDefaults.standard.data(forKey: "Rippple.blockedUsers"),
                   let users = try? decoder.decode([User].self, from: data) {
                    for user in users {
                        self.undercoverBlock(user: user)
                    }
                }
                if let data = UserDefaults.standard.data(forKey: "Rippple.blockedComments"),
                   let comments = try? decoder.decode([Comment].self, from: data) {
                    for user in comments.map({ $0.user }) {
                        self.undercoverBlock(user: user)
                    }
                }
                UserDefaults.standard.removeObject(forKey: "Rippple.blockedComments")
                UserDefaults.standard.removeObject(forKey: "Rippple.blockedUsers")
                UserDefaults.standard.synchronize()
            }
        }.disposed(by: disposeBag)

        onUsersHiddenFromCommentsChangedReceiver.listen { [weak self] blockedUsers in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.blockedUsers = blockedUsers
            }
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.blockedUsers = nil
        }.disposed(by: disposeBag)
    }

    private func undercoverBlock(user: User) {
        if SessionManager.shared.isLoggedOut {
            return
        }

        guard let slug = user.identifiers.slug else { return }

        TraktAPIProvider.noRatingProvider.request(TraktAPIService.hideUser(section: .comments,
                                                                           slug: slug),
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    print("Block user successful \(response)")
                } catch {
                    print("Block user error \(error)")
                }
            case .failure(let error):
                print("Block user error \(error)")
            }
        }
    }

    fileprivate var blockedUsers: [User]?

    fileprivate func block(user: User) {
        if SessionManager.shared.isLoggedOut {
            return
        }

        let slug = user.identifiers.slugOrTraktId

        SwiftMessages.show(message: "Blocking \(user.username)...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.hideUser(section: .comments,
                                                                   slug: slug),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Block user successful \(response)")

                    DispatchQueue.main.async {
                        HiddenMediaManager.shared.refresh()
                        SwiftMessages.show(message: "🔇 \(user.username) blocked")
                        userBlockedTransmitter.broadcast(user)
                    }

                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                }
            }
        }
    }

    fileprivate func unblock(user: User) {
        if SessionManager.shared.isLoggedOut {
            return
        }

        let slug = user.identifiers.slugOrTraktId

        SwiftMessages.show(message: "Unblocking \(user.username)...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.unhideUser(section: .comments,
                                                                     slug: slug),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Unblock user successful \(response)")

                    DispatchQueue.main.async {
                        HiddenMediaManager.shared.refresh()
                        SwiftMessages.show(message: "🔈 \(user.username) unblocked")
                        userBlockedTransmitter.broadcast(user)
                    }

                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                }
            }
        }
    }
}

extension User {
    var isBlocked: Bool {
        return FilterManager.shared.blockedUsers?.contains(self) == true
    }

    func block() {
        if FollowManager.shared.followed(user: self) {
            FollowManager.shared.follow(user: self)
        }
        FilterManager.shared.block(user: self)
    }

    func unblock() {
        FilterManager.shared.unblock(user: self)
    }
}

extension Comment {
    var isFiltered: Bool {
        return user.isBlocked
    }

    func filter() {
        user.block()
    }

    func unfilter() {
        user.unblock()
    }
}
