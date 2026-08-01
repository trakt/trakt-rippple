//
//  CountryWhereToWatchTableViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 05/02/2021.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import UIKit

final class CountryWhereToWatchTableViewController: RipppleHostingController<WhereToWatchSettingsView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: WhereToWatchSettingsView())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if navigationController!.viewControllers.first!.isKind(of: DeeplinkLoadingViewController.self) {
            navigationController?.setViewControllers([self], animated: false)
            navigationItem.leftBarButtonItems = [UIBarButtonItem(title: "Done",
                                                                 style: .plain,
                                                                 target: self,
                                                                 action: #selector(deeplinkDone))]
        }
    }
}

extension CountryWhereToWatchTableViewController {
    @objc func deeplinkDone() {
        dismiss(animated: true, completion: nil)
    }
}
