//
//  CardView.swift
//  Rippple
//
//  Created by Kevin Cador on 29/06/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

enum ViewRadius: CGFloat {
    case small = 8
    case medium = 12
    case large = 16
}

enum CardType {
    case top
    case middle
    case bottom
    case alone
}

final class CardView: UIView {
    @objc
    fileprivate func applyMode() {
        if traitCollection.userInterfaceStyle == .dark {
            backgroundView.backgroundColor = .secondarySystemBackground
            borderView.layer.borderColor = UIColor(asset: .separator).withAlphaComponent(0.5).cgColor
        } else {
            backgroundView.backgroundColor = .systemBackground
            borderView.layer.borderColor = UIColor(asset: .separator).lighter(amount: 0.15).cgColor
        }
    }

    var cardType: CardType = CardType.alone {
        didSet {
            switch cardType {
            case .top:
                constraint?.constant = 0
                backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                borderView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            case .bottom:
                constraint?.constant = -1
                backgroundView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                borderView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            case .middle:
                constraint?.constant = -1
                backgroundView.layer.maskedCorners = []
                borderView.layer.maskedCorners = []
                layer.maskedCorners = []
            case .alone:
                constraint?.constant = 0
                backgroundView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner, .layerMaxXMinYCorner]
                borderView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner, .layerMaxXMinYCorner]
                layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner, .layerMaxXMinYCorner]
            }
        }
    }

    private let borderView = UIView()
    private let backgroundView = UIView()

    private var constraint: NSLayoutConstraint?

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        clipsToBounds = true
        layer.cornerRadius = ViewRadius.large.rawValue
        layer.cornerCurve = .continuous

        borderView.layer.cornerRadius = ViewRadius.large.rawValue
        borderView.layer.cornerCurve = .continuous
        borderView.layer.borderWidth = 1
        borderView.layer.zPosition = .greatestFiniteMagnitude

        borderView.translatesAutoresizingMaskIntoConstraints = false

        insertSubview(borderView, at: 0)

        constraint = borderView.topAnchor.constraint(equalTo: self.topAnchor)
        NSLayoutConstraint.activate([
            constraint!,
            borderView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            borderView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])

        backgroundView.layer.cornerRadius = ViewRadius.large.rawValue
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        insertSubview(backgroundView, at: 1)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: self.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])

        applyMode()
        registerForTraitChanges([UITraitUserInterfaceStyle.self],
                                action: #selector(applyMode))
    }

    deinit {
        print("deinit card view")
    }
}

final class InsideCardView: UIView {
    @objc
    fileprivate func applyMode() {
        if traitCollection.userInterfaceStyle == .dark {
            layer.borderColor = UIColor(asset: .separator).withAlphaComponent(0.5).cgColor
            backgroundColor = .tertiarySystemBackground
        } else {
            layer.borderColor = UIColor(asset: .separator).lighter(amount: 0.15).cgColor
            backgroundColor = .systemBackground
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        registerForTraitChanges([UITraitUserInterfaceStyle.self],
                                action: #selector(applyMode))

        layer.cornerRadius = ViewRadius.large.rawValue
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.masksToBounds = true
        applyMode()
    }

    deinit {
        print("deinit card view")
    }
}
