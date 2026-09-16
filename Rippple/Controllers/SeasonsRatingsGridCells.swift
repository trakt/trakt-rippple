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
    private let progress = UIView()
    private let progressFill = UIView()
    private var progressWidthConstraint: NSLayoutConstraint?

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
        label.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        label.layer.borderWidth = 1

        contentView.addSubview(label)

        progress.translatesAutoresizingMaskIntoConstraints = false
        // Keep the compact bar consistent when Catalyst uses native Mac control styling.
        progress.backgroundColor = .white.withAlphaComponent(0.3)
        progress.layer.cornerRadius = 1.5
        progress.clipsToBounds = true
        label.addSubview(progress)

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = .white
        progressFill.layer.cornerRadius = 1.5
        progress.addSubview(progressFill)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            progress.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: 12),
            progress.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: -12),
            progress.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: -6),
            progress.heightAnchor.constraint(equalToConstant: 3.0),

            progressFill.leadingAnchor.constraint(equalTo: progress.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progress.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progress.bottomAnchor)
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
        updateProgress(nil)
        accessibilityLabel = nil
        isAccessibilityElement = false
    }

    func configure(with viewModel: SeasonsRatingsCellViewModel) {
        label.text = viewModel.text
        label.textColor = viewModel.textColor
        label.backgroundColor = viewModel.backgroundColor

        updateProgress(viewModel.progress)

        accessibilityLabel = viewModel.accessibilityLabel
        isAccessibilityElement = viewModel.accessibilityLabel != nil
    }

    private func updateProgress(_ value: Float?) {
        progress.isHidden = value == nil
        let fraction = min(max(value ?? 0, 0), 1)
        progressWidthConstraint?.isActive = false
        progressWidthConstraint = progressFill.widthAnchor.constraint(equalTo: progress.widthAnchor, multiplier: CGFloat(fraction))
        progressWidthConstraint?.isActive = true
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
