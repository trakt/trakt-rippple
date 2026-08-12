//
//  LinkTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 17/09/2021.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

protocol LinkTableViewCellDelegate: AnyObject {
    func cell(_ cell: LinkTableViewCell, action: LinkTableViewCell.Action)
}

final class LinkTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var title: UILabel!
    @IBOutlet var linkImage: UIImageView!

    @IBOutlet var card: CardView!

    @IBOutlet var actions: UIButton!

    enum Action {
        case presentOptions
    }

    weak var delegate: LinkTableViewCellDelegate?

    var cardType: CardType = .middle {
        didSet {
            card.cardType = cardType
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = .clear
        backgroundColor = .clear
    }

    @IBAction func presentShow(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .presentOptions)
    }
}
