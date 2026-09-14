//
//  EmptyTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/04/2023.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class EmptyTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var emoji: UILabel!
    @IBOutlet var title: UILabel!
    @IBOutlet var subtitle: UILabel!
    @IBOutlet var body: UILabel!
    @IBOutlet var action: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
}
