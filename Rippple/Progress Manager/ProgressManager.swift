//
//  ProgressManager.swift
//  Rippple
//
//  Created by Kevin Cador on 01/08/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Foundation

import Receiver
import LRUCache

struct ShowShowProgress {
    let show: Show
    let showProgress: ShowProgress
}
let (onProgressCacheChangedTransmitter, onProgressCacheChangedReceiver) = Receiver<ShowShowProgress>.make(with: .hot)
let (onProgressCacheHitTransmitter, onProgressCacheHitReceiver) = Receiver<ShowShowProgress>.make(with: .hot)

final class ProgressManager {

    private let disposeBag = DisposeBag()

    private init() { }

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

    public func refreshProgress(for show: Show) {
        print("ProgressCache - FORCE REFRESHING progress for \(show.title)")
        guard let key = show.identifiers.trakt else { return }
        cache.removeValue(forKey: key)
        show.mediaModel.progress { _ in }
    }

    public func resetCache(for show: Show) {
        print("ProgressCache - RESET progress for \(show.title)")
        guard let key = show.identifiers.trakt else { return }
        cache.removeValue(forKey: key)
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
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                    let showShowProgress = ShowShowProgress(show: show,
                                                            showProgress: showProgress)
                    ProgressManager.shared.cache.setValue(showShowProgress, forKey: showId)
                    onProgressCacheChangedTransmitter.broadcast(showShowProgress)
                    completion(showProgress)
                } catch {
                    print("Error Fetching Show progress \(error)")
                    completion(nil)
                }
            case let .failure(error):
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
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                        let showShowProgress = ShowShowProgress(show: show,
                                                                showProgress: showProgress)
                        ProgressManager.shared.cache.setValue(showShowProgress, forKey: showId)
                        onProgressCacheChangedTransmitter.broadcast(showShowProgress)
                        completion(showProgress)
                    } catch {
                        print("Error Fetching Show progress \(error)")
                        completion(nil)
                    }
                case let .failure(error):
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
                        case let .success(moyaResponse):
                            do {
                                let response = try moyaResponse.filterSuccessfulStatusCodes()

                                let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                                let showShowProgress = ShowShowProgress(show: show,
                                                                        showProgress: showProgress)
                                ProgressManager.shared.cache.setValue(showShowProgress, forKey: showId)
                                onProgressCacheChangedTransmitter.broadcast(showShowProgress)
                                continuation.resume(returning: showProgress)
                            } catch {
                                print("Error Fetching Show progress \(error)")
                                continuation.resume(throwing: error)
                            }
                        case let .failure(error):
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
