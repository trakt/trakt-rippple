//
//  WhereToWatchCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/01/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import UIKit

import Kingfisher

final class WhereToWatchCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var providerType: UILabel!
    @IBOutlet weak var providerLogo: UIImageView!

    var provider: ProviderType! {
        didSet {
            providerType.text = provider.type?.joined(separator: " or ")
            if let providerLogoURL = provider.logo, let url = ImagesManager.shared.imageURL(for: providerLogoURL) {
                providerLogo.kf.setImage(with: url,
                                         options: [.scaleFactor(traitCollection.displayScale), .processor(DownsamplingImageProcessor(size: bounds.size))])
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        providerLogo.layer.cornerRadius = ViewRadius.medium.rawValue
        providerLogo.layer.cornerCurve = .continuous
        providerLogo.layer.masksToBounds = true
        providerLogo.layer.borderWidth = 1
        providerLogo.layer.borderColor = UIColor.tertiarySystemFill.cgColor
    }

}
