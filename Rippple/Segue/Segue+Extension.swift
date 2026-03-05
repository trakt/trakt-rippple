//
//  Segue+Extension.swift
//  Rippple
//
//  Created by Kevin Cador on 24/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import UIKit

protocol SegueHandler {
    associatedtype ViewControllerSegue: RawRepresentable
    func segueIdentifierCase(for segue: UIStoryboardSegue) -> ViewControllerSegue?
}

extension SegueHandler where Self: UIViewController, ViewControllerSegue.RawValue == String {
    func segueIdentifierCase(for segue: UIStoryboardSegue) -> ViewControllerSegue {
        guard let identifier = segue.identifier,
            let identifierCase = ViewControllerSegue(rawValue: identifier) else {
                fatalError("Could not map segue identifier -- \(String(describing: segue.identifier)) -- to segue case")
        }
        return identifierCase
    }
}
