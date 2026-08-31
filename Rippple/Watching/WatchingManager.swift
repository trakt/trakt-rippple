//
//  WatchingManager.swift
//  Rippple
//
//  Created by Kevin Cador on 05/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver

final class WatchingManager {
    static let shared = WatchingManager()

    private let disposeBag = DisposeBag()

    let (onWatchingItemChangedTransmitter, onWatchingItemChangedReceiver) = Receiver<(WatchingItem?, WatchingItem?)>.make(with: .warm(upTo: 1))
    let (onProgressChangedTransmitter, onProgressChangedReceiver) = Receiver<Double>.make(with: .warm(upTo: 1))

    var refreshWatchingTimer: Timer?
    var refreshProgressTimer: Timer!

    var watchingItem: WatchingItem? {
        didSet {
            if watchingItem != oldValue {
                onWatchingItemChangedTransmitter.broadcast((watchingItem, oldValue))
            }
        }
    }

    var progress: Double = 0 {
        didSet {
            onProgressChangedTransmitter.broadcast(progress)
        }
    }

    var latestProgress: Double {
        guard let watchingItem = watchingItem else {
            return 0.0
        }

        let now = Date().timeIntervalSinceReferenceDate
        let start = watchingItem.startDate.timeIntervalSinceReferenceDate
        let end = watchingItem.expireDate.timeIntervalSinceReferenceDate

        return (now - start) / (end - start)
    }

    private func updateProgress() {
        let currentProgress = latestProgress

        if currentProgress == 0.0, progress != 0.0 {
            progress = 0.0
        } else if currentProgress != progress {
            progress = currentProgress
        }
    }

    private init() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didBecomeActive, .didFinishLaunching:
                self.refreshWatching()
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { _ in
            self.refreshWatching()
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.refreshWatchingTimer?.invalidate()
            self.updateWatchingItem(with: nil)
            self.progress = 0
        }.disposed(by: disposeBag)

        refreshProgressTimer = Timer.scheduledTimer(withTimeInterval: 5.0,
                                                    repeats: true) { _ in
            self.updateProgress()
        }
    }

    func refreshWatching(after time: Double = 0) {
        guard let refreshTimer = refreshWatchingTimer, refreshTimer.isValid else {
            // No refresh timer in progress. Creating one.
            refreshWatchingTimer = Timer.scheduledTimer(withTimeInterval: time,
                                                        repeats: false,
                                                        block: { _ in
                                                            self.fetchWatching()
                                                        })
            return
        }
        // A refresh timer is already in progress.
        if time == 0.0 {
            refreshTimer.invalidate()
            fetchWatching()
        }
    }

    func refreshWatching(with media: MediaModel?) {
        updateWatchingItem(with: media.map { WatchingItem(media: $0) })
        refreshWatching()
    }

    func updateWatchingItem(with item: WatchingItem?, forceBroadcast: Bool = false) {
        let previousItem = watchingItem
        watchingItem = item
        if forceBroadcast, previousItem == item {
            onWatchingItemChangedTransmitter.broadcast((item, previousItem))
        }
    }

    private func fetchWatching() {
        if SessionManager.shared.isLoggedOut {
            updateWatchingItem(with: nil)
            return
        }

        TraktAPIProvider.provider.request(.watching(slug: "me"),
                                          callbackQueue: .global(qos: .utility)) { result in
            defer {
                DispatchQueue.main.async {
                    self.refreshWatching(after: 5)
                }
            }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    if response.statusCode == 204 {
                        DispatchQueue.main.async {
                            self.updateWatchingItem(with: nil)
                        }
                        return
                    }

                    let watchingItem = try response.map(WatchingItem.self, using: TraktAPIProvider.decoder)

                    print("Fetched watching")
                    DispatchQueue.main.async {
                        self.updateWatchingItem(with: watchingItem)
                    }
                } catch {
                    print("Watching request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("Watching request failure \(error)")
            }
        }
    }
}

extension Movie {
    var isCurrentlyWatching: Bool {
        guard let watching = WatchingManager.shared.watchingItem else { return false }
        guard let watchingMovie = watching.movie else { return false }
        return watchingMovie == self
    }
}

extension Episode {
    var isCurrentlyWatching: Bool {
        guard let watching = WatchingManager.shared.watchingItem else { return false }
        guard let watchingEpisode = watching.episode else { return false }
        return watchingEpisode == self
    }
}

extension Show {
    var isCurrentlyWatching: Bool {
        guard let watching = WatchingManager.shared.watchingItem else { return false }
        guard let watchingShow = watching.show else { return false }
        return watchingShow == self
    }
}
