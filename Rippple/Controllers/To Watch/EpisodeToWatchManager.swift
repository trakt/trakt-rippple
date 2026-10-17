//
//  EpisodeToWatchManager.swift
//  Rippple
//
//  Created by Kevin Cador on 07/05/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver
import TinyStorage
import UserNotifications

let (onEpisodeToWatchChangedTransmitter, onEpisodeToWatchChangedReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
let (onShowsToWatchChangedTransmitter, onShowsToWatchChangedReceiver) = Receiver<[Show]>.make(with: .warm(upTo: 1))
let (onEpisodeToWatchStatusChangedTransmitter, onEpisodeToWatchStatusChangedReceiver) = Receiver<EpisodeToWatchManager.Status>.make(with: .warm(upTo: 1))

let (onRewatchingChangedTransmitter, onRewatchingChangedReceiver) = Receiver<Show>.make(with: .hot)

final class EpisodeToWatchManager {
    private static let fallbackRetryDelays: [TimeInterval] = [2.0, 4.0]

    private var debouncedForceRefresh: Debouncer!
    private var debouncedTransmit: Debouncer!
    private var debouncedRefreshProgress: Debouncer!

    private let fallbackRetryLock = NSLock()
    private var fallbackRetryGeneration = 0
    private var fallbackRetryWorkItem: DispatchWorkItem?

    enum Status {
        case loading
        case content
    }

    static let shared = EpisodeToWatchManager()

    private let disposeBag = DisposeBag()

    private init() {
        debouncedForceRefresh = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }
            self.forceRefresh()
        }
        debouncedTransmit = Debouncer(delay: 0.3) { [weak self] in
            guard let self = self else { return }
            self.transmit()
        }
        debouncedRefreshProgress = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }
            self.refreshProgress()
        }
    }

    var showsInList: [ToWatchGroup<Show>]? {
        didSet {
            TinyStorage.cache.store(showsInList, forKey: "EpisodeToWatchManager.showsInList")
        }
    }

    private let operationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Episode to-watch operation queue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private var status = Status.content {
        didSet {
            if status != oldValue {
                onEpisodeToWatchStatusChangedTransmitter.broadcast(status)
            }
        }
    }

    var shows: Set<Show>? {
        didSet {
            if let shows = shows {
                print("EpisodeToWatchManager.shows didSet -> Transmitting showsToWatch")
                let filteredShows = shows.filter { show -> Bool in
                    if show.isHiddenFromProgress == true { return false }
                    if show.isCompleted == true { return false }
                    if show.isDropped == true { return false }
                    return true
                }

                onShowsToWatchChangedTransmitter.broadcast([Show](filteredShows))

                TinyStorage.cache.store(shows, forKey: "EpisodeToWatchManager.shows")
            } else {
                TinyStorage.cache.remove(key: "EpisodeToWatchManager.shows")
            }
        }
    }

    private var mediaModels = [MediaModel]() {
        didSet {
            if oldValue.isEmpty {
                debouncedTransmit.fireNow()
            } else {
                debouncedTransmit.call()
            }

            TinyStorage.cache.store(mediaModels, forKey: "EpisodeToWatchManager.mediaModels")
        }
    }

    private var timer: Timer?
    private var futureMediaModels = [MediaModel]() {
        didSet {
            debouncedTransmit.call()

            TinyStorage.cache.store(futureMediaModels, forKey: "EpisodeToWatchManager.futureMediaModels")

            // find the first episode that will air in the future and create a timer
            for media in futureMediaModels {
                if let episode = media.episode, let firstAired = episode.firstAired, firstAired.distance(to: .now) < 0 {
                    timer?.invalidate()
                    print("FIRST AIRED: \(firstAired)")
                    timer = Timer(fire: firstAired,
                                  interval: 0,
                                  repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        print("EpisodeToWatchManager.forceRefresh because timer for future media was set")
                        self.debouncedForceRefresh.call()
                    }
                    if let timer = timer { RunLoop.main.add(timer, forMode: .common) }
                    break
                }
            }
        }
    }

    var filteredMediaModels: [MediaModel] {
        visibleEpisodeToWatchMediaModels()
    }

    private func transmit() {
        print("EpisodeToWatchManager.mediaModels transmit MediaModels and Future MediaModels")

        onEpisodeToWatchChangedTransmitter.broadcast(visibleEpisodeToWatchMediaModels())
        status = .content
        updateAppIcon()
    }

    private func visibleEpisodeToWatchMediaModels() -> [MediaModel] {
        mediaModels.filter { $0.hasVisibleEpisodeToWatch() }
    }

    private func visiblePinnedEpisodeToWatchMediaModels() -> [MediaModel] {
        mediaModels.filter { $0.hasVisiblePinnedEpisodeToWatch() }
    }

    private func updateAppIcon() {
        DispatchQueue.main.async {
            if UserDefaults.standard.integer(forKey: "Badge.mode") == 2 {
                let filteredMediaModels = self.visibleEpisodeToWatchMediaModels()
                UNUserNotificationCenter.current().setBadgeCount(filteredMediaModels.count)
            }
            if UserDefaults.standard.integer(forKey: "Badge.mode") == 3 {
                let filteredMediaModels = self.visibleEpisodeToWatchMediaModels()
                var episodeCount = 0
                for model in filteredMediaModels {
                    switch model {
                    case .showProgress(_, let progress):
                        if progress.toRewatchCount > 0 {
                            episodeCount += progress.toRewatchCount
                        } else {
                            episodeCount += max(1, progress.behind)
                        }
                    default:
                        break
                    }
                }
                UNUserNotificationCenter.current().setBadgeCount(episodeCount)
            }

            if UserDefaults.standard.integer(forKey: "Badge.mode") == 5 {
                let filteredMediaModels = self.visiblePinnedEpisodeToWatchMediaModels()
                UNUserNotificationCenter.current().setBadgeCount(filteredMediaModels.count)
            }
            if UserDefaults.standard.integer(forKey: "Badge.mode") == 6 {
                let filteredMediaModels = self.visiblePinnedEpisodeToWatchMediaModels()
                var episodeCount = 0
                for model in filteredMediaModels {
                    switch model {
                    case .showProgress(_, let progress):
                        if progress.toRewatchCount > 0 {
                            episodeCount += progress.toRewatchCount
                        } else {
                            episodeCount += max(1, progress.behind)
                        }
                    default:
                        break
                    }
                }
                UNUserNotificationCenter.current().setBadgeCount(episodeCount)
            }
        }
    }

    func setup() {
        if let showsInList = TinyStorage.cache.retrieve(type: [ToWatchGroup<Show>].self, forKey: "EpisodeToWatchManager.showsInList") {
            self.showsInList = showsInList
        }
        if let futureMediaModels = TinyStorage.cache.retrieve(type: [MediaModel].self, forKey: "EpisodeToWatchManager.futureMediaModels") {
            self.futureMediaModels = futureMediaModels
        }
        if let shows = TinyStorage.cache.retrieve(type: Set<Show>.self, forKey: "EpisodeToWatchManager.shows") {
            self.shows = shows
        }
        if let mediaModels = TinyStorage.cache.retrieve(type: [MediaModel].self, forKey: "EpisodeToWatchManager.mediaModels") {
            self.mediaModels = mediaModels
        }

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.startFallbackRetryChain()
            self.operationQueue.cancelAllOperations()
            self.timer?.invalidate()
            self.timer = nil
            self.status = .content
            self.showsInList = nil
            self.shows = nil
            self.mediaModels = []
            self.futureMediaModels = []
            TinyStorage.cache.remove(key: "EpisodeToWatchManager.showsInList")
            TinyStorage.cache.remove(key: "EpisodeToWatchManager.shows")
            TinyStorage.cache.remove(key: "EpisodeToWatchManager.mediaModels")
            TinyStorage.cache.remove(key: "EpisodeToWatchManager.futureMediaModels")
            onShowsToWatchChangedTransmitter.broadcast([])
            self.debouncedTransmit.fireNow()
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            print("EpisodeToWatchManager.forceRefresh because settings changes")
            self.debouncedForceRefresh.call()
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                print("EpisodeToWatchManager.forceRefresh because app didFifnish launching")
                self.debouncedForceRefresh.call()
            case .didBecomeActive(let time):
                if time > 60 * 60 * 4 {
                    print("EpisodeToWatchManager.forceRefresh because did Become active after 4h")
                    self.debouncedForceRefresh.call()
                } else if time > 60 * 60 * 2 {
                    print("EpisodeToWatchManager.refresh progress because did become active after 2h")
                    self.debouncedRefreshProgress.call()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onShowsWatchlistedChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if EpisodeToWatchSettings.shared.watchlist {
                print("EpisodeToWatchManager.forceRefresh because Watchlist changed")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        // Rebuild when WatchedManager updates the show metadata used below; SyncWatchedManager can finish before it.
        onWatchedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if EpisodeToWatchSettings.shared.watched {
                print("EpisodeToWatchManager.forceRefresh because watched changed")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        onUserFavoritesChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            if EpisodeToWatchSettings.shared.recommended {
                print("EpisodeToWatchManager.forceRefresh because recommended changed")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        onShowCollectionChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            if EpisodeToWatchSettings.shared.collected {
                print("EpisodeToWatchManager.forceRefresh because collection changed")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        episodeToWatchSettingsUpdatedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            print("EpisodeToWatchManager.forceRefresh because ToWatch Settings Changed")
            self.debouncedForceRefresh.call()
        }.disposed(by: disposeBag)

        onListChangedReceiver.listen { [weak self] lists in
            guard let self = self else { return }
            for list in lists where EpisodeToWatchSettings.shared.lists.contains(list) {
                print("EpisodeToWatchManager.forceRefresh because on list changed")
                self.debouncedForceRefresh.call()
                return
            }
        }.disposed(by: disposeBag)

        onShowSmartSearchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if EpisodeToWatchSettings.shared.smartSearches.isEmpty == false {
                print("EpisodeToWatchManager.forceRefresh because smart search changed")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        onRewatchingChangedReceiver.listen { show in
            if show.isInToWatch {
                ProgressManager.shared.refreshProgress(for: show)
            }
        }.disposed(by: disposeBag)

        onShowsHiddenFromProgressMediaChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            print("EpisodeToWatchManager.forceRefresh because hidden shows changed")

            self.debouncedForceRefresh.call()
        }.disposed(by: disposeBag)

        badgeModeReceiver.listen { [weak self] mode in
            guard let self = self else { return }
            if mode == 0 {
                UNUserNotificationCenter.current().setBadgeCount(0)
            } else {
                self.updateAppIcon()
            }
        }.disposed(by: disposeBag)

        onPinnedShowsToWatchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            print("EpisodeToWatchManager.forceRefresh because pinned changed")
            self.debouncedForceRefresh.call()
        }.disposed(by: disposeBag)

        onPinnedShowToWatchAddedReceiver.listen { show in
            ProgressManager.shared.refreshProgress(for: show)
        }.disposed(by: disposeBag)

        onPinnedShowToWatchRemovedReceiver.listen { show in
            ProgressManager.shared.refreshProgress(for: show)
        }.disposed(by: disposeBag)

        onCompletedShowsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            print("EpisodeToWatchManager.forceRefresh because completed shows update")
            self.debouncedForceRefresh.call()
        }.disposed(by: disposeBag)

        onDroppedShowsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            print("EpisodeToWatchManager.forceRefresh because dropped shows update")
            self.debouncedForceRefresh.call()
        }.disposed(by: disposeBag)

        episodeToWatchGroupModeReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedTransmit.call()
        }.disposed(by: disposeBag)

        episodeToWatchHideDuplicatesReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedTransmit.call()
        }.disposed(by: disposeBag)

        episodeToWatchBingeableOnlyReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedTransmit.call()
        }.disposed(by: disposeBag)

        onProgressCacheChangedReceiver.listen { [weak self] showShowProgress in
            guard let self = self else { return }
            if self.status == .loading { return }
            if showShowProgress.show.isInToWatch {
                for case .showProgress(let show, let progress) in mediaModels where show == showShowProgress.show {
                    if !(progress.aired == showShowProgress.showProgress.aired &&
                        progress.completed == showShowProgress.showProgress.completed &&
                        progress.lastWatchedAt == showShowProgress.showProgress.lastWatchedAt &&
                        progress.nextEpisodeToWatch == showShowProgress.showProgress.nextEpisodeToWatch &&
                        progress.resetAt == showShowProgress.showProgress.resetAt &&
                        progress.seasons == showShowProgress.showProgress.seasons &&
                        progress.lastWatchedEpisode == showShowProgress.showProgress.lastWatchedEpisode &&
                        progress.lastAiredEpisode == showShowProgress.showProgress.lastAiredEpisode) {
                        print("EpisodeToWatchManager.refreshProgress because the progress cache changed and checked found diff")
                        self.refreshProgress(shows: [showShowProgress.show])
                        return
                    } else {
                        return
                    }
                }
                print("EpisodeToWatchManager.refreshProgress anyway because the progress cache changed and the media should be found in To Watch but coulnd't be found")
                self.refreshProgress(shows: [showShowProgress.show])
            }
        }.disposed(by: disposeBag)
    }

    func forcedUserRefresh() {
        debouncedForceRefresh.call()
    }

    @MainActor
    func refreshProgress(forShowWithTraktIdentifier showTraktIdentifier: Int64) async {
        if let show = mediaModels.compactMap(\.show).first(where: {
            $0.identifiers.trakt == showTraktIdentifier
        }) {
            status = .loading
            ProgressManager.shared.resetCache(for: show)

            let operation = UpdateShowProgressOperation(shows: [show], mediaModels: mediaModels)
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                operation.completionBlock = {
                    continuation.resume()
                }
                operationQueue.addOperation(operation)
            }

            status = .content
            if !operation.isCancelled {
                mediaModels = operation.mediaModels
            }
        }

        debouncedTransmit.fireNow()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    func refreshForBackgroundTask(completion: @escaping @Sendable (Bool) -> Void) {
        forceRefresh(completion: completion)
    }

    private func forceRefresh(completion: (@Sendable (Bool) -> Void)? = nil) {
        if SessionManager.shared.isLoggedOut {
            print("EpisodeToWatchManager.forceRefresh stop because NOT logged in")
            completion?(false)
            return
        }

        let fallbackRetryGeneration = startFallbackRetryChain()
        status = .loading

        print("EpisodeToWatchManager.forceRefresh START")

        let sourcesOperation = ToWatchSourcesOperation(sources: toWatchSources(), lastKnownGroups: showsInList ?? [])
        sourcesOperation.completionBlock = { [weak self] in
            guard let self = self, !sourcesOperation.isCancelled else {
                completion?(false)
                return
            }

            let updateShowsProgressOperation = UpdateShowsProgressOperation(shows: sourcesOperation.media)
            updateShowsProgressOperation.completionBlock = { [weak self] in
                guard !updateShowsProgressOperation.isCancelled else {
                    completion?(false)
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !updateShowsProgressOperation.isCancelled, SessionManager.shared.isLoggedIn else {
                        completion?(false)
                        return
                    }
                    self.shows = sourcesOperation.media
                    self.showsInList = sourcesOperation.groups
                    self.mediaModels = updateShowsProgressOperation.mediaModels
                    self.futureMediaModels = updateShowsProgressOperation.futureMediaModels
                    self.fallbackRetryDetection(generation: fallbackRetryGeneration)
                    if let completion = completion {
                        self.debouncedTransmit.fireNow()
                        DispatchQueue.main.async {
                            completion(sourcesOperation.completedSuccessfully && updateShowsProgressOperation.completedSuccessfully)
                        }
                    }
                    print("EpisodeToWatchManager.forceRefresh STOP")
                }
            }
            self.operationQueue.addOperation(updateShowsProgressOperation)
        }
        operationQueue.addOperation(sourcesOperation)
    }

    private func toWatchSources() -> [ToWatchSource<Show>] {
        let settings = EpisodeToWatchSettings.shared
        var sources = [ToWatchSource<Show>.fixed(id: "pinned", name: "Pinned", order: 0, media: PinnedShowsManager.shared.pinnedShows)]
        if settings.watched {
            let watchedShows = WatchedManager.shared.watchedShowsMediaModels.compactMap { $0.show }
            sources.append(.fixed(id: "watched", name: "Watched", order: 1, media: Set(watchedShows)))
        }
        if settings.watchlist {
            sources.append(.watchlist(type: .shows, order: 2, media: \.show))
        }
        if settings.recommended {
            sources.append(.favorites(type: .shows, order: 3, media: \.show))
        }
        if settings.collected {
            sources.append(.collection(type: .shows, order: 4, media: \.show))
        }
        for otherList in settings.otherLists where otherList.enabled {
            if let list = otherList.list {
                sources.append(.list(list, id: otherList.id, order: 100 + otherList.rank, type: .shows, media: \.show))
            } else if let smartSearch = otherList.smartSearch {
                sources.append(.smartSearch(smartSearch, id: otherList.id, order: 100 + otherList.rank, media: \.show))
            }
        }
        return sources
    }

    private func refreshProgress() {
        if SessionManager.shared.isLoggedOut { return }
        let fallbackRetryGeneration = startFallbackRetryChain()
        guard let shows = shows else { return }

        status = .loading

        print("EpisodeToWatchManager.refreshProgress for all shows \(shows.count) START")

        let updateShowsProgressOperation = UpdateShowsProgressOperation(shows: shows)
        updateShowsProgressOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !updateShowsProgressOperation.isCancelled else { return }
                self.mediaModels = updateShowsProgressOperation.mediaModels
                self.futureMediaModels = updateShowsProgressOperation.futureMediaModels
                self.fallbackRetryDetection(generation: fallbackRetryGeneration)
                print("EpisodeToWatchManager.refreshProgress STOP")
            }
        }
        operationQueue.addOperation(updateShowsProgressOperation)
    }

    func refreshProgress(shows: [Show]) {
        let fallbackRetryGeneration = startFallbackRetryChain()
        refreshProgress(shows: shows,
                        fallbackRetryAttempt: 0,
                        fallbackRetryGeneration: fallbackRetryGeneration)
    }

    private func refreshProgress(shows: [Show],
                                 fallbackRetryAttempt: Int,
                                 fallbackRetryGeneration: Int) {
        if SessionManager.shared.isLoggedOut { return }
        if mediaModels.isEmpty { return } // means no media model in cache so nothing to do
        guard isCurrentFallbackRetryGeneration(fallbackRetryGeneration) else { return }

        if fallbackRetryAttempt == Self.fallbackRetryDelays.count {
            status = .loading
        }

        print("EpisodeToWatchManager.refreshProgress for some shows \(shows.count) START")

        let updateShowsProgressOperation = UpdateShowProgressOperation(shows: shows, mediaModels: mediaModels)
        updateShowsProgressOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      !updateShowsProgressOperation.isCancelled,
                      self.isCurrentFallbackRetryGeneration(fallbackRetryGeneration) else { return }
                self.mediaModels = updateShowsProgressOperation.mediaModels
                self.fallbackRetryDetection(completedRetryCount: fallbackRetryAttempt,
                                            generation: fallbackRetryGeneration)
                print("EpisodeToWatchManager.refreshProgress for some shows \(shows.count) STOP")
            }
        }
        operationQueue.addOperation(updateShowsProgressOperation)
    }

    private func fallbackRetryDetection(completedRetryCount: Int = 0, generation: Int) {
        guard isCurrentFallbackRetryGeneration(generation) else { return }
        guard completedRetryCount < Self.fallbackRetryDelays.count else {
            print("Stop refreshing because it seems like we've watched it but trakt cache isn't going to fix itself")
            clearFallbackRetryWorkItem(generation: generation)
            status = .content
            return
        }

        var showsToRetry = [Show]()
        for media in mediaModels {
            if let show = media.show,
               media.toRewatchCount == 0,
               let episode = media.episode,
               episode.isWatched || episode.isCurrentlyWatching {
                print("Refreshing \(show.title) again because it seems like it's watched but the To Watch didn't fetch it right")
                ProgressManager.shared.resetCache(for: show)
                showsToRetry.append(show)
            }
        }
        guard !showsToRetry.isEmpty else {
            clearFallbackRetryWorkItem(generation: generation)
            return
        }

        let retryDelay = Self.fallbackRetryDelays[completedRetryCount]
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.refreshProgress(shows: showsToRetry,
                                 fallbackRetryAttempt: completedRetryCount + 1,
                                 fallbackRetryGeneration: generation)
        }

        fallbackRetryLock.lock()
        guard generation == fallbackRetryGeneration else {
            fallbackRetryLock.unlock()
            return
        }
        fallbackRetryWorkItem?.cancel()
        fallbackRetryWorkItem = workItem
        fallbackRetryLock.unlock()

        // Give Trakt time to update progress before pulling the watched state again.
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay, execute: workItem)
    }

    @discardableResult
    private func startFallbackRetryChain() -> Int {
        fallbackRetryLock.lock()
        fallbackRetryGeneration += 1
        fallbackRetryWorkItem?.cancel()
        fallbackRetryWorkItem = nil
        let generation = fallbackRetryGeneration
        fallbackRetryLock.unlock()
        return generation
    }

    private func isCurrentFallbackRetryGeneration(_ generation: Int) -> Bool {
        fallbackRetryLock.lock()
        defer { fallbackRetryLock.unlock() }
        return generation == fallbackRetryGeneration
    }

    private func clearFallbackRetryWorkItem(generation: Int) {
        fallbackRetryLock.lock()
        defer { fallbackRetryLock.unlock() }
        guard generation == fallbackRetryGeneration else { return }
        fallbackRetryWorkItem?.cancel()
        fallbackRetryWorkItem = nil
    }
}

