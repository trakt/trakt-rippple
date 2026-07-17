//
//  ShelfConfigViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 02/09/2024.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import UIKit

final class ShelfConfigViewController: RipppleHostingController<ShelfConfigView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: ShelfConfigView())
    }
}
