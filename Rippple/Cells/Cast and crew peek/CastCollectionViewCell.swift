//
//  CastCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/09/2019.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class CastCollectionViewCell: UICollectionViewCell {
    @IBOutlet var avatarImageView: PeopleProfileImageView!
    @IBOutlet var avatarContainer: UIView!
    @IBOutlet var avatarInitialLabel: UILabel!

    @IBOutlet var personNameLabel: UILabel!
    @IBOutlet var asLabel: UILabel!
    @IBOutlet var additionalInfoLabel: RedactableLabel!

    private let disposeBag = DisposeBag()

    var showsEpisodeCount = true {
        didSet {
            updateAdditionalInfo()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        avatarContainer.layer.cornerRadius = 45
        avatarContainer.layer.masksToBounds = true
        avatarContainer.layer.borderWidth = 1
        avatarContainer.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        minimumContentSizeCategory = .extraSmall
        maximumContentSizeCategory = .large

        actorEpisodeCountsReceiver.listen { [weak self] redactsEpisodeCounts in
            guard let self = self else { return }
            guard self.showsEpisodeCount,
                  self.cast?.episodeCount != nil else { return }
            self.additionalInfoLabel.isRedactedByDefault = redactsEpisodeCounts
        }.disposed(by: disposeBag)
    }

    var cast: Cast? {
        didSet {
            if cast?.person?.ids == oldValue?.person?.ids {
                updateAdditionalInfo()
                return
            }
            hideAdditionalInfo()
            if let cast = cast {
                crew = nil
                personNameLabel.text = cast.person!.name
                asLabel.text = cast.characters.joined(separator: ", ")
                avatarImageView.person = cast.person
                avatarInitialLabel.text = cast.person!.name.initials
                updateAdditionalInfo()
            }
        }
    }

    var crew: Job? {
        didSet {
            if crew?.person?.ids == oldValue?.person?.ids { return }
            if let crew = crew {
                cast = nil
                personNameLabel.text = crew.person!.name
                avatarInitialLabel.text = crew.person!.name.initials
                asLabel.text = crew.jobs.joined(separator: ", ")
                avatarImageView.person = crew.person
                hideAdditionalInfo()
            }
        }
    }

    private func updateAdditionalInfo() {
        guard showsEpisodeCount, let episodeCount = cast?.episodeCount else {
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
