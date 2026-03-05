//
//  C1BrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 28/06/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit
import YouTubePlayerKit

final class C1BrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var backdrop: BackdropImageView!
    @IBOutlet weak var logo: LogoImageView?

    @IBOutlet weak var playButton: UIButton?

    private var youTubePlayer: YouTubePlayer?
    private var youTubePlayerHostingView: YouTubePlayerHostingView?

    var notes: String?
    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie:
                backdrop.media = media
                logo?.media = media
            case .show(let show):
                let media = show.mediaModel
                backdrop.media = media
                logo?.media = media
            case .episode(_, let show):
                let media = show.mediaModel
                backdrop.media = media
                logo?.media = media
            case .season(_, let show):
                let media = show.mediaModel
                backdrop.media = media
                logo?.media = media
            default:
                fatalError("Case not handled")
            }

            if let notes = notes, URL(string: notes) != nil {
                playButton?.layer.shadowOffset = CGSize(width: 0, height: 0)
                playButton?.layer.shadowOpacity = 1.0
                playButton?.layer.shadowRadius = 5.0

                if youTubePlayer == nil {
                    youTubePlayer = YouTubePlayer(source: .init(urlString: ""),
                                                  parameters: .init(autoPlay: true),
                                                  configuration: .init(fullscreenMode: .system,
                                                                       allowsInlineMediaPlayback: false))
                    youTubePlayerHostingView = YouTubePlayerHostingView(player: youTubePlayer!)
                    youTubePlayerHostingView!.layer.cornerRadius = 10
                    youTubePlayerHostingView!.layer.cornerCurve = .continuous
                    youTubePlayerHostingView!.layer.masksToBounds = true
                    youTubePlayerHostingView!.translatesAutoresizingMaskIntoConstraints = false
                    youTubePlayerHostingView!.alpha = 0.0
                    insertSubview(youTubePlayerHostingView!, at: 0)
                    NSLayoutConstraint.activate([
                        youTubePlayerHostingView!.topAnchor.constraint(equalTo: backdrop.topAnchor),
                        youTubePlayerHostingView!.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor),
                        youTubePlayerHostingView!.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor),
                        youTubePlayerHostingView!.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor)
                    ])
                }
                playButton?.isHidden = false
            } else {
                playButton?.isHidden = true
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        backdrop.layer.cornerRadius = ViewRadius.large.rawValue
        backdrop.layer.cornerCurve = .continuous
        backdrop.layer.masksToBounds = true
        backdrop.backgroundColor = UIColor.tertiarySystemFill
        backdrop.layer.borderWidth = 1
        backdrop.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        if let logo = logo {
            backdrop.addSubview(logo)

            logo.clipsToBounds = false
            logo.layer.masksToBounds = false
            logo.layer.shadowColor = UIColor.black.cgColor
            logo.layer.shadowOffset = CGSize(width: 0, height: 0)
            logo.layer.shadowOpacity = 1.0
            logo.layer.shadowRadius = 5.0
        }
    }

    @IBAction func playTrailer(_ sender: Any) {
        if let notes = notes, let url = URL(string: notes) {
            #if !targetEnvironment(macCatalyst)
            if notes.hasPrefix("https://www.youtube.com/watch?v=") {
                let pulseAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
                pulseAnimation.duration = 0.5
                pulseAnimation.fromValue = 0.4
                pulseAnimation.toValue = 1
                pulseAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                pulseAnimation.autoreverses = true
                pulseAnimation.repeatCount = .greatestFiniteMagnitude
                playButton?.layer.add(pulseAnimation, forKey: "animateOpacity")

                Task {
                    do {
                        try await youTubePlayerHostingView?.player.cue(source: .init(url: url)!)
                        try await youTubePlayerHostingView?.player.reload()
                    } catch {
                        await UIApplication.shared.open(url)
                    }
                    playButton?.layer.removeAnimation(forKey: "animateOpacity")
                }
            } else {
                UIApplication.shared.open(url)
            }
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }
}
