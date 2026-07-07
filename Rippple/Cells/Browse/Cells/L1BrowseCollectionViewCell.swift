//
//  L1BrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 16/06/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

final class L1BrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet var poster: PosterImageView!
    @IBOutlet var notesLabel: UILabel?

    var edgeToEdgeLayout = false {
        didSet {
            setCornerRadiusAndBorder()
        }
    }

    var notes: String? {
        didSet {
            if let notes = notes {
                notesLabel?.text = notes
            } else {
                notesLabel?.text = ""
            }
        }
    }

    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie(let movie):
                poster.movie = movie
            case .show(let show):
                poster.show = show
            case .episode(_, let show):
                poster.show = show
            case .season(_, let show):
                poster.show = show
            case .list:
                fatalError("This type is not handled")
            case .showProgress(let show, _):
                poster.show = show
            }
        }
    }

    private func setCornerRadiusAndBorder() {
        DispatchQueue.main.async {
            if self.edgeToEdgeLayout == false {
                self.poster.layer.cornerRadius = min(ViewRadius.large.rawValue, self.poster.bounds.height * 0.1)
                self.poster.layer.borderWidth = 1
            } else {
                self.poster.layer.cornerRadius = 0
                self.poster.layer.borderWidth = 0
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        setCornerRadiusAndBorder()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        setCornerRadiusAndBorder()

        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        poster.backgroundColor = UIColor.tertiarySystemFill

        if let notesLabelSuperview = notesLabel?.superview {
            notesLabelSuperview.backgroundColor = .clear
            notesLabel?.textColor = .label
        }
    }
}
