//
//  PeopleInfoTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 14/01/2019.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class PeopleInfoTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var mainInfoLabel: UILabel!
    @IBOutlet var secondaryInfoLabel: UILabel!

    @IBOutlet var candleLabel: UILabel!

    private static let heightFormatter: LengthFormatter = {
        let formatter = LengthFormatter()
        formatter.isForPersonHeightUse = true
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.unitStyle = .short
        return formatter
    }()

    var person: Person! {
        didSet {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium

            // Is it the people birthday today
            var happyBirthday = false
            if let birthday = person.birthday, person.death == nil {
                let components1 = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                let components2 = Calendar.current.dateComponents([.year, .month, .day], from: birthday)

                if components1.month == components2.month, components1.day == components2.day {
                    happyBirthday = true
                }
            }

            // Set emoji (dead or happy birthday)
            if person.death != nil {
                candleLabel.text = "🕯"
                candleLabel.isHidden = false
            } else if happyBirthday {
                candleLabel.text = "🥳"
                candleLabel.isHidden = false
            } else {
                candleLabel.isHidden = true
            }

            // Set mainInfoLabel
            // Dead
            if let death = person.death, let birthday = person.birthday {
                let ageComponents = Calendar.current.dateComponents([.year], from: birthday, to: death)
                let relativeDateFormatter = RelativeDateTimeFormatter()
                relativeDateFormatter.unitsStyle = .full
                relativeDateFormatter.dateTimeStyle = .numeric
                relativeDateFormatter.formattingContext = .standalone
                mainInfoLabel.text = "Died at \(ageComponents.year!) years old, \(relativeDateFormatter.localizedString(for: death, relativeTo: Date()))"
                mainInfoLabel.isHidden = false
                // Age
            } else if let birthday = person.birthday {
                let ageComponents = Calendar.current.dateComponents([.year], from: birthday, to: Date())
                mainInfoLabel.text = "\(ageComponents.year!) years old" + (happyBirthday == true ? " today" : "")
                mainInfoLabel.isHidden = false
                // Nothing
            } else {
                mainInfoLabel.isHidden = true
            }

            // Set secondaryInfoLabel
            // both info
            if let birthday = person.birthday, let birthplace = person.birthplace {
                secondaryInfoLabel.text = "Born \(dateFormatter.string(from: birthday)) in \(birthplace)"
                secondaryInfoLabel.isHidden = false
                // birthday only
            } else if let birthday = person.birthday {
                secondaryInfoLabel.text = "Born \(dateFormatter.string(from: birthday))"
                secondaryInfoLabel.isHidden = false
                // birthplace only
            } else if let birthplace = person.birthplace {
                secondaryInfoLabel.text = "Born in \(birthplace)"
                secondaryInfoLabel.isHidden = false
                // nothing
            } else {
                secondaryInfoLabel.isHidden = true
            }

            // Set secondaryInfoLabel
            // additional info if dead
            if let bornText = secondaryInfoLabel.text, let death = person.death {
                secondaryInfoLabel.text = "\(bornText)\nDied \(dateFormatter.string(from: death))"
                secondaryInfoLabel.isHidden = false
                // just the info if dead
            } else if let death = person.death {
                secondaryInfoLabel.text = "Died \(dateFormatter.string(from: death))"
                secondaryInfoLabel.isHidden = false
            }

            if let heightText = PeopleInfoTableViewCell.formattedHeight(fromCentimeters: person.height) {
                if let existingText = secondaryInfoLabel.text, existingText.isEmpty == false {
                    secondaryInfoLabel.text = "\(existingText) · \(heightText)"
                } else {
                    secondaryInfoLabel.text = heightText
                }
                secondaryInfoLabel.isHidden = false
            }

            setNeedsLayout()
            layoutIfNeeded()
        }
    }
}

private extension PeopleInfoTableViewCell {
    static func formattedHeight(fromCentimeters height: Float?) -> String? {
        guard let height = height, height > 0 else { return nil }

        let localizedHeight = heightFormatter.string(fromValue: Double(height), unit: .centimeter)

        return "Height \(localizedHeight)"
    }
}
