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
                guest = nil
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
            if cast?.person?.ids == oldValue?.person?.ids { return }
            if let cast = cast {
                crew = nil
                person = nil
                guest = nil
                personNameLabel.text = cast.person!.name
                avatarInitialLabel.text = cast.person!.name.initials
                asLabel.text = "as \(cast.characters.joined(separator: ", "))"
                asLabel.isHidden = cast.characters.isEmpty
                avatarImageView.person = cast.person
                if let episodeCount = cast.episodeCount {
                    additionalInfoLabel.isHidden = false
                    additionalInfoLabel.text = episodeCount <= 1 ? "\(episodeCount) episode" : "\(episodeCount) episodes"
                } else {
                    additionalInfoLabel.isHidden = true
                }
            }
        }
    }

    var guest: Cast? {
        didSet {
            if guest?.person?.ids == oldValue?.person?.ids { return }
            if let guest = guest {
                crew = nil
                person = nil
                cast = nil
                personNameLabel.text = guest.person!.name
                avatarInitialLabel.text = guest.person!.name.initials
                asLabel.text = "as \(guest.characters.joined(separator: ", "))"
                asLabel.isHidden = guest.characters.isEmpty
                avatarImageView.person = guest.person
                if let episodeCount = guest.episodeCount {
                    additionalInfoLabel.isHidden = false
                    additionalInfoLabel.text = episodeCount <= 1 ? "Guest Star in \(episodeCount) episode" : "\(episodeCount) episodes"
                } else {
                    additionalInfoLabel.isHidden = false
                    additionalInfoLabel.text = "Guest Star"
                }
            }
        }
    }

    var crew: Job? {
        didSet {
            if crew?.person?.ids == oldValue?.person?.ids { return }
            if let crew = crew {
                cast = nil
                person = nil
                guest = nil
                personNameLabel.text = crew.person!.name
                avatarInitialLabel.text = crew.person!.name.initials
                asLabel.text = "as \(crew.jobs.joined(separator: ", "))"
                asLabel.isHidden = crew.jobs.isEmpty
                avatarImageView.person = crew.person
                additionalInfoLabel.isHidden = true
            }
        }
    }
}
