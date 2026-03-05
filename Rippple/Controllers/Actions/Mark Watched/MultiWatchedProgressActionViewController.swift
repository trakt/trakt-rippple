//
//  MultiWatchedProgressActionViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 01/01/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import UIKit

import NVActivityIndicatorView

import Receiver

final class MultiWatchedProgressActionViewController: UIViewController {
    private var media: MediaModel!
    private var unwatched: [(SeasonProgress, EpisodeProgress)]!
    private var watchedAt: Date?

    @IBOutlet weak var loading: NVActivityIndicatorView!

    deinit {
        print("deinit MultiWatchedProgressActionViewController")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppManager.shared.isUserInteractionEnabled = false

        loading.tintColor = UIColor(asset: .globalTint)
        loading.startAnimating()
    }

    init?(coder: NSCoder, media: MediaModel, watchedAt: Date?, unwatched: [(SeasonProgress, EpisodeProgress)]) {
        self.media = media
        self.watchedAt = watchedAt
        self.unwatched = unwatched

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBSegueAction
    func makeMultiWatchedActionErrorViewController(coder: NSCoder, sender: Any?) -> MultiWatchedActionErrorViewController? {
        return MultiWatchedActionErrorViewController(coder: coder,
                                               media: media,
                                               watchedAt: watchedAt,
                                               unwatched: unwatched)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if UserManager.shared.currentUser == nil {
            dismiss(animated: true)
            AppManager.shared.isUserInteractionEnabled = true
            onNeedsToShowLoginTransmitter.broadcast(true)
            return
        }

        switch media {
        case .movie:
            fatalError("Not implemented")
        case .episode(_, let show):
            TraktAPIProvider.provider.request(TraktAPIService.addEpisodesToHistory(showId: show.identifiers.trakt!, watchedAt: watchedAt, seasonsEpisodes: unwatched.map { ($0.number, $1.number) }, runtime: show.runtime),
            callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        print("Mark multi watched successful \(response)")

                        DispatchQueue.main.async {
                            self.dismiss(animated: true, completion: nil)
                            onMarkWatchedTransmitter.broadcast(show.mediaModel)
                            AppManager.shared.isUserInteractionEnabled = true
                            SwiftMessages.show(message: "✅ Including \(self.unwatched.count) previous")
                        }
                    } catch {
                        print("Error marking watched show \(error)")
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "error", sender: nil)
                            AppManager.shared.isUserInteractionEnabled = true
                        }
                    }
                case let .failure(error):
                    print("Error marking watched show \(error)")
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "error", sender: nil)
                        AppManager.shared.isUserInteractionEnabled = true
                    }
                }
            }
        case .season:
            fatalError("Not implemented")
        case .show:
            fatalError("Not implemented")
        default:
            break
        }
    }
}
