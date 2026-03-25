//
//  MediaTitleTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 14/01/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

import Moya
import Haring
import Receiver

extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor!, size: 0) // size 0 means keep the size as it is
    }

    func bold() -> UIFont {
        return withTraits(traits: .traitBold)
    }

    func italic() -> UIFont {
        return withTraits(traits: .traitItalic)
    }
}

protocol MediaTitleTableViewCellDelegate: AnyObject {
    func cell(_ cell: MediaTitleTableViewCell, action: MediaTitleTableViewCell.Action)
}

extension UIView {
    var isHiddenInStackView: Bool {
        get {
            return isHidden
        }
        set {
            if isHidden != newValue {
                isHidden = newValue
            }
        }
    }
}

final class MediaTitleTableViewCell: UITableViewCell {

    private let disposeBag = DisposeBag()

    enum Action {
        case presentShow
        case presentCertifications
        case presentMedia(MediaModel)
    }

    weak var delegate: MediaTitleTableViewCellDelegate?

    @IBOutlet weak var genreLabel: UILabel!
    @IBOutlet weak var certificationLabel: UILabel!

    @IBOutlet weak var certificationBorderView: UIView!

    @IBOutlet weak var ratingsStack: UIView!
    @IBOutlet weak var rottenTomatoesCriticsRating: EFCountingLabel!
    @IBOutlet weak var rottenTomatoesAudienceRating: EFCountingLabel!
    @IBOutlet weak var rottentTomatoesCriticsImage: UIImageView!
    @IBOutlet weak var rottenTomatoesAudienceImage: UIImageView!

    @IBOutlet weak var runtimeLabel: UILabel!
    @IBOutlet weak var stingerLabel: UILabel!

    @IBOutlet weak var mainActionButton: UIButton!
    @IBOutlet weak var secondaryActionButton: UIButton!

    private var mainActionButtonMinHeightConstraint: NSLayoutConstraint?
    private var secondaryActionButtonMinHeightConstraint: NSLayoutConstraint?

