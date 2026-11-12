//
//  ComposerGIFs.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Kingfisher
import UIKit

struct ComposerGIFItem {
    let previewURL: URL?
    let gif: CommentGIF
    let shareSlug: String?
}

final class ComposerGIFCell: UICollectionViewCell {
    private let imageView = AnimatedImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemFill
        imageView.layer.cornerRadius = ViewRadius.medium.rawValue
        imageView.layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = [.button, .image]
        accessibilityLabel = "GIF"
        accessibilityHint = "Attaches this GIF to your comment."
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
    }

    func configure(with url: URL?) {
        guard let url = url else { return }
        imageView.setGIF(url: url, stillFrame: UIAccessibility.isReduceMotionEnabled)
    }
}

final class ComposerGIFHeaderView: UICollectionReusableView {
    let content = ComposerSectionHeader()

    override init(frame: CGRect) {
        super.init(frame: frame)
        content.pin(in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
