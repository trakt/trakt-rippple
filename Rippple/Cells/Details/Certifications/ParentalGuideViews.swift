//
//  ParentalGuideViews.swift
//  Rippple
//
//  Created by Kevin Cador on 16/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

extension ParentalGuide.Severity {
    var color: UIColor {
        switch self {
        case .none:
            return .tertiaryLabel
        case .mild:
            return .systemGreen
        case .moderate:
            return .systemYellow
        case .severe:
            return .systemRed
        }
    }
}

final class ParentalGuideIndicatorsView: UIStackView {
    init() {
        super.init(frame: .zero)

        spacing = 3
        alignment = .center
        isAccessibilityElement = false

        for _ in ParentalGuide.Category.allCases {
            let indicator = UIView()
            indicator.layer.cornerRadius = 2
            indicator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                indicator.widthAnchor.constraint(equalToConstant: 4),
                indicator.heightAnchor.constraint(equalToConstant: 10)
            ])
            addArrangedSubview(indicator)
        }

        configure(guide: nil)
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(guide: ParentalGuide?) {
        for (category, indicator) in zip(ParentalGuide.Category.allCases, arrangedSubviews) {
            let severity = guide?.severity(for: category)
            indicator.backgroundColor = severity?.color ?? .quaternaryLabel
        }
    }
}

final class ParentalGuideTableViewCell: TintedCanvasTableViewCell {
    private let card = CardView()
    private var cardTopConstraint: NSLayoutConstraint?
    private var cardBottomConstraint: NSLayoutConstraint?

    var cardType: CardType = .alone {
        didSet {
            card.cardType = cardType
            switch cardType {
            case .top:
                cardTopConstraint?.constant = 4
                cardBottomConstraint?.constant = 0
            case .middle:
                cardTopConstraint?.constant = 0
                cardBottomConstraint?.constant = 0
            case .bottom:
                cardTopConstraint?.constant = 0
                cardBottomConstraint?.constant = -4
            case .alone:
                cardTopConstraint?.constant = 4
                cardBottomConstraint?.constant = -4
            }
        }
    }

    private let categoryLabel = UILabel()
    private let severityLabel = UILabel()
    private let indicator = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        isAccessibilityElement = true

        categoryLabel.font = .preferredFont(forTextStyle: .subheadline).bold()
        categoryLabel.adjustsFontForContentSizeCategory = true
        categoryLabel.numberOfLines = 0
        categoryLabel.textColor = .label

        severityLabel.font = .preferredFont(forTextStyle: .subheadline)
        severityLabel.adjustsFontForContentSizeCategory = true
        severityLabel.textColor = .secondaryLabel
        severityLabel.numberOfLines = 0

        let labels = UIStackView(arrangedSubviews: [categoryLabel, severityLabel])
        labels.axis = .vertical
        labels.spacing = 4

        indicator.layer.cornerRadius = 2
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.widthAnchor.constraint(equalToConstant: 4).isActive = true

        let stack = UIStackView(arrangedSubviews: [indicator, labels])
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        card.addSubview(stack)

        cardTopConstraint = card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4)
        cardBottomConstraint = card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        cardTopConstraint?.isActive = true
        cardBottomConstraint?.isActive = true

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(category: ParentalGuide.Category, severity: ParentalGuide.Severity?, loading: Bool) {
        let label = loading ? "Loading…" : severity?.title ?? "Unknown"
        categoryLabel.text = category.title
        severityLabel.text = label
        indicator.backgroundColor = loading ? .quaternaryLabel : severity?.color ?? .quaternaryLabel
        accessibilityLabel = "\(category.title): \(label)"
    }
}
