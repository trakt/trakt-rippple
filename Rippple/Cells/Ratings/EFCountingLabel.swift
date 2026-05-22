//
//  EFCountingLabel.swift
//  EFCountingLabel
//
//  Created by EyreFree on 2016/12/11.
//
//  Copyright (c) 2017 EyreFree <eyrefree@eyrefree.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

public enum EFLabelCountingMethod: Int {
    case linear = 0
    case easeIn = 1
    case easeOut = 2
    case easeInOut = 3
}

// MARK: - UILabelCounter

let kUILabelCounterRate = Float(3.0)

public protocol UILabelCounter {
    func update(_ timeInterval: CGFloat) -> CGFloat
}

public class UILabelCounterLinear: UILabelCounter {
    public func update(_ timeInterval: CGFloat) -> CGFloat {
        return timeInterval
    }
}

public class UILabelCounterEaseIn: UILabelCounter {
    public func update(_ timeInterval: CGFloat) -> CGFloat {
        return CGFloat(powf(Float(timeInterval), kUILabelCounterRate))
    }
}

public class UILabelCounterEaseOut: UILabelCounter {
    public func update(_ timeInterval: CGFloat) -> CGFloat {
        return CGFloat(1.0 - powf(Float(1.0 - timeInterval), kUILabelCounterRate))
    }
}

public class UILabelCounterEaseInOut: UILabelCounter {
    public func update(_ timeInterval: CGFloat) -> CGFloat {
        let newt: CGFloat = 2 * timeInterval
        if newt < 1 {
            return CGFloat(0.5 * powf(Float(newt), kUILabelCounterRate))
        } else {
            return CGFloat(0.5 * (2.0 - powf(Float(2.0 - newt), kUILabelCounterRate)))
        }
    }
}

// MARK: - EFCountingLabel

open class EFCountingLabel: UILabel {
    public var format = "%f"
    public var method = EFLabelCountingMethod.linear
    public var animationDuration = TimeInterval(2)
    public var formatBlock: ((CGFloat) -> String)?
    public var attributedFormatBlock: ((CGFloat) -> NSAttributedString)?
    public var completionBlock: (() -> Void)?

    private var startingValue: CGFloat!
    private var destinationValue: CGFloat!
    private var progress: TimeInterval = 0
    private var lastUpdate: TimeInterval!
    private var totalTime: TimeInterval!
    private var easingRate: CGFloat!

    private var timer: CADisplayLink?
    private var counter: UILabelCounter = UILabelCounterLinear()

    public func countFrom(_ startValue: CGFloat, to endValue: CGFloat) {
        countFrom(startValue, to: endValue, withDuration: animationDuration)
    }

    public func countFrom(_ startValue: CGFloat, to endValue: CGFloat, withDuration duration: TimeInterval) {
        startingValue = startValue
        destinationValue = endValue

        // remove any (possible) old timers
        self.timer?.invalidate()
        self.timer = nil

        if duration == 0.0 {
            // No animation
            setTextValue(endValue)
            runCompletionBlock()
            return
        }

        easingRate = 3.0
        progress = 0
        totalTime = duration
        lastUpdate = Date.timeIntervalSinceReferenceDate

        switch method {
        case .linear:
            counter = UILabelCounterLinear()
        case .easeIn:
            counter = UILabelCounterEaseIn()
        case .easeOut:
            counter = UILabelCounterEaseOut()
        case .easeInOut:
            counter = UILabelCounterEaseInOut()
        }

        let timer = CADisplayLink(target: self, selector: #selector(EFCountingLabel.updateValue(_:)))
        timer.preferredFramesPerSecond = 30
        timer.add(to: RunLoop.current, forMode: RunLoop.Mode.default)
        timer.add(to: RunLoop.current, forMode: RunLoop.Mode.tracking)
        self.timer = timer
    }

    public func countFromCurrentValueTo(_ endValue: CGFloat) {
        countFrom(currentValue(), to: endValue)
    }

    public func countFromCurrentValueTo(_ endValue: CGFloat, withDuration duration: TimeInterval) {
        countFrom(currentValue(), to: endValue, withDuration: duration)
    }

    public func countFromZeroTo(_ endValue: CGFloat) {
        countFrom(0, to: endValue)
    }

    public func countFromZeroTo(_ endValue: CGFloat, withDuration duration: TimeInterval) {
        countFrom(0, to: endValue, withDuration: duration)
    }

    public func currentValue() -> CGFloat {
        if progress == 0 {
            return 0
        } else if progress >= totalTime {
            return destinationValue
        }

        let percent = progress / totalTime
        let updateVal = counter.update(CGFloat(percent))

        return startingValue + updateVal * (destinationValue - startingValue)
    }

    @objc public func updateValue(_ timer: Timer) {
        // update progress
        let now = Date.timeIntervalSinceReferenceDate
        progress += (now - lastUpdate)
        lastUpdate = now

        if progress >= totalTime {
            self.timer?.invalidate()
            self.timer = nil
            progress = totalTime
        }

        setTextValue(currentValue())

        if progress == totalTime {
            runCompletionBlock()
        }
    }

    private func setTextValue(_ value: CGFloat) {
        if let tryAttributedFormatBlock = attributedFormatBlock {
            attributedText = tryAttributedFormatBlock(value)
        } else if let tryFormatBlock = formatBlock {
            text = tryFormatBlock(value)
        } else {
            // check if counting with ints - cast to int
            if format.range(of: "%(.*)d", options: String.CompareOptions.regularExpression, range: nil) != nil
                || format.range(of: "%(.*)i") != nil {
                text = String(format: format, Int(value))
            } else {
                text = String(format: format, value)
            }
        }
    }

    private func setFormat(_ format: String) {
        self.format = format
        setTextValue(currentValue())
    }

    private func runCompletionBlock() {
        if let tryCompletionBlock = completionBlock {
            tryCompletionBlock()

            completionBlock = nil
        }
    }
}
