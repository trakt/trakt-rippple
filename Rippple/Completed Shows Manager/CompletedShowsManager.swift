//
//  CompletedShowsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 22/02/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import Foundation
import Receiver
import TinyStorage

let (onCompletedShowsChangedTransmitter, onCompletedShowsChangedReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))

private struct CompletedShow: Codable, Hashable {
    let show: Show
    let lastWatchedAt: Date
}

final class CompletedShowsManager {
    private let disposeBag = DisposeBag()
    private let stateLock = NSLock()

    private init() {}

    private var debouncedTransmit: Debouncer!

    var completedShowsModels: [MediaModel] {
        let snapshot = withStateLock { completedShows }

        return snapshot
            .sorted { $0.lastWatchedAt > $1.lastWatchedAt }
            .filter { $0.show.isHiddenFromProgress == false }
            .compactMap { $0.show.mediaModel }
    }

    func setup() {
        debouncedTransmit = Debouncer(delay: 0.3) { [weak self] in
            guard let self = self else { return }
            self.transmit()
        }

        if let array = TinyStorage.cache.retrieve(type: [CompletedShow].self, forKey: "CompletedShowsManager.completedShows") {
            updateCompletedShows { completedShows in
                completedShows = array
            }
        }

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.withStateLock {
                self.completedShows.removeAll()
                self.completedShowSet.removeAll()
            }
            TinyStorage.cache.remove(key: "CompletedShowsManager.completedShows")
            self.debouncedTransmit.fireNow()
        }.disposed(by: disposeBag)

        onShowsHiddenFromProgressMediaChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            onCompletedShowsChangedTransmitter.broadcast(self.completedShowsModels)
        }.disposed(by: disposeBag)

        onProgressCacheChangedReceiver.listen { [weak self] showShowProgress in
            guard let self = self else { return }
            self.checkCompleted(progress: showShowProgress)
        }.disposed(by: disposeBag)

        onProgressCacheHitReceiver.listen { [weak self] showShowProgress in
            guard let self = self else { return }
            self.checkCompleted(progress: showShowProgress)
        }.disposed(by: disposeBag)
    }

    private func checkCompleted(progress: ShowShowProgress) {
        let show = progress.show

        // if it's not in watched, don't try to check if it's complete
        guard let lastWatchedAt = progress.showProgress.lastWatchedAt else {
            updateCompletedShows { completedShows in
                completedShows.removeAll(where: { $0.show == show })
            }
            return
        }

        // don't check if the status is unclear
        if show.status == nil { return }

        // the shows's complete
        if show.status == "canceled" || show.status == "ended", progress.showProgress.nextEpisodeToWatch == nil, progress.showProgress.nextToRewatch == nil {
            updateCompletedShows { completedShows in
                if completedShows.contains(where: { $0.show == show }) == false {
                    completedShows.append(CompletedShow(show: show,
                                                        lastWatchedAt: lastWatchedAt))
                }
            }
        } else {
            updateCompletedShows { completedShows in
                completedShows.removeAll(where: { $0.show == show })
            }
        }
    }

    static let shared = CompletedShowsManager()

    private var completedShowSet = Set<Int64>()
    private var completedShows = [CompletedShow]()

    private func withStateLock<T>(_ work: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return work()
    }

    private func updateCompletedShows(_ update: (inout [CompletedShow]) -> Void) {
        let updatedShows: [CompletedShow]? = withStateLock {
            let oldShows = completedShows
            update(&completedShows)
            guard Set(oldShows) != Set(completedShows) else { return nil }
            completedShowSet = Set(completedShows.compactMap { $0.show.identifiers.trakt })
            return completedShows
        }

        guard let updatedShows else { return }
        debouncedTransmit.call()
        TinyStorage.cache.store(updatedShows, forKey: "CompletedShowsManager.completedShows")
    }

    private func transmit() {
        onCompletedShowsChangedTransmitter.broadcast(completedShowsModels)
    }

    var completedShowCount: Int {
        return withStateLock { completedShows.count }
    }

    fileprivate func containsCompletedShow(traktId: Int64) -> Bool {
        return withStateLock { completedShowSet.contains(traktId) }
    }
}

extension Show {
    var isCompleted: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CompletedShowsManager.shared.containsCompletedShow(traktId: traktId)
    }
}
