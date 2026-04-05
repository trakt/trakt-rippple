//
//  ServicesBrowseTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 12/08/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

private struct Service {
    var logoName: String

    var filter: SavedFilter
}

class ServicesBrowseTableViewCell: UITableViewCell {
    @IBOutlet weak var collectionView: UICollectionView!

    weak var presentingViewController: UIViewController?

    private let items: [Service] = [Service(logoName: "Netflix",
                                            filter: SavedFilter(section: "search",
                                                                name: "On Netflix",
                                                                path: "/search/movie,show",
                                                                query: "watchnow=netflix",
                                                                limit: nil)),
                                    Service(logoName: "Disney+",
                                            filter: SavedFilter(section: "search",
                                                                name: "On Disney+",
                                                                path: "/search/movie,show",
                                                                query: "watchnow=disney_plus",
                                                                limit: nil)),
                                    Service(logoName: "Prime Video",
                                            filter: SavedFilter(section: "search",
                                                                name: "On Prime Video",
                                                                path: "/search/movie,show",
                                                                query: "watchnow=amazon_prime_video",
                                                                limit: nil)),
                                    Service(logoName: "Apple TV+",
                                            filter: SavedFilter(section: "search",
                                                                name: "On Apple TV",
                                                                path: "/search/movie,show",
                                                                query: "watchnow=apple_tv_plus",
                                                                limit: nil)),
                                    Service(logoName: "Max",
                                            filter: SavedFilter(section: "search",
                                                                name: "On HBO Max",
                                                                path: "/search/movie,show",
                                                                query: "watchnow=hbo_max",
                                                                limit: nil)),
                                    Service(logoName: "Paramount+",
                                            filter: SavedFilter(section: "search",
                                                                name: "On Paramount+",
                                                                path: "/search/movie,show",
                                                                query: "watchnow=paramountplusessential,paramount_plus_premium",
                                                                limit: nil)),
                                    Service(logoName: "Hulu",
                                            filter: SavedFilter(section: "search",
                                                                name: "On Hulu",
                                                                path: "/search/movie,show",
                                                                query: "watchnow=us-hulu",
                                                                limit: nil))]

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.allowsFocus = false
        collectionView.delegate = self

        collectionView.register(UINib(nibName: "ServiceBrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "cell")
    }
}

extension ServicesBrowseTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ServiceBrowseCollectionViewCell

        let item = items[indexPath.row]
        cell.logoImageView.image = UIImage(named: item.logoName)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let presentingViewController = presentingViewController else {
            return
        }

        presentingViewController.performSegue(withIdentifier: "browse", sender: items[indexPath.row].filter)
    }
}
