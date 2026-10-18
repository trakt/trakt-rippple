//
//  CollectionManager.swift
//  Rippple
//
//  Created by Kevin Cador on 02/10/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import UIKit

let (onMovieCollectionChangedTransmitter, onMovieCollectionChangedReceiver) = Receiver<[Int64]>.make(with: .hot)
let (onShowCollectionChangedTransmitter, onShowCollectionChangedReceiver) = Receiver<[Int64]>.make(with: .hot)
let (onEpisodeCollectionChangedTransmitter, onEpisodeCollectionChangedReceiver) = Receiver<[Int64]>.make(with: .hot)

final class CollectionManager: @unchecked Sendable {
    private let disposeBag = DisposeBag()

    private init() {}

    func setup() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refresh()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refresh()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { _ in
            self.refresh()
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.movieCollection.removeAll()
            self.showCollection.removeAll()
            self.episodeCollection.removeAll()
        }.disposed(by: disposeBag)

        refresh()
    }

    func refresh() {
        refreshMovieCollection()
        refreshShowCollection()
    }

    static let shared = CollectionManager()

    /// Collected dates keyed by Trakt id. Shows use their latest collected episode.
    fileprivate var movieCollection = [Int64: Date]() {
        didSet {
            if movieCollection != oldValue {
                onMovieCollectionChangedTransmitter.broadcast(Array(movieCollection.keys))
            }
        }
    }

    fileprivate var showCollection = [Int64: Date]() {
        didSet {
            if showCollection != oldValue {
                onShowCollectionChangedTransmitter.broadcast(Array(showCollection.keys))
            }
        }
    }

    fileprivate var episodeCollection = [Int64: Date]() {
        didSet {
            if episodeCollection != oldValue {
                onEpisodeCollectionChangedTransmitter.broadcast(Array(episodeCollection.keys))
            }
        }
    }
}

private extension CollectionManager {
    private func refreshMovieCollection() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchMinimalMovieCollection { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let movies):
                DispatchQueue.main.async {
                    self.movieCollection = movies
                }
            case .failure(let error):
                print("refreshMovieCollection request failure \(error)")
            }
        }
    }

    /// The shows payload nests every collected episode, so it also fills the episode collection.
    private func refreshShowCollection() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchMinimalShowCollection { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let shows):
                var showCollection = [Int64: Date]()
                var episodeCollection = [Int64: Date]()
                for (showKey, seasons) in shows {
                    guard let showId = Int64(showKey) else { continue }
                    for episodes in seasons.values {
                        for (episodeKey, collectedAt) in episodes {
                            guard let episodeId = Int64(episodeKey) else { continue }
                            episodeCollection[episodeId] = collectedAt
                            showCollection[showId] = max(showCollection[showId] ?? collectedAt, collectedAt)
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.showCollection = showCollection
                    self.episodeCollection = episodeCollection
                }
            case .failure(let error):
                print("refreshShowCollection request failure \(error)")
            }
        }
    }
}

extension MediaModel {
    var isInCollection: Bool {
        switch self {
        case .movie(let movie):
            return movie.isInCollection
        case .show(let show):
            return show.isInCollection
        case .episode(let episode, _):
            return episode.isInCollection
        default:
            return false
        }
    }

    var collectedAt: Date? {
        switch self {
        case .movie(let movie):
            return movie.identifiers.trakt.flatMap { CollectionManager.shared.movieCollection[$0] }
        case .show(let show):
            return show.identifiers.trakt.flatMap { CollectionManager.shared.showCollection[$0] }
        case .episode(let episode, _):
            return episode.identifiers.trakt.flatMap { CollectionManager.shared.episodeCollection[$0] }
        default:
            return nil
        }
    }
}

extension Movie {
    var isInCollection: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CollectionManager.shared.movieCollection[traktId] != nil
    }
}

extension Show {
    var isInCollection: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CollectionManager.shared.showCollection[traktId] != nil
    }
}

extension Episode {
    var isInCollection: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CollectionManager.shared.episodeCollection[traktId] != nil
    }
}

final class CollectedImageView: UIImageView {
    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            switch media {
            case .movie(let movie):
                isHidden = !movie.isInCollection
            case .show(let show):
                isHidden = !show.isInCollection
            case .episode(let episode, _):
                isHidden = !episode.isInCollection
            default:
                isHidden = true
            }
            invalidateCellIntrinsicContentSize()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onMovieCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isInCollection
                case .show(let show):
                    self.isHidden = !show.isInCollection
                case .episode(let episode, _):
                    self.isHidden = !episode.isInCollection
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)

        onShowCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isInCollection
                case .show(let show):
                    self.isHidden = !show.isInCollection
                case .episode(let episode, _):
                    self.isHidden = !episode.isInCollection
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)

        onEpisodeCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isInCollection
                case .show(let show):
                    self.isHidden = !show.isInCollection
                case .episode(let episode, _):
                    self.isHidden = !episode.isInCollection
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)
    }
}
