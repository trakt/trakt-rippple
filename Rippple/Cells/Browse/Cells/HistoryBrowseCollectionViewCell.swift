//
//  HistoryBrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 14/07/2023.
//  Copyright © Trakt. All rights reserved.
//

import Kingfisher
import Receiver
import UIKit

final class HistoryBrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet var label: UILabel!
    @IBOutlet var sublabel: UILabel!
    @IBOutlet var emoji: UILabel!
    @IBOutlet var poster: PosterImageView!
    @IBOutlet var commentCount: CommentCountLabel!

    @IBOutlet var progress: CircularProgressView!

    private let disposeBag = DisposeBag()

    enum Content {
        case emoji(label: String, emoji: String)
        case media(media: MediaModel)
    }

    var content: Content? {
        didSet {
            switch content {
            case .emoji(let label, let emoji):
                configureEmoji(label: label, emoji: emoji)
            case .media(let media):
                configureMedia(media)
            case .none:
                resetContent()
            }
        }
    }

    var media: MediaModel? {
        didSet {
            guard let media = media else { return }

            commentCount.mode = .alone
            commentCount.media = media
            switch media {
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

    override func prepareForReuse() {
        super.prepareForReuse()

        content = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        poster.layer.cornerRadius = poster.bounds.height / 2.0
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
        guard let media = media,
              let watchingItem = watchingItem,
              let checkinModel = MediaModel(item: watchingItem) else {
            progress.isHidden = true
            return
        }
        if media == checkinModel {
            progress.isHidden = false
        } else {
            progress.isHidden = true
        }
    }

    private func configureEmoji(label: String, emoji: String) {
        media = nil
        commentCount.media = nil
        resetPoster()
        progress.isHidden = true
        sublabel.isHidden = true
        commentCount.superview!.isHidden = true
        self.emoji.isHidden = false

        self.label.text = label
        sublabel.text = nil
        self.emoji.text = emoji
    }

    private func configureMedia(_ media: MediaModel) {
        emoji.isHidden = true
        sublabel.isHidden = false
        commentCount.superview!.isHidden = false

        self.media = media
    }

    private func resetContent() {
        media = nil
        commentCount.media = nil
        resetPoster()
        label.text = nil
        sublabel.text = nil
        emoji.text = nil
        emoji.isHidden = true
        sublabel.isHidden = true
        progress.isHidden = true
        commentCount.superview!.isHidden = true
    }

    private func resetPoster() {
        poster.kf.cancelDownloadTask()
        poster.movie = nil
        poster.show = nil
        poster.season = nil
        poster.image = nil
    }
}
