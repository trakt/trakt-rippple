//
//  PinnedShowsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 13/11/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver
import UIKit

let (onPinnedShowsToWatchChangedTransmitter, onPinnedShowsToWatchChangedReceiver) = Receiver<[Show]>.make(with: .warm(upTo: 1))
let (onPinnedShowToWatchAddedTransmitter, onPinnedShowToWatchAddedReceiver) = Receiver<Show>.make(with: .hot)
let (onPinnedShowToWatchRemovedTransmitter, onPinnedShowToWatchRemovedReceiver) = Receiver<Show>.make(with: .hot)

final class PinnedShowsManager {
    static let shared = PinnedShowsManager()

    private let disposeBag = DisposeBag()

    private var refreshed = false

    private init() {
        if let encodedShows = NSUbiquitousKeyValueStore.default.object(forKey: "EpisodeToWatchManager.pinnedShows") as? Data {
            if let pinnedShows = try? JSONDecoder().decode(Set<Show>.self, from: encodedShows) {
                self.pinnedShows = Set<Show>(pinnedShows)
                onPinnedShowsToWatchChangedTransmitter.broadcast([Show](self.pinnedShows.filter { !$0.isHiddenFromProgress }))
                return
            }
        }
        pinnedShows = Set<Show>()
        onPinnedShowsToWatchChangedTransmitter.broadcast([Show](pinnedShows.filter { !$0.isHiddenFromProgress }))
    }

    var pinnedShows = Set<Show>() {
        didSet {
            if pinnedShows.isEmpty == false, refreshed == false {
                // refresh all pinned show only when the app is started to avoid doing it too much
                _Concurrency.Task {
                    var fullPinnedShow = Set<Show>()
                    for show in pinnedShows {
                        let fullShow = await fetchShow(show: show)
                        fullPinnedShow.insert(fullShow)
                    }
                    for show in fullPinnedShow where show.status == "canceled" || show.status == "ended" {
                        if let progress = await show.mediaModel.progress() {
                            if progress.nextEpisodeToWatch == nil,
                               progress.nextToRewatch == nil,
                               progress.behind == 0 {
                                fullPinnedShow.remove(show)
                            }
                        }
                    }
                    refreshed = true
                    pinnedShows = fullPinnedShow
                    storeAndTransmit(pinnedShows: pinnedShows)
                }
            } else if pinnedShows != oldValue {
                // if it's not the first launch and the pinned shows changed -> update the shows that need an update
                _Concurrency.Task {
                    var fullPinnedShow = Set<Show>()
                    for show in pinnedShows {
                        if show.rating == nil {
                            let fullShow = await fetchShow(show: show)
                            fullPinnedShow.insert(fullShow)
                        } else {
                            fullPinnedShow.insert(show)
                        }
                    }
                    pinnedShows = fullPinnedShow
                    storeAndTransmit(pinnedShows: pinnedShows)
                }
            }
        }
    }

    private func storeAndTransmit(pinnedShows: Set<Show>) {
        DispatchQueue.main.async {
            onPinnedShowsToWatchChangedTransmitter.broadcast([Show](pinnedShows.filter { !$0.isHiddenFromProgress }))
        }
        if let encoded = try? JSONEncoder().encode(pinnedShows) {
            NSUbiquitousKeyValueStore.default.set(encoded, forKey: "EpisodeToWatchManager.pinnedShows")
        }
    }

    func setup() {
        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if UserManager.shared.currentUser != nil {
                self.loadPinnedShows()

                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(loadPinnedShows),
                                                       name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                       object: nil)
            }
        }.disposed(by: disposeBag)
    }

    @objc private func loadPinnedShows() {
        if let encodedShows = NSUbiquitousKeyValueStore.default.object(forKey: "EpisodeToWatchManager.pinnedShows") as? Data {
            if let pinnedShows = try? JSONDecoder().decode(Set<Show>.self, from: encodedShows) {
                self.pinnedShows = Set<Show>(pinnedShows)
                return
            }
        }
        pinnedShows = Set<Show>()
    }

    /// Fetch the full show async + return the old Show if there's an error to not loose it
    private func fetchShow(show: Show) async -> Show {
        return await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.show(id: show.identifiers.traktIdOrSlug, extended: .full), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let fullShow = try response.map(Show.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: fullShow)
                    } catch {
                        continuation.resume(returning: show)
                    }
                case .failure:
                    continuation.resume(returning: show)
                }
            }
        }
    }
}

extension Show {
    func pin() {
        if !PurchaseManager.shared.purchased {
            UIApplication.shared.switchToPurchase()
            return
        }
        PinnedShowsManager.shared.pinnedShows.insert(self)
        onPinnedShowToWatchAddedTransmitter.broadcast(self)
        SwiftMessages.show(message: "📌 Pinned")
    }

    func unpin() {
        PinnedShowsManager.shared.pinnedShows.remove(self)
        onPinnedShowToWatchRemovedTransmitter.broadcast(self)
        SwiftMessages.show(message: "📌 Unpinned")
    }

    var isPinned: Bool {
        return PinnedShowsManager.shared.pinnedShows.contains(self)
    }
}
