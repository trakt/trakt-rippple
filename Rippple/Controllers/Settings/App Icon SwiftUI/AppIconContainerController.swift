//
//  AppIconContainerController.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import SwiftUI
import UIKit

final class AppIconContainerController: RipppleHostingController<AppIconChooserView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: AppIconChooserView())
    }
}
