//
//  OverviewTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 12/01/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

final class PeopleBioTableViewCell: UITableViewCell {

    @IBOutlet weak var biography: UILabel!

    var person: Person! {
        didSet {
            biography.text = person.biography ?? ""
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
}
