//
//  PulseTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 14/05/2024.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class PulseTableViewCell: TintedCanvasTableViewCell {
    enum CardType {
        case top
        case middle
        case bottom
        case alone
    }

    @IBOutlet var activityType: UILabel!
    @IBOutlet var referenceDate: UILabel!
    @IBOutlet var metaInfo: UILabel!
    @IBOutlet var picto: UIImageView!

    @IBOutlet var ownEventIndicator: UIView!

    @IBOutlet var backdrop: BackdropImageView!
    @IBOutlet var rateButton: UIButton?

    @IBOutlet var separator: UIView!

    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBOutlet var topConstraint: NSLayoutConstraint!
    @IBOutlet var contentConstraint: NSLayoutConstraint!

    @IBOutlet var notes: ActivityLabel!
    @IBOutlet var notesPicto: UIImageView!
    @IBOutlet var noteButton: UIButton!
    var onTapNoteButton: (() -> Void)?

    var ratedItem: RatedItem? {
        didSet {
            updateRateButton()
        }
    }

    var cardType: CardType = .middle {
        didSet {
            switch cardType {
            case .top:
                topConstraint.constant = 4
                bottomConstraint.constant = -10
                separator.alpha = 0.4
                contentConstraint.constant = -15
            case .bottom:
                topConstraint.constant = -10
                bottomConstraint.constant = 4
                separator.alpha = 0.0
                contentConstraint.constant = -15
            case .middle:
                topConstraint.constant = -10
                bottomConstraint.constant = -10
                separator.alpha = 0.4
                contentConstraint.constant = -15
            case .alone:
                topConstraint.constant = 4
                bottomConstraint.constant = 4
                separator.alpha = 0.0
                contentConstraint.constant = -14
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        selectionStyle = .default
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        selectedBackgroundView = backgroundView
        let multipleBackgroundView = UIView()
        multipleBackgroundView.backgroundColor = .ripppleTertiaryBackground
        multipleSelectionBackgroundView = multipleBackgroundView

        maximumContentSizeCategory = .extraExtraExtraLarge

        backdrop.showEpisodeSpoilers = true
        backdrop.layer.cornerRadius = 7
        backdrop.layer.cornerCurve = .continuous
        backdrop.layer.masksToBounds = true
        backdrop.layer.borderWidth = 1
        backdrop.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        backdrop.overrideBackgroundColor = UIColor.clear

        ownEventIndicator.backgroundColor = .secondaryLabel
        ownEventIndicator.layer.cornerRadius = 1
        ownEventIndicator.layer.cornerCurve = .circular

        noteButton.isHidden = true

        rateButton?.isHidden = true
        rateButton?.backgroundColor = UIColor(asset: .globalTint).withAlphaComponent(0.1)
        rateButton?.maximumContentSizeCategory = .accessibilityExtraExtraLarge
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        ratedItem = nil
        onTapNoteButton = nil
        noteButton.isHidden = true
        notesPicto.image = nil
        notesPicto.isHiddenInStackView = true
        notes.alpha = 1.0
        notes.tintColor = .label
    }

    @IBAction private func didTapNoteButton(_ sender: UIButton) {
        onTapNoteButton?()
    }

    private func updateRateButton() {
        guard let rateButton else { return }
        guard let ratedItem else {
            rateButton.isHidden = true
            rateButton.menu = nil
            return
        }

        let media = MediaModel(item: ratedItem)
        var configuration = rateButton.configuration
        rateButton.isHidden = false
        configuration?.indicator = .popup
        configuration?.baseBackgroundColor = UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(asset: .globalTint).withAlphaComponent(0.2)
            }
            return UIColor(asset: .globalTint).lighter(amount: 0.1).withAlphaComponent(0.2)
        }
        configuration?.title = ""
        configuration?.contentInsets = NSDirectionalEdgeInsets(top: 2,
                                                               leading: 4,
                                                               bottom: 2,
                                                               trailing: 4)
        configuration?.imagePadding = .zero
        configuration?.image = rateButtonImage(for: media)
        rateButton.configuration = configuration
        rateButton.menu = media.rateMenu
        rateButton.showsMenuAsPrimaryAction = true
    }

    private func rateButtonImage(for media: MediaModel) -> UIImage? {
        if let rating = media.userRating {
            return UIImage(systemName: "\(rating).circle")
        }
        return UIImage(systemName: "heart")
    }
}
