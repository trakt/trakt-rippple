//
//  BrowseLinkCardViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 26/06/2024.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class BrowseLinkCardViewCell: UITableViewCell {
    @IBOutlet var topLayoutConstraint: NSLayoutConstraint!

    @IBOutlet var cardView: CardView!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!

    @IBOutlet var indicatorImageView: UIImageView!
}
