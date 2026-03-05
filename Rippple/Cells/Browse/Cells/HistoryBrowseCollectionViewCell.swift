//
//  HistoryBrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 14/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import Receiver

import RPCircularProgress

final class HistoryBrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var sublabel: UILabel!
    @IBOutlet weak var emoji: UILabel!
    @IBOutlet weak var poster: PosterImageView!
    @IBOutlet weak var commentCount: CommentCountLabel!

    @IBOutlet weak var progress: RPCircularProgress!

    private let disposeBag = DisposeBag()

    enum Content {
        case emoji(label: String, emoji: String)
        case media(media: MediaModel)
    }
    var content: Content! {
        didSet {
            switch content {
            case .emoji(let label, let emoji):
                self.emoji.isHidden = false
                sublabel.isHidden = true
                progress.isHidden = true
                poster.image = nil
                commentCount.superview!.isHidden = true

                self.label.text = label
                self.emoji.text = emoji
            case .media(let media):
                emoji.isHidden = true
                sublabel.isHidden = false
                progress.isHidden = false
                commentCount.superview!.isHidden = false

                self.media = media
            case .none:
                // do nothing
                break
            }
        }
    }

    var media: MediaModel! {
        didSet {
            commentCount.mode = .alone
            commentCount.media = media
            switch media! {
            case .movie(let movie):
                poster.movie = movie
                label.text = movie.title
                sublabel.text = movie.releaseYear != nil ? "\(movie.releaseYear!)" : ""
            case .show:
                fatalError("This type is not handled")
            case .episode(let episode, let show):
                poster.show = show
                label.text = show.title
                sublabel.text = episode.localizedEpisodeNumber
            case .season:
                fatalError("This type is not handled")
            case .list:
                fatalError("This type is not handled")
            case .showProgress:
                fatalError("This type is not handled")
            }
            update(watchingItem: WatchingManager.shared.watchingItem)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        poster.layer.cornerRadius = poster.bounds.height/2.0
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.backgroundColor = UIColor.secondarySystemBackground
        poster.layer.borderWidth = 1
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        progress.trackTintColor = UIColor(asset: .globalTint).withAlphaComponent(0.4)
        progress.progressTintColor = UIColor(asset: .globalTint)
        progress.roundedCorners = true
        progress.thicknessRatio = 0.08
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        update(watchingItem: WatchingManager.shared.watchingItem)

        WatchingManager.shared.onProgressChangedReceiver.listen { [weak self] progress in
            guard let self = self else { return }
            self.update(watchingItem: WatchingManager.shared.watchingItem)
            self.progress.updateProgress(CGFloat(progress), animated: false)
        }.disposed(by: disposeBag)

        maximumContentSizeCategory = .extraExtraExtraLarge
    }

    private func update(watchingItem: WatchingItem?) {
        guard let watchingItem = watchingItem, let checkinModel = MediaModel(item: watchingItem) else {
            progress.isHidden = true
            return
        }
        if media == checkinModel {
            progress.isHidden = false
        } else {
            progress.isHidden = true
        }
    }
}
