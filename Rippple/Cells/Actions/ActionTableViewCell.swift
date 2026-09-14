//
//  ActionTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 10/02/2019.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class ActionTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var actionTitle: UILabel!
    @IBOutlet var actionImage: UIImageView!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            actionTitle.textColor = UIColor(asset: .globalTint)
        } else {
            actionTitle.textColor = .label
            actionTitle.font = UIFont.preferredFont(forTextStyle: .body)
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            actionTitle.textColor = UIColor(asset: .globalTint)
        } else {
            actionTitle.textColor = .label
            actionTitle.font = UIFont.preferredFont(forTextStyle: .body)
        }
    }
}
