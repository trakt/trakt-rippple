//
//  EpisodeShowTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 20/10/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver
import UIKit

final class EpisodeShowTableViewCell: UITableViewCell {
    @IBOutlet var title: RedactableLabel!
    @IBOutlet var subtitle: UILabel!
    @IBOutlet var additionalInfo: UILabel!
    @IBOutlet var watched: UIView!

    @IBOutlet var card: CardView!

    private let disposeBag = DisposeBag()

    private let fullDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    var resetDate: Date?
    var progress: EpisodeProgress? {
        didSet {
            switch media {
            case .episode(let episode, let show):
                setupEpisode(episode: episode, show: show)
            default:
                fatalError("Media type not handled in SeasonShowTableViewCell")
            }
        }
    }

    var media: MediaModel! {
        didSet {
            if media != oldValue {
                menuButtonContextMenu.media = media

                switch media {
                case .episode(let episode, let show):
                    setupEpisode(episode: episode, show: show)
                default:
                    fatalError("Media type not handled in SeasonShowTableViewCell")
                }
            }
        }
    }

    @IBOutlet var menuButton: UIButton!

    private let menuButtonContextMenu = MediaContextMenuInteractionDelegate()

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        additionalInfo.textColor = UIColor(asset: .globalTint)

        var configuration = UIButton.Configuration.plain()
        configuration.buttonSize = .small
        configuration.image = UIImage(systemName: "ellipsis")
        menuButton.configuration = configuration
        menuButton.preferredBehavioralStyle = .pad

        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = menuButtonContextMenu.menu
        menuButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.menuButton.menu = self.menuButtonContextMenu.menu
            UISelectionFeedbackGenerator().selectionChanged()
            self.menuButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
        }, for: .menuActionTriggered)

        selectionStyle = .default
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        selectedBackgroundView = backgroundView
        let multipleBackgroundView = UIView()
        multipleBackgroundView.backgroundColor = .tertiarySystemBackground
        multipleSelectionBackgroundView = multipleBackgroundView

        maximumContentSizeCategory = .extraExtraExtraLarge
    }

    private var historyRequest: Cancellable?
    override func prepareForReuse() {
        super.prepareForReuse()

        historyRequest?.cancel()
        historyRequest = nil
    }

    private func setupEpisode(episode: Episode, show: Show) {
        if let firstAired = episode.firstAired {
            if firstAired < Date() {
                title.textColor = .label
                subtitle.textColor = .secondaryLabel
            } else {
                title.textColor = .secondaryLabel
                subtitle.textColor = .secondaryLabel
            }
        } else {
            title.textColor = .tertiaryLabel
            subtitle.textColor = .tertiaryLabel
        }

        updateTitle(for: episode, isWatched: progress?.completed == true)

        if let firstAired = episode.firstAired {
            let relativeDate = CalendarRelativeDateFormatter.string(for: firstAired, uppercaseFirstLetter: true)
            subtitle.text = "\(relativeDate) on \(fullDateFormatter.string(from: firstAired))"
        } else {
            subtitle.text = "Airing unknown"
        }

        watched.backgroundColor = UIColor(asset: .globalTint)

        // if it's a special, check the history instead of progress because progress is not going to help
        if episode.season == 0 {
            // Cancel any previous request before starting a new one
            historyRequest?.cancel()
            historyRequest = nil

            // Default state while loading history
            if let firstAired = episode.firstAired {
                if firstAired < Date() {
                    watched.alpha = 0.2
                } else {
                    watched.alpha = 0.0
                }
            } else {
                watched.alpha = 0.0
            }

            // Fetch history for this specific episode to determine watched status
            historyRequest = TraktAPIProvider.provider.request(.history(slug: UserManager.shared.currentUser?.slug ?? "me",
                                                                        type: .episodes,
                                                                        id: episode.identifiers.trakt,
                                                                        pageInfo: PageInfo.firstPage(with: 1),
                                                                        endDate: nil), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                if self.historyRequest?.isCancelled == true { return }
                self.historyRequest = nil
                switch result {
                case .success(let response):
                    _ = try? response.filterSuccessfulStatusCodes()
                    let items = try? response.map([HistoryItem].self, using: TraktAPIProvider.decoder)
                    if items?.isEmpty == false {
                        DispatchQueue.main.async {
                            guard self.media == MediaModel.episode(episode, show) else { return }
                            self.watched.alpha = 1.0
                            self.updateTitle(for: episode, isWatched: true)
                        }
                    }
                case .failure:
                    break
                }
            }

            return
        }

        if let progress = progress {
            if progress.completed {
                if let resetDate = resetDate, let lastWatchedDate = progress.lastWatchedAt {
                    if lastWatchedDate.distance(to: resetDate) > 0 {
                        watched.backgroundColor = UIColor(asset: .globalTint).lighter().lighter()
                    }
                }
                watched.alpha = 1.0
            } else {
                if let firstAired = episode.firstAired {
                    if firstAired < Date() {
                        watched.alpha = 0.2
                    } else {
                        watched.alpha = 0.0
                    }
                } else {
                    watched.alpha = 0.0
                }
            }
        } else {
            if let firstAired = episode.firstAired {
                if firstAired < Date() {
                    watched.alpha = 0.2
                } else {
                    watched.alpha = 0.0
                }
            } else {
                watched.alpha = 0.0
            }
        }
    }

    private func updateTitle(for episode: Episode, isWatched: Bool) {
        if let episodeTitle = episode.title {
            let episodeText = episode.localizedEpisodeNumber + " · \(episodeTitle)"
            let episodeTitleRange = (episodeText as NSString).range(of: episodeTitle,
                                                                    options: .backwards)
            title.isRedactedByDefault =
                isWatched == false &&
                UserDefaults.standard.bool(forKey: "GeneralSettings.listsepisodetitle") == false
            title.setText(episodeText, redacting: episodeTitleRange)
        } else if let episodeType = episode.episodeType {
            title.isRedactedByDefault = false
            switch episodeType {
            case .standard:
                title.text = episode.localizedEpisodeNumber
            case .seriesPremiere:
                title.text = episode.localizedEpisodeNumber + " · Series Premiere"
            case .seasonPremiere:
                title.text = episode.localizedEpisodeNumber + " · Season Premiere"
            case .midSeasonFinale:
                title.text = episode.localizedEpisodeNumber + " · Mid Season Finale"
            case .midSeasonPremiere:
                title.text = episode.localizedEpisodeNumber + " · Mid Season Premiere"
            case .seasonFinale:
                title.text = episode.localizedEpisodeNumber + " · Season Finale"
            case .seriesFinale:
                title.text = episode.localizedEpisodeNumber + " · Series Finale"
            case .unknown:
                title.text = episode.localizedEpisodeNumber
            }
        } else {
            title.isRedactedByDefault = false
            title.text = episode.localizedEpisodeNumber
        }
    }
}
