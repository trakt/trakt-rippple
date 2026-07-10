//
//  DroppedShowsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 27/02/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import Foundation
import Receiver
import TinyStorage
import UIKit

let (onDroppedShowsChangedTransmitter, onDroppedShowsChangedReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))

private struct DroppedShow: Codable, Hashable {
    let show: Show
    let droppedDate: Date
}

final class DroppedShowsManager {
    private let disposeBag = DisposeBag()
    private let stateLock = NSLock()

    private init() {}

    static let shared = DroppedShowsManager()

    private var debouncedTransmit: Debouncer!

    private var droppedShows = [DroppedShow]() {
        didSet {
            if Set(oldValue) != Set(droppedShows) {
                TinyStorage.cache.store(droppedShows, forKey: "DroppedShowsManager.droppedShows")
                debouncedTransmit.call()
            }
        }
    }

    private var hiddenShows: [MediaModel]?
    private var manuallyDroppedShows: [HiddenShow]?
    private var droppedShowsSet = Set<Show>()

    func setup() {
        debouncedTransmit = Debouncer(delay: 0.3) { [weak self] in
            guard let self = self else { return }
            self.rebuildDroppedShowsSet()
            self.transmit()
        }

        if let array = TinyStorage.cache.retrieve(type: [DroppedShow].self, forKey: "DroppedShowsManager.droppedShows") {
            withStateLock {
                droppedShows = array
            }
        }

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.withStateLock {
                self.droppedShows.removeAll()
                self.hiddenShows = nil
                self.manuallyDroppedShows = nil
                self.droppedShowsSet.removeAll()
            }
            TinyStorage.cache.remove(key: "DroppedShowsManager.droppedShows")
            self.debouncedTransmit.fireNow()
        }.disposed(by: disposeBag)

        onShowsHiddenFromProgressMediaChangedReceiver.listen { [weak self] hiddenShows in
            guard let self = self else { return }
            self.withStateLock {
                self.hiddenShows = hiddenShows
            }
            self.debouncedTransmit.fireNow()
        }.disposed(by: disposeBag)

        onShowsDroppedMediaChangedReceiver.listen { [weak self] manuallyDroppedShows in
            guard let self = self else { return }
            self.withStateLock {
                self.manuallyDroppedShows = manuallyDroppedShows
            }
            self.debouncedTransmit.fireNow()
        }.disposed(by: disposeBag)

        onProgressCacheChangedReceiver.listen { [weak self] showShowProgress in
            guard let self = self else { return }
            self.checkDropped(progress: showShowProgress)
        }.disposed(by: disposeBag)

        onProgressCacheHitReceiver.listen { [weak self] showShowProgress in
            guard let self = self else { return }
            self.checkDropped(progress: showShowProgress)
        }.disposed(by: disposeBag)

        toWatchDroppedEnabledReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedTransmit.fireNow()
        }.disposed(by: disposeBag)
    }

    private func checkDropped(progress: ShowShowProgress) {
        let hasRequiredState = withStateLock {
            hiddenShows != nil && manuallyDroppedShows != nil
        }
        guard hasRequiredState else { return }

        let show = progress.show

        // if it's not in watched, don't try to check if it's dropped
        guard let lastWatchedAt = progress.showProgress.lastWatchedAt else {
            removeDroppedShow(show)
            return
        }

        // if it's completed, it's not dropped
        if show.isCompleted {
            removeDroppedShow(show)
            return
        }

        // if it's pinned, don't drop it!!
        if show.isPinned {
            removeDroppedShow(show)
            return
        }

        // if it's hidden or manually dropped, don't auto-drop it
        if show.isHiddenFromProgress || show.isManuallyDropped {
            removeDroppedShow(show)
            return
        }

        // if the show hasn't been watched for 6 month
        if lastWatchedAt < .now.addingTimeInterval(-15780000) {
            // if I'm rewatching, it's not going in the dropped
            if progress.showProgress.nextToRewatch != nil {
                removeDroppedShow(show)
            } else if let nextEpisode = progress.showProgress.nextEpisodeToWatch,
                      nextEpisode.number > 1, // Next episode is not a premiere
                      nextEpisode.episodeType != .midSeasonPremiere, // Next episode is not a mid-season
                      let firstAired = nextEpisode.firstAired, // Next episode first aired at least 6 month ago
                      firstAired < .now.addingTimeInterval(-15780000) {
                addDroppedShow(show, droppedDate: lastWatchedAt)
            } else {
                removeDroppedShow(show)
            }
        } else {
            removeDroppedShow(show)
        }
    }

    private func withStateLock<T>(_ work: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return work()
    }

    private func removeDroppedShow(_ show: Show) {
        withStateLock {
            droppedShows.removeAll(where: { $0.show == show })
        }
    }

    private func addDroppedShow(_ show: Show, droppedDate: Date) {
        withStateLock {
            guard hiddenShows != nil, manuallyDroppedShows != nil else { return }
            guard droppedShows.contains(where: { $0.show == show }) == false else { return }
            droppedShows.append(DroppedShow(show: show,
                                            droppedDate: droppedDate))
        }
    }

    private func transmit() {
        onDroppedShowsChangedTransmitter.broadcast(droppedShowsModels)
    }

    private func rebuildDroppedShowsSet() {
        withStateLock {
            var set = Set<Show>()
            if let manuallyDroppedShows = manuallyDroppedShows {
                for item in manuallyDroppedShows {
                    set.insert(item.show)
                }
            }
            if UserDefaults.standard.bool(forKey: "GeneralSettings.droppedshows") == true {
                for dropped in droppedShows {
                    set.insert(dropped.show)
                }
            }
            droppedShowsSet = set
        }
    }

    func isDropped(show: Show) -> Bool {
        return withStateLock { droppedShowsSet.contains(show) }
    }

    var droppedShowsModels: [MediaModel] {
        let (manuallyDroppedShows, droppedShows) = withStateLock {
            (self.manuallyDroppedShows, self.droppedShows)
        }

        var allDropped = [DroppedShow]()
        if let manuallyDroppedShows = manuallyDroppedShows {
            allDropped = manuallyDroppedShows.compactMap { DroppedShow(show: $0.show,
                                                                       droppedDate: $0.hiddenAt) }
        }
        if UserDefaults.standard.bool(forKey: "GeneralSettings.droppedshows") == true {
            allDropped.append(contentsOf: droppedShows)
        }
        return allDropped.sorted { $0.droppedDate > $1.droppedDate }.compactMap { $0.show.mediaModel }
    }

    var droppedShowsCount: Int {
        return droppedShowsModels.count
    }
}

extension Show {
    var isDropped: Bool {
        DroppedShowsManager.shared.isDropped(show: self)
    }

    fileprivate var isManuallyDropped: Bool {
        return HiddenMediaManager.shared.showsDroppedList?.contains { $0.show == self } == true
    }

    func drop() {
        guard let traktId = identifiers.trakt else { return }

        SwiftMessages.show(message: "Dropping Show...", style: .loading)

        TraktAPIProvider.provider.request(.hideShow(section: .dropped,
                                                    id: traktId),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Drop Show successful \(response)")

                    DispatchQueue.main.async {
                        HiddenMediaManager.shared.refresh()
                        SwiftMessages.show(message: "⏹️ Dropped")
                    }
                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                }
            }
        }
    }
}

final class DroppedImageView: UIImageView {
    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            update()
        }
    }

    private func update() {
        if media?.show?.isManuallyDropped == false {
            image = UIImage(systemName: "minus.arrow.trianglehead.counterclockwise")
        } else {
            image = UIImage(systemName: "minus.circle")
        }
        isHidden = !(media?.show?.isDropped ?? false)
        invalidateCellIntrinsicContentSize()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onDroppedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.update()
            }
        }.disposed(by: disposeBag)
    }
}
