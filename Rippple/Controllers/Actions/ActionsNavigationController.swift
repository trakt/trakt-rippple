//
//  ActionsNavigationController.swift
//  Rippple
//
//  Created by Kevin Cador on 07/07/2021.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

class ActionsNavigationController: StyledNavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()

        if let presentationController = presentationController as? UISheetPresentationController {
            presentationController.detents = [
                .medium(),
                .large()
            ]
            presentationController.prefersGrabberVisible = true
        }
    }
}
