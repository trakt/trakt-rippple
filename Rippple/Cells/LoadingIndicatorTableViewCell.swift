//
//  LoadingIndicatorTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 11/04/2023.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import UIKit

final class LoadingIndicatorTableViewCell: UITableViewCell {
    @IBOutlet var activityIndicator: NVActivityIndicatorView!

    override func awakeFromNib() {
        super.awakeFromNib()

        activityIndicator.startAnimating()

        selectionStyle = .none
    }
}
