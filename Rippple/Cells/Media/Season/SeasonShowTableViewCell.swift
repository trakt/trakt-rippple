//
//  SeasonShowTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 20/10/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation

import UIKit

import Receiver

protocol SeasonShowTableViewCellDelegate: AnyObject {
    func cell(_ cell: SeasonShowTableViewCell, action: SeasonShowTableViewCell.Action)
}

final class SeasonShowTableViewCell: UITableViewCell {

    enum Action {
        case actions
    }

    weak var delegate: SeasonShowTableViewCellDelegate?

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var meta: CommentCountLabel?
    @IBOutlet weak var whereToWatchImageView: WhereToWatchImageView?
    @IBOutlet weak var poster: PosterButton!

    @IBOutlet weak var card: CardView!

    @IBOutlet weak var menuButtonContainter: UIView?
    private let menuButtonContextMenu = MediaContextMenuInteractionDelegate()

    private let disposeBag = DisposeBag()

    var progress: SeasonProgress? {
        didSet {
            switch media {
            case .season(let season, let show):
                setupSeason(season: season, show: show)
            default:
                fatalError("Media type not handled in SeasonShowTableViewCell")
            }
        }
    }

    var media: MediaModel! {
        didSet {
            switch media {
            case .season(let season, let show):
                setupSeason(season: season, show: show)
            default:
                fatalError("Media type not handled in SeasonShowTableViewCell")
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for v in subviews where String(describing: type(of: v)).contains("EditControl") {
            v.removeFromSuperview()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        selectionStyle = .none
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        selectedBackgroundView = backgroundView
        let multipleBackgroundView = UIView()
        multipleBackgroundView.backgroundColor = .tertiarySystemBackground
        multipleSelectionBackgroundView = multipleBackgroundView

        poster.layer.cornerRadius = ViewRadius.medium.rawValue
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.layer.borderWidth = 1
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        poster.backgroundColor = UIColor.tertiarySystemFill
    }

    private func setupSeason(season: Season, show: Show) {
        title.text = season.title
        if let progress = progress, progress.completed > 0 {
            subtitle.text = "\(progress.aired) aired - \(progress.completed) watched"
        } else if let episodeCount = season.airedEpisodes {
            subtitle.text = "\(episodeCount) aired"
        } else {
            subtitle.text = ""
        }

        menuButtonContextMenu.media = media
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

            menuButton.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                menuButton.menu = self.menuButtonContextMenu.menu
                UISelectionFeedbackGenerator().selectionChanged()
                menuButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
             }, for: .menuActionTriggered)
        }

        meta?.media = media

        whereToWatchImageView?.isHidden = true
        whereToWatchImageView?.media = media

        poster.season = (show, season)
    }

    @IBAction func moreAction(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .actions)
    }
}
