//
//  ActionTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 10/02/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

final class ActionDateTableViewCell: UITableViewCell {
    @IBOutlet weak var actionTitle: UILabel!
    @IBOutlet weak var actionImage: UIImageView!

    @IBOutlet weak var datePicker: UIDatePicker!

    override func awakeFromNib() {
        super.awakeFromNib()

        datePicker.preferredDatePickerStyle = .compact
    }
}
