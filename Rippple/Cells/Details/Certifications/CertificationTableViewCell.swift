//
//  CertificationTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 31/12/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import Receiver

final class CertificationTableViewCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var metadataLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!

    var certification: Certification? {
        didSet {
            updateText()
        }
    }

    private func updateText() {
        if let certification = certification {
            nameLabel.text = certification.name
            metadataLabel.text = certification.metadata
            descriptionLabel.text = certification.longDescription
        }
    }
}
