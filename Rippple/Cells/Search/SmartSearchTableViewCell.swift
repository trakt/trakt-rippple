//
//  SmartSearchTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 08/11/2021.
//  Copyright © 2021 LINITIX. All rights reserved.
//

import UIKit

final class SmartSearchTableViewCell: UITableViewCell {
    @IBOutlet var title: UILabel!
    @IBOutlet var separator: UIView!

    @IBOutlet var card: UIView!

    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBOutlet var topConstraint: NSLayoutConstraint!
    @IBOutlet var titleConstraint: NSLayoutConstraint!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            card.backgroundColor = UIColor(asset: .globalTint)
            title.textColor = .white
            separator.isHidden = true
        } else {
            if traitCollection.userInterfaceStyle == .dark {
                card.backgroundColor = .secondarySystemBackground
                title.textColor = .label
            } else {
                card.backgroundColor = .systemBackground
                title.textColor = .label
            }
            separator.isHidden = false
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            card.backgroundColor = UIColor(asset: .globalTint)
            title.textColor = .white
            separator.isHidden = true
        } else {
            if traitCollection.userInterfaceStyle == .dark {
                card.backgroundColor = .secondarySystemBackground
                title.textColor = .label
            } else {
                card.backgroundColor = .systemBackground
                title.textColor = .label
            }
            separator.isHidden = false
        }
    }

    var cardType: CardType = .middle {
        didSet {
            switch cardType {
            case .top:
                topConstraint.constant = 4
                bottomConstraint.constant = -10
                separator.alpha = 0.5
                titleConstraint.constant = 3
            case .bottom:
                topConstraint.constant = -10
                bottomConstraint.constant = 4
                separator.alpha = 0.0
                titleConstraint.constant = -3
            case .middle:
                topConstraint.constant = -10
                bottomConstraint.constant = -10
                separator.alpha = 0.5
                titleConstraint.constant = 0
            case .alone:
                topConstraint.constant = 4
                bottomConstraint.constant = 4
                separator.alpha = 0.0
                titleConstraint.constant = 0
            }
        }
    }

    enum CardType {
        case top
        case middle
        case bottom
        case alone
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = .clear
        backgroundColor = .clear
    }
}
