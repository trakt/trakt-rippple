//
//  EmptyTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/04/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

final class EmptyTableViewCell: UITableViewCell {
    @IBOutlet weak var emoji: UILabel!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var body: UILabel!
    @IBOutlet weak var action: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
}
