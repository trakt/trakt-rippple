//
//  LoadingIndicatorTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 11/04/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import NVActivityIndicatorView

final class LoadingIndicatorTableViewCell: UITableViewCell {

    @IBOutlet weak var activityIndicator: NVActivityIndicatorView!

    override func awakeFromNib() {
        super.awakeFromNib()

        activityIndicator.startAnimating()

        selectionStyle = .none
    }
}
