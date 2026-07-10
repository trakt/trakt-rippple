//
//  CollectionManager.swift
//  Rippple
//
//  Created by Kevin Cador on 02/10/2020.
//  Copyright © 2020 Trakt. All rights reserved.
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
            self.collectedMovieItems.removeAll()
            self.collectedShowItems.removeAll()
            self.collectedEpisodeItems.removeAll()
        }.disposed(by: disposeBag)

        refresh()
    }

    func refresh() {
        refreshMovieCollection()
        refreshShowCollection()
        refreshEpisodeCollection()
    }

    static let shared = CollectionManager()

    fileprivate var movieCollection = [Int64]() {
        didSet {
            if movieCollection != oldValue {
                onMovieCollectionChangedTransmitter.broadcast(movieCollection)
            }
        }
    }

    fileprivate var showCollection = [Int64]() {
        didSet {
            if showCollection != oldValue {
                onShowCollectionChangedTransmitter.broadcast(showCollection)
            }
        }
    }

    fileprivate var episodeCollection = [Int64]() {
        didSet {
            if episodeCollection != oldValue {
                onEpisodeCollectionChangedTransmitter.broadcast(episodeCollection)
            }
        }
    }

    fileprivate var collectedMovieItems = [CollectionItem]()
    fileprivate var collectedShowItems = [CollectionItem]()
    fileprivate var collectedEpisodeItems = [CollectionItem]()
}

private extension CollectionManager {
    private func refreshMovieCollection() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchAllCollectionItems(slug: "me",
                                                 type: .movies,
                                                 extended: nil,
                                                 sort: .added) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let collectionItems):
                var ids = [Int64]()
                for item in collectionItems {
                    if let traktId = item.movie?.identifiers.trakt {
                        ids.append(traktId)
                    }
                }

                DispatchQueue.main.async {
                    self.movieCollection = ids
                    self.collectedMovieItems = collectionItems
                }
            case .failure(let error):
                print("refreshMovieCollection request failure \(error)")
            }
        }
    }

    private func refreshShowCollection() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchAllCollectionItems(slug: "me",
                                                 type: .shows,
                                                 extended: nil,
                                                 sort: .added) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let collectionItems):
                var ids = [Int64]()
                for item in collectionItems {
                    if let traktId = item.show?.identifiers.trakt {
                        ids.append(traktId)
                    }
                }

                DispatchQueue.main.async {
                    self.showCollection = ids
                    self.collectedShowItems = collectionItems
                }
            case .failure(let error):
                print("refreshShowCollection request failure \(error)")
            }
        }
    }

    private func refreshEpisodeCollection() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchAllCollectionItems(slug: "me",
                                                 type: .episodes,
                                                 extended: nil,
                                                 sort: .added) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let collectionItems):
                var ids = [Int64]()
                for item in collectionItems {
                    if let traktId = item.episode?.identifiers.trakt {
                        ids.append(traktId)
                    }
                }

                DispatchQueue.main.async {
                    self.episodeCollection = ids
                    self.collectedEpisodeItems = collectionItems
                }
            case .failure(let error):
                print("refreshEpisodeCollection request failure \(error)")
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

    var collectedMediaItem: CollectionItem? {
        switch self {
        case .movie(let movie):
            return CollectionManager.shared.collectedMovieItems.first(where: { $0.movie == movie })
        case .show(let show):
            return CollectionManager.shared.collectedShowItems.first(where: { $0.show == show })
        case .episode(let episode, let show):
            return CollectionManager.shared.collectedEpisodeItems.first(where: { $0.episode == episode && $0.show == show })
        default:
            return nil
        }
    }
}

extension Movie {
    var isInCollection: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CollectionManager.shared.movieCollection.contains(traktId)
    }
}

extension Show {
    var isInCollection: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CollectionManager.shared.showCollection.contains(traktId)
    }
}

extension Episode {
    var isInCollection: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CollectionManager.shared.episodeCollection.contains(traktId)
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
