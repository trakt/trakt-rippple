//
//  ProgressManager.swift
//  Rippple
//
//  Created by Kevin Cador on 01/08/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Foundation
import LRUCache
import Receiver

struct ShowShowProgress {
    let show: Show
    let showProgress: ShowProgress
}

let (onProgressCacheChangedTransmitter, onProgressCacheChangedReceiver) = Receiver<ShowShowProgress>.make(with: .hot)
let (onProgressCacheHitTransmitter, onProgressCacheHitReceiver) = Receiver<ShowShowProgress>.make(with: .hot)

final class ProgressManager {
    private let disposeBag = DisposeBag()

    private init() {}

    fileprivate var cache = LRUCache<Int64, ShowShowProgress>()

    static let shared = ProgressManager()

    func setup() {
        onSettingsChangedReceiver.listen { [weak self] settings in
            guard let self = self else { return }
            if settings == nil {
                self.cache.removeAll()
            }
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] watchingItem, oldWatchingItem in
            guard let self = self else { return }
            if let watchingItem = watchingItem, let show = watchingItem.show { // checkin
                self.refreshProgress(for: show)
            }
            if let oldWatchingItem = oldWatchingItem, let show = oldWatchingItem.show { // cancel checkin or end of checkin
                self.refreshProgress(for: show)
            }
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { [weak self] media in
            guard let self = self else { return }
            switch media {
            case .episode(_, let show), .show(let show), .season(_, let show):
                self.refreshProgress(for: show)
            default:
                break
            }
        }.disposed(by: disposeBag)

        onRemoveWatchMediaReceiver.listen { [weak self] media in
            guard let self = self else { return }
            switch media {
            case .episode(_, let show):
                self.refreshProgress(for: show)
            default:
                break
            }
        }.disposed(by: disposeBag)
    }

    func refreshProgress(for show: Show) {
        print("ProgressCache - FORCE REFRESHING progress for \(show.title)")
        guard let key = show.identifiers.trakt else { return }
        cache.removeValue(forKey: key)
        show.mediaModel.progress { _ in }
    }

    func resetCache(for show: Show) {
        print("ProgressCache - RESET progress for \(show.title)")
        guard let key = show.identifiers.trakt else { return }
        cache.removeValue(forKey: key)
    }

    func processAndCacheProgress(for show: Show,
                                 showId: Int64,
                                 progress: ShowProgress,
                                 completion: @escaping (ShowProgress) -> Void) {
        let cacheAndComplete: (ShowProgress) -> Void = { [weak self] finalProgress in
            guard let self = self else { return }
            let showShowProgress = ShowShowProgress(show: show,
                                                    showProgress: finalProgress)
            self.cache.setValue(showShowProgress, forKey: showId)
            onProgressCacheChangedTransmitter.broadcast(showShowProgress)
            completion(finalProgress)
        }

        guard let nextToRewatch = progress.nextToRewatch else {
            cacheAndComplete(progress)
            return
        }

        TraktAPIProvider.provider.request(.episode(id: String(showId),
                                                   season: nextToRewatch.0.number,
                                                   episode: nextToRewatch.1.number),
                                          callbackQueue: .global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)
                    let updatedProgress = progress.with(nextEpisode: episode)
                    cacheAndComplete(updatedProgress)
                } catch {
                    print("Error fetching episode for next to rewatch \(error)")
                    cacheAndComplete(progress)
                }
            case .failure(let error):
                print("Failed fetching episode for next to rewatch \(error)")
                cacheAndComplete(progress)
            }
        }
    }
}

extension MediaModel {
    func forceProgress(with completion: @escaping (_ progress: ShowProgress?) -> Void) {
        guard UserManager.shared.currentUser != nil else {
            completion(nil)
            return
        }

        guard let show = show else {
            completion(nil)
            return
        }
        guard let showId = show.identifiers.trakt else {
            completion(nil)
            return
        }

        print("ProgressCache - FORCED Fecthing progress on Trakt for \(show.title)")
        TraktAPIProvider.noChacheProvider.request(TraktAPIService.showProgress(id: showId, includesSpecials: false), callbackQueue: .global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                    ProgressManager.shared.processAndCacheProgress(for: show,
                                                                   showId: showId,
                                                                   progress: showProgress) { finalProgress in
                        completion(finalProgress)
                    }
                } catch {
                    print("Error Fetching Show progress \(error)")
                    completion(nil)
                }
            case .failure(let error):
                print("Error Fetching Show progress \(error)")
                completion(nil)
            }
        }
    }

    func progress(with completion: @escaping (_ progress: ShowProgress?) -> Void) {
        guard UserManager.shared.currentUser != nil else {
            completion(nil)
            return
        }

        guard let show = show else {
            completion(nil)
            return
        }
        guard let showId = show.identifiers.trakt else {
            completion(nil)
            return
        }

        if let cachedProgress = ProgressManager.shared.cache.value(forKey: showId) {
            print("ProgressCache - Using cached progress for \(show.title)")
            onProgressCacheHitTransmitter.broadcast(ShowShowProgress(show: cachedProgress.show,
                                                                     showProgress: cachedProgress.showProgress))
            completion(cachedProgress.showProgress)
        } else {
            print("ProgressCache - Fecthing progress on Trakt for \(show.title)")
            TraktAPIProvider.noChacheProvider.request(TraktAPIService.showProgress(id: showId, includesSpecials: false), callbackQueue: .global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                        ProgressManager.shared.processAndCacheProgress(for: show,
                                                                       showId: showId,
                                                                       progress: showProgress) { finalProgress in
                            completion(finalProgress)
                        }
                    } catch {
                        print("Error Fetching Show progress \(error)")
                        completion(nil)
                    }
                case .failure(let error):
                    print("Error Fetching Show progress \(error)")
                    completion(nil)
                }
            }
        }
    }

    func progress() async -> ShowProgress? {
        guard UserManager.shared.currentUser != nil else {
            return nil
        }

        guard let show = show else {
            return nil
        }

        guard let showId = show.identifiers.trakt else {
            return nil
        }

        if let cachedProgress = ProgressManager.shared.cache.value(forKey: showId) {
            print("ProgressCache - Using cached progress for \(show.title)")
            onProgressCacheHitTransmitter.broadcast(cachedProgress)
            return cachedProgress.showProgress
        } else {
            print("ProgressCache - Fecthing progress on Trakt for \(show.title)")
            do {
                let result: ShowProgress = try await withCheckedThrowingContinuation { continuation in
                    TraktAPIProvider.noChacheProvider.request(.showProgress(id: showId, includesSpecials: false), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                        switch result {
                        case .success(let moyaResponse):
                            do {
                                let response = try moyaResponse.filterSuccessfulStatusCodes()

                                let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                                ProgressManager.shared.processAndCacheProgress(for: show,
                                                                               showId: showId,
                                                                               progress: showProgress) { finalProgress in
                                    continuation.resume(returning: finalProgress)
                                }
                            } catch {
                                print("Error Fetching Show progress \(error)")
                                continuation.resume(throwing: error)
                            }
                        case .failure(let error):
                            print("Error Fetching Show progress \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                }
                return result
            } catch {
                return nil
            }
        }
    }
}

extension ShowProgress {
    func with(nextEpisode: Episode?) -> ShowProgress {
        ShowProgress(aired: aired,
                     completed: completed,
                     lastWatchedAt: lastWatchedAt,
                     nextEpisodeToWatch: nextEpisode,
                     resetAt: resetAt,
                     seasons: seasons,
                     lastEpisode: lastEpisode)
    }
}
