//
//  SpacerTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 04/07/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import UIKit

final class SpacerTableViewCell: UITableViewCell {
    private let spacer = UIView()

    var space: Float = 0.0 {
        didSet {
            constraint.constant = CGFloat(space.rounded(.down))
        }
    }

    private var constraint: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()

        selectionStyle = .none

        spacer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spacer)

        constraint = spacer.heightAnchor.constraint(equalToConstant: CGFloat(space.rounded(.down)))
        NSLayoutConstraint.activate([
            constraint,
            spacer.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            spacer.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            spacer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            spacer.topAnchor.constraint(equalTo: self.topAnchor)
        ])
    }
}
