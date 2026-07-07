//
//  MediaPreviewViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 13/07/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import NVActivityIndicatorView
import UIKit

final class MediaPreviewViewController: UIViewController {
    var media: MediaModel!

    @IBOutlet var tinyPosterImageView: PosterImageView!
    @IBOutlet var posterImageView: PosterImageView!

    @IBOutlet var loadingIndicator: NVActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()

        loadingIndicator.tintColor = UIColor(asset: .globalTint)
        loadingIndicator.startAnimating()

        precondition(media != nil, "Media should not be nil")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tinyPosterImageView.scale = 0.2
        tinyPosterImageView.overrideBackgroundColor = .clear
        posterImageView.overrideBackgroundColor = .clear
        posterImageView.transitionDuration = 0.25

        if let movie = media.movie {
            tinyPosterImageView.movie = movie
            tinyPosterImageView.backgroundColor = .clear
            posterImageView.movie = movie
            posterImageView.backgroundColor = .clear
        } else if let show = media.show {
            tinyPosterImageView.show = show
            tinyPosterImageView.backgroundColor = .clear
            posterImageView.show = show
            posterImageView.backgroundColor = .clear
        }
    }
}

final class PeoplePreviewViewController: UIViewController {
    var person: Person!

    @IBOutlet var tinyAvatarImageView: BigPeopleProfileImageView!
    @IBOutlet var avatarImageView: BigPeopleProfileImageView!

    @IBOutlet var loadingIndicator: NVActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()

        loadingIndicator.tintColor = UIColor(asset: .globalTint)
        loadingIndicator.startAnimating()

        precondition(person != nil, "Person should not be nil")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tinyAvatarImageView.scale = 0.2
        avatarImageView.transitionDuration = 0.25

        tinyAvatarImageView.person = person
        tinyAvatarImageView.backgroundColor = .clear
        avatarImageView.person = person
        avatarImageView.backgroundColor = .clear
    }
}

final class EpisodePreviewViewController: UIViewController {
    var media: MediaModel!

    @IBOutlet var backPreviewBackdropImageView: BackdropImageView!
    @IBOutlet var backBackdropImageView: BackdropImageView!

    @IBOutlet var frontPreviewBackdropImageView: BackdropImageView!
    @IBOutlet var frontBackdropImageView: BackdropImageView!

    @IBOutlet var loadingIndicator: NVActivityIndicatorView!

    private var showSpoilers = false {
        didSet {
            if showSpoilers {
                frontPreviewBackdropImageView.media = media
                frontBackdropImageView.media = media
            }
            DispatchQueue.main.async {
                self.frontBackdropImageView.isHidden = !self.showSpoilers
                self.frontPreviewBackdropImageView.isHidden = !self.showSpoilers
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        loadingIndicator.tintColor = UIColor(asset: .globalTint)
        loadingIndicator.startAnimating()

        precondition(media != nil, "media should not be nil")
        precondition(media.episode != nil, "media should be an episode")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        backPreviewBackdropImageView.scale = 0.3
        frontPreviewBackdropImageView.scale = 0.3
        backPreviewBackdropImageView.overrideBackgroundColor = .clear
        backBackdropImageView.overrideBackgroundColor = .clear
        frontPreviewBackdropImageView.overrideBackgroundColor = .clear
        frontBackdropImageView.overrideBackgroundColor = .clear
        backBackdropImageView.transitionDuration = 0.25
        frontBackdropImageView.transitionDuration = 0.25

        switch media! {
        case .episode(let episode, let show):
            // default
            showSpoilers = false
            backPreviewBackdropImageView.media = MediaModel.show(show)
            backBackdropImageView.media = MediaModel.show(show)
            if UserDefaults.standard.bool(forKey: "GeneralSettings.detailepisodetitle") {
                showSpoilers = true
            } else {
                media.progress { [weak self] progress in
                    guard let self = self else { return }
                    if let progress = progress {
                        for season in progress.seasons where season.number == episode.season {
                            for episodeProgress in season.episodes where episodeProgress.number == episode.number {
                                if episodeProgress.completed {
                                    self.showSpoilers = true
                                } else {
                                    self.showSpoilers = false
                                }
                                return
                            }
                        }
                    }
                }
            }
        default:
            break
        }
    }
}
