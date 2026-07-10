//
//  SharingViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 30/07/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import SwiftUI
import UIKit

final class SharingViewController: RipppleHostingController<SharingView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: SharingView())
    }
}
