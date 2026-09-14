//
//  CheckinView.swift
//  Rippple
//
//  Created by Kevin Cador on 24/06/2025.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class CheckinView: UIView {
    private let poster: PosterImageView = {
        let imageView = PosterImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isRounded = true
        imageView.backgroundColor = .ripppleTertiaryBackground
        imageView.layer.cornerRadius = 36.0 / 2.0
        imageView.layer.cornerCurve = .circular
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        imageView.widthAnchor.constraint(equalToConstant: 36).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 36).isActive = true
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private let title: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Checkin"
        label.font = .preferredFont(forTextStyle: .caption1).bold()
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()

    private let subtitle: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "In progress"
        label.font = .preferredFont(forTextStyle: .caption2).bold()
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()

    private let labelsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.distribution = .fill
        stack.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return stack
    }()

    private let progress: CircularProgressView = {
        let view = CircularProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 28).isActive = true
        view.heightAnchor.constraint(equalToConstant: 28).isActive = true
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.trackTintColor = .label.withAlphaComponent(0.4)
        view.progressTintColor = .label
        view.roundedCorners = true
        view.thicknessRatio = 0.225
        return view
    }()

    private let horizontalStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 6
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()

    private let button: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        contextMenu.referenceView = poster

        labelsStackView.addArrangedSubview(title)
        labelsStackView.addArrangedSubview(subtitle)

        horizontalStackView.addArrangedSubview(poster)
        horizontalStackView.addArrangedSubview(labelsStackView)
        horizontalStackView.addArrangedSubview(progress)

        addSubview(horizontalStackView)
        addSubview(button)

        button.translatesAutoresizingMaskIntoConstraints = false
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        let topConstraint = horizontalStackView.topAnchor.constraint(equalTo: topAnchor, constant: 6)
        topConstraint.priority = .required

        let leadingConstraint = horizontalStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6)
        leadingConstraint.priority = .required

        let trailingConstraint = horizontalStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        trailingConstraint.priority = .required

        let bottomConstraint = horizontalStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        bottomConstraint.priority = .required

        NSLayoutConstraint.activate([
            topConstraint,
            leadingConstraint,
            trailingConstraint,
            bottomConstraint,

            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])

        isUserInteractionEnabled = true
        let interaction = UIContextMenuInteraction(delegate: contextMenu)
        addInteraction(interaction)

        button.addAction(UIAction(handler: { _ in
            UIApplication.shared.switchToCurrentlyWatching(zoomSourceView: self)
        }),
        for: .touchUpInside)

        update(watchingItem: WatchingManager.shared.watchingItem)

        WatchingManager.shared.onWatchingItemChangedReceiver.listen { [weak self] watchingItem, _ in
            guard let self = self else { return }
            self.update(watchingItem: watchingItem)
        }.disposed(by: disposeBag)

        WatchingManager.shared.onProgressChangedReceiver.listen { [weak self] progress in
            guard let self = self else { return }
            self.progress.updateProgress(CGFloat(progress), animated: false)
        }.disposed(by: disposeBag)
    }

    private let disposeBag = DisposeBag()

    private let contextMenu = MediaContextMenuInteractionDelegate()

    deinit {
        print("deiniting check in view")
    }

    func update(watchingItem: WatchingItem?) {
        guard let watchingItem = watchingItem else {
            contextMenu.media = nil
            poster.movie = nil
            poster.show = nil
            title.text = nil
            subtitle.text = nil
            return
        }

        if let movie = watchingItem.movie {
            contextMenu.media = movie.mediaModel
            poster.show = nil
            poster.movie = movie
            title.text = movie.title
            subtitle.text = if let releaseYear = movie.releaseYear { "\(releaseYear)" } else { nil }
        } else if let show = watchingItem.show, let episode = watchingItem.episode {
            contextMenu.media = show.mediaModel
            poster.movie = nil
            poster.show = show
            title.text = show.title
            subtitle.text = episode.localizedEpisodeNumber
        }
    }
}
