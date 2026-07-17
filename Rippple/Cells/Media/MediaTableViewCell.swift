//
//  MediaTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 12/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

protocol MediaTableViewCellDelegate: AnyObject {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action)
}

final class MediaTableViewCell: UITableViewCell {
    enum Action {
        case details
        case close
    }

    weak var delegate: MediaTableViewCellDelegate? {
        didSet {
            cellContextMenu.controller = delegate as? UIViewController
            menuButtonContextMenu.controller = delegate as? UIViewController
        }
    }

    @IBOutlet var title: UILabel!
    @IBOutlet var subtitle: UILabel!
    @IBOutlet var meta: CommentCountLabel?
    @IBOutlet var submeta: LinkEnabledLabel?

    @IBOutlet var progress: ShowProgressBar?

    @IBOutlet var poster: PosterButton!

    @IBOutlet var recommendedStatus: RecommendedImageView?
    @IBOutlet var watchlistedStatus: WatchlistImageView?
    @IBOutlet var watchedStatus: WatchedImageView?
    @IBOutlet var toWatchStatus: ToWatchImageView?
    @IBOutlet var collectedStatus: CollectedImageView?
    @IBOutlet var commentedStatus: CommentedImageView?
    @IBOutlet var ratedStatus: RatingImageView?
    @IBOutlet var hiddenStatus: HiddenImageView?
    @IBOutlet var droppedStatus: DroppedImageView?
    @IBOutlet var pinnedStatus: PinnedImageView?
    @IBOutlet var listedStatus: ListedImageView?

    @IBOutlet var whereToWatchImageView: WhereToWatchImageView?

    @IBOutlet var menuButtonContainter: UIView?
    @IBOutlet var closeButton: UIButton?

    @IBOutlet var notesButton: UIButton?

    @IBOutlet var rateButton: UIButton?

    private let disposeBag = DisposeBag()

    var ratedItem: RatedItem? {
        didSet {
            if let ratedItem = ratedItem {
                media = MediaModel(item: ratedItem)
            }
        }
    }

