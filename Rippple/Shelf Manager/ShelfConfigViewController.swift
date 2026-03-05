//
//  ShelfConfigViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 02/09/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import UIKit
import SwiftUI

final class ShelfConfigViewController: UIHostingController<ShelfConfigView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: ShelfConfigView())
    }
}