private extension MediaModel {
    func hasVisibleEpisodeToWatch() -> Bool {
        guard case .showProgress(let show, let showProgress) = self else { return false }
        if show.isHiddenFromProgress == true { return false }
        if show.isCompleted == true { return false }
        if show.isDropped == true { return false }

        let hasVisibleEpisode: Bool
        if showProgress.toRewatchCount > 0 {
            hasVisibleEpisode = true
        } else if let nextEpisodeToWatch = showProgress.nextEpisodeToWatch,
                  let firstAired = nextEpisodeToWatch.firstAired {
            hasVisibleEpisode = firstAired.distance(to: Date()) > 0
        } else {
            hasVisibleEpisode = false
        }

        guard hasVisibleEpisode else { return false }
        if EpisodeToWatchSettings.shared.bingeableOnly {
            if showProgress.lastAiredEpisode?.isBingeableFinale == true {
                return true
            }
            if let lastAiredEpisode = showProgress.lastAiredEpisode,
               let nextEpisodeToWatch = showProgress.nextEpisodeToWatch {
                return lastAiredEpisode.season != nextEpisodeToWatch.season
            }
            return false
        }
        return true
    }

    func hasVisiblePinnedEpisodeToWatch() -> Bool {
        guard case .showProgress(let show, _) = self else { return false }
        guard show.isPinned else { return false }
        return hasVisibleEpisodeToWatch()
    }
}

