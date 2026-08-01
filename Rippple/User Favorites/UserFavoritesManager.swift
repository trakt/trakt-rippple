//
//  UserFavoritesManager.swift
//  Rippple
//
//  Created by Kevin Cador on 22/09/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import UIKit

let (onUserFavoritesChangedTransmitter, onUserFavoritesChangedReceiver) = Receiver<[Int64]>.make(with: .hot)

final class UserFavoritesManager {
    private let disposeBag = DisposeBag()

    private init() {}

    func setup() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refreshUserFavorites()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshUserFavorites()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { _ in
            self.refreshUserFavorites()
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.userFavorites.removeAll()
            self.userFavoriteItems.removeAll()
        }.disposed(by: disposeBag)

        refreshUserFavorites()
    }

    func refresh() {
        refreshUserFavorites()
    }

    static let shared = UserFavoritesManager()

    fileprivate var userFavorites = [Int64]() {
        didSet {
            if userFavorites != oldValue {
                onUserFavoritesChangedTransmitter.broadcast(userFavorites)
            }
        }
    }

    fileprivate var userFavoriteItems = [WatchlistItem]()
}

private extension UserFavoritesManager {
    private func refreshUserFavorites() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchAllRecommendedItems(slug: "me",
                                                  type: nil,
                                                  extended: .full,
                                                  sort: .added) { result in
            switch result {
            case .success(let favorites):
                let ids = favorites.compactMap(\.traktId)

                DispatchQueue.main.async {
                    self.userFavoriteItems = favorites
                    self.userFavorites = ids
                }
            case .failure(let error):
                print("refreshUserFavorites request failure \(error)")
            }
        }
    }
}

private extension WatchlistItem {
    var traktId: Int64? {
        switch type {
        case .movie:
            movie?.identifiers.trakt
        case .show:
            show?.identifiers.trakt
        case .season:
            season?.identifiers.trakt
        case .episode:
            episode?.identifiers.trakt
        case .list, .officiallist:
            list?.identifiers.trakt
        case .unknown:
            nil
        }
    }
}

extension Movie {
    var isUserFavorite: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return UserFavoritesManager.shared.userFavorites.contains(traktId)
    }
}

extension Show {
    var isUserFavorite: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return UserFavoritesManager.shared.userFavorites.contains(traktId)
    }
}

extension MediaModel {
    var userFavoriteMediaItem: WatchlistItem? {
        switch self {
        case .movie(let movie):
            return UserFavoritesManager.shared.userFavoriteItems.first(where: { $0.movie == movie })
        case .show(let show):
            return UserFavoritesManager.shared.userFavoriteItems.first(where: { $0.show == show })
        default:
            return nil
        }
    }
}

final class UserFavoritesImageView: UIImageView {
    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            switch media {
            case .movie(let movie):
                isHidden = !movie.isUserFavorite
            case .show(let show):
                isHidden = !show.isUserFavorite
            default:
                isHidden = true
            }
            invalidateCellIntrinsicContentSize()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onUserFavoritesChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isUserFavorite
                case .show(let show):
                    self.isHidden = !show.isUserFavorite
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)
    }
}
