//
//  CastCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/09/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

final class CastCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var avatarImageView: PeopleProfileImageView!
    @IBOutlet weak var avatarContainer: UIView!
    @IBOutlet weak var avatarInitialLabel: UILabel!

    @IBOutlet weak var personNameLabel: UILabel!
    @IBOutlet weak var asLabel: UILabel!
    @IBOutlet weak var additionalInfoLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        avatarContainer.layer.cornerRadius = 45
        avatarContainer.layer.masksToBounds = true
        avatarContainer.layer.borderWidth = 1
        avatarContainer.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        minimumContentSizeCategory = .extraSmall
        maximumContentSizeCategory = .large
    }

    var cast: Cast? {
        didSet {
            if cast?.person?.ids == oldValue?.person?.ids { return }
            if let cast = cast {
                self.crew = nil
                personNameLabel.text = cast.person!.name
                asLabel.text = cast.characters.joined(separator: ", ")
                avatarImageView.person = cast.person
                avatarInitialLabel.text = cast.person!.name.initials
                if let episodeCount = cast.episodeCount {
                    additionalInfoLabel.isHidden = false
                    additionalInfoLabel.text = episodeCount <= 1 ? "\(episodeCount) episode" : "\(episodeCount) episodes"
                } else {
                    additionalInfoLabel.isHidden = true
                }
            }
        }
    }

    var crew: Job? {
        didSet {
            if crew?.person?.ids == oldValue?.person?.ids { return }
            if let crew = crew {
                self.cast = nil
                personNameLabel.text = crew.person!.name
                avatarInitialLabel.text = crew.person!.name.initials
                asLabel.text = crew.jobs.joined(separator: ", ")
                avatarImageView.person = crew.person
                additionalInfoLabel.isHidden = true
            }
        }
    }
}
