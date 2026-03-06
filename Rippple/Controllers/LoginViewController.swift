//
//  LoginViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import UIKit

import Haring

import SafariServices

import Receiver

final class LoginViewController: UIViewController {

    @IBOutlet weak var footerLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var headerLabel: UILabel!

    @IBOutlet weak var loginButton: UIButton!

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        configureHeader()
        configureFooter()

        subtitleLabel.textColor = UIColor(asset: .globalTint)

        loginButton.tintColor = UIColor(asset: .safeGlobalTint)
        loginButton.configuration = .prominentGlass()

        onSettingsChangedReceiver.listen { _ in
            if SessionManager.shared.isLoggedIn, UserManager.shared.currentUser != nil {
                DispatchQueue.main.async {
                    UIApplication.shared.switchToMainApp()
                }
            }
        }.disposed(by: disposeBag)
    }

    private func configureHeader() {
        let markdownParser = MarkdownParser(font: UIFont(name: "HelveticaNeue-Bold", size: 29)!,
                                            color: .label,
                            automaticLinkDetectionEnabled: false)
        markdownParser.bold.color = UIColor(asset: .globalTint)
        markdownParser.bold.font = UIFont(name: "HelveticaNeue-Bold", size: 29)!
        let markdown = """
Track.
Discover.
Share.
Everywhere__*__
"""
        headerLabel.attributedText = markdownParser.parse(markdown)

        title = ""
    }

    private func configureFooter() {
        let markdownParser = MarkdownParser(font: UIFont.preferredFont(forTextStyle: .caption1),
                                            color: .secondaryLabel,
                            automaticLinkDetectionEnabled: false)
                markdownParser.bold.color = UIColor(asset: .globalTint)
                markdownParser.bold.font = UIFont.preferredFont(forTextStyle: .caption1)
                let markdown = """
        __*__ Rippple is a Trakt client available on iPhone, iPad and Mac. Sign in to your Trakt account to track, discover and share with the community.
        When signed in, enjoy a lot of Rippple's features for free. Then, unlock additional Premium features with a subscription. Or not.
        Don't hesitate to check our **Privacy Policy**.
        """
                footerLabel.attributedText = markdownParser.parse(markdown)
    }

    @IBAction func privacyAndTerms(_ sender: Any) {
        if let url = URL(string: "https://github.com/trakt/trakt-rippple/blob/main/PRIVACY.md"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    @IBAction func help(_ sender: Any) {
        if let url = URL(string: "https://github.com/trakt/trakt-rippple/blob/main/docs/RIPPPLE_101.md"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    @IBAction func loginToTrakt(_ sender: UIButton) {
        sender.isEnabled = false
        SessionManager.shared.initiateTraktLogin { [weak self] (isLoggedIn) in
            guard let self = self else { return }

            defer {
                DispatchQueue.main.async {
                    sender.isEnabled = true
                }
            }

            if isLoggedIn {
                // do nothing (onSettingsChangedReceiver will kick things off)
            } else {
                #if targetEnvironment(macCatalyst)
                let alertController = UIAlertController(title: "Login Failed",
                                                        message: "Something went wrong so we couldn't log you in. Please try again. If nothing happened, restarting Safari can help.",
                                                        preferredStyle: .alert)
                #else
                let alertController = UIAlertController(title: "Login Failed",
                                                        message: "Something went wrong so we couldn't log you in. Please try again.",
                                                        preferredStyle: .alert)
                #endif
                let cancelAction = UIAlertAction(title: "Ok", style: .cancel)
                alertController.addAction(cancelAction)

                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
}
