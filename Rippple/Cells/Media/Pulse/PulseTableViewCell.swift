//
//  PulseTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 14/05/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import UIKit

final class PulseTableViewCell: UITableViewCell {
    enum CardType {
        case top
        case middle
        case bottom
        case alone
    }

    @IBOutlet weak var activityType: UILabel!
    @IBOutlet weak var referenceDate: UILabel!
    @IBOutlet weak var notes: ActivityLabel!
    @IBOutlet weak var metaInfo: UILabel!
    @IBOutlet weak var picto: UIImageView!

    @IBOutlet weak var ownEventIndicator: UIView!

    @IBOutlet weak var backdrop: BackdropImageView!

    @IBOutlet var separator: UIView!

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentConstraint: NSLayoutConstraint!

    var cardType: CardType = CardType.middle {
        didSet {
            switch cardType {
            case .top:
                topConstraint.constant = 4
                bottomConstraint.constant = -10
                separator.alpha = 0.4
                contentConstraint.constant = -15
            case .bottom:
                topConstraint.constant = -10
                bottomConstraint.constant = 4
                separator.alpha = 0.0
                contentConstraint.constant = -15
            case .middle:
                topConstraint.constant = -10
                bottomConstraint.constant = -10
                separator.alpha = 0.4
                contentConstraint.constant = -15
            case .alone:
                topConstraint.constant = 4
                bottomConstraint.constant = 4
                separator.alpha = 0.0
                contentConstraint.constant = -14
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        selectionStyle = .default
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        selectedBackgroundView = backgroundView
        let multipleBackgroundView = UIView()
        multipleBackgroundView.backgroundColor = .tertiarySystemBackground
        multipleSelectionBackgroundView = multipleBackgroundView

        maximumContentSizeCategory = .extraExtraExtraLarge

        backdrop.showEpisodeSpoilers = true
        backdrop.layer.cornerRadius = 7
        backdrop.layer.cornerCurve = .continuous
        backdrop.layer.masksToBounds = true
        backdrop.layer.borderWidth = 1
        backdrop.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        backdrop.overrideBackgroundColor = UIColor.clear

        ownEventIndicator.backgroundColor = .secondaryLabel
        ownEventIndicator.layer.cornerRadius = 1
        ownEventIndicator.layer.cornerCurve = .circular
    }
}
