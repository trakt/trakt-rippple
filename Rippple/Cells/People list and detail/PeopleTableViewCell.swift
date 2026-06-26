//
//  PeopleTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 25/09/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

final class PeopleTableViewCell: UITableViewCell {
    @IBOutlet var avatarImageView: PeopleProfileImageView!
    @IBOutlet var avatarContainer: UIView!
    @IBOutlet var avatarInitialLabel: UILabel!

    @IBOutlet var personNameLabel: UILabel!
    @IBOutlet var asLabel: UILabel!
    @IBOutlet var additionalInfoLabel: UILabel!

    var showsEpisodeCount = true {
        didSet {
            if let cast = cast {
                updateAdditionalInfo(for: cast)
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        avatarContainer.layer.cornerRadius = 37.5
        avatarContainer.layer.masksToBounds = true
        avatarContainer.layer.borderWidth = 1
        avatarContainer.layer.borderColor = UIColor.tertiarySystemFill.cgColor
    }

    var person: Person? {
        didSet {
            if let person = person, person == oldValue {
                if let knownForDepartment = person.knownForDepartment, knownForDepartment.isEmpty == false {
                    asLabel.text = "Known for \(knownForDepartment)"
                    asLabel.isHidden = false
                } else {
                    asLabel.isHidden = true
                }
                return
            }
            if let person = person {
                crew = nil
                cast = nil
                personNameLabel.text = person.name
                avatarInitialLabel.text = person.name.initials
                if let knownForDepartment = person.knownForDepartment, knownForDepartment.isEmpty == false {
                    asLabel.text = "Known for \(knownForDepartment)"
                    asLabel.isHidden = false
                } else {
                    asLabel.isHidden = true
                }
                avatarImageView.person = person
                additionalInfoLabel.isHidden = true
            }
        }
    }

    var cast: Cast? {
        didSet {
            if cast?.person?.ids == oldValue?.person?.ids {
                if let cast = cast {
                    updateAdditionalInfo(for: cast)
                }
                return
            }
            if let cast = cast {
                crew = nil
                person = nil
                personNameLabel.text = cast.person!.name
                avatarInitialLabel.text = cast.person!.name.initials
                asLabel.text = "as \(cast.characters.joined(separator: ", "))"
                asLabel.isHidden = cast.characters.isEmpty
                avatarImageView.person = cast.person
                updateAdditionalInfo(for: cast)
            }
        }
    }

    var crew: Job? {
        didSet {
            if crew?.person?.ids == oldValue?.person?.ids { return }
            if let crew = crew {
                cast = nil
                person = nil
                personNameLabel.text = crew.person!.name
                avatarInitialLabel.text = crew.person!.name.initials
                asLabel.text = "as \(crew.jobs.joined(separator: ", "))"
                asLabel.isHidden = crew.jobs.isEmpty
                avatarImageView.person = crew.person
                additionalInfoLabel.isHidden = true
            }
        }
    }

    private func updateAdditionalInfo(for cast: Cast) {
        guard showsEpisodeCount, let episodeCount = cast.episodeCount else {
            additionalInfoLabel.text = nil
            additionalInfoLabel.isHidden = true
            return
        }

        additionalInfoLabel.isHidden = false
        additionalInfoLabel.text = episodeCount <= 1 ? "\(episodeCount) episode" : "\(episodeCount) episodes"
    }
}
