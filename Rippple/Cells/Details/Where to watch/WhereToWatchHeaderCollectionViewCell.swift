//
//  WhereToWatchHeaderCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 29/01/2021.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class WhereToWatchHeaderCollectionViewCell: UICollectionViewCell {
    @IBOutlet var info: UILabel!
    @IBOutlet var button: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()

        button.addAction(UIAction(handler: { _ in
            DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://settings/wheretowatch")!)
            if SessionManager.shared.isLoggedIn,
               DeeplinkManager.shared.shouldOpenDeeplink() {
                UIApplication.shared.switchToDeeplink()
            }
        }), for: .touchUpInside)
    }
}