    var calendarMode = false
    var toWatchMode = false
    var dimmedIfWatched = true
    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie(let movie):
                cellContextMenu.media = media
                menuButtonContextMenu.media = media
                progress?.media = nil
                progress?.superview?.isHiddenInStackView = true
                whereToWatchImageView?.isHiddenInStackView = true
                setupMovie(movie: movie)
            case .show(let show):
                cellContextMenu.media = media
                menuButtonContextMenu.media = media
                progress?.hideIfNoProgress = true
                progress?.media = media
                whereToWatchImageView?.isHiddenInStackView = true
                setupShow(show: show)
            case .episode(let episode, let show):
                cellContextMenu.media = show.mediaModel
                menuButtonContextMenu.media = media
                progress?.media = nil
                progress?.superview?.isHiddenInStackView = true
                whereToWatchImageView?.isHiddenInStackView = true
                setupEpisode(episode: episode, show: show)
            case .season(let season, let show):
                cellContextMenu.media = show.mediaModel
                menuButtonContextMenu.media = media
                progress?.media = nil
                progress?.superview?.isHiddenInStackView = true
                whereToWatchImageView?.isHiddenInStackView = true
                setupSeason(season: season, show: show)
            case .list:
                fatalError()
            case .showProgress(let show, let showProgress):
                if let episode = showProgress.nextEpisodeToWatch {
                    cellContextMenu.media = show.mediaModel
                    menuButtonContextMenu.media = episode.mediaModel(given: show)
                } else {
                    cellContextMenu.media = show.mediaModel
                    menuButtonContextMenu.media = show.mediaModel
                }
                progress?.media = nil
                progress?.superview?.isHiddenInStackView = true
                whereToWatchImageView?.isHiddenInStackView = true // will be set after if needed
                setupShowProgress(episode: showProgress.nextEpisodeToWatch, show: show, progress: showProgress)
            }

            updateSyncWatchedDimmingIfNeeded()

            if rateButton?.isHidden == false {
                var configuration = rateButton?.configuration
                configuration?.indicator = .popup
                configuration?.baseBackgroundColor = UIColor { trait in
                    trait.userInterfaceStyle == .dark ? UIColor(asset: .globalTint).withAlphaComponent(0.2) : UIColor(asset: .globalTint).lighter(amount: 0.1).withAlphaComponent(0.2)
                }
                configuration?.title = ""
                configuration?.contentInsets = NSDirectionalEdgeInsets(top: 2,
                                                                       leading: 4,
                                                                       bottom: 2,
                                                                       trailing: 4)
                configuration?.imagePadding = .zero
                if let rating = media.userRating {
                    configuration?.image = UIImage(systemName: "\(rating).circle")
                } else {
                    configuration?.image = UIImage(systemName: "heart")
                }
                rateButton?.configuration = configuration

                rateButton?.menu = media.rateMenu
                rateButton?.showsMenuAsPrimaryAction = true
            }

            if let menuButtonContainter = menuButtonContainter {
                for subviews in menuButtonContainter.subviews {
                    subviews.removeFromSuperview()
                }

                let menuButton = UIButton(frame: menuButtonContainter.bounds)
                menuButton.translatesAutoresizingMaskIntoConstraints = false
                menuButtonContainter.addSubview(menuButton)
                NSLayoutConstraint.activate([
                    menuButton.topAnchor.constraint(equalTo: menuButtonContainter.topAnchor),
                    menuButton.bottomAnchor.constraint(equalTo: menuButtonContainter.bottomAnchor),
                    menuButton.leadingAnchor.constraint(equalTo: menuButtonContainter.leadingAnchor),
                    menuButton.trailingAnchor.constraint(equalTo: menuButtonContainter.trailingAnchor)
                ])

                menuButton.menu = menuButtonContextMenu.menu
                menuButton.showsMenuAsPrimaryAction = true
                menuButton.isPointerInteractionEnabled = true

                var configuration = UIButton.Configuration.plain()
                configuration.buttonSize = .large
                configuration.image = UIImage(systemName: "ellipsis")
                menuButton.configuration = configuration
                menuButton.preferredBehavioralStyle = .pad

                if media.showProgressShow != nil {
                    menuButton.addAction(UIAction { [weak self] _ in
                        guard let self = self else { return }
                        menuButton.menu = self.menuButtonContextMenu.toWatchMenu
                        UISelectionFeedbackGenerator().selectionChanged()
                        menuButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                    }, for: .menuActionTriggered)
                } else {
                    menuButton.addAction(UIAction { [weak self] _ in
                        guard let self = self else { return }
                        menuButton.menu = self.menuButtonContextMenu.menu
                        UISelectionFeedbackGenerator().selectionChanged()
                        menuButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                    }, for: .menuActionTriggered)
                }
            }
            invalidateIntrinsicContentSize()
        }
    }

    var note: String? {
        didSet {
            submeta?.isHiddenInStackView = false
            if let note = note, note.isEmpty == false {
                submeta?.attributedText = attributedString()
                notesButton?.isUserInteractionEnabled = true
            } else {
                submeta?.attributedText = nil
                submeta?.isHiddenInStackView = true
                notesButton?.isUserInteractionEnabled = false
            }
            invalidateIntrinsicContentSize()
        }
    }

    private var markdownParser = SpoilerMarkdownParser(font: UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge))),
                                                       automaticLinkDetectionEnabled: true)
    private func attributedString() -> NSAttributedString? {
        guard let note = note else { return nil }

        markdownParser.color = .label
        markdownParser.strike.strikeColor = .label
        markdownParser.strike.color = .label
        markdownParser.highlight.color = .label
        markdownParser.highlight.highlightColor = UIColor(asset: .globalTint).withAlphaComponent(0.4)
        markdownParser.spoiler.color = .label
        markdownParser.allSpoiler.color = .label
        markdownParser.displaySpoiler.color = .label
        markdownParser.mention.color = .label
        markdownParser.highlight.font = UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge)))

        markdownParser.spoilerStrategy = .showAllSpoilers

        return markdownParser.parse(note.htmlDecoded.emojiUnescapedString)
    }

    private let cellContextMenu = MediaContextMenuInteractionDelegate()
    private let menuButtonContextMenu = MediaContextMenuInteractionDelegate()

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        submeta?.isHiddenInStackView = true
        rateButton?.isHiddenInStackView = true

        rateButton?.backgroundColor = UIColor(asset: .globalTint).withAlphaComponent(0.1)

        poster.layer.cornerRadius = ViewRadius.medium.rawValue
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.layer.borderWidth = 1
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        poster.backgroundColor = UIColor.tertiarySystemFill

        let interaction = UIContextMenuInteraction(delegate: cellContextMenu)
        poster.addInteraction(interaction)

        onShowsHiddenFromProgressMediaChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            switch self.media {
            case .showProgress(let show, _):
                if show.isHiddenFromProgress {
                    self.contentView.alpha = 0.6
                } else {
                    self.contentView.alpha = 1.0
                }
            default:
                self.contentView.alpha = 1.0
            }
        }.disposed(by: disposeBag)

        onCommentsCountDisplayReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if case .showProgress = self.media { return }
            self.meta?.media = nil
            self.meta?.media = self.media
        }.disposed(by: disposeBag)

        meta?.maximumContentSizeCategory = .extraExtraExtraLarge
        recommendedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        watchlistedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        watchedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        toWatchStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        collectedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        commentedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        ratedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        hiddenStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        droppedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        pinnedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        rateButton?.maximumContentSizeCategory = .accessibilityExtraExtraLarge
        listedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge

        onCompletedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if dimmedIfWatched == false { return }
            if case .show(let show) = self.media {
                DispatchQueue.main.async {
                    if show.isCompleted, self.closeButton == nil {
                        self.contentView.alpha = 0.6
                    } else {
                        self.contentView.alpha = 1.0
                    }
                }
            }
        }.disposed(by: disposeBag)

        onSyncWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if case .movie = self.media {
                self.updateSyncWatchedDimmingIfNeeded()
            }
        }.disposed(by: disposeBag)

        onSyncWatchedEpisodesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if case .episode = self.media {
                self.updateSyncWatchedDimmingIfNeeded()
            }
        }.disposed(by: disposeBag)

        onShowsHiddenFromProgressMediaChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if dimmedIfWatched == false { return }
            if case .showProgress(let show, _) = self.media {
                if show.isHiddenFromProgress, closeButton == nil {
                    contentView.alpha = 0.6
                } else {
                    contentView.alpha = 1.0
                }
            }
        }.disposed(by: disposeBag)

        onProgressCacheChangedReceiver.hotOnly().listen { [weak self] progress in
            guard let self = self else { return }
            if dimmedIfWatched == false { return }
            if case .season(let season, let show) = self.media, progress.show == show {
                DispatchQueue.main.async {
                    self.setDimmed(progress.showProgress.isWatched(season: season))
                }
            }
        }.disposed(by: disposeBag)

        RatingsManager.shared.onRatedItemsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            guard let rateButton = self.rateButton else { return }
            if rateButton.isHidden == false {
                var configuration = rateButton.configuration
                if let rating = self.media.userRating {
                    configuration?.image = UIImage(systemName: "\(rating).circle")
                } else {
                    configuration?.image = UIImage(systemName: "heart")
                }
                rateButton.configuration = configuration

                rateButton.menu = self.media.rateMenu
            }
        }.disposed(by: disposeBag)

        notesButton?.isUserInteractionEnabled = false
    }

    private func setDimmed(_ dimmed: Bool) {
        if dimmedIfWatched == false || closeButton != nil {
            contentView.alpha = 1.0
        } else {
            contentView.alpha = dimmed ? 0.6 : 1.0
        }
    }

    private func updateSyncWatchedDimmingIfNeeded() {
        switch media {
        case .movie(let movie):
            setDimmed(SyncWatchedManager.shared.isWatched(type: .movies,
                                                          traktId: movie.identifiers.trakt!))
        case .episode(let episode, _):
            setDimmed(SyncWatchedManager.shared.isWatched(type: .episodes,
                                                          traktId: episode.identifiers.trakt!))
        default:
            break
        }
    }

    private func episodeEventLabel(for episode: Episode) -> String? {
        switch episode.episodeType {
        case .seriesPremiere?:
            return "Series Premiere"
        case .seasonPremiere?:
            return "Season Premiere"
        case .midSeasonFinale?:
            return "Mid Season Finale"
        case .midSeasonPremiere?:
            return "Mid Season Premiere"
        case .seasonFinale?:
            return "Season Finale"
        case .seriesFinale?:
            return "Series Finale"
        case .standard?, .unknown?, nil:
            if episode.season == 1, episode.number == 1 {
                return "Series Premiere"
            } else if episode.number == 1 {
                return "Season Premiere"
            } else {
                return nil
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        notesButton?.isUserInteractionEnabled = false

        submeta?.isHiddenInStackView = true
        dimmedIfWatched = true
        menuButtonContainter?.isHiddenInStackView = false
    }

    private func setupMovie(movie: Movie) {
        title.text = movie.title

        if calendarMode == true {
            var info = [String]()
            if let release = movie.releaseYear {
                info.append("\(release)")
            }
            if let status = movie.status, status != "released" {
                info.append(status)
            }
            subtitle.text = info.joined(separator: " · ")
            submeta?.isHiddenInStackView = false

            let media: MediaModel = .movie(movie)

            recommendedStatus?.media = media
            collectedStatus?.media = media
            watchlistedStatus?.media = media
            watchedStatus?.media = media
            toWatchStatus?.isHiddenInStackView = true
            commentedStatus?.media = media
            if let ratedItem = ratedItem {
                ratedStatus?.ratedItem = ratedItem
            } else {
                ratedStatus?.media = media
            }
            hiddenStatus?.isHiddenInStackView = true
            pinnedStatus?.isHiddenInStackView = true
            droppedStatus?.isHiddenInStackView = true
            listedStatus?.isHiddenInStackView = true

            poster.movie = movie

            whereToWatchImageView?.media = media

            return
        }

        var info = [String]()
        if let release = movie.releaseYear {
            info.append("\(release)")
        }
        if let status = movie.status, status != "released" {
            info.append(status)
        }
        subtitle.text = info.joined(separator: " · ")

        let media: MediaModel = .movie(movie)
        meta?.media = media

        if toWatchMode {
            recommendedStatus?.isHiddenInStackView = true
            collectedStatus?.isHiddenInStackView = true
            watchlistedStatus?.isHiddenInStackView = true
            watchedStatus?.isHiddenInStackView = true
            toWatchStatus?.isHiddenInStackView = true
            commentedStatus?.isHiddenInStackView = true
            ratedStatus?.isHiddenInStackView = true
            hiddenStatus?.isHiddenInStackView = true
            droppedStatus?.isHiddenInStackView = true
            pinnedStatus?.isHiddenInStackView = true
            whereToWatchImageView?.media = media
            listedStatus?.isHiddenInStackView = true
        } else {
            recommendedStatus?.media = media
            collectedStatus?.media = media
            watchlistedStatus?.media = media
            watchedStatus?.media = media
            toWatchStatus?.isHiddenInStackView = true
            commentedStatus?.media = media
            if let ratedItem = ratedItem {
                ratedStatus?.ratedItem = ratedItem
            } else {
                ratedStatus?.media = media
            }
            hiddenStatus?.isHiddenInStackView = true
            droppedStatus?.isHiddenInStackView = true
            pinnedStatus?.media = media
            whereToWatchImageView?.media = media
            listedStatus?.media = media
        }

        poster.movie = movie
    }

    private func setupEpisode(episode: Episode, show: Show) {
        title.text = show.title

        if calendarMode == true {
            let media: MediaModel = .episode(episode, show)
            watchlistedStatus?.media = media
            watchedStatus?.media = media
            recommendedStatus?.isHiddenInStackView = true
            collectedStatus?.media = media
            toWatchStatus?.isHiddenInStackView = true
            commentedStatus?.media = media

            if episode.isWatched, let title = episode.title {
                subtitle.text = episode.localizedEpisodeNumber + " · \(title)"
            } else if let eventLabel = episodeEventLabel(for: episode) {
                subtitle.text = episode.localizedEpisodeNumber + " · \(eventLabel)"
            } else {
                subtitle.text = episode.localizedEpisodeNumber
            }

            submeta?.isHiddenInStackView = false

            if let ratedItem = ratedItem {
                ratedStatus?.ratedItem = ratedItem
            } else {
                ratedStatus?.media = media
            }
            hiddenStatus?.isHiddenInStackView = true
            pinnedStatus?.isHiddenInStackView = true
            droppedStatus?.isHiddenInStackView = true
            listedStatus?.isHiddenInStackView = true

            poster.show = show

            whereToWatchImageView?.media = media

            return
        }

        if let title = episode.title {
            subtitle.text = episode.localizedEpisodeNumber + " · \(title)"
        } else {
            subtitle.text = episode.localizedEpisodeNumber
        }

        let media: MediaModel = .episode(episode, show)
        meta?.media = media

        watchlistedStatus?.media = media
        watchedStatus?.media = media
        recommendedStatus?.isHiddenInStackView = true
        collectedStatus?.media = media
        toWatchStatus?.isHiddenInStackView = true
        commentedStatus?.media = media
        if let ratedItem = ratedItem {
            ratedStatus?.ratedItem = ratedItem
        } else {
            ratedStatus?.media = media
        }
        hiddenStatus?.isHiddenInStackView = true
        pinnedStatus?.isHiddenInStackView = true
        droppedStatus?.isHiddenInStackView = true
        whereToWatchImageView?.media = media
        listedStatus?.media = media

        poster.show = show
    }

    private func setupShowProgress(episode: Episode?, show: Show, progress: ShowProgress) {
        if let episode = episode {
            title.text = show.title

            subtitle.text = "\(episode.localizedEpisodeNumber)"
            if let runtime = episode.runtime {
                subtitle.text = "\(subtitle.text!) · \(runtime)′"
            } else if let runtime = show.runtime {
                subtitle.text = "\(subtitle.text!) · \(runtime)′"
            }
            if let episodeType = episode.episodeType {
                switch episodeType {
                case .standard:
                    break
                case .seriesPremiere:
                    subtitle.text = "\(subtitle.text!) · Series Premiere"
                case .seasonPremiere:
                    subtitle.text = "\(subtitle.text!) · Season Premiere"
                case .midSeasonFinale:
                    subtitle.text = "\(subtitle.text!) · Mid Season Finale"
                case .midSeasonPremiere:
                    subtitle.text = "\(subtitle.text!) · Mid Season Premiere"
                case .seasonFinale:
                    subtitle.text = "\(subtitle.text!) · Season Finale"
                case .seriesFinale:
                    subtitle.text = "\(subtitle.text!) · Series Finale"
                case .unknown:
                    break
                }
            }

            if UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle") == true, let title = episode.title {
                submeta?.isHiddenInStackView = false
                submeta?.text = title
            } else {
                submeta?.isHiddenInStackView = true
            }

            if progress.toRewatchCount > 0 {
                meta?.text = "\(progress.toRewatchCount) to rewatch"
            } else {
                let behind = progress.behind
                if behind > 0 {
                    meta?.text = "\(behind) behind"
                } else {
                    meta?.text = "At least one behind"
                }
            }

            recommendedStatus?.isHiddenInStackView = true
            collectedStatus?.isHiddenInStackView = true
            watchlistedStatus?.isHiddenInStackView = true
            watchedStatus?.isHiddenInStackView = true
            toWatchStatus?.isHiddenInStackView = true
            commentedStatus?.isHiddenInStackView = true
            ratedStatus?.isHiddenInStackView = true
            hiddenStatus?.isHiddenInStackView = true
            pinnedStatus?.isHiddenInStackView = true
            droppedStatus?.isHiddenInStackView = true
            whereToWatchImageView?.media = media
            listedStatus?.isHiddenInStackView = true

            poster.show = show
        }

        if dimmedIfWatched == false {
            contentView.alpha = 1.0
        } else {
            if show.isHiddenFromProgress, closeButton == nil {
                contentView.alpha = 0.6
            } else {
                contentView.alpha = 1.0
            }
        }
    }

    private func setupSeason(season: Season, show: Show) {
        title.text = show.title
        if let seasonTitle = season.title {
            subtitle.text = seasonTitle
        } else if season.number > 0 {
            subtitle.text = "Season \(season.number)"
        } else {
            subtitle.text = "A Season"
        }

        meta?.media = media

        recommendedStatus?.isHiddenInStackView = true
        collectedStatus?.isHiddenInStackView = true
        watchlistedStatus?.media = media
        watchedStatus?.media = media
        toWatchStatus?.isHiddenInStackView = true
        commentedStatus?.isHiddenInStackView = true
        if let ratedItem = ratedItem {
            ratedStatus?.ratedItem = ratedItem
        } else {
            ratedStatus?.media = media
        }
        hiddenStatus?.media = media
        pinnedStatus?.isHiddenInStackView = true
        droppedStatus?.isHiddenInStackView = true
        whereToWatchImageView?.media = media
        listedStatus?.media = media

        poster.season = (show, season)

        setDimmed(false)
        guard show.isWatchedAtLeastOnce else { return }

        show.mediaModel.progress { [weak self] progress in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard case .season(let currentSeason, let currentShow) = self.media,
                      currentSeason == season,
                      currentShow == show else { return }

                self.setDimmed(progress?.isWatched(season: season) == true)
            }
        }
    }

    private func setupShow(show: Show) {
        title.text = show.title

        var info = [String]()
        if let airedEpisodes = show.airedEpisodes, airedEpisodes != 0 {
            info.append("\(airedEpisodes) episode\(airedEpisodes > 1 ? "s" : "")")
        } else if let release = show.releaseYear {
            info.append("\(release)")
        }
        if let status = show.status, status != "returning series" {
            info.append(status.capitalized)
        }
        subtitle.text = info.joined(separator: " · ")

        meta?.media = media

        recommendedStatus?.media = media
        watchlistedStatus?.media = media
        watchedStatus?.media = media
        toWatchStatus?.media = media
        collectedStatus?.media = media
        commentedStatus?.isHiddenInStackView = true
        if let ratedItem = ratedItem {
            ratedStatus?.ratedItem = ratedItem
        } else {
            ratedStatus?.media = media
        }
        hiddenStatus?.media = media
        droppedStatus?.media = media
        pinnedStatus?.media = media
        whereToWatchImageView?.media = media
        listedStatus?.media = media

        poster.show = show

        if dimmedIfWatched == false {
            contentView.alpha = 1.0
        } else {
            if show.isCompleted, closeButton == nil {
                contentView.alpha = 0.6
            } else {
                contentView.alpha = 1.0
            }
        }
    }

    @IBAction func posterAction(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .details)
    }

    @IBAction func closeAction(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .close)
    }
}
