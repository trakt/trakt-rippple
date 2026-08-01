//
//  UIWindow+Extension.swift
//  Rippple
//
//  Created by Kevin Cador on 02/12/2017.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

public struct TransitionOptions {
    public enum Curve {
        case linear
        case easeIn
        case easeOut
        case easeInOut

        var function: CAMediaTimingFunction {
            let key: String!
            switch self {
            case .linear: key = convertFromCAMediaTimingFunctionName(CAMediaTimingFunctionName.linear)
            case .easeIn: key = convertFromCAMediaTimingFunctionName(CAMediaTimingFunctionName.easeIn)
            case .easeOut: key = convertFromCAMediaTimingFunctionName(CAMediaTimingFunctionName.easeOut)
            case .easeInOut: key = convertFromCAMediaTimingFunctionName(CAMediaTimingFunctionName.easeInEaseOut)
            }
            return CAMediaTimingFunction(name: convertToCAMediaTimingFunctionName(key))
        }
    }

    public enum Direction {
        case fade
        case toTop
        case toBottom
        case toLeft
        case toRight

        func transition() -> CATransition {
            let transition = CATransition()
            transition.type = CATransitionType.push
            switch self {
            case .fade:
                transition.type = CATransitionType.fade
                transition.subtype = nil
            case .toLeft:
                transition.subtype = CATransitionSubtype.fromLeft
            case .toRight:
                transition.subtype = CATransitionSubtype.fromRight
            case .toTop:
                transition.subtype = CATransitionSubtype.fromTop
            case .toBottom:
                transition.subtype = CATransitionSubtype.fromBottom
            }
            return transition
        }
    }

    public var duration: TimeInterval = 0.20

    public var direction: TransitionOptions.Direction = .toRight

    public var style: TransitionOptions.Curve = .linear

    public init(direction: TransitionOptions.Direction = .toRight, style: TransitionOptions.Curve = .linear) {
        self.direction = direction
        self.style = style
    }

    public init() {}

    var animation: CATransition {
        let transition = direction.transition()
        transition.duration = duration
        transition.timingFunction = style.function
        return transition
    }
}

public extension UIWindow {
    func setRootViewController(_ controller: UIViewController, options: TransitionOptions = TransitionOptions()) {
        layer.add(options.animation, forKey: kCATransition)
        rootViewController = controller
        makeKeyAndVisible()
    }
}

/// Helper function inserted by Swift 4.2 migrator.
private func convertFromCAMediaTimingFunctionName(_ input: CAMediaTimingFunctionName) -> String {
    return input.rawValue
}

/// Helper function inserted by Swift 4.2 migrator.
private func convertToCAMediaTimingFunctionName(_ input: String) -> CAMediaTimingFunctionName {
    return CAMediaTimingFunctionName(rawValue: input)
}
