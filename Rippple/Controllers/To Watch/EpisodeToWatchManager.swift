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

struct ToWatchGroup: Codable {
    let name: String
    let order: Int
    let shows: Set<Show>
}

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

    var showsInList: [ToWatchGroup]? {
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
        if let showsInList = TinyStorage.cache.retrieve(type: [ToWatchGroup].self, forKey: "EpisodeToWatchManager.showsInList") {
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

        onShowsWatchlistedChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            if EpisodeToWatchSettings.shared.watchlist {
                print("EpisodeToWatchManager.forceRefresh because Watchlist changed")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        onSyncWatchedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
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

    private func forceRefresh() {
        if SessionManager.shared.isLoggedOut {
            print("EpisodeToWatchManager.forceRefresh stop because NOT logged in")
            return
        }

        let fallbackRetryGeneration = startFallbackRetryChain()
        status = .loading

        print("EpisodeToWatchManager.forceRefresh START")

        let updateShowsOperation = UpdateShowsOperation(pinnedShows: PinnedShowsManager.shared.pinnedShows)
        updateShowsOperation.completionBlock = {
            guard updateShowsOperation.completedSuccessfully else {
                DispatchQueue.main.async {
                    self.status = .content
                    print("EpisodeToWatchManager.forceRefresh preserving the last complete result because a source failed")
                }
                return
            }

            let shows = updateShowsOperation.shows
            let updateShowsProgressOperation = UpdateShowsProgressOperation(shows: shows)
            updateShowsProgressOperation.completionBlock = {
                self.shows = updateShowsOperation.shows
                self.showsInList = updateShowsOperation.showsInList
                self.mediaModels = updateShowsProgressOperation.mediaModels
                self.futureMediaModels = updateShowsProgressOperation.futureMediaModels
                self.fallbackRetryDetection(generation: fallbackRetryGeneration)
                print("EpisodeToWatchManager.forceRefresh STOP")
            }
            self.operationQueue.addOperation(updateShowsProgressOperation)
        }
        operationQueue.addOperation(updateShowsOperation)
    }

    private func refreshProgress() {
        if SessionManager.shared.isLoggedOut { return }
        let fallbackRetryGeneration = startFallbackRetryChain()
        guard let shows = shows else { return }

        status = .loading

        print("EpisodeToWatchManager.refreshProgress for all shows \(shows.count) START")

        let updateShowsProgressOperation = UpdateShowsProgressOperation(shows: shows)
        updateShowsProgressOperation.completionBlock = {
            if updateShowsProgressOperation.isCancelled { return }
            self.mediaModels = updateShowsProgressOperation.mediaModels
            self.futureMediaModels = updateShowsProgressOperation.futureMediaModels
            self.fallbackRetryDetection(generation: fallbackRetryGeneration)
            print("EpisodeToWatchManager.refreshProgress STOP")
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
        updateShowsProgressOperation.completionBlock = {
            if updateShowsProgressOperation.isCancelled { return }
            guard self.isCurrentFallbackRetryGeneration(fallbackRetryGeneration) else { return }
            self.mediaModels = updateShowsProgressOperation.mediaModels
            self.fallbackRetryDetection(completedRetryCount: fallbackRetryAttempt,
                                        generation: fallbackRetryGeneration)
            print("EpisodeToWatchManager.refreshProgress for some shows \(shows.count) STOP")
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

private class UpdateShowsOperation: Operation, @unchecked Sendable {
    private let showsDispatchGroup = DispatchGroup()
    private let resultLock = NSLock()
    private var cancellables = [Cancellable?]()

    private var sourceFetchFailed = false

    fileprivate var completedSuccessfully: Bool {
        resultLock.lock()
        defer { resultLock.unlock() }
        return isCancelled == false && sourceFetchFailed == false
    }

    fileprivate var shows = Set<Show>()
    fileprivate var showsInList = [ToWatchGroup]()

    private let pinnedShows: Set<Show>

    init(pinnedShows: Set<Show>) {
        self.pinnedShows = pinnedShows
    }

    private func recordSourceFetchFailure() {
        resultLock.lock()
        sourceFetchFailed = true
        resultLock.unlock()
    }

    override func cancel() {
        for cancellable in cancellables {
            cancellable?.cancel()
        }

        state = .isFinished

        super.cancel()
    }

    private enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }

    private var state: State = .isReady {
        willSet(newValue) {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }

    override var isAsynchronous: Bool {
        true
    }

    override var isExecuting: Bool {
        state == .isExecuting
    }

    override var isFinished: Bool {
        if isCancelled && state != .isExecuting { return true }
        return state == .isFinished
    }

    override func start() {
        if isCancelled { return }

        state = .isExecuting

        let pinnedShows = pinnedShows
        shows.formUnion(pinnedShows)
        showsInList.append(ToWatchGroup(name: "Pinned", order: 0, shows: pinnedShows))

        let toWatchSettings = EpisodeToWatchSettings.shared
        if toWatchSettings.watchlist {
            showsDispatchGroup.enter()
            fetchWatchlistedShows { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isCancelled { return }
                    self.showsDispatchGroup.leave()
                }
            }
        }
        if toWatchSettings.recommended {
            showsDispatchGroup.enter()
            fetchRecommendedShows { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isCancelled { return }
                    self.showsDispatchGroup.leave()
                }
            }
        }
        if toWatchSettings.collected {
            showsDispatchGroup.enter()
            fetchCollectedShows { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isCancelled { return }
                    self.showsDispatchGroup.leave()
                }
            }
        }
        if toWatchSettings.watched {
            showsDispatchGroup.enter()
            let watched = WatchedManager.shared.watchedShowsMediaModels.compactMap { $0.show }
            shows.formUnion(watched)
            showsInList.append(ToWatchGroup(name: "Watched", order: 1, shows: Set(watched)))
            showsDispatchGroup.leave()
        }

        for otherList in toWatchSettings.otherLists where otherList.enabled == true {
            if let list = otherList.list {
                showsDispatchGroup.enter()
                fetchShows(for: list, order: 100 + otherList.rank) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if self.isCancelled { return }
                        self.showsDispatchGroup.leave()
                    }
                }
            } else if let smartSearch = otherList.smartSearch {
                showsDispatchGroup.enter()
                fetchShows(from: smartSearch, order: 100 + otherList.rank) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if self.isCancelled { return }
                        self.showsDispatchGroup.leave()
                    }
                }
            }
        }

        showsDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.state = .isFinished
            }
        }
    }

    private func fetchWatchlistedShows(completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        TraktAPIProvider.fetchAllWatchlistItems(slug: "me",
                                                type: .shows,
                                                extended: .full,
                                                sort: .none) { [weak self] result in
            guard let self = self else { return }
            defer { completion() }
            if self.isCancelled { return }
            switch result {
            case .success(let items):
                let shows = items.map { $0.show! }
                DispatchQueue.main.async {
                    self.shows.formUnion(shows)
                    self.showsInList.append(ToWatchGroup(name: "Watchlisted", order: 2, shows: Set(shows)))
                }
            case .failure(let error):
                self.recordSourceFetchFailure()
                print("fetchWatchlistedShows (towatch) request failure \(error)")
            }
        }
    }

    private func fetchRecommendedShows(completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        TraktAPIProvider.fetchAllRecommendedItems(slug: "me",
                                                  type: .shows,
                                                  extended: .full,
                                                  sort: .none) { [weak self] result in
            guard let self = self else { return }
            defer { completion() }
            if self.isCancelled { return }
            switch result {
            case .success(let items):
                let shows = items.map { $0.show! }
                DispatchQueue.main.async {
                    self.shows.formUnion(shows)
                    self.showsInList.append(ToWatchGroup(name: "Favorites", order: 3, shows: Set(shows)))
                }
            case .failure(let error):
                self.recordSourceFetchFailure()
                print("fetchRecommendedShows (towatch) request failure \(error)")
            }
        }
    }

    private func fetchCollectedShows(completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        TraktAPIProvider.fetchAllCollectionItems(slug: "me",
                                                 type: .shows,
                                                 extended: .full,
                                                 sort: .none) { [weak self] result in
            guard let self = self else { return }
            defer { completion() }
            if self.isCancelled { return }
            switch result {
            case .success(let items):
                let shows = items.map { $0.show! }
                DispatchQueue.main.async {
                    self.shows.formUnion(shows)
                    self.showsInList.append(ToWatchGroup(name: "Collected", order: 4, shows: Set(shows)))
                }
            case .failure(let error):
                self.recordSourceFetchFailure()
                print("fetchCollectedShows (towatch) request failure \(error)")
            }
        }
    }

    private func fetchShows(for list: List, order: Int, completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        TraktAPIProvider.fetchAllListItems(slug: list.user.identifiers.slug,
                                           id: list.identifiers.trakt!,
                                           type: .shows) { [weak self] result in
            guard let self = self else { return }
            defer { completion() }
            if self.isCancelled { return }
            switch result {
            case .success(let items):
                let shows = items.map { $0.show! }
                DispatchQueue.main.async {
                    self.shows.formUnion(shows)
                    self.showsInList.append(ToWatchGroup(name: list.name, order: order, shows: Set(shows)))
                }
            case .failure(let error):
                self.recordSourceFetchFailure()
                print("fetchShowsforlist (towatch) request failure \(error)")
            }
        }
    }

    private func fetchShows(from smartSearch: SmartSearch, order: Int, completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        let service = smartSearch.service
        let cancellable = TraktAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else {
                return
            }

            defer {
                completion()
            }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    var searchResults: [MediaItem]
                    if case .popularShows = service {
                        searchResults = try response.map([Show].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: nil, show: $0, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                    } else {
                        searchResults = try response.map([MediaItem].self, using: TraktAPIProvider.decoder)
                    }

                    let shows = searchResults.compactMap { $0.show }
                    DispatchQueue.main.async {
                        self.shows.formUnion(shows)
                        self.showsInList.append(ToWatchGroup(name: smartSearch.name ?? "Smart Search",
                                                             order: order,
                                                             shows: Set(shows)))
                    }
                } catch {
                    self.recordSourceFetchFailure()
                    print("fetchShows for Smart Search (towatch) request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                self.recordSourceFetchFailure()
                print("fetchShows for Smart Search (towatch) request failure \(error)")
            }
        }
        cancellables.append(cancellable)
    }
}

