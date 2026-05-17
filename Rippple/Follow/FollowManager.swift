//
//  FollowManager.swift
//  Rippple
//
//  Created by Kevin Cador on 11/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Foundation

import Receiver

final class FollowManager {

    private let disposeBag = DisposeBag()

    private init() { }

    func setup() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refreshFollowing()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshFollowing()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { _ in
            self.refreshFollowing()
        }.disposed(by: disposeBag)

        self.refreshFollowing()
    }

    static let shared = FollowManager()

    let (onFollowingChangedTransmitter, onFollowingChangedReceiver) = Receiver<[User]>.make(with: .hot)
    let (onPendingFollowingChangedTransmitter, onPendingFollowingChangedReceiver) = Receiver<[User]>.make(with: .hot)

    private var following = [User]() {
        didSet {
            onFollowingChangedTransmitter.broadcast(following)
        }
    }
    private var pendingFollowing = [User]() {
        didSet {
            onPendingFollowingChangedTransmitter.broadcast(pendingFollowing)
        }
    }

    var followingCount: Int {
        return following.count
    }
    var pendingFollowingCount: Int {
        return pendingFollowing.count
    }

    func following(at index: Int) -> User {
        return following[index]
    }
    func pendingFollowing(at index: Int) -> User {
        return pendingFollowing[index]
    }

    func followed(user: User) -> Bool {
        return following.contains(user)
    }
    func isPendingFollowing(user: User) -> Bool {
        return pendingFollowing.contains(user)
    }

    func unfollow(user: User) {
        TraktAPIProvider.provider.request(.unfollow(slug: user.slug), callbackQueue: .global(qos: .userInitiated)) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    SwiftMessages.show(message: "👍 @\(user.slug) unfollowed")
                case let .failure(error):
                    SwiftMessages.show(message: "😓 Unfollow failed", style: .error(error))
                }
            }
            self.refreshFollowing()
        }
    }

    func follow(user: User) {
        func add(user: User) {
            if following.firstIndex(of: user) == nil {
                following.insert(user, at: 0)
            }
        }

        func remove(user: User) {
            if let index = following.firstIndex(of: user) {
                following.remove(at: index)
            }
        }

        if followed(user: user) {
            // Remove it from the list directly
            remove(user: user)
            TraktAPIProvider.provider.request(.unfollow(slug: user.slug), callbackQueue: .global(qos: .userInitiated)) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        remove(user: user)
                        SwiftMessages.show(message: "👍 @\(user.slug) unfollowed")
                    case let .failure(error):
                        add(user: user)
                        SwiftMessages.show(message: "😓 Unfollow failed", style: .error(error))
                    }
                }
            }
        } else {
            // Add it to the list directly
            add(user: user)
            TraktAPIProvider.provider.request(.follow(slug: user.slug), callbackQueue: .global(qos: .userInitiated)) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        add(user: user)
                        SwiftMessages.show(message: "👍 @\(user.slug) followed")
                    case let .failure(error):
                        remove(user: user)
                        SwiftMessages.show(message: "😓 Follow failed", style: .error(error))
                    }
                }
            }
        }
    }
}

private extension FollowManager {

    private func refreshFollowing() {
        if SessionManager.shared.isLoggedOut {
            return
        }

        TraktAPIProvider.provider.request(.following(slug: nil),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    let following = try response.map([Follow].self, using: TraktAPIProvider.decoder).reversed().map { $0.user }
                    DispatchQueue.main.async {
                        self.following = following
                    }
                } catch {
                    print("Following request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("Following request failure \(error)")
            }
        }

        TraktAPIProvider.provider.request(.pendingFollowing,
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    let pendingFollowing = try response.map([Follow].self, using: TraktAPIProvider.decoder).reversed().map { $0.user }
                    DispatchQueue.main.async {
                        self.pendingFollowing = pendingFollowing
                    }
                } catch {
                    print("Pending following request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("Pending following request failure \(error)")
            }
        }
    }
}

extension User {
    var isFollowing: Bool {
        return FollowManager.shared.followed(user: self)
    }
}

extension String {
    private static let slugSafeCharacters = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-")

    public func slugify() -> String {
        var result: String?

        if let latin = self.applyingTransform(StringTransform("Any-Latin; Latin-ASCII; Lower;"), reverse: false) {
            let urlComponents = latin.components(separatedBy: String.slugSafeCharacters.inverted)
            let joined = urlComponents.filter { $0 != "" }.joined(separator: "-").lowercased()
            if let regex = try? NSRegularExpression(pattern: "-+", options: []) {
                let range = NSRange(location: 0, length: joined.utf16.count)
                result = regex.stringByReplacingMatches(in: joined, options: [], range: range, withTemplate: "-")
            } else {
                // fallback
                result = joined.replacingOccurrences(of: "---", with: "-").replacingOccurrences(of: "--", with: "-")
            }
        }

        if let result = result {
            if result.count > 0 {
                return result
            }
        }

        return self
    }
}

extension String {
    private static let hashtagSafeCharacters = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_")

    public func hashtagify() -> String {
        var result: String?

        if let latin = self.applyingTransform(StringTransform("Any-Latin; Latin-ASCII; Lower;"), reverse: false) {
            let urlComponents = latin.components(separatedBy: String.hashtagSafeCharacters.inverted)
            result = urlComponents.filter { $0 != "" }.map { $0.capitalizingFirstLetter() }
                .joined(separator: "")
        }

        if let result = result {
            if result.count > 0 {
                return "#\(result)"
            }
        }

        return self
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}
