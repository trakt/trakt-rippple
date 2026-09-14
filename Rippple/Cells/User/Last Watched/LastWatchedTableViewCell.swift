//
//  LastWatchedTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 20/01/2022.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

protocol LastWatchedTableViewCellDelegate: AnyObject {
    func cell(_ cell: LastWatchedTableViewCell, action: LastWatchedTableViewCell.Action)
}

final class LastWatchedTableViewCell: TintedCanvasTableViewCell {
    enum Action {
        case details
    }

    weak var delegate: LastWatchedTableViewCellDelegate? {
        didSet {
            cellContextMenu.controller = delegate as? UIViewController
        }
    }

    @IBOutlet var title: UILabel!
    @IBOutlet var subtitle: UILabel!
    @IBOutlet var meta: UILabel!

    @IBOutlet var progress: CircularProgressView!

    @IBOutlet var poster: PosterButton!
    private let cellContextMenu = MediaContextMenuInteractionDelegate()

    private let disposeBag = DisposeBag()

    @IBOutlet var cardView: CardView?

    private var refreshWatchingTimer: Timer?

    /// request
    private var request: Cancellable?

    override func awakeFromNib() {
        super.awakeFromNib()

        poster.layer.cornerRadius = 8
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.layer.borderWidth = 1
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        poster.backgroundColor = UIColor.tertiarySystemFill

        let interaction = UIContextMenuInteraction(delegate: cellContextMenu)
        poster.addInteraction(interaction)

        progress.trackTintColor = UIColor(asset: .globalTint).withAlphaComponent(0.4)
        progress.progressTintColor = UIColor(asset: .globalTint)
        progress.roundedCorners = true
        progress.thicknessRatio = 0.2
    }

    deinit {
        print("LastWatchedTableViewCell deinit")
    }

    var user: User! {
        didSet {
            if user == oldValue { return } // do not update if it's the same user to avoid spamming update
            title.text = ""
            subtitle.text = ""
            meta.text = "Loading..."
            poster.movie = nil
            poster.show = nil

            progress.isHidden = true

            if let user = user {
                if user.isCurrentUser {
                    WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
                        guard let self = self else { return }
                        self.updateInfo()
                    }.disposed(by: disposeBag)

                    WatchingManager.shared.onProgressChangedReceiver.hotOnly().listen { [weak self] _ in
                        guard let self = self else { return }
                        self.updateInfo()
                    }.disposed(by: disposeBag)

                    onMarkWatchedReceiver.listen { [weak self] _ in
                        guard let self = self else { return }
                        self.updateInfo()
                    }.disposed(by: disposeBag)

                    onRemoveWatchReceiver.listen { [weak self] _ in
                        guard let self = self else { return }
                        self.updateInfo()
                    }.disposed(by: disposeBag)
                } else {
                    // only use the timer to refresh if it's another user
                    refreshWatchingTimer?.invalidate()
                    refreshWatchingTimer = Timer.scheduledTimer(withTimeInterval: 60.0,
                                                                repeats: true,
                                                                block: { [weak self] _ in
                                                                    guard let self = self else { return }
                                                                    self.updateInfo()
                                                                })
                }
            }
            updateInfo()
        }
    }

    private func updateInfo() {
        if let user = user {
            if user.isCurrentUser {
                watching = WatchingManager.shared.watchingItem
                if watching == nil {
                    loadLastWatched()
                }
            } else {
                TraktAPIProvider.provider.request(.watching(slug: user.slug),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()
                            if response.statusCode == 204 {
                                self.loadLastWatched()
                                return
                            }

                            let watchingItem = try response.map(WatchingItem.self, using: TraktAPIProvider.decoder)

                            print("Fetched watching")
                            DispatchQueue.main.async {
                                self.watching = watchingItem
                            }
                        } catch {
                            print("Watching request JSON mapping failed! \(error)")
                            DispatchQueue.main.async {
                                self.loadLastWatched()
                            }
                        }
                    case .failure(let error):
                        print("Watching request failure \(error)")
                        DispatchQueue.main.async {
                            self.loadLastWatched()
                        }
                    }
                }
            }
        }
    }

    private func loadLastWatched() {
        loadLastHistoryItem { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.title.text = "Error"
                self.subtitle.text = "Tap to retry"
                self.meta.text = "\(error.localizedDescription)"
                self.poster.movie = nil
                self.poster.show = nil

                self.progress.isHidden = true
            }
        }
    }

    private func loadLastHistoryItem(with completion: @escaping (_ error: Error?) -> Void) {
        request = TraktAPIProvider.provider.request(TraktAPIService.history(slug: user.slug, type: nil, id: nil, pageInfo: PageInfo.firstPage(with: 1), endDate: nil),
                                                    callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let fetchedActivities = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.lastItem = fetchedActivities.first
                        completion(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Last activity (/history) request JSON mapping failed! \(error)")
                        completion(error)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("Last activity (/history) request failure \(error)")
                    completion(error)
                }
            }
        }
    }

    private var watching: WatchingItem? {
        didSet {
            if let item = watching {
                let media = MediaModel(item: item)

                subtitle.text = "Now Watching"

                let now = Date.now.timeIntervalSinceReferenceDate
                let start = item.startDate.timeIntervalSinceReferenceDate
                let end = item.expireDate.timeIntervalSinceReferenceDate

                let currentProgress = (now - start) / (end - start)

                progress.updateProgress(CGFloat(currentProgress),
                                        animated: false)
                progress.isHidden = false

                switch media! {
                case .movie(let movie):
                    setupMovie(movie: movie)
                case .show:
                    fatalError()
                case .episode(let episode, let show):
                    setupEpisode(episode: episode, show: show)
                case .season:
                    fatalError()
                case .list:
                    fatalError()
                case .showProgress:
                    fatalError()
                }
            }
        }
    }

    private var lastItem: HistoryItem? {
        didSet {
            if let item = lastItem {
                let media = MediaModel(item: item)
                subtitle.text = "Last Watched"

                progress.isHidden = true

                switch media! {
                case .movie(let movie):
                    setupMovie(movie: movie)
                case .show:
                    fatalError()
                case .episode(let episode, let show):
                    setupEpisode(episode: episode, show: show)
                case .season:
                    fatalError()
                case .list:
                    fatalError()
                case .showProgress:
                    fatalError()
                }
            } else {
                title.text = "Nothing"
                subtitle.text = "Last Watched"
                meta.text = ""
                poster.movie = nil
                poster.show = nil

                progress.isHidden = true
            }
        }
    }

    private func setupMovie(movie: Movie) {
        title.text = movie.title
        meta.text = if let releaseYear = movie.releaseYear { "\(releaseYear)" } else { "" }
        poster.movie = movie
        cellContextMenu.media = media
    }

    private func setupEpisode(episode: Episode, show: Show) {
        title.text = show.title
        meta.text = episode.localizedEpisodeNumber
        poster.show = show
        cellContextMenu.media = show.mediaModel
    }

    var media: MediaModel? {
        if let watching = watching {
            return MediaModel(item: watching)
        } else if let lastItem = lastItem {
            return MediaModel(item: lastItem)
        } else {
            return nil
        }
    }

    @IBAction func posterAction(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .details)
    }
}