extension Episode {
    var isBingeableFinale: Bool {
        episodeType?.isBingeableFinale == true
    }
}

extension EpisodeType {
    var isBingeableFinale: Bool {
        switch self {
        case .midSeasonFinale, .seasonFinale, .seriesFinale:
            return true
        case .standard, .seriesPremiere, .seasonPremiere, .midSeasonPremiere, .unknown:
            return false
        }
    }
}

private final class UpdateShowsProgressOperation: ToWatchAsyncOperation, @unchecked Sendable {
    private let shows: Set<Show>
    private var showProgressMap = [Show: ShowProgress]()
    private var sourceFetchFailed = false

    private(set) var mediaModels = [MediaModel]()
    private(set) var futureMediaModels = [MediaModel]()

    var completedSuccessfully: Bool {
        !isCancelled && !sourceFetchFailed
    }

    init(shows: Set<Show>) {
        self.shows = shows
    }

    override func execute() {
        print("EpisodeToWatchManager.forceRefresh shows found \(shows.count)")

        let shows = shows.filter { !$0.isCompleted && !$0.isDropped && !$0.isHiddenFromProgress }

        print("EpisodeToWatchManager.forceRefresh shows after filter \(shows.count)")

        // Reset the cache for shows that have new episodes
        let previousShows = EpisodeToWatchManager.shared.shows ?? []
        for show in shows {
            if let index = previousShows.firstIndex(of: show), previousShows[index].airedEpisodes != show.airedEpisodes {
                print("EpisodeToWatchManager reseting cache for \(show.title) because number of aired episode is different")
                ProgressManager.shared.resetCache(for: show)
            }
        }

        let progressDispatchGroup = DispatchGroup()
        for show in shows {
            progressDispatchGroup.enter()
            _Concurrency.Task { [weak self] in
                let showProgress = await show.mediaModel.progress()
                DispatchQueue.main.async { [weak self] in
                    defer { progressDispatchGroup.leave() }
                    guard let self = self, !self.isCancelled else { return }
                    guard let showProgress = showProgress else {
                        self.sourceFetchFailed = true
                        return
                    }
                    self.showProgressMap[show] = showProgress
                }
            }
        }

        progressDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.fetchUpcomingEpisodes { [weak self] in
                guard let self = self, !self.isCancelled else { return }
                self.mediaModels = self.showProgressMap.sortedForToWatch()
                self.finish()
            }
        }
    }

    private func fetchUpcomingEpisodes(completion: @escaping () -> Void) {
        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        track(TraktAPIProvider.provider.request(.showsCalendar(startDate: startDate, days: 60, filters: [String: String]()),
                                                callbackQueue: .global(qos: .utility)) { [weak self] result in
                guard let self = self else { return }
                defer { completion() }
                do {
                    let response = try result.get().filterSuccessfulStatusCodes()
                    let calendarItems = try response.map([ShowEpisodeCalendarItem].self, using: TraktAPIProvider.decoder)
                    self.futureMediaModels = self.futureMediaModels(with: calendarItems)
                } catch {
                    self.sourceFetchFailed = true
                    print("showsCalendar request failed! \(error)")
                }
            })
    }

    private func futureMediaModels(with calendarItems: [ShowEpisodeCalendarItem]) -> [MediaModel] {
        let airedCutoff = Date.now.advanced(by: -60 * 60 * 8)
        var progressByShow = showProgressMap
        for calendarItem in calendarItems {
            guard let progress = progressByShow[calendarItem.show] else { continue }

            // We already have a next episode in the books -> additional checks
            // Or we don't and we just copy the next from the calendar request
            if let nextEpisodeFirstAired = progress.nextEpisodeToWatch?.firstAired {
                // if the date of the next episode to watch is in the past, take the one from the calendar
                // Otherwise, take the closest airing from now
                if nextEpisodeFirstAired < airedCutoff {
                    progressByShow[calendarItem.show] = progress.with(nextEpisode: calendarItem.episode)
                } else if let episodeFirstAired = calendarItem.episode.firstAired, nextEpisodeFirstAired > episodeFirstAired {
                    progressByShow[calendarItem.show] = progress.with(nextEpisode: calendarItem.episode)
                }
            } else {
                progressByShow[calendarItem.show] = progress.with(nextEpisode: calendarItem.episode)
            }
        }

        return progressByShow.compactMap { show, progress -> (firstAired: Date, show: Show, progress: ShowProgress)? in
            guard let nextEpisode = progress.nextEpisodeToWatch,
                  nextEpisode.season != 0,
                  let firstAired = nextEpisode.firstAired,
                  firstAired > airedCutoff else { return nil }
            return (firstAired, show, progress)
        }
        .sorted { ($0.firstAired, $0.show.title) < ($1.firstAired, $1.show.title) }
        .map { MediaModel.showProgress($0.show, $0.progress) }
    }
}

