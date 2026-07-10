//
//  ToWatchStoryCollectionViewCell.swift
//  ToWatchStoryCollectionViewCell
//
//  Created by Kevin Cador on 20/07/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import UIKit

final class ToWatchStoryCollectionViewCell: UICollectionViewCell {
    @IBOutlet var days: UILabel!
    @IBOutlet var poster: PosterImageView!

    private let dateFormatter = DateFormatter()
    func updateLabel() {
        switch media! {
        case .movie(let movie):
            let releaseDate = dateFormatter.date(from: movie.released ?? "") ?? Date()
            updateDateLabel(for: releaseDate)
        case .show:
            fatalError()
        case .episode(let episode, _):
            if let firstAired = episode.firstAired {
                updateDateLabel(for: firstAired, showsFinaleFlag: episode.isBingeableFinale)
            }
        case .season:
            fatalError()
        case .list:
            fatalError()
        case .showProgress(_, let showProgress):
            if let nextToWatch = showProgress.nextEpisodeToWatch, let firstAired = nextToWatch.firstAired {
                updateDateLabel(for: firstAired, showsFinaleFlag: nextToWatch.isBingeableFinale)
            }
        }
    }

    private func updateDateLabel(for date: Date, showsFinaleFlag: Bool = false) {
        let relativeDate = CalendarRelativeDateFormatter.string(for: date, unitsStyle: .short)
        guard showsFinaleFlag else {
            days.text = relativeDate
            days.accessibilityLabel = nil
            return
        }

        let symbolFont = days.font.withSize(days.font.pointSize * 0.8)
        let configuration = UIImage.SymbolConfiguration(font: symbolFont)
        guard let symbol = UIImage(systemName: "flag.fill", withConfiguration: configuration) else {
            days.text = relativeDate
            days.accessibilityLabel = nil
            return
        }

        let attachment = NSTextAttachment()
        attachment.image = symbol.withTintColor(days.textColor, renderingMode: .alwaysOriginal)
        attachment.bounds = CGRect(x: 0,
                                   y: (days.font.capHeight - symbol.size.height) / 2,
                                   width: symbol.size.width,
                                   height: symbol.size.height)

        let value = NSMutableAttributedString(attachment: attachment)
        value.append(NSAttributedString(string: " \(relativeDate)",
                                        attributes: [.font: days.font as Any,
                                                     .foregroundColor: days.textColor as Any]))
        days.attributedText = value
        days.accessibilityLabel = "Finale, \(relativeDate)"
    }

    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie(let movie):
                poster.movie = movie
                updateLabel()
            case .show:
                fatalError()
            case .episode(_, let show):
                poster.show = show
                updateLabel()
            case .season:
                fatalError()
            case .list:
                fatalError()
            case .showProgress(let show, _):
                poster.show = show
                updateLabel()
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        poster.layer.cornerRadius = ViewRadius.medium.rawValue
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.layer.borderWidth = 1
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        poster.backgroundColor = UIColor.tertiarySystemFill

        dateFormatter.dateFormat = "yyyy-MM-dd"

        maximumContentSizeCategory = .large
    }
}
