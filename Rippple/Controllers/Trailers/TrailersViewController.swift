//
//  TrailersViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 29/11/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import UIKit
import SwiftUI

final class TrailersViewController: UIViewController {

    var media: MediaModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Videos"

        guard let media = media else { return }

        let hostingViewController = UIHostingController(rootView: TrailersView(mediaModel: media))
        addChild(hostingViewController)
        hostingViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingViewController.view)
        hostingViewController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostingViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
