//
//  ListFeaturedPeopleTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 14/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

/// A list's featured people as a facepile card, laid out like the media page's social activity card.
final class ListFeaturedPeopleTableViewCell: TintedCanvasTableViewCell {
    private enum Metrics {
        /// Faces and names shown before "and N more": few enough for the sentence to fit beside the faces.
        static let shownPeople = 3
        static let avatarSize: CGFloat = 34
        static let avatarStep: CGFloat = avatarSize * 0.7
        /// The face crop margin follows the image view's size, so small avatars come out zoomed in.
        /// Cropping as if the avatar were a 75pt people row keeps the whole face visible.
        static let avatarCropScale: CGFloat = 75 / avatarSize
    }

    var people = [Person]() {
        didSet {
            guard people != oldValue else { return }
            render()
        }
    }

    private let card = CardView()
    private let contentStackView = UIStackView()
    private let avatarsContainer = UIView()
    private lazy var avatarsContainerWidthConstraint = avatarsContainer.widthAnchor.constraint(equalToConstant: 0)
    private let featuringLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        contentStackView.alpha = highlighted ? 0.5 : 1
    }

    // MARK: - Layout

    private func setup() {
        selectionStyle = .none
        maximumContentSizeCategory = .extraExtraExtraLarge
        isAccessibilityElement = true
        accessibilityTraits = .button

        featuringLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        featuringLabel.adjustsFontForContentSizeCategory = true
        featuringLabel.textColor = .secondaryLabel
        featuringLabel.numberOfLines = 0

        avatarsContainer.setContentHuggingPriority(.required, for: .horizontal)
        avatarsContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentStackView.addArrangedSubview(avatarsContainer)
        contentStackView.addArrangedSubview(featuringLabel)
        contentStackView.alignment = .center
        contentStackView.spacing = 8

        card.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        contentView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            contentStackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            contentStackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
            contentStackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            contentStackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            avatarsContainer.heightAnchor.constraint(equalToConstant: Metrics.avatarSize),
            avatarsContainerWidthConstraint
        ])
    }

    private func render() {
        avatarsContainer.subviews.forEach { $0.removeFromSuperview() }

        let shownPeople = people.prefix(Metrics.shownPeople)
        for (index, person) in shownPeople.enumerated() {
            place(makeAvatar(for: person), at: index)
        }
        avatarsContainerWidthConstraint.constant = shownPeople.isEmpty ? 0 : Metrics.avatarSize + CGFloat(shownPeople.count - 1) * Metrics.avatarStep

        featuringLabel.text = featuringText
        accessibilityLabel = featuringText
        accessibilityHint = people.count == 1 ? "Opens this person's page." : "Shows all featured people."
    }

    /// "Featuring A", "Featuring A and B", "Featuring A, B and C" or "Featuring A, B, C and 10 more".
    private var featuringText: String {
        let names = people.prefix(Metrics.shownPeople).map(\.name)
        guard let lastName = names.last else { return "" }

        let othersCount = people.count - names.count
        if othersCount > 0 {
            return "Featuring \(names.joined(separator: ", ")) and \(othersCount) more"
        }
        if names.count == 1 {
            return "Featuring \(lastName)"
        }
        return "Featuring \(names.dropLast().joined(separator: ", ")) and \(lastName)"
    }

    // MARK: - Avatars

    private func place(_ avatar: UIView, at index: Int) {
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.layer.zPosition = CGFloat(index)
        avatarsContainer.addSubview(avatar)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: avatarsContainer.leadingAnchor, constant: CGFloat(index) * Metrics.avatarStep),
            avatar.centerYAnchor.constraint(equalTo: avatarsContainer.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: Metrics.avatarSize),
            avatar.heightAnchor.constraint(equalToConstant: Metrics.avatarSize)
        ])
    }

    /// Sized up front: its contents use autoresizing and would otherwise grow by the avatar size once laid out.
    private func makeAvatar(for person: Person) -> UIView {
        let avatar = UIView(frame: CGRect(x: 0, y: 0, width: Metrics.avatarSize, height: Metrics.avatarSize))
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = Metrics.avatarSize / 2
        avatar.layer.borderWidth = 1
        avatar.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        avatar.backgroundColor = .ripppleTertiaryBackground.withAlphaComponent(1.0)

        let initialsLabel = UILabel(frame: avatar.bounds)
        initialsLabel.text = person.name.initials
        initialsLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        initialsLabel.textColor = .tertiaryLabel
        initialsLabel.textAlignment = .center
        initialsLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        avatar.addSubview(initialsLabel)

        // The image view sizes its download and face crop from its bounds, so the frame is set before the person.
        let imageView = PeopleProfileImageView(frame: avatar.bounds)
        imageView.scale = Metrics.avatarCropScale
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        avatar.addSubview(imageView)
        imageView.person = person
        // Setting the person fills the background, which would hide the initials when there is no portrait.
        imageView.backgroundColor = .clear

        return avatar
    }
}
