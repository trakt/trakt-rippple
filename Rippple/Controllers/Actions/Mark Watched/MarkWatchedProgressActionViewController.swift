//
//  MarkWatchedProgressActionViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/04/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import UIKit

import NVActivityIndicatorView

import Receiver

let (onMarkWatchedTransmitter, onMarkWatchedReceiver) = Receiver<MediaModel>.make(with: .hot)

final class MarkWatchedProgressActionViewController: UIViewController {
    private var media: MediaModel!
    private var unwatched: [(SeasonProgress, EpisodeProgress)]?
    private var episodes: [MediaModel]?
    private var watchedAt: Date?

    @IBOutlet weak var loading: NVActivityIndicatorView!

    deinit {
        print("deinit MarkWatchedProgressActionViewController")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppManager.shared.isUserInteractionEnabled = false

        loading.tintColor = UIColor(asset: .globalTint)
        loading.startAnimating()
    }

    init?(coder: NSCoder, media: MediaModel, watchedAt: Date?, unwatched: [(SeasonProgress, EpisodeProgress)]? = nil) {
        self.media = media
        self.watchedAt = watchedAt
        self.unwatched = unwatched

        super.init(coder: coder)
    }

    init?(coder: NSCoder, media: MediaModel, watchedAt: Date?, episodes: [MediaModel]) {
        self.media = media
        self.watchedAt = watchedAt
        self.episodes = episodes

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBSegueAction
    func makeMarkWatchedActionErrorViewController(coder: NSCoder, sender: Any?) -> MarkWatchedActionErrorViewController? {
        return MarkWatchedActionErrorViewController(coder: coder,
                                               media: media,
                                               watchedAt: watchedAt,
                                               unwatched: unwatched)
    }

    @IBSegueAction
    func makeMultiWatchedProgressActionViewController(coder: NSCoder, sender: Any?) -> MultiWatchedProgressActionViewController? {
        guard let unwatched = unwatched else { return nil }
        if let watchedAt = watchedAt {
            let watchedAt = Calendar.current.date(byAdding: .second,
                                                  value: (media.show?.runtime ?? 1) * -60,
                                                  to: watchedAt)
            return MultiWatchedProgressActionViewController(coder: coder,
                                                            media: media,
                                                            watchedAt: watchedAt,
                                                            unwatched: unwatched)
        } else {
            return MultiWatchedProgressActionViewController(coder: coder,
                                                            media: media,
                                                            watchedAt: watchedAt,
                                                            unwatched: unwatched)
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

        switch media {
        case .movie(let movie):
            TraktAPIProvider.provider.request(TraktAPIService.addMovieToHistory(id: movie.identifiers.trakt!, watchedAt: watchedAt),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        print("Mark movie watched successful \(response)")

                        DispatchQueue.main.async {
                            self.dismiss(animated: true, completion: nil)
                            onMarkWatchedTransmitter.broadcast(self.media)
                            AppManager.shared.isUserInteractionEnabled = true
                            SwiftMessages.show(message: "✅ Added to watched history")
                        }
                    } catch {
                        print("Error marking watched movie \(error)")
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "error", sender: nil)
                            AppManager.shared.isUserInteractionEnabled = true
                        }
                    }
                case let .failure(error):
                    print("Error marking watched movie \(error)")
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "error", sender: nil)
                        AppManager.shared.isUserInteractionEnabled = true
                    }
                }
            }
        case .episode(let episode, _):
            TraktAPIProvider.provider.request(TraktAPIService.addEpisodeToHistory(id: episode.identifiers.trakt!, watchedAt: watchedAt),
            callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        print("Mark episode watched successful \(response)")

                        DispatchQueue.main.async {
                            AppManager.shared.isUserInteractionEnabled = true
                            SwiftMessages.show(message: "✅ Added to watched history")
                            if self.unwatched == nil {
                                onMarkWatchedTransmitter.broadcast(self.media)
                                self.dismiss(animated: true, completion: nil)
                            } else {
                                self.performSegue(withIdentifier: "previous", sender: nil)
                            }
                        }
                    } catch {
                        print("Error marking watched episode \(error)")
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "error", sender: nil)
                            AppManager.shared.isUserInteractionEnabled = true
                        }
                    }
                case let .failure(error):
                    print("Error marking watched episode \(error)")
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "error", sender: nil)
                        AppManager.shared.isUserInteractionEnabled = true
                    }
                }
            }
        case .season(let season, _):
            TraktAPIProvider.provider.request(TraktAPIService.addSeasonToHistory(id: season.identifiers.trakt!, watchedAt: watchedAt),
            callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        print("Mark season watched successful \(response)")

                        DispatchQueue.main.async {
                            self.dismiss(animated: true, completion: nil)
                            onMarkWatchedTransmitter.broadcast(self.media)
                            AppManager.shared.isUserInteractionEnabled = true
                            SwiftMessages.show(message: "✅ Added to watched history")
                        }
                    } catch {
                        print("Error marking watched season \(error)")
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "error", sender: nil)
                            AppManager.shared.isUserInteractionEnabled = true
                        }
                    }
                case let .failure(error):
                    print("Error marking watched season \(error)")
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "error", sender: nil)
                        AppManager.shared.isUserInteractionEnabled = true
                    }
                }
            }
        case .show(let show):
            if let episodes = episodes {
                TraktAPIProvider.provider.request(TraktAPIService.addEpisodesToHistory(showId: show.identifiers.trakt!, watchedAt: watchedAt, seasonsEpisodes: episodes.map { ($0.episode!.season, $0.episode!.number )}, runtime: show.runtime),
                callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case let .success(moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                            print("Mark show watched successful \(response)")

                            DispatchQueue.main.async {
                                self.dismiss(animated: true, completion: nil)
                                onMarkWatchedTransmitter.broadcast(self.media)
                                AppManager.shared.isUserInteractionEnabled = true
                                SwiftMessages.show(message: "✅ Added \(episodes.count) to history")
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
            } else {
                TraktAPIProvider.provider.request(TraktAPIService.addShowToHistory(id: show.identifiers.trakt!, watchedAt: watchedAt),
                callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case let .success(moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                            print("Mark show watched successful \(response)")

                            DispatchQueue.main.async {
                                self.dismiss(animated: true, completion: nil)
                                onMarkWatchedTransmitter.broadcast(self.media)
                                AppManager.shared.isUserInteractionEnabled = true
                                SwiftMessages.show(message: "✅ Added to watched history")
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
            }
        default:
            break
        }
    }
}
