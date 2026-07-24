//
//  PeopleTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 25/09/2019.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class PeopleTableViewCell: UITableViewCell {
    @IBOutlet var avatarImageView: PeopleProfileImageView!
    @IBOutlet var avatarContainer: UIView!
    @IBOutlet var avatarInitialLabel: UILabel!

    @IBOutlet var personNameLabel: UILabel!
    @IBOutlet var asLabel: UILabel!
    @IBOutlet var additionalInfoLabel: RedactableLabel!

    private let disposeBag = DisposeBag()

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

        actorEpisodeCountsReceiver.listen { [weak self] redactsEpisodeCounts in
            guard let self = self else { return }
            guard self.showsEpisodeCount,
                  self.cast?.episodeCount != nil else { return }
            self.additionalInfoLabel.isRedactedByDefault = redactsEpisodeCounts
        }.disposed(by: disposeBag)
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
                hideAdditionalInfo()
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
            hideAdditionalInfo()
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
                hideAdditionalInfo()
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
            hideAdditionalInfo()
            return
        }

        additionalInfoLabel.isRedactedByDefault = UserDefaults.standard.bool(forKey: "GeneralSettings.actorEpisodeCountSpoilers")
        additionalInfoLabel.text = episodeCount <= 1 ? "\(episodeCount) episode" : "\(episodeCount) episodes"
        additionalInfoLabel.isHidden = false
    }

    private func hideAdditionalInfo() {
        additionalInfoLabel.text = nil
        additionalInfoLabel.isHidden = true
    }
}
