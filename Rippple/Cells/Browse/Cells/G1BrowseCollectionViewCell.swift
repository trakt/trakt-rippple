//
//  G1BrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 18/01/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import UIKit

final class G1BrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet var backdrop: BackdropImageView!

    @IBOutlet var title: UILabel!
    @IBOutlet var subtitle: UILabel!
    @IBOutlet var meta: UILabel!
    @IBOutlet var actionButton: UIButton!

    weak var presentingViewController: UIViewController? {
        didSet {
            actionButtonController.controller = presentingViewController
        }
    }

    var actionButtonStyle: ShelfBrowseActionButtonStyle = .none {
        didSet {
            actionButtonController.style = actionButtonStyle
            secondGradientLayer.isHidden = actionButtonStyle == .none
        }
    }

    private let actionButtonController = ShelfBrowseActionButtonController()

    var media: MediaModel! {
        didSet {
            actionButtonController.media = media
            switch media! {
            case .movie(let movie):
                backdrop.media = media
                title.text = movie.title
                if let releaseYear = movie.releaseYear {
                    subtitle.text = "\(releaseYear)"
                    subtitle.isHidden = false
                } else {
                    subtitle.isHidden = true
                }
                if let genres = movie.genres {
                    meta.text = genres.joined(separator: ", ").capitalized
                    meta.isHidden = false
                } else {
                    meta.isHidden = true
                }
            case .show(let show):
                backdrop.media = show.mediaModel
                title.text = show.title
                if let status = show.status {
                    subtitle.text = "\(status.capitalized)"
                    subtitle.isHidden = false
                } else {
                    subtitle.isHidden = true
                }
                if let airedEpisodes = show.airedEpisodes {
                    meta.text = "\(airedEpisodes) episode\(airedEpisodes > 1 ? "s" : "")"
                    meta.isHidden = false
                } else {
                    meta.isHidden = true
                }
            case .episode(let episode, let show):
                backdrop.media = show.mediaModel
                title.text = show.title
                subtitle.text = episode.localizedEpisodeNumber
                subtitle.isHidden = false
                if let episodeTitle = episode.title {
                    meta.text = episodeTitle
                    meta.isHidden = false
                } else {
                    meta.isHidden = true
                }
            case .season(let season, let show):
                backdrop.media = show.mediaModel
                title.text = show.title
                subtitle.text = season.title ?? "Season \(season.number)"
                subtitle.isHidden = false
                if let airedEpisodes = season.airedEpisodes {
                    meta.text = "\(airedEpisodes) episode\(airedEpisodes > 1 ? "s" : "")"
                    meta.isHidden = false
                } else {
                    meta.isHidden = true
                }
            case .showProgress(let show, let progress):
                backdrop.showEpisodeSpoilers = UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle")
                title.text = show.title

                if let episode = progress.nextEpisodeToWatch {
                    backdrop.media = episode.mediaModel(given: show)

                    if UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle") == true, let title = episode.title {
                        subtitle.text = "\(episode.localizedEpisodeNumber) - \(title)"
                    } else {
                        subtitle.text = episode.localizedEpisodeNumber
                    }
                } else {
                    backdrop.media = show.mediaModel
                    subtitle.text = "Unknown next episode"
                }

                if progress.toRewatchCount > 0 {
                    meta.text = "\(progress.toRewatchCount) to rewatch"
                } else {
                    let behind = progress.behind
                    if behind > 0 {
                        meta?.text = "\(behind) behind"
                    } else {
                        meta?.text = "At least one behind"
                    }
                }
            default:
                fatalError("Case not handled")
            }
        }
    }

    private let secondGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()

        backdrop.layer.cornerRadius = ViewRadius.large.rawValue
        backdrop.layer.cornerCurve = .continuous
        backdrop.layer.masksToBounds = true
        backdrop.backgroundColor = UIColor.tertiarySystemFill
        backdrop.layer.borderWidth = 1
        backdrop.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        let colorEnd = UIColor.clear.cgColor
        let colorStart = UIColor.black.withAlphaComponent(0.85).cgColor

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [colorStart, colorEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.frame = backdrop.bounds

        secondGradientLayer.colors = [colorStart, colorEnd]
        secondGradientLayer.startPoint = CGPoint(x: 1.0, y: 1.0)
        secondGradientLayer.endPoint = CGPoint(x: 0.5, y: 0.5)
        secondGradientLayer.frame = backdrop.bounds

        backdrop.layer.addSublayer(gradientLayer)
        backdrop.layer.addSublayer(secondGradientLayer)

        title.layer.shadowColor = UIColor.black.cgColor
        title.layer.shadowRadius = 2.0
        title.layer.shadowOpacity = 0.7
        title.layer.shadowOffset = .zero
        title.layer.masksToBounds = false

        subtitle.layer.shadowColor = UIColor.black.cgColor
        subtitle.layer.shadowRadius = 2.0
        subtitle.layer.shadowOpacity = 0.7
        subtitle.layer.shadowOffset = .zero
        subtitle.layer.masksToBounds = false

        meta.layer.shadowColor = UIColor.black.cgColor
        meta.layer.shadowRadius = 2.0
        meta.layer.shadowOpacity = 0.7
        meta.layer.shadowOffset = .zero
        meta.layer.masksToBounds = false

        actionButtonController.configure(button: actionButton, appearance: .white)
    }
}

