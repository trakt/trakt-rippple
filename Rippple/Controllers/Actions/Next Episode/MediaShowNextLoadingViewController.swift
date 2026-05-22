//
//  MediaShowNextLoadingViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 04/03/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import NVActivityIndicatorView
import UIKit

final class MediaShowNextLoadingViewController: UIViewController {
    var media: MediaModel!

    @IBOutlet var loading: NVActivityIndicatorView!

    deinit {
        print("deinit MediaShowNextLoadingViewController")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppManager.shared.isUserInteractionEnabled = false

        loading.tintColor = UIColor(asset: .globalTint)
        loading.startAnimating()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let actionViewController = segue.destination as? MediaNoNextEpisodeViewController {
            actionViewController.media = media
        }

        if let actionViewController = segue.destination as? MediaNextEpisodeErrorViewController {
            actionViewController.media = media
        }

        if let mediaViewController = segue.destination as? MediaViewController {
            let media = sender as! MediaModel
            mediaViewController.media = media
            mediaViewController.isDeeplink = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if UserManager.shared.currentUser == nil {
            dismiss(animated: true)
            AppManager.shared.isUserInteractionEnabled = true
            onNeedsToShowLoginTransmitter.broadcast(true)
            return
        }

        Task {
            if let showProgress = await media.progress() {
                DispatchQueue.main.async {
                    self.handleShowProgress(showProgress: showProgress)
                }
            } else {
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "error", sender: nil)
                    AppManager.shared.isUserInteractionEnabled = true
                }
            }
        }
    }

    private func handleShowProgress(showProgress: ShowProgress) {
        guard let show = media.show else { return }
        if let nextToRewatch = showProgress.nextToRewatch {
            TraktAPIProvider.provider.request(TraktAPIService.episode(id: String(show.identifiers.trakt!), season: nextToRewatch.0.number, episode: nextToRewatch.1.number),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "media",
                                              sender: episode.mediaModel(given: show))
                            AppManager.shared.isUserInteractionEnabled = true
                        }
                    } catch {
                        print("Error fetching episode \(error)")
                        self.performSegue(withIdentifier: "error", sender: nil)
                        AppManager.shared.isUserInteractionEnabled = true
                    }
                case .failure(let error):
                    print("Failed fetching episode \(error)")
                    self.performSegue(withIdentifier: "error", sender: nil)
                    AppManager.shared.isUserInteractionEnabled = true
                }
            }
        } else if let nextEpisode = showProgress.nextEpisodeToWatch {
            performSegue(withIdentifier: "media",
                         sender: nextEpisode.mediaModel(given: show))
            AppManager.shared.isUserInteractionEnabled = true
        } else {
            performSegue(withIdentifier: "no next", sender: nil)
            AppManager.shared.isUserInteractionEnabled = true
        }
    }
}
