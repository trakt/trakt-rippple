//
//  RateTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 28/08/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

final class RateTableViewCell: UITableViewCell {

    @IBOutlet weak var actionTitle: UILabel!
    @IBOutlet weak var actionEmoji: UILabel!

    var currentRating = false {
        didSet {
            if currentRating {
                actionTitle.textColor = UIColor(asset: .globalTint)
//                actionTitle.font = actionTitle.font.bold()
            } else {
                actionTitle.textColor = .label
                actionTitle.font = UIFont.preferredFont(forTextStyle: .body)
            }
        }
    }

    var rating = 0 {
        didSet {
            switch rating {
            case 1:
                actionEmoji.text = "😴"
                actionTitle.text = "1 - I fell asleep"
            case 2:
                actionEmoji.text = "😩"
                actionTitle.text = "2 - Terrible"
            case 3:
                actionEmoji.text = "👎"
                actionTitle.text = "3 - Bad"
            case 4:
                actionEmoji.text = "🙁"
                actionTitle.text = "4 - Poor"
            case 5:
                actionEmoji.text = "😐"
                actionTitle.text = "5 - Meh"
            case 6:
                actionEmoji.text = "😌"
                actionTitle.text = "6 - Fair"
            case 7:
                actionEmoji.text = "👍"
                actionTitle.text = "7 - Good"
            case 8:
                actionEmoji.text = "👏"
                actionTitle.text = "8 - Great"
            case 9:
                actionEmoji.text = "👌"
                actionTitle.text = "9 - Superb"
            case 10:
                actionEmoji.text = "💯"
                actionTitle.text = "10 - Masterpiece"
            default:
                fatalError()
            }
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected || currentRating {
            actionTitle.textColor = UIColor(asset: .globalTint)
//            actionTitle.font = actionTitle.font.bold()
        } else {
            actionTitle.textColor = .label
            actionTitle.font = UIFont.preferredFont(forTextStyle: .body)
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted || currentRating {
            actionTitle.textColor = UIColor(asset: .globalTint)
//            actionTitle.font = actionTitle.font.bold()
        } else {
            actionTitle.textColor = .label
            actionTitle.font = UIFont.preferredFont(forTextStyle: .body)
        }
    }
}