final class ShelfBrowseActionButtonController {
    enum Appearance {
        case tinted
        case white
    }

    weak var controller: UIViewController? {
        didSet {
            contextMenu.controller = controller
        }
    }

    var style: ShelfBrowseActionButtonStyle = .none {
        didSet {
            updateButton()
        }
    }

    var showsFullMenuForDefaultStyle = false {
        didSet {
            updateButton()
        }
    }

    var media: MediaModel? {
        didSet {
            updateButton()
        }
    }

    private weak var button: UIButton?
    private var appearance: Appearance = .tinted
    private let contextMenu = MediaContextMenuInteractionDelegate()
    private let checkmarkActionIdentifier = UIAction.Identifier("ShelfBrowseActionButton.checkmark")
    private let playActionIdentifier = UIAction.Identifier("ShelfBrowseActionButton.play")
    private let plusActionIdentifier = UIAction.Identifier("ShelfBrowseActionButton.plus")

    func configure(button: UIButton, appearance: Appearance = .tinted) {
        self.button = button
        self.appearance = appearance
        button.preferredBehavioralStyle = .pad
        button.isPointerInteractionEnabled = true
        button.maximumContentSizeCategory = .accessibilityExtraExtraLarge
        button.backgroundColor = .clear
        updateButton()
    }

    private func updateButton() {
        guard let button else { return }

        let actionMedia = actionableMedia
        let usesDefaultStyle = style == .none
        let showsDefaultButton = usesDefaultStyle && showsFullMenuForDefaultStyle
        button.isHidden = (usesDefaultStyle && !showsFullMenuForDefaultStyle) || actionMedia == nil
        button.menu = nil
        button.showsMenuAsPrimaryAction = false
        button.removeAction(identifiedBy: checkmarkActionIdentifier, for: .primaryActionTriggered)
        button.removeAction(identifiedBy: playActionIdentifier, for: .primaryActionTriggered)
        button.removeAction(identifiedBy: plusActionIdentifier, for: .primaryActionTriggered)

        guard let actionMedia = actionMedia,
              let systemImageName = style.systemImageName ?? (showsDefaultButton ? "ellipsis" : nil) else {
            return
        }

        contextMenu.media = actionMedia
        contextMenu.controller = controller

        var configuration = button.configuration ?? UIButton.Configuration.tinted()
        configuration.cornerStyle = .capsule
        configuration.indicator = .automatic
        configuration.image = UIImage(systemName: systemImageName)
        configuration.baseForegroundColor = foregroundColor
        configuration.baseBackgroundColor = backgroundColor
        configuration.title = ""
        configuration.imagePadding = 4.0

        button.configuration = configuration
        button.accessibilityLabel = style.label

        switch style {
        case .none:
            button.menu = contextMenu.menu
            button.showsMenuAsPrimaryAction = true
        case .ellipsis:
            button.menu = menu(for: actionMedia)
            button.showsMenuAsPrimaryAction = true
        case .checkmark:
            button.addAction(UIAction(title: "", image: nil, identifier: checkmarkActionIdentifier) { [weak self] _ in
                guard let self = self else { return }
                self.actionableMedia?.markWatched()
                self.animateButton()
            }, for: .primaryActionTriggered)
        case .play:
            button.addAction(UIAction(title: "", image: nil, identifier: playActionIdentifier) { [weak self] _ in
                guard let self = self else { return }
                self.actionableMedia?.checkin()
                self.animateButton()
            }, for: .primaryActionTriggered)
        case .plus:
            button.addAction(UIAction(title: "", image: nil, identifier: plusActionIdentifier) { [weak self] _ in
                guard let self = self else { return }
                self.contextMenu.markWatched()
                self.animateButton()
            }, for: .primaryActionTriggered)
        }
    }

    private var foregroundColor: UIColor {
        switch appearance {
        case .tinted:
            return UIColor(asset: .globalTint)
        case .white:
            return .white
        }
    }

    private var backgroundColor: UIColor {
        switch appearance {
        case .tinted:
            return UIColor(asset: .safeGlobalTint).withAlphaComponent(0.5)
        case .white:
            return UIColor.white.withAlphaComponent(0.5)
        }
    }

    private var actionableMedia: MediaModel? {
        guard let media else { return nil }

        if case .showProgress(let show, let progress) = media,
           let episode = progress.nextEpisodeToWatch {
            return episode.mediaModel(given: show)
        }

        return media
    }

    private func menu(for media: MediaModel) -> UIMenu {
        switch media {
        case .movie, .show, .season, .episode:
            return contextMenu.quickTrackMenu
        case .list, .showProgress:
            return UIMenu(title: "")
        }
    }

    private func animateButton() {
        UISelectionFeedbackGenerator().selectionChanged()
        button?.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
    }
}
