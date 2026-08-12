//
//  SeasonsRatingsGridCells.swift
//  Rippple
//
//  Created by Kevin Cador on 24/05/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class SeasonsRatingsHeaderCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = String(describing: SeasonsRatingsHeaderCollectionViewCell.self)

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .ripppleViewBackground
        contentView.backgroundColor = .ripppleViewBackground

        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.maximumContentSizeCategory = .extraExtraExtraLarge
        label.font = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: nil)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.backgroundColor = .ripppleViewBackground

        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
        accessibilityLabel = nil
    }

    func configure(text: String?) {
        label.text = text
        accessibilityLabel = text
        isAccessibilityElement = text != nil
    }
}

final class SeasonsRatingsContentCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = String(describing: SeasonsRatingsContentCollectionViewCell.self)

    let label = UILabel()
    private let progress = UIProgressView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .ripppleViewBackground
        contentView.backgroundColor = .clear

        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.maximumContentSizeCategory = .extraExtraExtraLarge
        label.font = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: nil)
        label.textAlignment = .center
        label.layer.cornerRadius = ViewRadius.medium.rawValue
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.layer.borderColor = UIColor(asset: .shadow).cgColor
        label.layer.borderWidth = 0.5

        contentView.addSubview(label)

        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.progressTintColor = .white
        progress.trackTintColor = .white.withAlphaComponent(0.3)
        label.addSubview(progress)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            progress.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: 5),
            progress.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: -5),
            progress.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: -3),
            progress.heightAnchor.constraint(equalToConstant: 3.0)
        ])

        resetContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        resetContent()
    }

    private func resetContent() {
        layer.zPosition = 0
        label.text = nil
        label.textColor = .white
        label.backgroundColor = .clear
        progress.alpha = 0.0
        progress.progress = 0.0
        accessibilityLabel = nil
        isAccessibilityElement = false
    }

    func configure(with viewModel: SeasonsRatingsCellViewModel) {
        label.text = viewModel.text
        label.textColor = viewModel.textColor
        label.backgroundColor = viewModel.backgroundColor

        if let progressValue = viewModel.progress {
            progress.alpha = 1.0
            progress.progress = progressValue
        } else {
            progress.alpha = 0.0
            progress.progress = 0.0
        }

        accessibilityLabel = viewModel.accessibilityLabel
        isAccessibilityElement = viewModel.accessibilityLabel != nil
    }
}

final class SeasonsRatingsEmptyCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = String(describing: SeasonsRatingsEmptyCollectionViewCell.self)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .ripppleViewBackground
        contentView.backgroundColor = .ripppleViewBackground
        maximumContentSizeCategory = .extraExtraExtraLarge
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        layer.zPosition = 0
        isAccessibilityElement = false
    }
}
