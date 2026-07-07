//
//  LoginBrowseViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 19/04/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import Receiver
import UIKit

let (onNeedsToShowLoginTransmitter, onNeedsToShowLoginReceiver) = Receiver<Bool>.make(with: .hot)

final class LoginBrowseViewController: UIViewController {
    private let disposeBag = DisposeBag()

    @IBOutlet var loginButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Preview"

        loginButton.configuration?.title = "Start Tracking →"

        loginButton.tintColor = UIColor(asset: .safeGlobalTint)
        loginButton.configuration = .prominentGlass()

        onNeedsToShowLoginReceiver.listen { [weak self] needToShow in
            guard let self = self else { return }
            if needToShow {
                DispatchQueue.main.async {
                    self.presentedViewController?.dismiss(animated: true)
                    self.performSegue(withIdentifier: "login", sender: nil)
                }
            }
        }.disposed(by: disposeBag)
    }
}
