//
//  MediaReactionsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 14/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import LRUCache
import Moya
import Receiver

let (onMediaReactionsChangedTransmitter, onMediaReactionsChangedReceiver) = Receiver<MediaReactionsTarget>.make(with: .hot)
let (onEmojiReactionsDisplayTransmitter, onEmojiReactionsDisplayReceiver) = Receiver<Bool>.make(with: .hot)

final class MediaReactionsManager {
    static let shared = MediaReactionsManager()
    static let maximumReactionsPerMedia = 3

    /// Opt-out setting: when off, reactions are neither shown nor sendable.
    static var isEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "EmojiReactionsSettings.enabled")
    }

    static var isShowerEnabled: Bool {
        return isEnabled && UserDefaults.standard.bool(forKey: "EmojiReactionsSettings.shower")
    }

    /// Reactions are only shown on movies and shows for now: seasons and episodes keep the data logic, hidden.
    static func showsReactions(for media: MediaModel?) -> Bool {
        return isEnabled && (media?.movie != nil || media?.showShow != nil)
    }

    func startManaging() {}

    private let disposeBag = DisposeBag()

    private struct CachedSummary {
        let summary: MediaReactionsSummary
        let date: Date
    }

    private let summaries = LRUCache<MediaReactionsTarget, CachedSummary>(countLimit: 100)
    private let heldReactions = LRUCache<MediaReactionsTarget, [UserMediaReaction]>(countLimit: 100)

    /// Picker order, refreshed from the API. Main thread confined.
    private(set) var possibleReactions = [ReactionType(type: "heart_eyes", emoji: "😍"),
                                          ReactionType(type: "love", emoji: "❤️"),
                                          ReactionType(type: "rofl", emoji: "🤣"),
                                          ReactionType(type: "holding_back_tears", emoji: "🥹"),
                                          ReactionType(type: "partying", emoji: "🥳"),
                                          ReactionType(type: "mind_blown", emoji: "🤯"),
                                          ReactionType(type: "cursing", emoji: "🤬"),
                                          ReactionType(type: "weary", emoji: "😩"),
                                          ReactionType(type: "woozy", emoji: "🥴"),
                                          ReactionType(type: "yawning", emoji: "🥱"),
                                          ReactionType(type: "spoiler", emoji: "🫣"),
                                          ReactionType(type: "shushing", emoji: "🤫"),
                                          ReactionType(type: "smiling_tear", emoji: "🥲"),
                                          ReactionType(type: "neutral", emoji: "😐"),
                                          ReactionType(type: "shocked", emoji: "😱"),
                                          ReactionType(type: "anxious", emoji: "😰"),
                                          ReactionType(type: "thinking", emoji: "🤔"),
                                          ReactionType(type: "flushed", emoji: "😳"),
                                          ReactionType(type: "melting", emoji: "🫠"),
                                          ReactionType(type: "grimacing", emoji: "😬"),
                                          ReactionType(type: "vomiting", emoji: "🤮"),
                                          ReactionType(type: "eye_roll", emoji: "🙄"),
                                          ReactionType(type: "like", emoji: "👍"),
                                          ReactionType(type: "rock_on", emoji: "🤘"),
                                          ReactionType(type: "dislike", emoji: "👎"),
                                          ReactionType(type: "bravo", emoji: "👏"),
                                          ReactionType(type: "skull", emoji: "💀"),
                                          ReactionType(type: "popcorn", emoji: "🍿"),
                                          ReactionType(type: "fire", emoji: "🔥"),
                                          ReactionType(type: "crying", emoji: "😭"),
                                          ReactionType(type: "pinched_fingers", emoji: "🤌"),
                                          ReactionType(type: "broken_heart", emoji: "💔"),
                                          ReactionType(type: "freezing", emoji: "🥶"),
                                          ReactionType(type: "disguised", emoji: "🥸"),
                                          ReactionType(type: "nerd", emoji: "🤓"),
                                          ReactionType(type: "monocle", emoji: "🧐")]

    private init() {
        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refreshPossibleReactions()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshPossibleReactions()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.heldReactions.removeAll()
            }
        }.disposed(by: disposeBag)
    }

    // MARK: - Cache

    func summary(for target: MediaReactionsTarget) -> MediaReactionsSummary? {
        return summaries.value(forKey: target)?.summary
    }

    func heldReactions(for target: MediaReactionsTarget) -> [UserMediaReaction]? {
        return heldReactions.value(forKey: target)
    }

    // MARK: - Fetching

    private func refreshPossibleReactions() {
        TraktAPIProvider.provider.request(.mediaReactionTypes, callbackQueue: .global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }
            guard let reactions = try? result.get().filterSuccessfulStatusCodes().map([ReactionType].self, using: TraktAPIProvider.decoder),
                  !reactions.isEmpty else {
                print("Get /v3/reactions/media request failed")
                return
            }
            DispatchQueue.main.async {
                self.possibleReactions = reactions
            }
        }
    }

    /// Completes on the main thread, from the cache when it is less than 5 minutes old.
    @discardableResult
    func fetchSummary(for target: MediaReactionsTarget,
                      ignoringCache: Bool = false,
                      completion: @escaping (MediaReactionsSummary?) -> Void) -> Cancellable? {
        if !ignoringCache, let cached = summaries.value(forKey: target), cached.date.timeIntervalSinceNow > -300 {
            DispatchQueue.main.async {
                completion(cached.summary)
            }
            return nil
        }

        let provider = ignoringCache ? TraktAPIProvider.noChacheProvider : TraktAPIProvider.provider
        let requestDate = Date()
        return provider.request(.mediaReactionsSummary(target: target), callbackQueue: .global(qos: .utility)) { [weak self] result in
            let summary = try? result.get().filterSuccessfulStatusCodes().map(MediaReactionsSummary.self, using: TraktAPIProvider.decoder)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // A refetch started later, after a reaction, already landed: keep it.
                if !ignoringCache, let cached = self.summaries.value(forKey: target), cached.date > requestDate {
                    completion(cached.summary)
                    return
                }
                if let summary = summary {
                    self.summaries.setValue(CachedSummary(summary: summary, date: Date()), forKey: target)
                }
                completion(summary)
            }
        }
    }

    /// Completes on the main thread, without a request and with no reactions when logged out.
    @discardableResult
    func fetchHeldReactions(for target: MediaReactionsTarget,
                            completion: @escaping ([UserMediaReaction]?) -> Void) -> Cancellable? {
        guard TraktAPIProvider.source.token != nil else {
            DispatchQueue.main.async {
                completion([])
            }
            return nil
        }

        return TraktAPIProvider.noChacheProvider.request(.userMediaReactions(target: target), callbackQueue: .global(qos: .utility)) { [weak self] result in
            let reactions = try? result.get().filterSuccessfulStatusCodes().map([UserMediaReaction].self, using: TraktAPIProvider.decoder)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let reactions = reactions {
                    self.heldReactions.setValue(reactions, forKey: target)
                }
                completion(reactions)
            }
        }
    }

    // MARK: - Reacting

    /// `completion` is called on the main thread once the caches match the server, with `true` on success.
    func react(to target: MediaReactionsTarget, with reaction: ReactionType, completion: ((Bool) -> Void)? = nil) {
        guard TraktAPIProvider.source.token != nil else {
            onNeedsToShowLoginTransmitter.broadcast(true)
            completion?(false)
            return
        }

        TraktAPIProvider.provider.request(.addMediaReaction(target: target, reaction: reaction.type)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse) where moyaResponse.statusCode == 409:
                SwiftMessages.show(message: "😓 You can send up to 3 reactions")
                self.sync(target, refetchingHeld: true, succeeded: false, completion: completion)
            case .success(let moyaResponse):
                do {
                    // The response is the user's held reactions.
                    let reactions = try moyaResponse.filterSuccessfulStatusCodes().map([UserMediaReaction].self, using: TraktAPIProvider.decoder)
                    self.heldReactions.setValue(reactions, forKey: target)
                    SwiftMessages.show(message: "👍 Reaction added")
                    AppManager.shared.emitEmoji(emoji: reaction.emoji)
                    self.sync(target, refetchingHeld: false, succeeded: true, completion: completion)
                } catch {
                    SwiftMessages.show(message: "😓 Reaction failed", style: .error(error))
                    self.sync(target, refetchingHeld: true, succeeded: false, completion: completion)
                }
            case .failure(let error):
                SwiftMessages.show(message: "😓 Reaction failed", style: .error(error))
                completion?(false)
            }
        }
    }

    /// `completion` is called on the main thread once the caches match the server, with `true` on success.
    func removeReaction(_ reaction: ReactionType, from target: MediaReactionsTarget, completion: ((Bool) -> Void)? = nil) {
        guard TraktAPIProvider.source.token != nil else {
            onNeedsToShowLoginTransmitter.broadcast(true)
            completion?(false)
            return
        }

        let held = heldReactions.value(forKey: target) ?? []
        let ids = held.filter { $0.reaction.type == reaction.type }.map { $0.id }
        TraktAPIProvider.provider.request(.removeMediaReactions(target: target, ids: ids)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                    self.heldReactions.setValue(held.filter { !ids.contains($0.id) }, forKey: target)
                    SwiftMessages.show(message: "👍 Reaction removed")
                    self.sync(target, refetchingHeld: false, succeeded: true, completion: completion)
                } catch {
                    SwiftMessages.show(message: "😓 Reaction failed", style: .error(error))
                    self.sync(target, refetchingHeld: true, succeeded: false, completion: completion)
                }
            case .failure(let error):
                SwiftMessages.show(message: "😓 Reaction failed", style: .error(error))
                self.sync(target, refetchingHeld: true, succeeded: false, completion: completion)
            }
        }
    }

    /// Refetches the summary, and the held reactions when the server rejected a reaction, so the caches match
    /// the server, then tells listeners.
    private func sync(_ target: MediaReactionsTarget, refetchingHeld: Bool, succeeded: Bool, completion: ((Bool) -> Void)?) {
        guard refetchingHeld else {
            syncSummary(target, succeeded: succeeded, completion: completion)
            return
        }
        fetchHeldReactions(for: target) { [weak self] _ in
            guard let self = self else { return }
            self.syncSummary(target, succeeded: succeeded, completion: completion)
        }
    }

    private func syncSummary(_ target: MediaReactionsTarget, succeeded: Bool, completion: ((Bool) -> Void)?) {
        fetchSummary(for: target, ignoringCache: true) { _ in
            onMediaReactionsChangedTransmitter.broadcast(target)
            completion?(succeeded)
        }
    }
}
