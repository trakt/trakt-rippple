//
//  BrowseLinkCardViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 26/06/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import UIKit

final class BrowseLinkCardViewCell: UITableViewCell {

    @IBOutlet weak var topLayoutConstraint: NSLayoutConstraint!

    @IBOutlet weak var cardView: CardView!

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!

    @IBOutlet weak var indicatorImageView: UIImageView!
}
