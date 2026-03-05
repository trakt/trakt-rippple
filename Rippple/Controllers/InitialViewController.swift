//
//  InitialViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 02/12/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import UIKit

import NVActivityIndicatorView
import Receiver

final class InitialViewController: UIViewController {

    @IBOutlet weak var loadingAnimationContainer: NVActivityIndicatorView!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppManager.shared.setup()
        loadingAnimationContainer.tintColor = UIColor(asset: .globalTint)
        loadingAnimationContainer.startAnimating()
    }

    private var disposable: Disposable?

    deinit {
        disposable?.dispose()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if SessionManager.shared.isLoggedIn {
            UIApplication.shared.switchToMainApp()
        } else {
            UIApplication.shared.switchToLogin()
        }
    }
}
