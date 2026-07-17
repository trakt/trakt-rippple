//
//  AutomationViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 04/09/2022.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import UIKit

final class AutomationViewController: RipppleHostingController<AutomationSettingsView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: AutomationSettingsView())
    }
}
