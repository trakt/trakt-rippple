//
//  ProfileButton.swift
//  Rippple
//
//  Created by Kevin Cador on 27/12/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import UIKit

import Receiver

import Kingfisher

final class ProfileButton: UIButton {

    private let disposeBag = DisposeBag()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        sizeToFit()
        #if !targetEnvironment(macCatalyst)
        let size: CGFloat = 30
        #else
        let size: CGFloat = 24
        #endif

        imageView?.layer.cornerRadius = size/2.0
        imageView?.layer.cornerCurve = .continuous
        imageView?.layer.masksToBounds = true
        imageView?.backgroundColor = UIColor.secondarySystemBackground
        imageView?.layer.borderWidth = 1
        imageView?.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        onSettingsChangedReceiver.listen { [weak self] settings in
            guard let self = self else { return }
            guard let settings = settings else { return }

            // Introduce a sec of delay to avoid weird diaply bug
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.kf.setImage(with: settings.user.images!.avatar.full,
                                 for: .normal,
                                 options: [.scaleFactor(self.traitCollection.displayScale),
                                           .processor(RoundCornerImageProcessor(cornerRadius: size/2.0,
                                                                                targetSize: .init(width: size, height: size)))], completionHandler: { _ in
                    self.sizeToFit()
                })
            }
        }.disposed(by: disposeBag)
    }

}
