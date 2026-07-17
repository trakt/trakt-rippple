//
//  DeepLinksViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 06/01/2024.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import UIKit

final class DeepLinksViewController: RipppleHostingController<DeepLinksView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: DeepLinksView())
    }
}
