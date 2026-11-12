//
//  PurchaseModalViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 09/09/2022.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class PurchaseModalViewController: UIViewController {
    var benefit: VIPBenefit?

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let purchaseViewController = segue.destination as? PurchaseViewController {
            purchaseViewController.benefit = benefit
        }
    }

    @IBAction func done(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
