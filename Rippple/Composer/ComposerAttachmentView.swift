//
//  ComposerAttachmentView.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class ComposerAttachmentView: UIView {
    var onRemove: (() -> Void)?

    private let gifView = CommentGIFView()
    private let removeButton: UIButton = {
        var configuration = UIButton.Configuration.glass()
        configuration.image = UIImage(systemName: "xmark",
                                      withConfiguration: UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium))
        configuration.cornerStyle = .capsule
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = "Remove GIF"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var gif: CommentGIF?

    override init(frame: CGRect) {
        super.init(frame: frame)
        gifView.install(in: self)
        addSubview(removeButton)
        removeButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            self.onRemove?()
        }, for: .primaryActionTriggered)
        NSLayoutConstraint.activate([
            removeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            removeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            removeButton.widthAnchor.constraint(equalToConstant: 32),
            removeButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(gif: CommentGIF?, isRemovable: Bool) {
        removeButton.isHidden = isRemovable == false
        guard gif != self.gif else { return }
        self.gif = gif
        guard let gif = gif else {
            gifView.reset()
            isHidden = true
            return
        }
        isHidden = false
        gifView.configure(gif: gif, isSpoilerBlurred: false)
        accessibilityElements = isRemovable ? [gifView, removeButton] : [gifView]
    }
}
