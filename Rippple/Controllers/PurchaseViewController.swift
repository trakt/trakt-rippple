//
//  PurchaseViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 26/12/2017.
//  Copyright © Trakt. All rights reserved.
//

import Haring
import Receiver
import SafariServices
import StoreKit
import SwiftUI
import UIKit

final class PurchaseViewController: UIViewController {
    private let disposeBag = DisposeBag()

    @IBOutlet var purchaseButton: UIButton!

    private lazy var productManager = ProductManager.shared
    private lazy var purchaseManager = PurchaseManager.shared

    @IBOutlet var purchaseStackView: UIStackView?

    override func viewDidLoad() {
        super.viewDidLoad()

        if productManager.monthlySubscription == nil {
            productManager.reloadProducts()
        }

        productManager.onProductChangedReceiver.listen { [weak self] state in
            guard let self = self else { return }
            guard let purchaseButton = self.purchaseButton else { return }
            switch state {
            case .loading:
                purchaseButton.setAttributedTitle("Loading...".attributedString, for: .normal)
                purchaseButton.isUserInteractionEnabled = false
            case .error:
                purchaseButton.setAttributedTitle("Try Again".attributedString, for: .normal)
                purchaseButton.isUserInteractionEnabled = true
            case .content:
                purchaseButton.setAttributedTitle(self.subscriptionAttributedTitle, for: .normal)
                purchaseButton.isUserInteractionEnabled = true
            }
        }.disposed(by: disposeBag)

        PurchaseManager.shared.onPurchasedChangedReceiver.skipRepeats().hotOnly().listen { [weak self] purchased in
            DispatchQueue.main.async {
                if purchased == false { return }
                guard let self = self else { return }
                let viewController = self.navigationController?.viewControllers.last
                self.navigationController?.popViewController(animated: true)
                // if last is first, dismiss because it means we are in a modal
                if self.navigationController?.viewControllers.first == viewController {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }.disposed(by: disposeBag)

        let purchaseWhyView = PurchaseWhyView {
            self.purchaseStackView?.arrangedSubviews[1].setNeedsLayout()
            self.purchaseStackView?.arrangedSubviews[1].layoutIfNeeded()
            self.purchaseStackView?.arrangedSubviews[1].invalidateIntrinsicContentSize()
        }
        let hostingController = RipppleHostingController(rootView: purchaseWhyView)
        addChild(hostingController)
        purchaseStackView?.insertArrangedSubview(hostingController.view, at: 1)
        hostingController.didMove(toParent: self)
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        configureHeader()
    }

    @IBOutlet var headerLabel: UILabel!
    private func configureHeader() {
        let markdownParser = MarkdownParser(font: UIFont.preferredFont(forTextStyle: .title2),
                                            color: .label,
                                            automaticLinkDetectionEnabled: false)
        markdownParser.bold.color = UIColor(asset: .globalTint)
        let markdown = """
        Unlock more with **Trakt VIP**.
        VIP supports Trakt, unlocks powerful features, and higher limits for people who care about what they watch.
        """
        headerLabel?.attributedText = markdownParser.parse(markdown)
    }

    @IBAction func terms(_ sender: Any) {
        if let url = URL(string: "https://github.com/trakt/trakt-rippple/blob/main/TERMS.md"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    @IBAction func privacy(_ sender: Any) {
        if let url = URL(string: "https://github.com/trakt/trakt-rippple/blob/main/PRIVACY.md"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    @IBAction func subscribe(_ sender: Any) {
        if productManager.monthlySubscription == nil {
            var preferredStyle = UIAlertController.Style.alert
            if traitCollection.userInterfaceIdiom == .phone {
                preferredStyle = .actionSheet
            }
            let alertController = UIAlertController(title: "Something went wrong",
                                                    message: "Rippple couldn't get the product information on the App Store. Please check your internet connection, your App Store account, and try again.",
                                                    preferredStyle: preferredStyle)

            let retry = UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.productManager.reloadProducts()
            }
            alertController.addAction(retry)

            alertController.popoverPresentationController?.sourceView = purchaseButton

            present(alertController, animated: true)
        } else {
            let hostingController = RipppleHostingController(rootView: PurchaseConfirmationView())
            present(hostingController, animated: true)
        }
    }

    @IBAction func profile(_ sender: Any) {
        guard let profileViewController = UIStoryboard(name: "Profile", bundle: nil).instantiateInitialViewController() else { return }
        view.window?.rootViewController?.present(profileViewController, animated: true, completion: nil)
    }

    var subscriptionAttributedTitle: NSAttributedString {
        let string = "Upgrade to VIP\nGet the full Trakt experience"
        let attributedString = NSMutableAttributedString(string: string)

        let font = UIFont.boldSystemFont(ofSize: 16.0)
        let smallFont = UIFont.systemFont(ofSize: 11.0)

        attributedString.addAttribute(kCTFontAttributeName as NSAttributedString.Key,
                                      value: font,
                                      range: NSRange(location: 0, length: 14))

        attributedString.addAttribute(kCTFontAttributeName as NSAttributedString.Key,
                                      value: smallFont,
                                      range: NSRange(location: 14, length: string.count - 14))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.lineHeightMultiple = 0
        paragraphStyle.alignment = .center

        attributedString.addAttribute(kCTParagraphStyleAttributeName as NSAttributedString.Key,
                                      value: paragraphStyle,
                                      range: NSRange(location: 0, length: string.count))

        return attributedString
    }
}

private extension String {
    var attributedString: NSAttributedString {
        let attributedString = NSMutableAttributedString(string: self)

        let font = UIFont.boldSystemFont(ofSize: 16.0)

        attributedString.addAttribute(kCTFontAttributeName as NSAttributedString.Key,
                                      value: font,
                                      range: NSRange(location: 0, length: count))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        attributedString.addAttribute(kCTParagraphStyleAttributeName as NSAttributedString.Key,
                                      value: paragraphStyle,
                                      range: NSRange(location: 0, length: count))

        return attributedString
    }
}
