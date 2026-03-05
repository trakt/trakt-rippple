//
//  ShowProgressBar.swift
//  Rippple
//
//  Created by Kevin Cador on 13/06/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import UIKit

import Receiver

final class ShowProgressBar: UIView {

    private let disposeBag = DisposeBag()

    var hideIfNoProgress = false

    @IBInspectable var color: UIColor? = UIColor(asset: .globalTint)
    private var showsProgress: ShowProgress? {
        didSet {
            if showsProgress?.lastWatchedAt != nil {
                DispatchQueue.main.async {
                    self.setNeedsDisplay()
                    self.superview?.isHidden = false
                    self.invalidateCellIntrinsicContentSize()
                }
            } else {
                DispatchQueue.main.async {
                    if self.hideIfNoProgress {
                        self.superview?.isHidden = true
                    } else {
                        self.superview?.isHidden = false
                        self.setNeedsDisplay()
                    }
                    self.invalidateCellIntrinsicContentSize()
                }
            }
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        layer.sublayers?.removeAll()

        guard let secondaryColor = color?.withAlphaComponent(0.4).cgColor else { return }
        guard let color = color?.cgColor else { return }

        let backgroundMask = CAShapeLayer()
        backgroundMask.path = UIBezierPath(roundedRect: rect, cornerRadius: 10).cgPath
        layer.mask = backgroundMask

        guard let showsProgress = showsProgress else { return }

        DispatchQueue.global(qos: .userInteractive).async {
            let width = rect.width
            let seasonWidth: CGFloat = 2
            var episodes: CGFloat = 0
            var seasons: CGFloat = 0
            for season in showsProgress.seasons {
                if season.number == 0 { continue }
                seasons += 1
                for _ in season.episodes {
                    episodes += 1
                }
            }
            let episodeWidth = (width-((seasons-1)*seasonWidth))/episodes
            var origin: CGPoint = .zero

            let watchedPath = UIBezierPath()
            let unwatchedPath = UIBezierPath()
            for season in showsProgress.seasons {
                if season.number == 0 { continue }
                if season.number != 1 {
                    origin = CGPoint(x: origin.x + seasonWidth, y: origin.y)
                }
                for episode in season.episodes {
                    let path = UIBezierPath(rect: CGRect(origin: origin,
                                                         size: CGSize(width: episodeWidth, height: rect.height)))
                    if episode.completed {
                        watchedPath.append(path)
                    } else {
                        unwatchedPath.append(path)
                    }
                    origin = CGPoint(x: origin.x + episodeWidth, y: origin.y)
                }
            }

            DispatchQueue.main.async {
                let watchedShape = CAShapeLayer()
                watchedShape.path = watchedPath.cgPath
                watchedShape.fillColor = color
                self.layer.addSublayer(watchedShape)

                let unwatchedShape = CAShapeLayer()
                unwatchedShape.path = unwatchedPath.cgPath
                unwatchedShape.fillColor = secondaryColor
                self.layer.addSublayer(unwatchedShape)
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = UIColor(asset: .globalTint).withAlphaComponent(0.2)

        contentMode = .redraw

        onProgressCacheChangedReceiver.listen { [weak self] progress in
            guard let self = self else { return }
            if progress.show == self.media?.show {
                self.showsProgress = progress.showProgress
            }
        }.disposed(by: disposeBag)
    }

    var media: MediaModel? {
        didSet {
            if media == nil {
                return
            }
            if media == oldValue { return }
            if hideIfNoProgress {
                superview?.isHidden = true
                invalidateCellIntrinsicContentSize()
            }
            if media!.show?.isWatchedAtLeastOnce == true {
                media!.progress(with: { [weak self] progress in
                    guard let self = self else { return }
                    self.showsProgress = progress
                })
            } else {
                showsProgress = nil
            }
        }
    }
}
