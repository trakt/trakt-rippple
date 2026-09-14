//
//  GenreBrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 04/07/2023.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class GenreBrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet var backgroundContainer: UIView!
    @IBOutlet var label: UILabel?
    @IBOutlet var emoji: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundContainer.layer.cornerRadius = backgroundContainer.bounds.height / 2.0
        backgroundContainer.layer.masksToBounds = true
        backgroundContainer.backgroundColor = UIColor.ripppleSecondaryBackground
        backgroundContainer.layer.borderWidth = 1
        backgroundContainer.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        maximumContentSizeCategory = .extraExtraLarge
    }
}
