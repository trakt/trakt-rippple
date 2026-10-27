//
//  MediaTitleTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class MediaTitleTableViewCell: TintedCanvasTableViewCell {
    let titleCardView = MediaTitleCardView.loadFromNib()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleCardView.prepareForReuse()
    }

    private func setup() {
        selectionStyle = .none
        contentView.addSubview(titleCardView)
        NSLayoutConstraint.activate(titleCardView.edgeConstraints(to: contentView, insets: UITableViewCell.mediaCardInsets))
    }
}
