//
//  FollowingCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 11/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Kingfisher
import UIKit

final class FollowingCollectionViewCell: UICollectionViewCell {
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var usernameLabel: UILabel!

    private let filter = RoundCornerImageProcessor(
        cornerRadius: 25.0,
        targetSize: CGSize(width: 50.0, height: 50.0)
    )

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2.0
        avatarImageView.layer.borderWidth = 1
        avatarImageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        avatarImageView.clipsToBounds = true

        maximumContentSizeCategory = .large
    }

    var user: User! {
        didSet {
            let username = user.username
            usernameLabel.text = username

            if let images = user.images {
                avatarImageView.kf.setImage(with: images.avatar.full,
                                            placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_tiny"),
                                            options: [.scaleFactor(traitCollection.displayScale),
                                                      .processor(filter)])
            } else {
                avatarImageView.image = #imageLiteral(resourceName: "bg_placeholder_avatar_tiny")
            }
        }
    }
}
