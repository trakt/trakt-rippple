//
//  NotificationCenterTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 28/04/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

final class NotificationCenterTableViewCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var body: UILabel!
    @IBOutlet weak var date: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        selectionStyle = .none
    }
}
