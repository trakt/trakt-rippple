//
//  DeepLinksViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 06/01/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import UIKit
import SwiftUI

final class DeepLinksViewController: UIHostingController<DeepLinksView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: DeepLinksView())
    }
}
