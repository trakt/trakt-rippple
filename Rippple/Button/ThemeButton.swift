//
//  ThemeButton.swift
//  Rippple
//
//  Created by Kevin Cador on 07/09/2019.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

class TitleOnlyButton: UIButton {
    override func awakeFromNib() {
        super.awakeFromNib()
        commonSetup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonSetup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonSetup()
    }

    private func commonSetup() {
        setTitleColor(UIColor(asset: .globalTint), for: .normal)
        setTitleColor(UIColor(asset: .globalTint), for: .application)
        setTitleColor(.secondaryLabel, for: .disabled)
        setTitleColor(UIColor(asset: .globalTint).lighter(), for: .focused)
        setTitleColor(UIColor(asset: .globalTint).lighter(), for: .highlighted)
        setTitleColor(UIColor(asset: .globalTint), for: .reserved)
        setTitleColor(UIColor(asset: .globalTint).lighter(), for: .selected)

        maximumContentSizeCategory = .large
    }
}

final class ShadowButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? UIColor(asset: .globalTint).lighter() : UIColor(asset: .globalTint)
            if oldValue == false && isHighlighted {
                highlight()
            } else if oldValue == true && !isHighlighted {
                unHighlight()
            }
        }
    }

    override var isSelected: Bool {
        didSet {
            backgroundColor = isHighlighted ? UIColor(asset: .globalTint).lighter() : UIColor(asset: .globalTint)
        }
    }

    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? UIColor(asset: .globalTint) : UIColor(asset: .globalTint).darker()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        commonSetup()
    }

    @objc
    private func configureView() {
        layer.shadowColor = UIColor(asset: .shadow).cgColor
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        commonSetup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        commonSetup()
    }

    deinit {
        print("deiniting theme button")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.size.height / 2.0
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    private func commonSetup() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self],
                                action: #selector(configureView))

        layer.shadowColor = UIColor(asset: .shadow).cgColor
        layer.shadowOpacity = 0.6
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 0)

        layer.borderWidth = 0.3
        layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor

        maximumContentSizeCategory = .extraExtraExtraLarge
    }

    private func highlight() {
        UISelectionFeedbackGenerator().selectionChanged()
        animateScale(to: 0.95, duration: 0.4)
    }

    private func unHighlight() {
        animateScale(to: 1, duration: 0.4)
    }

    private func animateScale(to scale: CGFloat, duration: TimeInterval) {
        UIView.animate(withDuration: duration,
                       delay: 0,
                       usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 3.0,
                       options: [],
                       animations: { self.transform = .init(scaleX: scale, y: scale) },
                       completion: nil)
    }
}

final class ThemeButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? UIColor(asset: .globalTint).lighter() : UIColor(asset: .globalTint)
        }
    }

    override var isSelected: Bool {
        didSet {
            backgroundColor = isHighlighted ? UIColor(asset: .globalTint).lighter() : UIColor(asset: .globalTint)
        }
    }

    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? UIColor(asset: .globalTint) : UIColor(asset: .globalTint).darker()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        commonInit()
    }

    @objc
    private func configureView() {
        layer.shadowColor = UIColor(asset: .shadow).cgColor
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        commonInit()
    }

    private func commonInit() {
        backgroundColor = UIColor(asset: .globalTint)

        registerForTraitChanges([UITraitUserInterfaceStyle.self],
                                action: #selector(configureView))

        layer.shadowColor = UIColor(asset: .shadow).cgColor
        layer.shadowOpacity = 0.6
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 0)

        maximumContentSizeCategory = .extraExtraExtraLarge
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        commonInit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.size.height / 2.0
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath

        titleLabel?.textColor = .ripppleTintContrastingLabel
        imageView?.tintColor = .ripppleTintContrastingLabel
    }
}
