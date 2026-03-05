//
//  GenresBrowseTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 04/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

class GenresBrowseTableViewCell: UITableViewCell {
    @IBOutlet weak var collectionView: UICollectionView!

    weak var presentingViewController: UIViewController?

    private var items = [Genre]() {
        didSet {
            collectionView.reloadData()
        }
    }

    public var service: TraktAPIService? {
        didSet {
            TraktAPIProvider.provider.request(service ?? .movieGenres, callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let genres = try response.map([Genre].self, using: TraktAPIProvider.decoder).filter { $0.slug != "none" }

                        DispatchQueue.main.async {
                            self.items = genres
                        }
                    } catch {
                        print("Error Fetching Genres \(error)")
                    }
                case let .failure(error):
                    print("Error Fetching Genres \(error)")
                }
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.allowsFocus = false
        collectionView.delegate = self

        collectionView.register(UINib(nibName: "GenreBrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "cell")
    }
}

extension GenresBrowseTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! GenreBrowseCollectionViewCell

        cell.label?.text = items[indexPath.row].name
        cell.emoji?.text = items[indexPath.row].emoji

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let presentingViewController = presentingViewController else {
            return
        }

        if service?.path.localizedStandardContains("shows") ?? false {
            presentingViewController.performSegue(withIdentifier: "browse", sender: items[indexPath.row].showsSavedFilter)
        } else {
            presentingViewController.performSegue(withIdentifier: "browse", sender: items[indexPath.row].moviesSavedFilter)
        }
    }
}

extension Genre {
    var moviesSavedFilter: SavedFilter {
        return SavedFilter(section: "search", name: "\(name)", path: "/search/movie", query: "genres=+\(slug)", limit: 100)
    }

    var showsSavedFilter: SavedFilter {
        return SavedFilter(section: "search", name: "\(name)", path: "/search/show", query: "genres=+\(slug)", limit: 100)
    }

    var emoji: String {
        switch slug {
        case "action": return "💥"
        case "adventure": return "⚔️"
        case "animation": return "🐰"
        case "anime": return "🍱"
        case "comedy": return "😂"
        case "crime": return "🔎"
        case "disaster": return "🌪️"
        case "documentary": return "🗂️"
        case "donghua": return "🐉"
        case "drama": return "🎭"
        case "eastern": return "🏯"
        case "family": return "👨‍👩‍👧‍👦"
        case "fan-film": return "📹"
        case "fantasy": return "🧚"
        case "film-noir": return "🌃"
        case "history": return "🏛️"
        case "holiday": return "🎄"
        case "horror": return "🧟‍♂️"
        case "indie": return "🎥"
        case "music": return "🎵"
        case "musical": return "🎶"
        case "mystery": return "🕵️‍♂️"
        case "none": return "❌"
        case "road": return "🛣️"
        case "romance": return "❤️"
        case "science-fiction": return "🚀"
        case "short": return "🎞️"
        case "sports": return "⚽"
        case "sporting-event": return "🏆"
        case "suspense": return "😱"
        case "thriller": return "🩸"
        case "tv-movie": return "📺"
        case "war": return "🫡"
        case "western": return "🌵"
        case "superhero": return "🦸‍♂️"
        case "biography": return "✍️"
        case "children": return "🛝"
        case "game-show": return "🎯"
        case "mini-series": return "1️⃣"
        case "news": return "📰"
        case "reality": return "💊"
        case "soap": return "🧼"
        case "talk-show": return "🎙️"
        case "home-and-garden": return "🏡"
        case "special-interest": return "🧐"
        default: return ""
        }
    }
}
