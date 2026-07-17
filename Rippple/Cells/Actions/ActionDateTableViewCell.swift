//
//  ActionDateTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 10/02/2019.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class ActionDateTableViewCell: UITableViewCell {
    @IBOutlet var actionTitle: UILabel!
    @IBOutlet var actionImage: UIImageView!

    @IBOutlet var datePicker: UIDatePicker!

    override func awakeFromNib() {
        super.awakeFromNib()

        datePicker.preferredDatePickerStyle = .compact
    }
}
