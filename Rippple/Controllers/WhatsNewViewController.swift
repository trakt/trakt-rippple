//
//  WhatsNewViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 14/02/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import UIKit

import WebKit

final class WhatsNewViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.backgroundColor = .white

        title = "What's New?"

        if let url = URL(string: "https://headwayapp.co/rippple-updates") {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done",
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(done))
    }

    @objc func done() {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func review(_ sender: Any) {
        if let url = URL(string: "macappstore://apps.apple.com/app/id6758765611?action=write-review"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "itms-apps://apps.apple.com/app/id6758765611?action=write-review"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "https://apps.apple.com/app/id6758765611?action=write-review"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
