//
//  ServiceBrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 12/08/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

final class ServiceBrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet var backgroundContainer: UIView!

    @IBOutlet var logoImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundContainer.layer.cornerRadius = backgroundContainer.bounds.height / 2.0
        backgroundContainer.layer.cornerCurve = .continuous
        backgroundContainer.layer.masksToBounds = true
        backgroundContainer.backgroundColor = UIColor.tertiarySystemFill
        backgroundContainer.layer.borderWidth = 1
        backgroundContainer.layer.borderColor = UIColor.tertiarySystemFill.cgColor
    }
}
