//
//  StandardListTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 22/09/2020.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class StandardListTableViewCell: UITableViewCell {
    @IBOutlet var title: UILabel!

    @IBOutlet var card: CardView!
    @IBOutlet var chevron: UIView!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            title.textColor = UIColor(asset: .globalTint)
        } else {
            title.textColor = .label
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            title.textColor = UIColor(asset: .globalTint)
        } else {
            title.textColor = .label
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = .clear
        backgroundColor = .clear
    }
}
