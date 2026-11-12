//
//  MediaBackdropTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class MediaBackdropTableViewCell: TintedCanvasTableViewCell {
    let backdropView = MediaBackdropView()

    private let insideCardView = InsideCardView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none
        addMediaCard(around: insideCardView)

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        insideCardView.addSubview(backdropView)
        NSLayoutConstraint.activate(backdropView.edgeConstraints(to: insideCardView))
    }
}
