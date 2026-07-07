//
//  TraktStatusCheckManager.swift
//  Rippple
//
//  Created by Kevin Cador on 26/02/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import Foundation
import Receiver

let (onLastWatchedEpisodeActivitiesChangedTransmitter, onLastWatchedEpisodeActivitiesChangedReceiver) = Receiver<LastEpisodesActivities>.make(with: .hot)
let (onLastWatchedMovieActivitiesChangedTransmitter, onLastWatchedMovieActivitiesChangedReceiver) = Receiver<LastMoviesActivities>.make(with: .hot)
let (onLastHiddenShowActivitiesChangedTransmitter, onLastHiddenShowActivitiesChangedReceiver) = Receiver<LastShowsActivities>.make(with: .hot)
let (onLastDroppedShowActivitiesChangedTransmitter, onLastDroppedShowActivitiesChangedReceiver) = Receiver<LastShowsActivities>.make(with: .hot)
let (onLastHiddenUsersFromCommentsActivitiesChangedTransmitter, onLastHiddenUsersFromCommentsActivitiesChangedReceiver) = Receiver<LastCommentsActivities>.make(with: .hot)

final class TraktStatusCheckManager {
    private let disposeBag = DisposeBag()

    private init() {
        if let data = UserDefaults.standard.data(forKey: "TraktStatusCheckManager.lastActivities"), let lastActivities = try? PropertyListDecoder().decode(LastActivities.self, from: data) {
            self.lastActivities = lastActivities
        }
    }

    private var refreshTimer: Timer?

    func setup() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            TraktStatusCheckManager.shared.refresh()
        }
    }

    static let shared = TraktStatusCheckManager()

    private var lastActivities: LastActivities? {
        didSet {
            if let lastEpisodeActivities = lastActivities?.episodes, oldValue?.episodes != lastEpisodeActivities {
                onLastWatchedEpisodeActivitiesChangedTransmitter.broadcast(lastEpisodeActivities)
            }
            if let lastMoviesActivities = lastActivities?.movies, oldValue?.movies != lastMoviesActivities {
                onLastWatchedMovieActivitiesChangedTransmitter.broadcast(lastMoviesActivities)
            }
            if let lastShowActivities = lastActivities?.shows, oldValue?.shows.hiddenAt != lastShowActivities.hiddenAt {
                onLastHiddenShowActivitiesChangedTransmitter.broadcast(lastShowActivities)
            }
            if let lastShowActivities = lastActivities?.shows, oldValue?.shows.droppedAt != lastShowActivities.droppedAt {
                onLastDroppedShowActivitiesChangedTransmitter.broadcast(lastShowActivities)
            }
            if let lastCommentsActivities = lastActivities?.comments, oldValue?.comments != lastCommentsActivities {
                onLastHiddenUsersFromCommentsActivitiesChangedTransmitter.broadcast(lastCommentsActivities)
            }
            UserDefaults.standard.set(try? PropertyListEncoder().encode(lastActivities), forKey: "TraktStatusCheckManager.lastActivities")
            UserDefaults.standard.synchronize()
        }
    }

    func refresh() {
        refreshTimer?.invalidate()
        if SessionManager.shared.isLoggedOut {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                TraktStatusCheckManager.shared.refresh()
            }
            return
        }
        TraktAPIProvider.provider.request(.lastActivities,
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let lastActivities = try response.map(LastActivities.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.lastActivities = lastActivities
                        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                            TraktStatusCheckManager.shared.refresh()
                        }
                    }
                } catch {
                    print("LastActivities request JSON mapping failed! \(error)")
                    DispatchQueue.main.async {
                        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                            TraktStatusCheckManager.shared.refresh()
                        }
                    }
                }
            case .failure(let error):
                print("LastActivities request failure \(error)")
                DispatchQueue.main.async {
                    self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                        TraktStatusCheckManager.shared.refresh()
                    }
                }
            }
        }
    }
}