extension Show {
    var isInToWatch: Bool {
        if UserManager.shared.currentUser == nil { return false }
        if isCompleted { return false }
        if isDropped { return false }
        if isHiddenFromProgress { return false }
        guard let showsInToWatch = EpisodeToWatchManager.shared.shows else { return false }
        return showsInToWatch.contains(self)
    }
}

private final class UpdateShowProgressOperation: ToWatchAsyncOperation, @unchecked Sendable {
    private let shows: [Show]
    private var showProgressMap = [Show: ShowProgress]()

    private(set) var mediaModels = [MediaModel]()

    init(shows: [Show], mediaModels: [MediaModel]) {
        self.shows = shows
        for case .showProgress(let show, let showProgress) in mediaModels {
            showProgressMap[show] = showProgress
        }
    }

    override func execute() {
        let progressDispatchGroup = DispatchGroup()
        for show in shows {
            progressDispatchGroup.enter()
            _Concurrency.Task { [weak self] in
                let showProgress = await show.mediaModel.progress()
                DispatchQueue.main.async { [weak self] in
                    defer { progressDispatchGroup.leave() }
                    guard let self = self, !self.isCancelled, let showProgress = showProgress else { return }
                    self.showProgressMap[show] = showProgress
                }
            }
        }

        progressDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.mediaModels = self.showProgressMap.sortedForToWatch()
            self.finish()
        }
    }
}

