//
//  MediaHeaderTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 01/08/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import UIKit

protocol MediaHeaderTableViewCellDelegate: AnyObject {
    func cell(_ cell: MediaHeaderTableViewCell, action: MediaHeaderTableViewCell.Action)
}

final class MediaHeaderTableViewCell: UITableViewCell {

    enum Action {
        case presentEpisodeList
    }

    weak var delegate: MediaHeaderTableViewCellDelegate?

    @IBOutlet weak var title: UILabel!

    @IBOutlet weak var copyButton: UIButton!
    @IBOutlet weak var listButton: UIButton!

    var media: MediaModel! {
        didSet {
            var finalMenuElements = [UIAction]()
            switch self.media! {
            case .movie(let movie):
                var titleElements = [String]()
                titleElements.append("Movie")
                titleElements.append(movie.title)
                if let releaseYear = movie.releaseYear {
                    titleElements.append("\(releaseYear)")
                }
                title.text = titleElements.joined(separator: " · ")

                listButton.isHidden = true

                if let originalTitle = movie.originalTitle, movie.officialTitle != originalTitle {
                    let fullTitle = "\(movie.officialTitle)\((movie.releaseYear != nil) ? " \(movie.releaseYear!)" : "")"
                    finalMenuElements.append(UIAction(title: originalTitle,
                                                      handler: { _ in
                        UIPasteboard.general.string = originalTitle
                    }))
                    finalMenuElements.append(UIAction(title: movie.officialTitle,
                                                      handler: { _ in
                        UIPasteboard.general.string = movie.officialTitle
                    }))
                    finalMenuElements.append(UIAction(title: fullTitle,
                                                      handler: { _ in
                        UIPasteboard.general.string = fullTitle
                    }))
                    finalMenuElements.append(UIAction(title: fullTitle.slugify(),
                                                      handler: { _ in
                        UIPasteboard.general.string = fullTitle.slugify()
                    }))
                    finalMenuElements.append(UIAction(title: movie.officialTitle.hashtagify(),
                                                      handler: { _ in
                        UIPasteboard.general.string = movie.officialTitle.hashtagify()
                    }))
                } else {
                    let fullTitle = self.media!.mediaTitle
                    finalMenuElements.append(UIAction(title: movie.title,
                                                      handler: { _ in
                        UIPasteboard.general.string = movie.title
                    }))
                    finalMenuElements.append(UIAction(title: fullTitle,
                                                      handler: { _ in
                        UIPasteboard.general.string = fullTitle
                    }))
                    finalMenuElements.append(UIAction(title: fullTitle.slugify(),
                                                      handler: { _ in
                        UIPasteboard.general.string = fullTitle.slugify()
                    }))
                    finalMenuElements.append(UIAction(title: movie.title.hashtagify(),
                                                      handler: { _ in
                        UIPasteboard.general.string = movie.title.hashtagify()
                    }))
                }
            case .show(let show):
                var titleElements = [String]()
                titleElements.append("Show")
                titleElements.append(show.title)
                if let releaseYear = show.releaseYear {
                    titleElements.append("\(releaseYear)")
                }
                title.text = titleElements.joined(separator: " · ")

                if let originalTitle = show.originalTitle, show.officialTitle != originalTitle {
                    let fullTitle = "\(show.officialTitle)\((show.releaseYear != nil) ? " \(show.releaseYear!)" : "")"
                    finalMenuElements.append(UIAction(title: originalTitle,
                                                      handler: { _ in
                        UIPasteboard.general.string = originalTitle
                    }))
                    finalMenuElements.append(UIAction(title: show.officialTitle,
                                                      handler: { _ in
                        UIPasteboard.general.string = show.officialTitle
                    }))
                    finalMenuElements.append(UIAction(title: fullTitle,
                                                      handler: { _ in
                        UIPasteboard.general.string = fullTitle
                    }))
                    finalMenuElements.append(UIAction(title: fullTitle.slugify(),
                                                      handler: { _ in
                        UIPasteboard.general.string = fullTitle.slugify()
                    }))
                    finalMenuElements.append(UIAction(title: show.officialTitle.hashtagify(),
                                                      handler: { _ in
                        UIPasteboard.general.string = show.officialTitle.hashtagify()
                    }))
                } else {
                    let fullTitle = self.media!.mediaTitle
                    finalMenuElements.append(UIAction(title: show.title,
                                                      handler: { _ in
                        UIPasteboard.general.string = show.title
                    }))
                    finalMenuElements.append(UIAction(title: fullTitle,
                                                      handler: { _ in
                        UIPasteboard.general.string = fullTitle
                    }))
                    finalMenuElements.append(UIAction(title: fullTitle.slugify(),
                                                      handler: { _ in
                        UIPasteboard.general.string = fullTitle.slugify()
                    }))
                    finalMenuElements.append(UIAction(title: show.title.hashtagify(),
                                                      handler: { _ in
                        UIPasteboard.general.string = show.title.hashtagify()
                    }))
                }
            case .episode(let episode, let show):
                var titleElements = [String]()
                titleElements.append("Episode")
                titleElements.append(show.title)
                titleElements.append(episode.localizedEpisodeNumber)
                title.text = titleElements.joined(separator: " · ")

                let fullTitle = self.media!.mediaTitle
                finalMenuElements.append(UIAction(title: show.title,
                                                  handler: { _ in
                    UIPasteboard.general.string = show.title
                }))
                if let episodeTitle = episode.title {
                    finalMenuElements.append(UIAction(title: "\(show.title) \(episodeTitle)",
                                                      handler: { _ in
                        UIPasteboard.general.string = "\(show.title) \(episodeTitle)"
                    }))
                }
                finalMenuElements.append(UIAction(title: fullTitle,
                                                  handler: { _ in
                    UIPasteboard.general.string = fullTitle
                }))
                finalMenuElements.append(UIAction(title: fullTitle.slugify(),
                                                  handler: { _ in
                    UIPasteboard.general.string = fullTitle.slugify()
                }))
                finalMenuElements.append(UIAction(title: fullTitle.hashtagify(),
                                                  handler: { _ in
                    UIPasteboard.general.string = fullTitle.hashtagify()
                }))
            case .season(let season, let show):
                var titleElements = [String]()
                titleElements.append("Season")
                titleElements.append(show.title)
                titleElements.append(season.title ?? "\(season.localizedSeasonNumber)")
                title.text = titleElements.joined(separator: " · ")

                let fullTitle = self.media!.mediaTitle
                if let title = season.title {
                    finalMenuElements.append(UIAction(title: "\(show.title) \(title)",
                                                      handler: { _ in
                        UIPasteboard.general.string = show.title
                    }))
                }
                finalMenuElements.append(UIAction(title: fullTitle,
                                                  handler: { _ in
                    UIPasteboard.general.string = fullTitle
                }))
                finalMenuElements.append(UIAction(title: fullTitle.slugify(),
                                                  handler: { _ in
                    UIPasteboard.general.string = fullTitle.slugify()
                }))
                finalMenuElements.append(UIAction(title: fullTitle.hashtagify(),
                                                  handler: { _ in
                    UIPasteboard.general.string = fullTitle.hashtagify()
                }))
            case .list:
                break
            case .showProgress:
                break
            }

            copyButton.showsMenuAsPrimaryAction = true
            copyButton.menu = UIMenu(title: "Copy Text", options: .displayInline, children: finalMenuElements)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        title.font = title.font.bold()

        copyButton.tintColor = .secondaryLabel
        listButton.tintColor = .secondaryLabel
    }

    @IBAction func listButtonTouchedUpInside(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .presentEpisodeList)
    }
}
