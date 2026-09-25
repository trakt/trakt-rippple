//
//  CommentGIFView.swift
//  Rippple
//
//  Created by Kevin Cador on 16/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import Kingfisher
import KingfisherWebP
import UIKit

/// An attachment shared by discussions and compact comment previews.
final class CommentGIFView: UIView {
    var onHeightChanged: (() -> Void)?

    private let imageView = AnimatedImageView()
    private let statusButton = UIButton(type: .custom)
    private var attachmentURL: URL?
    private var requestIdentifier = UUID()
    private var heightConstraint: NSLayoutConstraint?
    private var isCompact = false
    private var maximumHeight: CGFloat = 280
    private var isLoading = false
    private let compactPlaceholderSize: CGFloat = 96
    private let fullPlaceholderSize = CGSize(width: 176, height: 132)
    private var placeholderImageSize: CGSize?
    private var imageSize = CGSize(width: 4, height: 3)

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = ViewRadius.medium.rawValue
        imageView.layer.cornerCurve = .continuous
        imageView.backgroundColor = .secondarySystemFill
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Attached GIF"
        addSubview(imageView)

        statusButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 18, weight: .medium), forImageIn: .normal)
        statusButton.tintColor = .secondaryLabel
        statusButton.backgroundColor = .secondarySystemFill
        statusButton.layer.cornerRadius = ViewRadius.medium.rawValue
        statusButton.layer.cornerCurve = .continuous
        statusButton.clipsToBounds = true
        statusButton.isAccessibilityElement = true
        statusButton.addTarget(self, action: #selector(retryLoading), for: .touchUpInside)
        addSubview(statusButton)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reduceMotionChanged),
                                               name: UIAccessibility.reduceMotionStatusDidChangeNotification,
                                               object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func install(after label: UILabel, compact: Bool) {
        guard let stack = label.superview as? UIStackView,
              let index = stack.arrangedSubviews.firstIndex(of: label) else { return }
        isCompact = compact
        maximumHeight = compact ? 64 : 280
        translatesAutoresizingMaskIntoConstraints = false
        if compact {
            stack.removeArrangedSubview(label)
            label.removeFromSuperview()
            let bodyStack = UIStackView(arrangedSubviews: [label, self])
            bodyStack.axis = .horizontal
            bodyStack.alignment = .bottom
            bodyStack.spacing = 8
            stack.insertArrangedSubview(bodyStack, at: index)
            let width = widthAnchor.constraint(equalToConstant: compactPlaceholderSize)
            width.priority = UILayoutPriority(999)
            width.isActive = true
        } else {
            stack.insertArrangedSubview(self, at: index + 1)
        }
        let height = heightAnchor.constraint(equalToConstant: compact ? compactPlaceholderSize : maximumHeight)
        height.priority = .defaultHigh
        height.isActive = true
        heightConstraint = height
        setContentCompressionResistancePriority(.required, for: .vertical)
        isHidden = true
    }

    func configure(with model: CommentModel) {
        defer { setNeedsLayout() }
        let comment = model.comment
        guard let gif = comment.gif, !gif.url.isEmpty else {
            reset()
            return
        }
        guard !comment.isFiltered, !comment.user.isBlocked else {
            reset()
            return
        }
        guard !model.hidesCommentMedia else {
            reset()
            isHidden = false
            showPlaceholder(symbol: "eye.slash", accessibilityLabel: "GIF hidden. Open comment to view spoiler.")
            return
        }
        guard let url = URL(string: gif.url), url.scheme?.lowercased() == "https", url.host != nil else {
            reset()
            isHidden = false
            showPlaceholder(symbol: "exclamationmark.triangle", accessibilityLabel: "GIF unavailable")
            return
        }
        guard attachmentURL != url else { return }
        reset()
        isHidden = false
        attachmentURL = url
        if let width = gif.width, let height = gif.height,
           width.isFinite, height.isFinite, width > 0, height > 0 {
            let aspectRatio = height / width
            if aspectRatio.isFinite, aspectRatio > 0 {
                placeholderImageSize = CGSize(width: width, height: height)
            }
        }
        loadImage()
    }

    func reset() {
        isLoading = false
        updateLoadingPulse()
        requestIdentifier = UUID()
        imageView.kf.cancelDownloadTask()
        imageView.stopAnimating()
        imageView.image = nil
        imageView.isHidden = true
        attachmentURL = nil
        placeholderImageSize = nil
        imageSize = CGSize(width: 4, height: 3)
        statusButton.setImage(nil, for: .normal)
        statusButton.isUserInteractionEnabled = false
        statusButton.accessibilityHint = nil
        statusButton.accessibilityTraits = .image
        statusButton.accessibilityLabel = nil
        statusButton.isHidden = true
        isHidden = true
    }

    private func showPlaceholder(symbol: String?, accessibilityLabel: String, canRetry: Bool = false) {
        isLoading = symbol == nil
        updateLoadingPulse()
        statusButton.setImage(symbol.flatMap { UIImage(systemName: $0) }, for: .normal)
        statusButton.isUserInteractionEnabled = canRetry
        statusButton.accessibilityTraits = canRetry ? .button : .image
        statusButton.accessibilityHint = canRetry ? "Double-tap to retry loading the GIF." : nil
        statusButton.accessibilityLabel = accessibilityLabel
        statusButton.isHidden = false
        setNeedsLayout()
    }

    private func updateLoadingPulse() {
        statusButton.layer.removeAnimation(forKey: "loadingPulse")
        guard isLoading, window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.45
        pulse.duration = 0.85
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        statusButton.layer.add(pulse, forKey: "loadingPulse")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateLoadingPulse()
    }

    @objc private func retryLoading() {
        guard statusButton.isUserInteractionEnabled, attachmentURL != nil else { return }
        loadImage()
    }

    private func loadImage() {
        guard let url = attachmentURL else { return }
        let requestIdentifier = UUID()
        self.requestIdentifier = requestIdentifier
        imageView.isHidden = true
        showPlaceholder(symbol: nil, accessibilityLabel: "Loading GIF")

        imageView.autoPlayAnimatedImage = !UIAccessibility.isReduceMotionEnabled
        var options: KingfisherOptionsInfo = [
            .processor(WebPProcessor.default),
            .cacheSerializer(WebPSerializer.default)
        ]
        if UIAccessibility.isReduceMotionEnabled {
            options.append(.onlyLoadFirstFrame)
        }
        let resource = KF.ImageResource(downloadURL: url,
                                        cacheKey: url.absoluteString + (UIAccessibility.isReduceMotionEnabled ? "#still" : ""))
        imageView.kf.setImage(with: resource, options: options) { [weak self] result in
            guard let self = self, self.requestIdentifier == requestIdentifier else { return }
            switch result {
            case .success(let value):
                self.isLoading = false
                self.updateLoadingPulse()
                self.imageSize = value.image.size
                self.statusButton.isHidden = true
                self.imageView.isHidden = false
                self.setNeedsLayout()
            case .failure:
                self.showPlaceholder(symbol: "exclamationmark.triangle", accessibilityLabel: "GIF couldn’t load", canRetry: true)
            }
        }
    }

    @objc private func reduceMotionChanged() {
        requestIdentifier = UUID()
        imageView.kf.cancelDownloadTask()
        imageView.stopAnimating()
        imageView.image = nil
        loadImage()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isHidden, bounds.width > 0, imageSize.width > 0, imageSize.height > 0 else { return }
        let showsLargePlaceholder = isLoading || statusButton.isUserInteractionEnabled
        let preferredPlaceholderSize: CGSize
        if isCompact {
            let side: CGFloat = showsLargePlaceholder ? compactPlaceholderSize : 64
            preferredPlaceholderSize = CGSize(width: side, height: side)
        } else {
            preferredPlaceholderSize = showsLargePlaceholder ? fullPlaceholderSize : CGSize(width: 64, height: 44)
        }
        let placeholderImageSize = showsLargePlaceholder ? placeholderImageSize : nil
        let layoutImageSize = imageView.isHidden ? (placeholderImageSize ?? imageSize) : imageSize
        if !isCompact, let heightConstraint = heightConstraint {
            let height = imageView.isHidden && placeholderImageSize == nil
                ? preferredPlaceholderSize.height
                : min(maximumHeight, bounds.width * (layoutImageSize.height / layoutImageSize.width))
            if abs(heightConstraint.constant - height) > 0.5 {
                heightConstraint.constant = height
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.onHeightChanged?()
                }
            }
        }
        let scale = min(bounds.width / layoutImageSize.width, min(bounds.height, maximumHeight) / layoutImageSize.height)
        let size = CGSize(width: layoutImageSize.width * scale, height: layoutImageSize.height * scale)
        let alignsRight = isCompact != (effectiveUserInterfaceLayoutDirection == .rightToLeft)
        let x = alignsRight ? bounds.width - size.width : 0
        let y = isCompact ? bounds.height - size.height : 0
        imageView.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
        let placeholderSize = placeholderImageSize != nil ? size : CGSize(width: min(bounds.width, preferredPlaceholderSize.width), height: min(bounds.height, preferredPlaceholderSize.height))
        let placeholderX = alignsRight ? bounds.width - placeholderSize.width : 0
        let placeholderY = isCompact ? bounds.height - placeholderSize.height : 0
        statusButton.frame = CGRect(origin: CGPoint(x: placeholderX, y: placeholderY), size: placeholderSize)
    }
}
