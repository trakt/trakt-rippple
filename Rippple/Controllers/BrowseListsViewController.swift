//
//  BrowseListsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class BrowseListsViewController: UIViewController {
    enum Category: String, CaseIterable {
        case trending = "Trending"
        case popular = "Popular"
        case official = "Official"

        var service: TraktAPIService {
            switch self {
            case .trending: return .trendingLists(type: .personal)
            case .popular: return .popularLists(type: .personal)
            case .official: return .popularLists(type: .official)
            }
        }
    }

    var category: Category = .trending

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "\(category.rawValue) Lists"
        navigationItem.style = .browser
        navigationItem.subtitle = "Loading..."
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .ripppleViewBackground

        guard let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ListSearchResultsViewController") as? ListSearchResultsViewController else { return }
        controller.service = category.service
        controller.allowsLoggedOutRequests = true
        controller.onSubtitleChanged = { [weak self] subtitle in
            guard let self = self else { return }
            self.navigationItem.subtitle = subtitle
        }

        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
    }
}
