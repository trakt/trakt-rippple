//
//  MediaBackdropView.swift
//  Rippple
//
//  Created by Kevin Cador on 22/06/2020.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

/// The backdrop with its loading steps, episode spoiler rule and tap, shared by the compact backdrop row and the
/// full-width media card.
final class MediaBackdropView: UIView {
    enum Style {
        case sharp
        case blurred
    }

    let (loadResultTransmitter, loadResultReceiver) = Receiver<Bool>.make(with: .hot)

    weak var delegate: MediaArtworkViewDelegate?

    private let disposeBag = DisposeBag()
    private let previewBackdropImageView = BackdropImageView()
    private let backdropImageView = BackdropImageView()
    private let blurredPosterFillView = PosterImageView()
    private lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(openImageBrowser))
    private var needsImageLoad = false
    private var loadedWidth: CGFloat = 0
    private var showsEpisodeStill = false

    private(set) var media: MediaModel?

    var style = Style.sharp {
        didSet {
            guard style != oldValue else { return }
            applyStyle()
            blurredPosterFillView.isHidden = true
            previewBackdropImageView.media = nil
            backdropImageView.media = nil
            needsImageLoad = true
            setNeedsLayout()
        }
    }

    var dragPreviewView: UIView {
        return backdropImageView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
    }

    /// Always re-applies the episode spoiler setting, so calling it again with the same media picks up a settings change.
    func configure(media: MediaModel) {
        if media != self.media {
            tapRecognizer.isEnabled = false
            blurredPosterFillView.isHidden = true
            loadedWidth = 0
        }
        self.media = media
        needsImageLoad = true
        setNeedsLayout()
    }

    /// Image sizes come from the views' bounds, so loading waits for the first layout. A sharp backdrop that grows a
    /// lot, like in a Mac window being widened, loads a sharper file that cross-fades over the one on screen.
    override func layoutSubviews() {
        super.layoutSubviews()
        // A cell is first laid out at a default size before the table sizes it, so wait until it's on screen.
        guard window != nil, bounds.width > 0 else { return }
        if style == .sharp, needsImageLoad == false, loadedWidth > 0, bounds.width > loadedWidth * 1.25 {
            loadedWidth = bounds.width
            backdropImageView.reloadKeepingImage()
        }
        guard needsImageLoad else { return }
        needsImageLoad = false
        loadImages()
    }

    private func loadImages() {
        guard let media = media else { return }
        loadedWidth = bounds.width

        // Backdrop image views have no season artwork, so a season shows its show's backdrop.
        var displayedMedia = media
        if case .season(_, let show) = media {
            displayedMedia = .show(show)
        }

        guard case .episode(let episode, let show) = media,
              UserDefaults.standard.bool(forKey: "GeneralSettings.episodeImageSpoilers") else {
            showBackdrop(of: displayedMedia, showsEpisodeStill: true)
            return
        }

        if let progress = ProgressManager.shared.cachedProgress(for: show) {
            showBackdrop(of: displayedMedia, showsEpisodeStill: MediaBackdropView.isWatched(episode, in: progress))
            return
        }

        // While the watched state loads, the show's backdrop shows. The still dissolves over it if the episode is
        // watched.
        showBackdrop(of: displayedMedia, showsEpisodeStill: false)
        media.progress { [weak self] progress in
            guard MediaBackdropView.isWatched(episode, in: progress) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.media == media else { return }
                self.showBackdrop(of: displayedMedia, showsEpisodeStill: true)
            }
        }
    }

    private func showBackdrop(of displayedMedia: MediaModel, showsEpisodeStill: Bool) {
        self.showsEpisodeStill = showsEpisodeStill
        let imageViews = style == .sharp ? [previewBackdropImageView, backdropImageView] : [backdropImageView]
        for imageView in imageViews {
            // Clearing a different media first keeps the spoiler change from reloading the previous backdrop.
            if imageView.media != displayedMedia {
                imageView.media = nil
            }
            imageView.showEpisodeSpoilers = showsEpisodeStill
            imageView.media = displayedMedia
        }
    }

    /// Only a watch dated now or earlier counts, so a check-in that's still running keeps the still hidden.
    private static func isWatched(_ episode: Episode, in progress: ShowProgress?) -> Bool {
        guard let progress = progress else { return false }
        for season in progress.seasons where season.number == episode.season {
            for episodeProgress in season.episodes where episodeProgress.number == episode.number {
                return episodeProgress.completed && (episodeProgress.lastWatchedAt ?? .distantPast) <= Date()
            }
        }
        return false
    }

    /// Opens what's on screen: an episode hiding its still opens the show's backdrops, so a tap never reveals a spoiler.
    @objc private func openImageBrowser() {
        guard let media = media else { return }
        switch media {
        case .movie, .show:
            delegate?.artworkView(self, didRequestImageBrowserFor: media, filter: .backdrop)
        case .season:
            delegate?.artworkView(self, didRequestImageBrowserFor: media, filter: nil)
        case .episode(_, let show):
            if showsEpisodeStill {
                delegate?.artworkView(self, didRequestImageBrowserFor: media, filter: .still)
            } else {
                delegate?.artworkView(self, didRequestImageBrowserFor: .show(show), filter: .backdrop)
            }
        case .list, .showProgress:
            return
        }
    }

    /// A blurred backdrop sits behind a poster, so when it fails the poster fills in, blurred. It's only a fallback, never a
    /// placeholder while the backdrop loads.
    private func showBlurredPosterIfNeeded(backdropDidLoad: Bool) {
        guard style == .blurred, let media = media else { return }
        blurredPosterFillView.isHidden = backdropDidLoad
        if backdropDidLoad == false {
            blurredPosterFillView.showPoster(of: media)
        }
    }

    private func applyStyle() {
        switch style {
        case .sharp:
            previewBackdropImageView.isHidden = false
            backdropImageView.isBlurred = false
        case .blurred:
            previewBackdropImageView.isHidden = true
            backdropImageView.isBlurred = true
        }
    }

    private func setup() {
        isAccessibilityElement = true
        accessibilityLabel = "Backdrop"
        accessibilityHint = "Opens the image browser"
        accessibilityTraits = [.image, .button]

        previewBackdropImageView.scale = 0.3
        backdropImageView.transitionDuration = 0.15

        blurredPosterFillView.scale = 0.25
        blurredPosterFillView.isBlurred = true
        blurredPosterFillView.isHidden = true
        blurredPosterFillView.overrideBackgroundColor = .clear
        blurredPosterFillView.backgroundColor = .clear
        blurredPosterFillView.translatesAutoresizingMaskIntoConstraints = false
        blurredPosterFillView.ignoresImageSize()
        addSubview(blurredPosterFillView)
        NSLayoutConstraint.activate(blurredPosterFillView.edgeConstraints(to: self))

        for imageView in [previewBackdropImageView, backdropImageView] {
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.overrideBackgroundColor = .clear
            imageView.backgroundColor = .clear
            imageView.fadesCachedImages = false
            imageView.dissolvesSpoilerChanges = true
            imageView.ignoresImageSize()
            imageView.layer.cornerRadius = ViewRadius.large.rawValue
            imageView.layer.cornerCurve = .continuous
            imageView.layer.masksToBounds = true
            addSubview(imageView)
            NSLayoutConstraint.activate(imageView.edgeConstraints(to: self))
        }

        tapRecognizer.isEnabled = false
        addGestureRecognizer(tapRecognizer)

        backdropImageView.completion = { [weak self] result in
            guard let self = self else { return }
            self.tapRecognizer.isEnabled = result
            self.showBlurredPosterIfNeeded(backdropDidLoad: result)
            self.loadResultTransmitter.broadcast(result)
        }

        onProgressCacheChangedReceiver.listen { [weak self] showProgress in
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.showsEpisodeStill == false,
                      case .episode(let episode, let show) = self.media,
                      showProgress.show == show,
                      MediaBackdropView.isWatched(episode, in: showProgress.showProgress) else { return }
                self.showBackdrop(of: .episode(episode, show), showsEpisodeStill: true)
            }
        }.disposed(by: disposeBag)
    }
}
