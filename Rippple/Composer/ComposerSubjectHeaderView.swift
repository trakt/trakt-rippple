//
//  ComposerSubjectHeaderView.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class ComposerSubjectHeaderView: UIView {
    private let card = CardView()
    private let poster = PosterImageView()
    private let avatar = PeopleProfileImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailLabel = UILabel()
    private let labelsStack = UIStackView()
    private let rowStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        poster.translatesAutoresizingMaskIntoConstraints = false
        poster.backgroundColor = .ripppleTertiaryBackground
        poster.overrideBackgroundColor = .ripppleTertiaryBackground
        poster.layer.cornerRadius = ViewRadius.small.rawValue
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.layer.borderWidth = 1
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.layer.cornerRadius = 22
        avatar.layer.cornerCurve = .circular
        avatar.layer.masksToBounds = true
        avatar.layer.borderWidth = 1
        avatar.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        detailLabel.font = .preferredFont(forTextStyle: .caption1).bold()
        detailLabel.textColor = .secondaryLabel
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 1
        for label in [detailLabel, titleLabel, subtitleLabel] {
            label.adjustsFontForContentSizeCategory = true
            labelsStack.addArrangedSubview(label)
        }
        labelsStack.axis = .vertical
        labelsStack.alignment = .leading
        labelsStack.spacing = 2

        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 12
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.addArrangedSubview(poster)
        rowStack.addArrangedSubview(avatar)
        rowStack.addArrangedSubview(labelsStack)
        card.addSubview(rowStack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            poster.widthAnchor.constraint(equalToConstant: 40),
            poster.heightAnchor.constraint(equalToConstant: 60),
            avatar.widthAnchor.constraint(equalToConstant: 44),
            avatar.heightAnchor.constraint(equalToConstant: 44)
        ])

        maximumContentSizeCategory = .extraExtraExtraLarge
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self],
                                action: #selector(updateBorders))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(subject: ComposerSubject?, detail: String?) {
        guard let subject = subject else {
            isHidden = true
            return
        }
        isHidden = false
        detailLabel.text = detail
        detailLabel.isHidden = detail == nil

        switch subject {
        case .media(let media):
            avatar.isHidden = true
            poster.isHidden = false
            configure(media: media)
        case .person(let person):
            poster.isHidden = true
            avatar.isHidden = false
            titleLabel.text = person.name
            subtitleLabel.text = person.knownForDepartment?.capitalized ?? "Person"
            // PeopleProfileImageView sizes its downsampling from its bounds, which are fixed here.
            avatar.bounds.size = CGSize(width: 44, height: 44)
            avatar.person = person
        }

        accessibilityLabel = ["About \(titleLabel.text ?? "")", subtitleLabel.text, detail]
            .compactMap { $0 }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }

    @objc private func updateBorders() {
        poster.layer.borderColor = UIColor.tertiarySystemFill.resolvedColor(with: traitCollection).cgColor
        avatar.layer.borderColor = UIColor.tertiarySystemFill.resolvedColor(with: traitCollection).cgColor
    }

    private func configure(media: MediaModel) {
        switch media {
        case .movie(let movie):
            poster.movie = movie
            titleLabel.text = movie.title
            subtitleLabel.text = (["Movie"] + [movie.releaseYear.map(String.init)].compactMap { $0 }).joined(separator: " · ")
        case .show(let show), .showProgress(let show, _):
            poster.show = show
            titleLabel.text = show.title
            subtitleLabel.text = (["TV Show"] + [show.releaseYear.map(String.init)].compactMap { $0 }).joined(separator: " · ")
        case .season(let season, let show):
            poster.season = (show, season)
            titleLabel.text = show.title
            subtitleLabel.text = season.title ?? "Season \(season.number)"
        case .episode(let episode, let show):
            poster.show = show
            titleLabel.text = episode.title ?? episode.localizedEpisodeNumber
            subtitleLabel.text = "\(show.title) · \(episode.localizedEpisodeNumber)"
        case .list(let list):
            poster.isHidden = true
            titleLabel.text = list.name.emojiUnescapedString
            subtitleLabel.text = "List"
        }
    }
}