private class UpdateShowsProgressOperation: Operation, @unchecked Sendable {
    private let progressDispatchGroup = DispatchGroup()

    private var cancellables = [Cancellable?]()

    private var shows = Set<Show>()
    private var showProgressMap = [Show: ShowProgress]()

    fileprivate var mediaModels = [MediaModel]()
    fileprivate var futureMediaModels = [MediaModel]()

    init(shows: Set<Show>) {
        self.shows = shows
    }

    override func cancel() {
        for cancellable in cancellables {
            cancellable?.cancel()
        }

        state = .isFinished

        super.cancel()
    }

    private enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }

    private var filteredProgress: [Show: ShowProgress] {
        if isCancelled { return [Show: ShowProgress]() }
        return showProgressMap
    }

    private var state: State = .isReady {
        willSet(newValue) {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }

    override var isAsynchronous: Bool {
        true
    }

    override var isExecuting: Bool {
        state == .isExecuting
    }

    override var isFinished: Bool {
        if isCancelled && state != .isExecuting { return true }
        return state == .isFinished
    }

    override func start() {
        guard !isCancelled else { return }

        state = .isExecuting

        print("EpisodeToWatchManager.forceRefresh shows found \(shows.count)")

        // Filter completed, dropped AND hidden shows
        let shows = shows.filter { show in
            if show.isCompleted { return false }
            if show.isDropped { return false }
            if show.isHiddenFromProgress { return false }
            return true
        }

        print("EpisodeToWatchManager.forceRefresh shows after filter \(shows.count)")

        // Reset the cache for shows that have new episodes
        for updatedShow in shows {
            if let oldShow = EpisodeToWatchManager.shared.shows?.first(where: { $0 == updatedShow }) {
                if oldShow.airedEpisodes != updatedShow.airedEpisodes {
                    print("EpisodeToWatchManager reseting cache for \(updatedShow.title) because number of aired episode is different")
                    ProgressManager.shared.resetCache(for: updatedShow)
                }
            }
        }

        for show in shows {
            progressDispatchGroup.enter()
            _Concurrency.Task {
                let showProgress = await show.mediaModel.progress()
                DispatchQueue.main.async {
                    defer { self.progressDispatchGroup.leave() }
                    guard !self.isCancelled, let showProgress = showProgress else { return }
                    self.showProgressMap[show] = showProgress
                }
            }
        }

        // Upcoming fetching
        progressDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self else { return }
            if self.isCancelled { return }

            self.progressDispatchGroup.enter()
            TraktAPIProvider.provider.request(.showsCalendar(startDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, days: 60, filters: [String: String]()), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
                guard let self = self else { return }
                defer { self.progressDispatchGroup.leave() }

                // real copy of the show progress to be able to work on it
                var showProgressMapCopy = [Show: ShowProgress]().merging(self.showProgressMap) { $1 }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let showEpisodeCalendarItems = try response.map([ShowEpisodeCalendarItem].self, using: TraktAPIProvider.decoder)
                        for showEpisodeCalendarItem in showEpisodeCalendarItems {
                            guard let progress = showProgressMapCopy[showEpisodeCalendarItem.show] else { continue }

                            // We already have a next episode in the books -> additional checks
                            // Or we don't and we just copy the next from the calendar request
                            if let nextEpisodeToWatch = progress.nextEpisodeToWatch, let nextEpisodeFirstAired = nextEpisodeToWatch.firstAired {
                                // if the date of the next episode to watch is in the past, take the one from the calendar
                                // Otherwise, take the closest airing from now
                                if nextEpisodeFirstAired < Date.now.advanced(by: -60 * 60 * 8) {
                                    showProgressMapCopy[showEpisodeCalendarItem.show] = progress.with(nextEpisode: showEpisodeCalendarItem.episode)
                                } else if let episodeFirstAired = showEpisodeCalendarItem.episode.firstAired, nextEpisodeFirstAired > episodeFirstAired {
                                    showProgressMapCopy[showEpisodeCalendarItem.show] = progress.with(nextEpisode: showEpisodeCalendarItem.episode)
                                }
                            } else {
                                showProgressMapCopy[showEpisodeCalendarItem.show] = progress.with(nextEpisode: showEpisodeCalendarItem.episode)
                            }
                        }

                        // Filter and set the futureMediaModels
                        self.futureMediaModels = showProgressMapCopy.filter { $0.1.nextEpisodeToWatch != nil && $0.1.nextEpisodeToWatch!.season != 0 && $0.1.nextEpisodeToWatch!.firstAired != nil && $0.1.nextEpisodeToWatch!.firstAired!.distance(to: Date.now.advanced(by: -60 * 60 * 8)) < 0 }
                            .sorted { ($0.1.nextEpisodeToWatch!.firstAired!, $0.0.title) < ($1.1.nextEpisodeToWatch!.firstAired!, $1.0.title) }
                            .map { MediaModel.showProgress($0.key, $0.value) }
                    } catch {
                        print("showsCalendar request JSON mapping failed! \(error)")
                    }
                case .failure(let error):
                    print("showsCalendar request failure \(error)")
                }
            }

            self.progressDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
                guard let self = self else { return }
                if self.isCancelled { return }

                switch EpisodeToWatchSettings.shared.sort {
                case .automatic:
                    self.mediaModels = self.filteredProgress.sortByAutomatic()
                case .watched:
                    self.mediaModels = self.filteredProgress.sortByLastWatched()
                case .released:
                    self.mediaModels = self.filteredProgress.sortByEpisodeRelease()
                case .leastEpisodeRemaining:
                    self.mediaModels = self.filteredProgress.sortByLeastEpisodeRemaining()
                case .mostCompleted:
                    self.mediaModels = self.filteredProgress.sortByMostCompleted()
                case .mostPlayed:
                    self.mediaModels = self.filteredProgress.sortByMostPlayed()
                case .releaseYear:
                    self.mediaModels = self.filteredProgress.sortByShowReleaseYear()
                case .rating:
                    self.mediaModels = self.filteredProgress.sortByShowRating()
                case .voteCount:
                    self.mediaModels = self.filteredProgress.sortByShowVotes()
                case .random:
                    self.mediaModels = self.filteredProgress.sortByRandom()
                case .userRating:
                    self.mediaModels = self.filteredProgress.sortByUserShowRating()
                case .title:
                    self.mediaModels = self.filteredProgress.sortByTitle()
                case .timeLeft:
                    self.mediaModels = self.filteredProgress.sortByTimeLeft()
                }

                if EpisodeToWatchSettings.shared.reverse {
                    self.mediaModels.reverse()
                }

                self.state = .isFinished
            }
        }
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

