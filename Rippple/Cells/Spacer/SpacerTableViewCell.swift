//
//  SpacerTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 04/07/2025.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class SpacerTableViewCell: TintedCanvasTableViewCell {
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
            spacer.leadingAnchor.constraint(equalTo: leadingAnchor),
            spacer.trailingAnchor.constraint(equalTo: trailingAnchor),
            spacer.bottomAnchor.constraint(equalTo: bottomAnchor),
            spacer.topAnchor.constraint(equalTo: topAnchor)
        ])
    }
}
