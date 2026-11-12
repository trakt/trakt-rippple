//
//  MediaPosterView.swift
//  Rippple
//
//  Created by Kevin Cador on 20/06/2020.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import UIKit

protocol MediaArtworkViewDelegate: AnyObject {
    func artworkView(_ view: UIView, didRequestImageBrowserFor media: MediaModel, filter: ImageItem.ImageType?)
    func artworkView(_ view: UIView, didRequestSaving image: UIImage)
    func artworkView(_ view: UIView, didRequestSharing image: UIImage)
}

/// The poster with its loading steps, tap and image menu, shared by the compact poster row and the full-width media card.
/// Both set it on the backdrop, so it has the edge and shadow of a card, and a card's background until it loads.
final class MediaPosterView: UIView {
    let (loadResultTransmitter, loadResultReceiver) = Receiver<Bool>.make(with: .hot)

    weak var delegate: MediaArtworkViewDelegate?

    let posterImageView = PosterImageView()

    private let placeholderView = CardView()
    private let previewPosterImageView = PosterImageView()
    private let loadingIndicator = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 80, height: 80),
                                                           type: .ballScaleMultiple)
    private lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(openImageBrowser))
    private var needsImageLoad = false

    var media: MediaModel? {
        didSet {
            guard media != oldValue else { return }
            tapRecognizer.isEnabled = false
            placeholderView.isHidden = false
            needsImageLoad = true
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// Image sizes come from the views' bounds, so loading waits for the first layout.
    override func layoutSubviews() {
        super.layoutSubviews()
        castMediaCardShadow(around: posterImageView.frame)
        // A cell is first laid out at a default size before the table sizes it, so wait until it's on screen.
        guard needsImageLoad, window != nil, bounds.width > 0, let media = media else { return }
        needsImageLoad = false
        previewPosterImageView.showPoster(of: media)
        posterImageView.showPoster(of: media)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
    }

    func makeContextMenuConfiguration(identifier: NSCopying) -> UIContextMenuConfiguration? {
        guard let image = posterImageView.image else { return nil }

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil) { [weak self] _ in
            let copyAction = UIAction(title: "Copy Image", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.image = image
            }
            let saveAction = UIAction(title: "Save Image", image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.artworkView(self, didRequestSaving: image)
            }
            let shareAction = UIAction(title: "Share Image", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.artworkView(self, didRequestSharing: image)
            }
            return UIMenu(children: [copyAction, saveAction, shareAction])
        }
    }

    @objc private func applyBorder() {
        for imageView in [previewPosterImageView, posterImageView] {
            imageView.layer.borderWidth = 1
            imageView.layer.borderColor = UIColor.tertiarySystemFill.resolvedColor(with: traitCollection).cgColor
        }
    }

    @objc private func openImageBrowser() {
        guard let media = media else { return }
        delegate?.artworkView(self, didRequestImageBrowserFor: media, filter: .poster)
    }

    private func setup() {
        isAccessibilityElement = true
        accessibilityLabel = "Poster"
        accessibilityHint = "Opens the image browser"
        accessibilityTraits = [.image, .button]

        loadingIndicator.tintColor = UIColor(asset: .globalTint)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()

        placeholderView.translatesAutoresizingMaskIntoConstraints = false

        previewPosterImageView.scale = 0.5
        posterImageView.transitionDuration = 0.15

        for imageView in [previewPosterImageView, posterImageView] {
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.overrideBackgroundColor = .clear
            imageView.backgroundColor = .clear
            imageView.fadesCachedImages = false
            imageView.ignoresImageSize()
            imageView.layer.cornerRadius = ViewRadius.large.rawValue
            imageView.layer.cornerCurve = .continuous
            imageView.layer.masksToBounds = true
        }

        addSubview(placeholderView)
        addSubview(loadingIndicator)
        addSubview(previewPosterImageView)
        addSubview(posterImageView)

        NSLayoutConstraint.activate(placeholderView.edgeConstraints(to: posterImageView) +
            previewPosterImageView.edgeConstraints(to: posterImageView) + [
                loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
                loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
                loadingIndicator.widthAnchor.constraint(equalToConstant: 80),
                loadingIndicator.heightAnchor.constraint(equalToConstant: 80),

                posterImageView.topAnchor.constraint(equalTo: topAnchor),
                posterImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
                posterImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                posterImageView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
                posterImageView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
                posterImageView.widthAnchor.constraint(equalTo: posterImageView.heightAnchor, multiplier: 2.0 / 3.0)
            ])

        applyBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self], action: #selector(applyBorder))

        tapRecognizer.isEnabled = false
        addGestureRecognizer(tapRecognizer)

        posterImageView.completion = { [weak self] result in
            guard let self = self else { return }
            self.tapRecognizer.isEnabled = result
            self.placeholderView.isHidden = result
            self.loadResultTransmitter.broadcast(result)
        }
    }
}

extension PosterImageView {
    func showPoster(of media: MediaModel) {
        switch media {
        case .movie(let movie):
            self.movie = movie
        case .show(let show), .episode(_, let show), .showProgress(let show, _):
            self.show = show
        case .season(let season, let show):
            self.season = (show, season)
        case .list:
            return
        }
    }
}
