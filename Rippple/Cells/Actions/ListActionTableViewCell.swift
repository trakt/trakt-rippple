//
//  ListActionTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 13/12/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

final class ListActionTableViewCell: UITableViewCell {

    private var fetchTask: _Concurrency.Task<Void, Never>?

    public var isLoading = false
    public var isInList = false

    public var media: MediaModel?

    @IBOutlet var card: CardView!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet weak var accessoryIndicator: UIImageView!

    @IBOutlet weak var privacyImageView: UIImageView!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            titleLabel.alpha = 0.8
        } else {
            titleLabel.alpha = 1.0
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            titleLabel.alpha = 0.8
        } else {
            titleLabel.alpha = 1.0
        }
    }

    public var list: List? {
        didSet {
            guard let list = list else { return }
            if list != oldValue {
                titleLabel.text = "Loading..."
                accessoryIndicator.image = UIImage(systemName: "circle.dotted")
            }

            switch list.privacy {
            case .all:
                privacyImageView.image = UIImage(systemName: "globe")
            case .me:
                privacyImageView.image = UIImage(systemName: "lock.fill")
            case .friends:
                privacyImageView.image = UIImage(systemName: "lock.open.fill")
            case .link:
                privacyImageView.image = UIImage(systemName: "link")
            case .unknown:
                privacyImageView.image = UIImage()
            }
            checkMediaInList()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        fetchTask?.cancel()
        fetchTask = nil
    }

    private var listItemsType: ListMediaType? {
        guard let media = media else { return nil }
        switch media {
        case .movie:
            return .movies
        case .show:
            return .shows
        case .episode:
            return .episodes
        case .season:
            return .seasons
        case .list:
            return nil
        case .showProgress:
            fatalError()
        }
    }

    private func checkMediaInList() {
        guard let media = media else { return }
        guard let list = list else { return }

        if SessionManager.shared.isLoggedOut { return }

        fetchTask?.cancel()

        isLoading = true

        let listItemsType = self.listItemsType
        fetchTask = _Concurrency.Task { [weak self] in
            guard let self = self else { return }
            do {
                let results = try await TraktAPIProvider.fetchAllListItems(slug: list.user.identifiers.slug,
                                                                           id: list.identifiers.trakt!,
                                                                           type: listItemsType,
                                                                           extended: nil)
                if _Concurrency.Task.isCancelled { return }

                var inList = false
                for item in results {
                    if let movie = media.movie {
                        if movie.identifiers.trakt! == item.movie?.identifiers.trakt {
                            inList = true
                            break
                        }
                    }
                    if let episode = media.episodeEpisode {
                        if episode.identifiers.trakt! == item.episode?.identifiers.trakt {
                            inList = true
                            break
                        }
                    }
                    if let season = media.season {
                        if season.identifiers.trakt! == item.season?.identifiers.trakt {
                            inList = true
                            break
                        }
                    }
                    if let show = media.showShow {
                        if show.identifiers.trakt! == item.show?.identifiers.trakt {
                            inList = true
                            break
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isInList = inList
                    if inList {
                        self.accessoryIndicator.image = UIImage(systemName: "checkmark.circle.fill")
                    } else {
                        self.accessoryIndicator.image = UIImage(systemName: "circle")
                    }
                    self.titleLabel.text = self.list?.name.emojiUnescapedString
                    self.titleLabel.textColor = .label
                }
            } catch {
                if _Concurrency.Task.isCancelled { return }
                DispatchQueue.main.async {
                    print("List items request failure \(error)")
                    self.isLoading = false
                }
            }
        }
    }
}
