//
//  AppIconCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 06/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import SwiftUI
import UIKit

final class AppIconCollectionViewCell: UICollectionViewCell {
    var appIcon: AppIcon = .init(name: "Original", identifier: .original) {
        didSet {
            let vc = RipppleHostingController(rootView: AppIconGeneratorView(appIconIdentifier: appIcon.identifier))

            icon = vc.view
            guard let icon = icon else { return }
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.layer.masksToBounds = true
            icon.layer.cornerCurve = .continuous
            icon.layer.cornerRadius = 25
            icon.layer.borderColor = UIColor.secondarySystemBackground.cgColor
            icon.layer.borderWidth = 1

            contentView.addSubview(icon)

            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                icon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                icon.topAnchor.constraint(equalTo: contentView.topAnchor),
                icon.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
    }

    var icon: UIView?

    override func awakeFromNib() {
        super.awakeFromNib()

        registerForTraitChanges([UITraitUserInterfaceStyle.self],
                                action: #selector(configureView))
    }

    @objc
    private func configureView() {
        icon?.layer.borderColor = UIColor.secondarySystemBackground.cgColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        for view in contentView.subviews {
            view.removeFromSuperview()
        }
    }
}
