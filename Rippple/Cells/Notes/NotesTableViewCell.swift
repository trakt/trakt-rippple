//
//  NotesTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/09/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Foundation

import Receiver

protocol NotesTableViewCellDelegate: AnyObject {
    func cell(_ cell: NotesTableViewCell, action: NotesTableViewCell.Action)
}

final class NotesTableViewCell: UITableViewCell {

    enum Action {
        case media(MediaModel)
        case person(Person)
    }

    weak var delegate: NotesTableViewCellDelegate?

    @IBOutlet weak var metadata: UILabel!
    @IBOutlet weak var notes: NotesLabel!

    @IBOutlet weak var contentPoster: PosterImageView!
    @IBOutlet weak var contentShot: PeopleProfileImageView!
    @IBOutlet weak var contentTitle: UILabel!
    @IBOutlet weak var contentSubtitle: UILabel!

    private let disposeBag = DisposeBag()

    var noteItem: NoteItem! {
        didSet {
            notes.noteItem = noteItem
            switch noteItem.noteAttachement.type {
            case .movie:
                metadata.text = "Movie Notes"
                media = MediaModel(item: noteItem)
            case .show:
                metadata.text = "Show Notes"
                media = MediaModel(item: noteItem)
            case .season:
                metadata.text = "Season Notes"
                media = MediaModel(item: noteItem)
            case .episode:
                metadata.text = "Episode Notes"
                media = MediaModel(item: noteItem)
            case .person:
                metadata.text = "People Notes"
                person = noteItem.person!
            case .history:
                metadata.text = "History Notes"
                media = MediaModel(item: noteItem)
            case .collection:
                metadata.text = "Library Notes"
                media = MediaModel(item: noteItem)
            case .rating:
                let media = MediaModel(item: noteItem)
                if let userRating = media?.userRating {
                    metadata.text = "Rating Notes - \(userRating)/10"
                } else {
                    metadata.text = "Rating Notes"
                }
                self.media = media
            case .unknown:
                metadata.text = "Unknown Notes"
            }
            switch noteItem.note.privacy {
            case .all:
                metadata.text = metadata.text! + " - Public"
            case .friends:
                metadata.text = metadata.text! + " - Friends"
            case .me:
                metadata.text = metadata.text! + " - Private"
            case .unknown:
                metadata.text = metadata.text!
            }
            if noteItem.note.spoiler {
                metadata.text = metadata.text! + " - Spoiler Alert!"
            }
        }
    }

    private var person: Person? {
        didSet {
            guard let person = person else { return }
            contentShot.person = person
            contentTitle.text = person.name
            contentSubtitle.text = ""
            contentShot.isHidden = false
        }
    }

    private var media: MediaModel? {
        didSet {
            switch media {
            case .movie(let movie):
                contentTitle.text = movie.title
                var info = [String]()
                if let release = movie.releaseYear {
                    info.append("\(release)")
                }
                if let status = movie.status, status != "released" {
                    info.append(status)
                }
                contentSubtitle.text = info.joined(separator: " · ")

                contentPoster.movie = movie
            case .show(let show):
                contentTitle.text = show.title
                var info = [String]()
                if let airedEpisodes = show.airedEpisodes, airedEpisodes != 0 {
                    info.append("\(airedEpisodes) episode\((airedEpisodes > 1 ? "s" : ""))")
                } else if let release = show.releaseYear {
                    info.append("\(release)")
                }
                if let status = show.status, status != "returning series" {
                    info.append(status)
                }
                contentSubtitle.text = info.joined(separator: " · ")

                contentPoster.show = show
            case .episode(let episode, let show):
                contentTitle.text = show.title
                contentSubtitle.text = episode.localizedEpisodeNumber

                contentPoster.show = show
            case .season(let season, let show):
                contentTitle.text = show.title
                if let seasonTitle = season.title {
                    contentSubtitle.text = seasonTitle
                } else if season.number > 0 {
                    contentSubtitle.text = "Season \(season.number)"
                } else {
                    contentSubtitle.text = "A Season"
                }

                contentPoster.show = show
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            case nil:
                fatalError()
            }
            contentShot.isHidden = true
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentPoster.layer.cornerRadius = contentPoster.bounds.size.height/2.0
        contentPoster.layer.cornerCurve = .circular
        contentPoster.layer.masksToBounds = true
        contentPoster.layer.borderWidth = 1
        contentPoster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        contentShot.layer.cornerRadius = contentShot.bounds.size.height/2.0
        contentShot.layer.cornerCurve = .circular
        contentShot.layer.masksToBounds = true
        contentShot.layer.borderWidth = 1
        contentShot.layer.borderColor = UIColor.tertiarySystemFill.cgColor
    }

    @IBAction func mediaAreaTouched(_ sender: Any) {
        guard let delegate = delegate else { return }
        if let media = media {
            delegate.cell(self, action: .media(media))
        } else if let person = person {
            delegate.cell(self, action: .person(person))
        }
    }
}
