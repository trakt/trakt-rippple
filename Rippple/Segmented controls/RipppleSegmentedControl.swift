//
//  RipppleSegmentedControl.swift
//  Rippple
//
//  Created by Kevin Cador on 01/09/2020.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class RipppleSegmentedControl: UISegmentedControl {
    #if targetEnvironment(macCatalyst)
    override func layoutSubviews() {
        super.layoutSubviews()

        var theFrame = frame
        theFrame.size.height = 24.0
        frame = theFrame
    }
    #endif
}