private class UpdateShowProgressOperation: Operation, @unchecked Sendable {
    private let progressDispatchGroup = DispatchGroup()

    private var cancellables = [Cancellable?]()

    private var shows: [Show]!
    private var showProgressMap = [Show: ShowProgress]()

    fileprivate var mediaModels: [MediaModel]!

    init(shows: [Show], mediaModels: [MediaModel]) {
        self.shows = shows
        for mediaModel in mediaModels {
            switch mediaModel {
            case .showProgress(let show, let showProgress):
                showProgressMap[show] = showProgress
            default:
                fatalError()
            }
        }
    }

    override func cancel() {
        for cancellable in cancellables {
            cancellable?.cancel()
        }

        state = .isFinished

        super.cancel()
    }

    private enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }

    private var filteredProgress: [Show: ShowProgress] {
        if isCancelled { return [Show: ShowProgress]() }
        return showProgressMap
    }

    private var state: State = .isReady {
        willSet(newValue) {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }

    override var isAsynchronous: Bool {
        true
    }

    override var isExecuting: Bool {
        state == .isExecuting
    }

    override var isFinished: Bool {
        if isCancelled && state != .isExecuting { return true }
        return state == .isFinished
    }

    override func start() {
        guard !isCancelled else { return }

        state = .isExecuting

        for show in shows {
            progressDispatchGroup.enter()
            let progressDispatchGroup = progressDispatchGroup
            _Concurrency.Task {
                let showProgress = await show.mediaModel.progress()
                DispatchQueue.main.async {
                    defer { progressDispatchGroup.leave() }
                    guard !self.isCancelled, let showProgress = showProgress else { return }
                    self.showProgressMap[show] = showProgress
                }
            }
        }

        progressDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self else { return }
            if self.isCancelled { return }

            switch EpisodeToWatchSettings.shared.sort {
            case .automatic:
                self.mediaModels = self.filteredProgress.sortByAutomatic()
            case .watched:
                self.mediaModels = self.filteredProgress.sortByLastWatched()
            case .released:
                self.mediaModels = self.filteredProgress.sortByEpisodeRelease()
            case .leastEpisodeRemaining:
                self.mediaModels = self.filteredProgress.sortByLeastEpisodeRemaining()
            case .mostCompleted:
                self.mediaModels = self.filteredProgress.sortByMostCompleted()
            case .mostPlayed:
                self.mediaModels = self.filteredProgress.sortByMostPlayed()
            case .releaseYear:
                self.mediaModels = self.filteredProgress.sortByShowReleaseYear()
            case .rating:
                self.mediaModels = self.filteredProgress.sortByShowRating()
            case .voteCount:
                self.mediaModels = self.filteredProgress.sortByShowVotes()
            case .random:
                self.mediaModels = self.filteredProgress.sortByRandom()
            case .userRating:
                self.mediaModels = self.filteredProgress.sortByUserShowRating()
            case .title:
                self.mediaModels = self.filteredProgress.sortByTitle()
            case .timeLeft:
                self.mediaModels = self.filteredProgress.sortByTimeLeft()
            }

            if EpisodeToWatchSettings.shared.reverse {
                self.mediaModels.reverse()
            }

            self.state = .isFinished
        }
    }
}

private extension Dictionary where Key == Show, Value == ShowProgress {
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
