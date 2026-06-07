//
//  CircularProgressView.swift
//  Rippple
//
//  Created by Kevin Cador on 24/05/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class CircularProgressView: UIView {
    @IBInspectable var trackTintColor: UIColor = .init(white: 1.0, alpha: 0.3) {
        didSet {
            trackLayer.strokeColor = trackTintColor.cgColor
        }
    }

    @IBInspectable var progressTintColor: UIColor = .white {
        didSet {
            progressLayer.strokeColor = progressTintColor.cgColor
        }
    }

    @IBInspectable var roundedCorners: Bool = true {
        didSet {
            updateLineCaps()
        }
    }

    @IBInspectable var thicknessRatio: CGFloat = 0.3 {
        didSet {
            thicknessRatio = clamped(thicknessRatio, minValue: 0.01, maxValue: 1.0)
            updatePath()
        }
    }

    private(set) var progress: CGFloat = 0

    var timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let progressAnimationKey = "progress"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePath()
    }

    func updateProgress(_ progress: CGFloat,
                        animated: Bool = true,
                        initialDelay: CFTimeInterval = 0,
                        duration: CFTimeInterval? = nil,
                        completion: (() -> Void)? = nil) {
        let targetProgress = clamped(progress)
        let currentProgress = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd

        progressLayer.removeAnimation(forKey: progressAnimationKey)
        self.progress = targetProgress

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.strokeEnd = targetProgress
        CATransaction.commit()

        guard animated, currentProgress != targetProgress else {
            completion?()
            return
        }

        let animationDuration = duration ?? CFTimeInterval(abs(targetProgress - currentProgress))
        guard animationDuration > 0 else {
            completion?()
            return
        }

        let animation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeEnd))
        animation.fromValue = currentProgress
        animation.toValue = targetProgress
        animation.duration = animationDuration
        animation.beginTime = progressLayer.convertTime(CACurrentMediaTime(), from: nil) + initialDelay
        animation.fillMode = .backwards
        animation.timingFunction = timingFunction

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        progressLayer.add(animation, forKey: progressAnimationKey)
        CATransaction.commit()
    }
}

private extension CircularProgressView {
    func setup() {
        isOpaque = false
        backgroundColor = .clear

        for item in [trackLayer, progressLayer] {
            item.fillColor = UIColor.clear.cgColor
            item.strokeStart = 0
            layer.addSublayer(item)
        }

        trackLayer.strokeEnd = 1
        progressLayer.strokeEnd = progress

        trackLayer.strokeColor = trackTintColor.cgColor
        progressLayer.strokeColor = progressTintColor.cgColor
        updateLineCaps()
    }

    func updateLineCaps() {
        progressLayer.lineCap = roundedCorners ? .round : .butt
    }

    func updatePath() {
        let diameter = min(bounds.width, bounds.height)
        guard diameter > 0 else { return }

        let lineWidth = (diameter / 2) * thicknessRatio
        let radius = max(0, (diameter - lineWidth) / 2)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath(arcCenter: center,
                                radius: radius,
                                startAngle: -.pi / 2,
                                endAngle: 3 * .pi / 2,
                                clockwise: true)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for item in [trackLayer, progressLayer] {
            item.frame = bounds
            item.path = path.cgPath
            item.lineWidth = lineWidth
        }
        progressLayer.strokeEnd = progress
        CATransaction.commit()
    }

    func clamped(_ value: CGFloat, minValue: CGFloat = 0, maxValue: CGFloat = 1) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}