    private let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let dateFormatter = RelativeDateTimeFormatter()
        dateFormatter.unitsStyle = .full
        dateFormatter.dateTimeStyle = .numeric
        dateFormatter.formattingContext = .dynamic
        return dateFormatter
    }()

    @IBOutlet weak var cardView: UIView!

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        cancelCancellable()
    }

    private var debouncedUpdateQuickActions: Debouncer!

    override func awakeFromNib() {
        super.awakeFromNib()

        rottenTomatoesCriticsRating.method = .easeInOut
        rottenTomatoesCriticsRating.formatBlock = { value in
            return String(format: "%02d", Int(value)) + "%"
        }
        rottenTomatoesCriticsRating.font = .preferredMonospacedFont(for: .caption2, weight: .regular)
        rottenTomatoesAudienceRating.method = .easeInOut
        rottenTomatoesAudienceRating.formatBlock = { value in
            return String(format: "%02d", Int(value)) + "%"
        }
        rottenTomatoesAudienceRating.font = .preferredMonospacedFont(for: .caption2, weight: .regular)

        debouncedUpdateQuickActions = Debouncer(delay: 0.5) { [weak self] in
            guard let self = self else { return }
            UIView.performWithoutAnimation {
                self.updateQuickActions()
            }
        }

        registerForTraitChanges([UITraitUserInterfaceStyle.self],
                                action: #selector(configureView))
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self],
                                action: #selector(updateQuickActionButtonMinimumHeightsForTraitChanges))

        certificationBorderView.layer.borderWidth = 0.8
        certificationBorderView.layer.borderColor = UIColor.secondaryLabel.cgColor
        certificationBorderView.layer.cornerRadius = 5.0
        certificationBorderView.layer.cornerCurve = .continuous

        onShowsToWatchChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            guard let media = self.media else { return }
            // If it's a show, we update quick actions
            if media.showShow != nil {
                DispatchQueue.main.async {
                    self.debouncedUpdateQuickActions.call()
                }
            }
        }.disposed(by: disposeBag)

        onWatchedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedUpdateQuickActions.call()
        }.disposed(by: disposeBag)

        onWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedUpdateQuickActions.call()
        }.disposed(by: disposeBag)

        RatingsManager.shared.onRatedItemsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedUpdateQuickActions.call()
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedUpdateQuickActions.call()
        }.disposed(by: disposeBag)

        onProgressCacheChangedReceiver.listen { [weak self] progress in
            guard let self = self else { return }
            guard let media = self.media else { return }
            if progress.show == media.show {
                self.debouncedUpdateQuickActions.call()
            }
        }.disposed(by: disposeBag)

        mainActionButton.configuration = UIButton.Configuration.borderedTinted()
        mainActionButton.configuration?.imagePadding = 5
        secondaryActionButton.configuration = UIButton.Configuration.borderedTinted()
        secondaryActionButton.configuration?.imagePadding = 5

        let actionButtonsMinimumHeight = quickActionButtonMinimumHeight()
        let mainActionButtonMinHeightConstraint = mainActionButton.heightAnchor.constraint(
            greaterThanOrEqualToConstant: actionButtonsMinimumHeight)
        mainActionButtonMinHeightConstraint.priority = .required
        mainActionButtonMinHeightConstraint.isActive = true
        self.mainActionButtonMinHeightConstraint = mainActionButtonMinHeightConstraint

        let secondaryActionButtonMinHeightConstraint = secondaryActionButton.heightAnchor.constraint(
            greaterThanOrEqualToConstant: actionButtonsMinimumHeight)
        secondaryActionButtonMinHeightConstraint.priority = .required
        secondaryActionButtonMinHeightConstraint.isActive = true
        self.secondaryActionButtonMinHeightConstraint = secondaryActionButtonMinHeightConstraint

        applyQuickActionButtonMultilineTitleStyle(mainActionButton)
        applyQuickActionButtonMultilineTitleStyle(secondaryActionButton)
    }

    @objc
    private func updateQuickActionButtonMinimumHeightsForTraitChanges() {
        let actionButtonsMinimumHeight = quickActionButtonMinimumHeight()
        mainActionButtonMinHeightConstraint?.constant = actionButtonsMinimumHeight
        secondaryActionButtonMinHeightConstraint?.constant = actionButtonsMinimumHeight
    }

    private func quickActionButtonMinimumHeight() -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: traitCollection)
        let twoLineTextHeight = font.lineHeight * 2
        var configuration = UIButton.Configuration.borderedTinted()
        configuration.imagePadding = 5
        let verticalInsets = configuration.contentInsets.top + configuration.contentInsets.bottom
        let titleSubtitleSpacing: CGFloat = 2
        return ceil(twoLineTextHeight + titleSubtitleSpacing + verticalInsets)
    }

    private func applyQuickActionButtonMultilineTitleStyle(_ button: UIButton) {
        guard var config = button.configuration else { return }
        config.titleLineBreakMode = .byWordWrapping
        config.subtitleLineBreakMode = .byWordWrapping
        button.configuration = config
    }

    @objc
    private func configureView() {
        certificationBorderView.layer.borderColor = self.certificationLabel.textColor.cgColor
    }

    private let contextMenuHelper = ContextMenuHelper()

    var media: MediaModel? {
        didSet {
            if oldValue == media { return }
            switch media! {
            case .movie(let movie):
                if let genres = movie.genres {
                    genreLabel.text = genres.joined(separator: ", ").capitalized
                } else {
                    genreLabel.text = ""
                }
                genreLabel.isHiddenInStackView = genreLabel.text!.isEmpty == true

                if let certification = movie.certification {
                    certificationLabel.text = certification
                } else {
                    certificationLabel.text = ""
                }
                certificationLabel.superview?.isHiddenInStackView = certificationLabel.text!.isEmpty == true
                certificationBorderView.isHiddenInStackView = certificationLabel.text!.isEmpty == true

                if let tmdbId = movie.identifiers.tmdb {
                    stingerLabel.text = "Loading stinger info..."
                    stingerLabel.alpha = 0.0
                    cancellable = fetchStingerFor(service: TmdbAPIService.movieKeywords(tmdbId))
                } else {
                    stingerLabel.text = "No stinger"
                    stingerLabel.alpha = 0.0
                }

                fetchRatingsFor(type: .movie(movieId: movie.identifiers.trakt!))
            case .show(let show):
                if let genres = show.genres {
                    genreLabel.text = genres.joined(separator: ", ").capitalized
                } else {
                    genreLabel.text = ""
                }
                genreLabel.isHiddenInStackView = genreLabel.text!.isEmpty == true

                if let certification = show.certification {
                    certificationLabel.text = certification
                } else {
                    certificationLabel.text = ""
                }
                certificationLabel.superview?.isHiddenInStackView = certificationLabel.text!.isEmpty == true
                certificationBorderView.isHiddenInStackView = certificationLabel.text!.isEmpty == true

                stingerLabel.text = "No stinger"
                stingerLabel.alpha = 0.0

                fetchRatingsFor(type: .show(showId: show.identifiers.trakt!))
            case .episode(let episode, _):
                updateEpisodeMetadata()

                certificationLabel.superview?.isHiddenInStackView = true
                certificationBorderView.isHiddenInStackView = true
                ratingsStack.isHiddenInStackView = true

                if let episodeType = episode.episodeType {
                    switch episodeType {
                    case .standard:
                        stingerLabel.text = ""
                        stingerLabel.alpha = 0.0
                    case .seriesPremiere:
                        stingerLabel.text = "Series Premiere"
                        stingerLabel.alpha = 1.0
                    case .seasonPremiere:
                        stingerLabel.text = "Season Premiere"
                        stingerLabel.alpha = 1.0
                    case .midSeasonFinale:
                        stingerLabel.text = "Mid Season Finale"
                        stingerLabel.alpha = 1.0
                    case .midSeasonPremiere:
                        stingerLabel.text = "Mid Season Premiere"
                        stingerLabel.alpha = 1.0
                    case .seasonFinale:
                        stingerLabel.text = "Season Finale"
                        stingerLabel.alpha = 1.0
                    case .seriesFinale:
                        stingerLabel.text = "Series Finale"
                        stingerLabel.alpha = 1.0
                    case .unknown:
                        break
                    }
                    stingerLabel.alpha = 1.0
                } else {
                    stingerLabel.text = ""
                    stingerLabel.alpha = 0.0
                }
            case .season:
                updateSeasonMetadata()

                certificationLabel.isHiddenInStackView = true
                certificationBorderView.isHiddenInStackView = true
                ratingsStack.isHiddenInStackView = true

                stingerLabel.text = ""
                stingerLabel.alpha = 0.0
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
            debouncedUpdateQuickActions.fireNow()

            updateRuntimeDisplay()
        }
    }

    private func updateSeasonMetadata() {
        guard let media = self.media else { return }
        guard let show = media.show else { return }
        guard let season = media.season else { return }

        let markdownParser = SpoilerMarkdownParser(font: .preferredFont(forTextStyle: .subheadline),
                                            color: .label,
                                            automaticLinkDetectionEnabled: false)
        markdownParser.bold.color = UIColor(asset: .globalTint)
        markdownParser.bold.font = .preferredFont(forTextStyle: .subheadline).bold()
        markdownParser.spoilerStrategy = .hideInlineSpoilers

        // placeholder
        var markdown = "__\(show.title)__ - \(season.localizedSeasonNumber)"
        if let seasonTitle = season.title {
            markdown = "__\(show.title)__ - \(seasonTitle)"
        }
        genreLabel.attributedText = markdownParser.parse(markdown)
        genreLabel.numberOfLines = 0
        genreLabel.isHiddenInStackView = false
    }

    private func updateEpisodeMetadata() {
        guard let media = self.media else { return }
        guard let show = media.show else { return }
        guard let episode = media.episode else { return }

        let markdownParser = SpoilerMarkdownParser(font: .preferredFont(forTextStyle: .subheadline),
                                            color: .label,
                                            automaticLinkDetectionEnabled: false)
        markdownParser.bold.color = UIColor(asset: .globalTint)
        markdownParser.bold.font = .preferredFont(forTextStyle: .subheadline).bold()
        markdownParser.spoilerStrategy = .hideInlineSpoilers

        // placeholder
        var markdown = "__\(show.title)__ \(episode.localizedEpisodeNumber)"
        genreLabel.attributedText = markdownParser.parse(markdown)

        markdown = ""
        if let episodeTitle = episode.title {
            if UserDefaults.standard.bool(forKey: "GeneralSettings.detailepisodetitle") {
                markdown = "__\(show.title)__ \(episode.localizedEpisodeNumber) - \(episodeTitle)"
                genreLabel.attributedText = markdownParser.parse(markdown)
            } else {
                show.mediaModel.progress { [weak self] progress in
                    guard let self = self else { return }
                    if let progress = progress {
                        for season in progress.seasons where season.number == episode.season {
                            for episodeProgress in season.episodes where episodeProgress.number == episode.number {
                                if episodeProgress.completed {
                                    markdown = "__\(show.title)__ \(episode.localizedEpisodeNumber) - \(episodeTitle)"
                                } else {
                                    markdown = "__\(show.title)__ \(episode.localizedEpisodeNumber) - [spoiler]\(episodeTitle)[/spoiler]"
                                }
                            }
                        }
                    }
                    if markdown == "" {
                        markdown = "__\(show.title)__ \(episode.localizedEpisodeNumber) - [spoiler]\(episodeTitle)[/spoiler]"
                    }
                    DispatchQueue.main.async {
                        self.genreLabel.attributedText = markdownParser.parse(markdown)
                        self.invalidateIntrinsicContentSize()
                    }
                }
            }
        } else {
            markdown = "__\(show.title)__ \(episode.localizedEpisodeNumber)"
            genreLabel.attributedText = markdownParser.parse(markdown)
        }
        genreLabel.numberOfLines = 0
        genreLabel.isHiddenInStackView = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        for button in genreLabel.subviews where button.isKind(of: UIButton.self) {
            button.removeFromSuperview()
        }
        placeShowButton()
        placeEpisodeSpoilerButton()
    }

    private func placeShowButton() {
        guard let media = self.media else { return }
        guard let show = media.show else { return }
        guard let attributedText = genreLabel.attributedText else { return }

        let showText = show.title

        var subRange: Range<String.Index>?
        for n in showText.split(separator: " ") {
            guard let range = attributedText.string.range(of: n, range: (subRange?.upperBound ?? attributedText.string.startIndex)..<attributedText.string.endIndex) else { return }
            subRange = range
            if let frame = genreLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                // button.backgroundColor = .red.withAlphaComponent(0.3)
                button.addTarget(self,
                                 action: #selector(presentShow),
                                 for: .touchUpInside)
                genreLabel.addSubview(button)
            }
        }
        genreLabel.isUserInteractionEnabled = true
    }

    private func placeEpisodeSpoilerButton() {
        guard let media = self.media else { return }
        guard let episode = media.episode else { return }
        guard let attributedText = genreLabel.attributedText else { return }
        guard let episodeTitle = episode.title else { return }

        var subRange = attributedText.string.range(of: " - ")
        for n in episodeTitle.split(separator: " ") {
            guard let range = attributedText.string.range(of: n, range: (subRange?.upperBound ?? attributedText.string.startIndex)..<attributedText.string.endIndex) else { return }
            subRange = range
            if let frame = genreLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                // button.backgroundColor = .blue.withAlphaComponent(0.3)
                button.addTarget(self,
                                 action: #selector(removeSpoilers),
                                 for: .touchUpInside)
                genreLabel.addSubview(button)
            }
        }
        genreLabel.isUserInteractionEnabled = true
    }

    @objc func removeSpoilers() {
        guard let media = self.media else { return }
        guard let show = media.show else { return }
        guard let episode = media.episode else { return }
        guard let episodeTitle = episode.title else { return }

        let markdownParser = SpoilerMarkdownParser(font: .preferredFont(forTextStyle: .subheadline),
                                            color: .label,
                                            automaticLinkDetectionEnabled: false)
        markdownParser.bold.color = UIColor(asset: .globalTint)
        markdownParser.bold.font = .preferredFont(forTextStyle: .subheadline).bold()
        markdownParser.spoilerStrategy = .hideInlineSpoilers

        let markdown = "__\(show.title)__ \(episode.localizedEpisodeNumber) - \(episodeTitle)"
        genreLabel.attributedText = markdownParser.parse(markdown)
    }

    private func updateQuickActions() {
        guard let media = media else { return }

        mainActionButton.enumerateEventHandlers { action, _, event, _ in
            if let action = action {
                mainActionButton.removeAction(action, for: event)
            }
        }
        secondaryActionButton.enumerateEventHandlers { action, _, event, _ in
            if let action = action {
                secondaryActionButton.removeAction(action, for: event)
            }
        }

        mainActionButton.minimumContentSizeCategory = .medium
        mainActionButton.maximumContentSizeCategory = .extraExtraExtraLarge
        mainActionButton.configuration?.cornerStyle = .large
        secondaryActionButton.minimumContentSizeCategory = .medium
        secondaryActionButton.maximumContentSizeCategory = .extraExtraExtraLarge
        secondaryActionButton.configuration?.cornerStyle = .large

        switch media {
        case .movie(let movie):
            if let watchingItem = WatchingManager.shared.watchingItem, let watchingModel = MediaModel(item: watchingItem), watchingModel == media {
                mainActionButton.configuration?.title = "Cancel Check-in"
                mainActionButton.configuration?.image = UIImage(systemName: "nosign")
                mainActionButton.menu = nil
                mainActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    media.cancelCheckin()
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .touchUpInside)

                secondaryActionButton.configuration?.title = "Share"
                secondaryActionButton.configuration?.image = UIImage(systemName: "wave.3.right")
                secondaryActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                secondaryActionButton.menu = contextMenuHelper.quickShareMenu
                secondaryActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.secondaryActionButton.menu = self.contextMenuHelper.quickShareMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)
                secondaryActionButton.isHidden = false
            } else if movie.isWatched {
                if let rating = media.userRating {
                    mainActionButton.configuration?.title = "Rated \(rating)"
                    mainActionButton.configuration?.image = UIImage(systemName: "heart.fill")
                } else {
                    mainActionButton.configuration?.title = "Rate"
                    mainActionButton.configuration?.image = UIImage(systemName: "heart")
                }
                mainActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                mainActionButton.menu = contextMenuHelper.media.rateMenu
                mainActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.mainActionButton.menu = self.contextMenuHelper.media.rateMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)

                secondaryActionButton.configuration?.title = "Share"
                secondaryActionButton.configuration?.image = UIImage(systemName: "wave.3.right")
                secondaryActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                secondaryActionButton.menu = contextMenuHelper.quickShareMenu
                secondaryActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.secondaryActionButton.menu = self.contextMenuHelper.quickShareMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)
            } else {
                mainActionButton.configuration?.title = "Track"
                mainActionButton.configuration?.image = UIImage(systemName: "play")
                mainActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                mainActionButton.menu = contextMenuHelper.quickTrackMenu
                mainActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.mainActionButton.menu = self.contextMenuHelper.quickTrackMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)

                secondaryActionButton.configuration?.title = "Stack"
                secondaryActionButton.configuration?.image = UIImage(systemName: "rectangle.stack")
                secondaryActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                secondaryActionButton.menu = contextMenuHelper.quickStackMenu
                secondaryActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.secondaryActionButton.menu = self.contextMenuHelper.quickStackMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)
            }
        case .show(let show):
            if show.isInToWatch {
                show.mediaModel.progress { [weak self] progress in
                    guard let self = self else { return }
                    if let progress = progress, let nextEpisode = progress.nextEpisodeToWatch {
                        DispatchQueue.main.async { [self] in
                            self.mainActionButton.configuration?.titleAlignment = .center
                            self.mainActionButton.configuration?.title = "Next"
                            if let firstAired = nextEpisode.firstAired, firstAired > Date() {
                                self.mainActionButton.configuration?.subtitle = self.relativeDateTimeFormatter.localizedString(for: firstAired, relativeTo: Date())
                            } else {
                                self.mainActionButton.configuration?.subtitle = nextEpisode.localizedEpisodeNumber
                            }
                            self.mainActionButton.configuration?.image = nil
                            self.mainActionButton.menu = nil
                            self.mainActionButton.addAction(UIAction(handler: { [weak self] _ in
                                guard let self = self else { return }
                                self.present(media: nextEpisode.mediaModel(given: show))
                                UISelectionFeedbackGenerator().selectionChanged()
                                self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                            }), for: .touchUpInside)
                            self.applyQuickActionButtonMultilineTitleStyle(self.mainActionButton)
                            self.invalidateIntrinsicContentSize()
                        }
                    } else {
                        TraktAPIProvider.provider.request(.nextEpisode(id: show.identifiers.trakt!),
                                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case let .success(moyaResponse):
                                do {
                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                    let nextEpisode = try response.map(Episode.self, using: TraktAPIProvider.decoder)

                                    DispatchQueue.main.async {
                                        self.mainActionButton.configuration?.titleAlignment = .center
                                        self.mainActionButton.configuration?.title = "Next"
                                        if let firstAired = nextEpisode.firstAired {
                                            self.mainActionButton.configuration?.subtitle = self.relativeDateTimeFormatter.localizedString(for: firstAired, relativeTo: Date())
                                        } else {
                                            self.mainActionButton.configuration?.subtitle = nextEpisode.localizedEpisodeNumber
                                        }
                                        self.mainActionButton.configuration?.image = nil
                                        self.mainActionButton.menu = nil
                                        self.mainActionButton.addAction(UIAction(handler: { [weak self] _ in
                                            guard let self = self else { return }
                                            self.present(media: nextEpisode.mediaModel(given: show))
                                            UISelectionFeedbackGenerator().selectionChanged()
                                            self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                                        }), for: .touchUpInside)
                                        self.applyQuickActionButtonMultilineTitleStyle(self.mainActionButton)
                                        self.invalidateIntrinsicContentSize()
                                    }
                                } catch {
                                    DispatchQueue.main.async {
                                        self.mainActionButton.configuration?.title = "Track"
                                        self.mainActionButton.configuration?.image = UIImage(systemName: "play")
                                        self.mainActionButton.showsMenuAsPrimaryAction = true
                                        self.contextMenuHelper.media = media
                                        self.mainActionButton.menu = self.contextMenuHelper.quickTrackMenu
                                        self.mainActionButton.addAction(UIAction { [weak self] _ in
                                            guard let self = self else { return }
                                            self.contextMenuHelper.media = self.media
                                            self.mainActionButton.menu = self.contextMenuHelper.quickTrackMenu
                                            UISelectionFeedbackGenerator().selectionChanged()
                                            self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                                         }, for: .menuActionTriggered)
                                        self.applyQuickActionButtonMultilineTitleStyle(self.mainActionButton)
                                        self.invalidateIntrinsicContentSize()
                                    }
                                }
                            case .failure:
                                DispatchQueue.main.async {
                                    self.mainActionButton.configuration?.title = "Track"
                                    self.mainActionButton.configuration?.image = UIImage(systemName: "play")
                                    self.mainActionButton.showsMenuAsPrimaryAction = true
                                    self.contextMenuHelper.media = media
                                    self.mainActionButton.menu = self.contextMenuHelper.quickTrackMenu
                                    self.mainActionButton.addAction(UIAction { [weak self] _ in
                                        guard let self = self else { return }
                                        self.contextMenuHelper.media = self.media
                                        self.mainActionButton.menu = self.contextMenuHelper.quickTrackMenu
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                                     }, for: .menuActionTriggered)
                                    self.applyQuickActionButtonMultilineTitleStyle(self.mainActionButton)
                                    self.invalidateIntrinsicContentSize()
                                }
                            }
                        }
                    }
                }

                secondaryActionButton.configuration?.title = "Share"
                secondaryActionButton.configuration?.image = UIImage(systemName: "wave.3.right")
                secondaryActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                secondaryActionButton.menu = contextMenuHelper.quickShareMenu
                secondaryActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.secondaryActionButton.menu = self.contextMenuHelper.quickShareMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)
            } else if show.isHiddenFromProgress {
                mainActionButton.configuration?.title = "Unhide"
                mainActionButton.configuration?.image = UIImage(systemName: "eye.circle")
                mainActionButton.menu = nil
                mainActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    media.unhideShow()
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .touchUpInside)

                secondaryActionButton.configuration?.title = "Stack"
                secondaryActionButton.configuration?.image = UIImage(systemName: "rectangle.stack")
                secondaryActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                secondaryActionButton.menu = contextMenuHelper.quickStackMenu
                secondaryActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.secondaryActionButton.menu = self.contextMenuHelper.quickStackMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)
            } else if show.isCompleted {
                mainActionButton.configuration?.title = "Rewatch"
                mainActionButton.configuration?.image = UIImage(systemName: "backward.circle")
                mainActionButton.menu = nil
                mainActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    media.startRewatchingShow()
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .touchUpInside)

                if let rating = media.userRating {
                    secondaryActionButton.configuration?.title = "Rated \(rating)"
                    secondaryActionButton.configuration?.image = UIImage(systemName: "heart.fill")
                } else {
                    secondaryActionButton.configuration?.title = "Rate"
                    secondaryActionButton.configuration?.image = UIImage(systemName: "heart")
                }
                secondaryActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                secondaryActionButton.menu = contextMenuHelper.media.rateMenu
                secondaryActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.secondaryActionButton.menu = self.contextMenuHelper.media.rateMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)
            } else {
                mainActionButton.configuration?.title = "Track"
                mainActionButton.configuration?.image = UIImage(systemName: "play")
                mainActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                mainActionButton.menu = contextMenuHelper.quickTrackMenu
                mainActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.mainActionButton.menu = self.contextMenuHelper.quickTrackMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)

                secondaryActionButton.configuration?.title = "Stack"
                secondaryActionButton.configuration?.image = UIImage(systemName: "rectangle.stack")
                secondaryActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                secondaryActionButton.menu = contextMenuHelper.quickStackMenu
                secondaryActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.secondaryActionButton.menu = self.contextMenuHelper.quickStackMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)
            }
        case .episode(let episode, let show):
            if let watchingItem = WatchingManager.shared.watchingItem, let watchingModel = MediaModel(item: watchingItem), watchingModel == media {
                mainActionButton.configuration?.title = "Cancel Check-in"
                mainActionButton.configuration?.image = UIImage(systemName: "nosign")
                mainActionButton.menu = nil
                mainActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    media.cancelCheckin()
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .touchUpInside)

                secondaryActionButton.configuration?.title = "Share"
                secondaryActionButton.configuration?.image = UIImage(systemName: "wave.3.right")
                secondaryActionButton.showsMenuAsPrimaryAction = true
                contextMenuHelper.media = media
                secondaryActionButton.menu = contextMenuHelper.quickShareMenu
                secondaryActionButton.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.contextMenuHelper.media = self.media
                    self.secondaryActionButton.menu = self.contextMenuHelper.quickShareMenu
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                 }, for: .menuActionTriggered)
                secondaryActionButton.isHidden = false
            } else {
                show.mediaModel.progress { [weak self] progress in
                    guard let self = self else { return }
                    DispatchQueue.main.async { [self] in
                        if let progress = progress {
                            for season in progress.seasons where season.number == episode.season {
                                for episodeProgress in season.episodes where episodeProgress.number == episode.number {
                                    if episodeProgress.completed {
                                        if let rating = media.userRating {
                                            self.mainActionButton.configuration?.title = "Rated \(rating)"
                                            self.mainActionButton.configuration?.image = UIImage(systemName: "heart.fill")
                                        } else {
                                            self.mainActionButton.configuration?.title = "Rate"
                                            self.mainActionButton.configuration?.image = UIImage(systemName: "heart")
                                        }
                                        self.mainActionButton.showsMenuAsPrimaryAction = true
                                        self.contextMenuHelper.media = media
                                        self.mainActionButton.menu = self.contextMenuHelper.media.rateMenu
                                        self.mainActionButton.addAction(UIAction { [weak self] _ in
                                            guard let self = self else { return }
                                            self.contextMenuHelper.media = self.media
                                            self.mainActionButton.menu = self.contextMenuHelper.media.rateMenu
                                            UISelectionFeedbackGenerator().selectionChanged()
                                            self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                                        }, for: .menuActionTriggered)

                                        self.secondaryActionButton.configuration?.title = "Share"
                                        self.secondaryActionButton.configuration?.image = UIImage(systemName: "wave.3.right")
                                        self.secondaryActionButton.showsMenuAsPrimaryAction = true
                                        self.contextMenuHelper.media = media
                                        self.secondaryActionButton.menu = self.contextMenuHelper.quickShareMenu
                                        self.secondaryActionButton.addAction(UIAction { [weak self] _ in
                                            guard let self = self else { return }
                                            self.contextMenuHelper.media = self.media
                                            self.secondaryActionButton.menu = self.contextMenuHelper.quickShareMenu
                                            UISelectionFeedbackGenerator().selectionChanged()
                                            self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                                        }, for: .menuActionTriggered)
                                        self.secondaryActionButton.isHidden = false

                                        self.applyQuickActionButtonMultilineTitleStyle(self.mainActionButton)
                                        self.applyQuickActionButtonMultilineTitleStyle(self.secondaryActionButton)
                                        self.invalidateIntrinsicContentSize()
                                        return
                                    }
                                }
                            }
                        }
                        self.mainActionButton.configuration?.title = "Track"
                        self.mainActionButton.configuration?.image = UIImage(systemName: "play")
                        self.mainActionButton.showsMenuAsPrimaryAction = true
                        self.contextMenuHelper.media = media
                        self.mainActionButton.menu = self.contextMenuHelper.quickTrackMenu
                        self.mainActionButton.addAction(UIAction { [weak self] _ in
                            guard let self = self else { return }
                            self.contextMenuHelper.media = self.media
                            self.mainActionButton.menu = self.contextMenuHelper.quickTrackMenu
                            UISelectionFeedbackGenerator().selectionChanged()
                            self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
                        }, for: .menuActionTriggered)

                        self.secondaryActionButton.isHidden = true
                        self.applyQuickActionButtonMultilineTitleStyle(self.mainActionButton)
                        self.applyQuickActionButtonMultilineTitleStyle(self.secondaryActionButton)
                        self.invalidateIntrinsicContentSize()
                    }
                }
            }
        case .season:
            mainActionButton.configuration?.title = "Track"
            mainActionButton.configuration?.image = UIImage(systemName: "play")
            mainActionButton.showsMenuAsPrimaryAction = true
            contextMenuHelper.media = media
            mainActionButton.menu = contextMenuHelper.quickTrackMenu
            mainActionButton.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.contextMenuHelper.media = self.media
                self.mainActionButton.menu = self.contextMenuHelper.quickTrackMenu
                UISelectionFeedbackGenerator().selectionChanged()
                self.mainActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
             }, for: .menuActionTriggered)

            secondaryActionButton.configuration?.title = "Stack"
            secondaryActionButton.configuration?.image = UIImage(systemName: "rectangle.stack")
            secondaryActionButton.showsMenuAsPrimaryAction = true
            contextMenuHelper.media = media
            secondaryActionButton.menu = contextMenuHelper.quickStackMenu
            secondaryActionButton.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.contextMenuHelper.media = self.media
                self.secondaryActionButton.menu = self.contextMenuHelper.quickStackMenu
                UISelectionFeedbackGenerator().selectionChanged()
                self.secondaryActionButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
             }, for: .menuActionTriggered)
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
        applyQuickActionButtonMultilineTitleStyle(mainActionButton)
        applyQuickActionButtonMultilineTitleStyle(secondaryActionButton)
        invalidateIntrinsicContentSize()
    }

    @objc func presentShow() {
        guard let delegate = delegate else { return }
        switch media! {
        case .episode, .season:
            delegate.cell(self, action: .presentShow)
        default:
            return
        }
    }

    func present(media: MediaModel) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .presentMedia(media))
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    private func fetchStingerFor(service: TmdbAPIService) -> Cancellable {
        return TmdbAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let keywords = try response.map(Keywords.self, using: TraktAPIProvider.decoder).keywords.map { $0.name }

                    DispatchQueue.main.async {
                        let stingerMap: [(String, String)] = [
                            ("beforecreditsstinger", "before"),
                            ("duringcreditsstinger", "during"),
                            ("aftercreditsstinger", "after")
                        ]

                        let found = stingerMap
                            .filter { keywords.contains($0.0) }
                            .map { $0.1 }

                        if found.isEmpty {
                            self.stingerLabel.text = "No stinger reported (yet)"
                            self.stingerLabel.alpha = 0.0
                        } else {
                            let joined = ListFormatter.localizedString(byJoining: found)
                            self.stingerLabel.text = "incl. \(joined)-credits stinger\(found.count > 1 ? "s" : "")"
                            self.stingerLabel.alpha = 1.0
                        }
                        self.invalidateIntrinsicContentSize()
                    }
                } catch {
                    print("Keywords (tmdb) request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("Keywords (tmdb) request failure \(error)")
            }
        }
    }

    fileprivate func share() {
        guard let media = self.media else { return }
        guard let sharedURL = media.traktWebsiteMediaLink else { return }
        let activityViewController = UIActivityViewController(activityItems: [sharedURL], applicationActivities: nil)
        UIApplication.shared.present(activityViewController)
    }

    private func updateRuntimeDisplay() {
        let mode = UserDefaults.standard.bool(forKey: "MediaTitleTableViewCell.runtime.mode")

        if mode == true {
            switch media! {
            case .movie(let movie):
                let runtime = movie.runtime ?? 0
                let hours = runtime / 60
                let minutes = runtime % 60
                if hours > 0 {
                    runtimeLabel.text = "\(hours)h \(minutes)m"
                } else {
                    runtimeLabel.text = "\(minutes)m"
                }
            case .show(let show):
                let runtime = show.runtime ?? 0
                let hours = runtime / 60
                let minutes = runtime % 60
                if hours > 0 {
                    runtimeLabel.text = "\(hours)h \(minutes)m"
                } else {
                    runtimeLabel.text = "\(minutes)m"
                }
            case .episode(let episode, let show):
                let runtime = episode.runtime ?? show.runtime ?? 0
                let hours = runtime / 60
                let minutes = runtime % 60
                if hours > 0 {
                    runtimeLabel.text = "\(hours)h \(minutes)m"
                } else {
                    runtimeLabel.text = "\(minutes)m"
                }
            case .season(_, let show):
                let runtime = show.runtime ?? 0
                let hours = runtime / 60
                let minutes = runtime % 60
                if hours > 0 {
                    runtimeLabel.text = "\(hours)h \(minutes)m"
                } else {
                    runtimeLabel.text = "\(minutes)m"
                }
            default:
                break
            }
        } else {
            switch media! {
            case .movie(let movie):
                runtimeLabel.text = "\(movie.runtime ?? 0) min"
            case .show(let show):
                runtimeLabel.text = "\(show.runtime ?? 0) min"
            case .episode(let episode, let show):
                runtimeLabel.text = "\(episode.runtime ?? show.runtime ?? 0) min"
            case .season(_, let show):
                runtimeLabel.text = "\(show.runtime ?? 0) min"
            default:
                break
            }
        }
        invalidateIntrinsicContentSize()
    }

    @IBAction func ageRatingCertificationButtonTouchedUpInside(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .presentCertifications)
    }

    @IBAction func runtimeButtonTouchedUpInside(_ sender: Any) {
        let mode = UserDefaults.standard.bool(forKey: "MediaTitleTableViewCell.runtime.mode")

        UserDefaults.standard.set(!mode,
                                  forKey: "MediaTitleTableViewCell.runtime.mode")
        UserDefaults.standard.synchronize()

        updateRuntimeDisplay()
    }

    private static let monoFresh = UIImage(resource: .rottenTomatoesFresh).mono
    private static let monoPositive = UIImage(resource: .rottenTomatoesPositiveAudience).mono

    private func fetchRatingsFor(type: TraktObjectType) {
        rottenTomatoesAudienceRating.text = "--%"
        rottenTomatoesCriticsRating.text = "--%"
        rottentTomatoesCriticsImage.image = MediaTitleTableViewCell.monoFresh
        rottenTomatoesAudienceImage.image = MediaTitleTableViewCell.monoPositive
        TraktAPIProvider.provider.request(.ratings(type: type), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let ratings = try response.map(Ratings.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        if let rating = ratings.rottenTomatoes.rating {
                            self.rottenTomatoesCriticsRating.countFromCurrentValueTo(CGFloat(rating),
                                                                                     withDuration: 0.7)
                            UIView.transition(with: self.rottentTomatoesCriticsImage,
                                              duration: 0.7,
                                              options: .transitionCrossDissolve,
                                              animations: {
                                if let state = ratings.rottenTomatoes.state {
                                    switch state {
                                    case "fresh":
                                        self.rottentTomatoesCriticsImage.image = UIImage(resource: ImageResource.rottenTomatoesFresh)
                                    case "certified":
                                        self.rottentTomatoesCriticsImage.image = UIImage(resource: ImageResource.rottenTomatoesCertifiedFreshSmall)
                                    case "rotten":
                                        self.rottentTomatoesCriticsImage.image = UIImage(resource: ImageResource.rottenTomatoesRotten)
                                    default:
                                        // Fallback
                                        if rating >= 75 {
                                            // certified fresh
                                            self.rottentTomatoesCriticsImage.image = UIImage(resource: ImageResource.rottenTomatoesCertifiedFreshSmall)
                                        } else if rating >= 60 {
                                            // fresh
                                            self.rottentTomatoesCriticsImage.image = UIImage(resource: ImageResource.rottenTomatoesFresh)
                                        } else {
                                            // rotten
                                            self.rottentTomatoesCriticsImage.image = UIImage(resource: ImageResource.rottenTomatoesRotten)
                                        }
                                    }
                                }
                            })
                        } else {
                            self.rottenTomatoesCriticsRating.text = "--%"
                        }
                        if let userRating = ratings.rottenTomatoes.userRating {
                            self.rottenTomatoesAudienceRating.countFromCurrentValueTo(CGFloat(userRating),
                                                                                      withDuration: 0.7)
                            UIView.transition(with: self.rottenTomatoesAudienceImage,
                                              duration: 0.7,
                                              options: .transitionCrossDissolve,
                                              animations: {
                                if let state = ratings.rottenTomatoes.userState {
                                    switch state {
                                    case "upright":
                                        self.rottenTomatoesAudienceImage.image = UIImage(resource: ImageResource.rottenTomatoesPositiveAudience)
                                    case "certified":
                                        self.rottenTomatoesAudienceImage.image = UIImage(resource: ImageResource.rottenTomatoesVerifiedHotSmall)
                                    case "spilled":
                                        self.rottenTomatoesAudienceImage.image = UIImage(resource: ImageResource.rottenTomatoesNegativeAudience)
                                    default:
                                        // Fallback
                                        if userRating >= 90 {
                                            // verified hot
                                            self.rottenTomatoesAudienceImage.image = UIImage(resource: ImageResource.rottenTomatoesVerifiedHotSmall)
                                        } else if userRating >= 60 {
                                            // upright
                                            self.rottenTomatoesAudienceImage.image = UIImage(resource: ImageResource.rottenTomatoesPositiveAudience)
                                        } else {
                                            // spilled
                                            self.rottenTomatoesAudienceImage.image = UIImage(resource: ImageResource.rottenTomatoesNegativeAudience)
                                        }
                                    }
                                }
                            })
                        } else {
                            self.rottenTomatoesAudienceRating.text = "--%"
                        }
                    }
                } catch {
                    print("Ratings request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("Ratings request failure \(error)")
            }
        }
    }
}

extension UIImage {
    var mono: UIImage? {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectTonal") else { return self }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let output = currentFilter.outputImage,
            let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
        return self
    }
}

extension UIFont {
    static func preferredMonospacedFont(for style: TextStyle, weight: Weight) -> UIFont {
        let metrics = UIFontMetrics(forTextStyle: style)
        let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        let font = UIFont.monospacedDigitSystemFont(ofSize: desc.pointSize, weight: weight)
        return metrics.scaledFont(for: font)
    }
}
