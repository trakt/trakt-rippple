//
//  ListBrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 02/05/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

private final class HorizontalOnlyCollectionView: UICollectionView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        let velocity = panGestureRecognizer.velocity(in: self)
        if abs(velocity.y) > abs(velocity.x) {
            return false
        }

        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    override var contentOffset: CGPoint {
        get {
            super.contentOffset
        }
        set {
            super.contentOffset = CGPoint(x: newValue.x, y: 0)
        }
    }

    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        super.setContentOffset(CGPoint(x: contentOffset.x, y: 0), animated: animated)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if contentOffset.y != 0 {
            super.contentOffset = CGPoint(x: contentOffset.x, y: 0)
        }
    }
}

final class ListBrowseTableViewCell: BrowseTableViewCell {
    private let listHeight: CGFloat = 240

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        installCollectionView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installCollectionView()
    }

    private func installCollectionView() {
        guard collectionView == nil else { return }

        selectionStyle = .none
        backgroundColor = .systemBackground
        contentView.backgroundColor = .clear

        let collectionView = HorizontalOnlyCollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = false
        collectionView.isDirectionalLockEnabled = true
        collectionView.backgroundColor = .systemBackground
        collectionView.contentInsetAdjustmentBehavior = .never

        contentView.addSubview(collectionView)
        self.collectionView = collectionView

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: listHeight)
        ])

        configureCollectionViewIfNeeded()
    }
}

final class ListBrowseCollectionViewCell: UICollectionViewCell {
    let poster = PosterImageView()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let textStackView = UIStackView()
    private let actionButton = UIButton(type: .system)
    private let separatorView = UIView()

    var showsSeparator = true {
        didSet {
            separatorView.isHidden = !showsSeparator
        }
    }

    weak var presentingViewController: UIViewController? {
        didSet {
            actionButtonController.controller = presentingViewController
        }
    }

    var actionButtonStyle: ShelfBrowseActionButtonStyle = .ellipsis {
        didSet {
            actionButtonController.style = actionButtonStyle
        }
    }

    private let actionButtonController = ShelfBrowseActionButtonController()

    var media: MediaModel! {
        didSet {
            actionButtonController.media = media
            updateContent()
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

    override func prepareForReuse() {
        super.prepareForReuse()

        poster.image = nil
        poster.movie = nil
        poster.show = nil
        poster.season = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
        actionButtonController.media = nil
        showsSeparator = true
    }

    private func setup() {
        contentView.backgroundColor = .clear

        poster.translatesAutoresizingMaskIntoConstraints = false
        poster.layer.cornerRadius = ViewRadius.small.rawValue
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.layer.borderWidth = 1
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        poster.backgroundColor = UIColor.tertiarySystemFill
        poster.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail

        textStackView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.axis = .vertical
        textStackView.alignment = .fill
        textStackView.spacing = 2
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(subtitleLabel)
        textStackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        var actionButtonConfiguration = UIButton.Configuration.tinted()
        actionButtonConfiguration.image = UIImage(systemName: "heart")
        actionButtonConfiguration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            font: UIFont.preferredFont(forTextStyle: .headline),
            scale: .medium
        ).applying(UIImage.SymbolConfiguration(weight: .bold))
        actionButton.configuration = actionButtonConfiguration
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        actionButtonController.showsFullMenuForDefaultStyle = true
        actionButtonController.configure(button: actionButton, appearance: .tinted)

        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = .separator

        contentView.addSubview(poster)
        contentView.addSubview(textStackView)
        contentView.addSubview(actionButton)
        contentView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            poster.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            poster.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            poster.heightAnchor.constraint(equalTo: contentView.heightAnchor, constant: -14),
            poster.widthAnchor.constraint(equalTo: poster.heightAnchor, multiplier: 2.0 / 3.0),

            textStackView.leadingAnchor.constraint(equalTo: poster.trailingAnchor, constant: 12),
            textStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStackView.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),

            actionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            actionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            separatorView.leadingAnchor.constraint(equalTo: textStackView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1)
        ])

        maximumContentSizeCategory = .extraExtraExtraLarge
    }

    private func updateContent() {
        switch media! {
        case .movie(let movie):
            poster.movie = movie
            titleLabel.text = movie.title
            subtitleLabel.text = movieMetadata(movie)
        case .show(let show):
            poster.show = show
            titleLabel.text = show.title
            subtitleLabel.text = showMetadata(show)
        case .episode(let episode, let show):
            poster.show = show
            titleLabel.text = show.title
            subtitleLabel.text = episodeMetadata(episode)
        case .season(let season, let show):
            poster.season = (show, season)
            titleLabel.text = show.title
            subtitleLabel.text = seasonMetadata(season)
        case .showProgress(let show, let progress):
            poster.show = show
            titleLabel.text = show.title
            subtitleLabel.text = showProgressMetadata(progress)
        case .list:
            fatalError("This type is not handled")
        }
    }

    private func movieMetadata(_ movie: Movie) -> String {
        var info = [String]()
        if let release = movie.releaseYear {
            info.append("\(release)")
        }
        if let status = movie.status, status != "released" {
            info.append(status.capitalized)
        }
        return info.joined(separator: " · ")
    }

    private func showMetadata(_ show: Show) -> String {
        var info = [String]()
        if let airedEpisodes = show.airedEpisodes, airedEpisodes != 0 {
            info.append("\(airedEpisodes) episode\(airedEpisodes > 1 ? "s" : "")")
        } else if let release = show.releaseYear {
            info.append("\(release)")
        }
        if let status = show.status, status != "returning series" {
            info.append(status.capitalized)
        }
        return info.joined(separator: " · ")
    }

    private func episodeMetadata(_ episode: Episode) -> String {
        if let title = episode.title {
            return episode.localizedEpisodeNumber + " · \(title)"
        }
        return episode.localizedEpisodeNumber
    }

    private func seasonMetadata(_ season: Season) -> String {
        season.title ?? "Season \(season.number)"
    }

    private func showProgressMetadata(_ progress: ShowProgress) -> String {
        var info = [String]()

        if let episode = progress.nextEpisodeToWatch {
            if UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle") == true,
               let title = episode.title {
                info.append("\(episode.localizedEpisodeNumber) · \(title)")
            } else {
                info.append(episode.localizedEpisodeNumber)
            }
        }

        if progress.toRewatchCount > 0 {
            info.append("\(progress.toRewatchCount) to rewatch")
        } else if progress.behind > 0 {
            info.append("\(progress.behind) behind")
        }

        return info.joined(separator: " · ")
    }
}