private extension Dictionary where Key == Show, Value == ShowProgress {
    func sortedForToWatch() -> [MediaModel] {
        let mediaModels: [MediaModel]
        switch EpisodeToWatchSettings.shared.sort {
        case .automatic:
            mediaModels = sortByAutomatic()
        case .watched:
            mediaModels = sortByLastWatched()
        case .released:
            mediaModels = sortByEpisodeRelease()
        case .leastEpisodeRemaining:
            mediaModels = sortByLeastEpisodeRemaining()
        case .mostCompleted:
            mediaModels = sortByMostCompleted()
        case .mostPlayed:
            mediaModels = sortByMostPlayed()
        case .releaseYear:
            mediaModels = sortByShowReleaseYear()
        case .rating:
            mediaModels = sortByShowRating()
        case .voteCount:
            mediaModels = sortByShowVotes()
        case .random:
            mediaModels = sortByRandom()
        case .userRating:
            mediaModels = sortByUserShowRating()
        case .title:
            mediaModels = sortByTitle()
        case .timeLeft:
            mediaModels = sortByTimeLeft()
        }
        return EpisodeToWatchSettings.shared.reverse ? mediaModels.reversed() : mediaModels
    }

    func sortByRandom() -> [MediaModel] {
        return shuffled().compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByAutomatic() -> [MediaModel] {
        var mediaModels = [MediaModel]()

        let referenceDate = Date.now // copy the data to make sure we're working on the same dataset

        var rewatching = [Show: ShowProgress]() // it's a show that is being rewatched
        var justOut = [Show: ShowProgress]() // it's out since 3 days or less (the next episode only)
        var binging = [Show: ShowProgress]() // it's being ginge watched
        var others = [Show: ShowProgress]() // not in other lists
        var hidden = [Show: ShowProgress]() // it's hidden (we put it in the bottom)

        for showProgress in self {
            if showProgress.key.isHiddenFromProgress {
                hidden[showProgress.key] = showProgress.value
                continue
            }

            if showProgress.value.toRewatchCount > 0 {
                rewatching[showProgress.key] = showProgress.value
                continue
            }

            if let nextEpisodeToWatchFirstAired = showProgress.value.nextEpisodeToWatch?.firstAired, nextEpisodeToWatchFirstAired > referenceDate.advanced(by: -(3 * 86400)), nextEpisodeToWatchFirstAired <= referenceDate {
                justOut[showProgress.key] = showProgress.value
                continue
            }

            if showProgress.key.isBingeWatched {
                binging[showProgress.key] = showProgress.value
                continue
            }

            others[showProgress.key] = showProgress.value
        }

        for progress in rewatching.sorted(by: { ($0.value.lastWatchedAt ?? Date.distantPast, $0.key.sortableTitle) > ($1.value.lastWatchedAt ?? Date.distantPast, $1.key.sortableTitle) }) {
            mediaModels.append(MediaModel.showProgress(progress.key, progress.value))
        }

        for progress in justOut.sorted(by: { ($0.value.lastWatchedAt ?? Date.distantPast, $0.key.sortableTitle) > ($1.value.lastWatchedAt ?? Date.distantPast, $1.key.sortableTitle) }) {
            mediaModels.append(MediaModel.showProgress(progress.key, progress.value))
        }

        for progress in binging.sorted(by: { ($0.value.lastWatchedAt ?? Date.distantPast, $0.key.sortableTitle) > ($1.value.lastWatchedAt ?? Date.distantPast, $1.key.sortableTitle) }) {
            mediaModels.append(MediaModel.showProgress(progress.key, progress.value))
        }

        for progress in others.sorted(by: { ($0.value.lastWatchedAt ?? Date.distantPast,
                                             $0.key.weightedRating,
                                             $0.key.sortableTitle) > ($1.value.lastWatchedAt ?? Date.distantPast,
                                                                      $1.key.weightedRating,
                                                                      $1.key.sortableTitle) }) {
            mediaModels.append(MediaModel.showProgress(progress.key, progress.value))
        }

        for progress in hidden.sorted(by: { ($0.value.lastWatchedAt ?? Date.distantPast, $0.key.sortableTitle) > ($1.value.lastWatchedAt ?? Date.distantPast, $1.key.sortableTitle) }) {
            mediaModels.append(MediaModel.showProgress(progress.key, progress.value))
        }

        return mediaModels
    }

    func sortByLeastEpisodeRemaining() -> [MediaModel] {
        return sorted {
            let count1 = $0.value.toRewatchCount > 0 ? $0.value.toRewatchCount : $0.value.behind
            let count2 = $1.value.toRewatchCount > 0 ? $1.value.toRewatchCount : $1.value.behind
            return (count1, $0.key.sortableTitle) < (count2, $1.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByTitle() -> [MediaModel] {
        return sorted {
            $0.key.title.sortableString < $1.key.title.sortableString
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByShowVotes() -> [MediaModel] {
        return sorted {
            ($0.key.votes ?? 0, $1.key.sortableTitle) > ($1.key.votes ?? 0, $0.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByUserShowRating() -> [MediaModel] {
        return sorted {
            ($0.key.userRating ?? 0, $1.key.sortableTitle) > ($1.key.userRating ?? 0, $0.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByEpisodeRelease() -> [MediaModel] {
        return sorted {
            ($0.value.nextEpisodeToWatch?.firstAired ?? Date.distantPast, $1.key.sortableTitle) > ($1.value.nextEpisodeToWatch?.firstAired ?? Date.distantPast, $0.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByLastWatched() -> [MediaModel] {
        return sorted {
            ($0.value.lastWatchedAt ?? Date.distantPast, $1.key.sortableTitle) > ($1.value.lastWatchedAt ?? Date.distantPast, $0.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByMostCompleted() -> [MediaModel] {
        return sorted {
            let completionRatio0 = $0.value.aired > 0 ? Double($0.value.completed) / Double($0.value.aired) : 0.0
            let completionRatio1 = $1.value.aired > 0 ? Double($1.value.completed) / Double($1.value.aired) : 0.0
            // Use count to sort the non-started by count of episodes because if I started it now it would be more complete with less episodes
            let count1 = $0.value.toRewatchCount > 0 ? $0.value.toRewatchCount : $0.value.behind
            let count2 = $1.value.toRewatchCount > 0 ? $1.value.toRewatchCount : $1.value.behind
            return (completionRatio0, count2, $1.key.sortableTitle) > (completionRatio1, count1, $0.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByMostPlayed() -> [MediaModel] {
        return sorted {
            ($0.value.completed, $1.key.sortableTitle) > ($1.value.completed, $0.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByMostEpisodeRemaining() -> [MediaModel] {
        return sorted {
            let count1 = $0.value.toRewatchCount > 0 ? $0.value.toRewatchCount : $0.value.behind
            let count2 = $1.value.toRewatchCount > 0 ? $1.value.toRewatchCount : $1.value.behind
            return (count1, $1.key.sortableTitle) > (count2, $0.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByTimeLeft() -> [MediaModel] {
        return sorted {
            let defaultRuntime = 45

            let remainingEpisodes1 = $0.value.toRewatchCount > 0 ? $0.value.toRewatchCount : Swift.max(1, $0.value.behind)
            let runtime1 = $0.key.runtime ?? $0.value.nextEpisodeToWatch?.runtime ?? defaultRuntime
            let timeLeft1 = remainingEpisodes1 * runtime1

            let remainingEpisodes2 = $1.value.toRewatchCount > 0 ? $1.value.toRewatchCount : Swift.max(1, $1.value.behind)
            let runtime2 = $1.key.runtime ?? $1.value.nextEpisodeToWatch?.runtime ?? defaultRuntime
            let timeLeft2 = remainingEpisodes2 * runtime2

            return (timeLeft1, $0.key.sortableTitle) < (timeLeft2, $1.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByShowReleaseYear() -> [MediaModel] {
        return sorted {
            ($0.key.releaseYear ?? 1970, $0.key.sortableTitle) < ($1.key.releaseYear ?? 1970, $1.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }

    func sortByShowRating() -> [MediaModel] {
        return sorted {
            ($0.key.rating ?? 0, $1.key.sortableTitle) > ($1.key.rating ?? 0, $0.key.sortableTitle)
        }.compactMap { MediaModel.showProgress($0.key, $0.value) }
    }
}

extension Show {
    var weightedRating: Double {
        let m = 3000.0
        let C = 6.5
        let v = Double(votes ?? 0)
        let R = rating ?? 0
        return (v / (v + m)) * R + (m / (v + m)) * C
    }
}
