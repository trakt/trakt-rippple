//
//  NotificationCenterTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 28/04/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

final class NotificationCenterTableViewCell: UITableViewCell {
    @IBOutlet var title: UILabel!
    @IBOutlet var subtitle: UILabel!
    @IBOutlet var body: UILabel!
    @IBOutlet var date: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        selectionStyle = .none
    }
}
