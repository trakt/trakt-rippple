//
//  DeeplinkViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 29/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import UIKit

final class DeeplinkViewController: UIViewController {
    var listType: CommentsCoordinator.ListType!

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            commentsViewController.coordinator = CommentsCoordinator(type: listType)
        }
    }

    @IBAction func done(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
