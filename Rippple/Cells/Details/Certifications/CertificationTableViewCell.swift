//
//  CertificationTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 31/12/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Receiver
import UIKit

final class CertificationTableViewCell: UITableViewCell {
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var metadataLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!

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
