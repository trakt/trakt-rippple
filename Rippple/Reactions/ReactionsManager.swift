//
//  ReactionsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 24/07/2025.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

final class ReactionsManager {
    static let shared = ReactionsManager()

    func startManaging() {}

    private let disposeBag = DisposeBag()

    var possibleReactions = [ReactionType(type: "like", emoji: "👍"),
                             ReactionType(type: "dislike", emoji: "👎"),
                             ReactionType(type: "love", emoji: "❤️"),
                             ReactionType(type: "laugh", emoji: "😂"),
                             ReactionType(type: "shocked", emoji: "😱"),
                             ReactionType(type: "bravo", emoji: "👏"),
                             ReactionType(type: "spoiler", emoji: "🫣")]
    fileprivate var userReactions = [UserReaction]()

    private init() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refreshReactions()
                self.refreshUserCommentsReactions()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshReactions()
                    self.refreshUserCommentsReactions()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { _ in
            self.refreshUserCommentsReactions()
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.userReactions.removeAll()
        }.disposed(by: disposeBag)
    }

    private func refreshReactions() {
        if SessionManager.shared.isLoggedOut { return }

        TraktAPIProvider.provider.request(.reactions,
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    let reactions = try response.map([ReactionType].self,
                                                     using: TraktAPIProvider.decoder)

                    self.possibleReactions = reactions
                } catch {
                    print("Get /reactions request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("Get /reactions request failure \(error)")
            }
        }
    }

    fileprivate func refreshUserCommentsReactions() {
        if SessionManager.shared.isLoggedOut { return }

        TraktAPIProvider.noChacheProvider.request(.userCommentsReactions,
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let reactions = try response.map([UserReaction].self,
                                                     using: TraktAPIProvider.decoder)

                    self.userReactions = reactions
                } catch {
                    print("Get /users/me/comments/reactions request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("Get /users/me/comments/reactions request failure \(error)")
            }
        }
    }
}

extension Comment {
    func userReacted(with: String) -> Bool {
        return ReactionsManager.shared.userReactions.contains { $0.reaction.emoji == with && $0.comment?.identifier == identifier }
    }

    var userReacted: Bool {
        return ReactionsManager.shared.userReactions.contains { $0.comment?.identifier == identifier }
    }

    func addReaction(reaction: ReactionType) {
        TraktAPIProvider.provider.request(.addCommentReaction(id: identifier, reaction: reaction.type)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                    SwiftMessages.show(message: "👍 Reaction added")
                    ReactionsManager.shared.userReactions.append(.init(reactedAt: .now,
                                                                       reaction: reaction,
                                                                       type: "comment",
                                                                       comment: .init(identifier: identifier)))
                    ReactionsManager.shared.refreshUserCommentsReactions()
                    onCommentReactTransmitter.broadcast(identifier)
                } catch {
                    SwiftMessages.show(message: "😓 Reaction failed", style: .error(error))
                }
            case .failure(let error):
                SwiftMessages.show(message: "😓 Reaction failed", style: .error(error))
            }
        }
    }

    func removeReaction(reaction: ReactionType) {
        TraktAPIProvider.provider.request(.removeCommentReaction(id: identifier, reaction: reaction.type)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                    SwiftMessages.show(message: "👍 Reaction removed")
                    ReactionsManager.shared.userReactions.removeAll { $0.reaction == reaction && $0.type == "comment" && $0.comment?.identifier == identifier }
                    ReactionsManager.shared.refreshUserCommentsReactions()
                    onCommentReactTransmitter.broadcast(identifier)
                } catch {
                    SwiftMessages.show(message: "😓 Reaction failed", style: .error(error))
                }
            case .failure(let error):
                SwiftMessages.show(message: "😓 Reaction failed", style: .error(error))
            }
        }
    }
}
