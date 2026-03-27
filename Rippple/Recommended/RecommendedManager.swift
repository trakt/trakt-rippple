//
//  RecommendedManager.swift
//  Rippple
//
//  Created by Kevin Cador on 22/09/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation
import UIKit

import Receiver

let (onRecommendedChangedTransmitter, onRecommendedChangedReceiver) = Receiver<[Int64]>.make(with: .hot)

final class RecommendedManager {

    private let disposeBag = DisposeBag()

    private init() { }

    func setup() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refreshRecommended()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshRecommended()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { _ in
            self.refreshRecommended()
        }.disposed(by: disposeBag)

        refreshRecommended()
    }

    func refresh() {
        refreshRecommended()
    }

    static let shared = RecommendedManager()

    fileprivate var recommended = [Int64]() {
        didSet {
            if self.recommended != oldValue {
                onRecommendedChangedTransmitter.broadcast(recommended)
            }
        }
    }

    fileprivate var recommendedItems = [WatchlistItem]()
}

private extension RecommendedManager {

    private func refreshRecommended() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchAllRecommendedItems(slug: "me",
                                                  type: nil,
                                                  extended: .full,
                                                  sort: .added) { result in
            switch result {
            case let .success(favorites):
                let ids = favorites.compactMap(\.traktId)

                DispatchQueue.main.async {
                    self.recommendedItems = favorites
                    self.recommended = ids
                }
            case let .failure(error):
                print("refreshRecommended request failure \(error)")
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
    var isRecommended: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return RecommendedManager.shared.recommended.contains(traktId)
    }
}

extension Show {
    var isRecommended: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return RecommendedManager.shared.recommended.contains(traktId)
    }
}

extension MediaModel {
    var recommendedMediaItem: WatchlistItem? {
        switch self {
        case .movie(let movie):
            return RecommendedManager.shared.recommendedItems.first(where: { $0.movie == movie })
        case .show(let show):
            return RecommendedManager.shared.recommendedItems.first(where: { $0.show == show })
        default:
            return nil
        }
    }
}

final class RecommendedImageView: UIImageView {

    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            switch media {
            case .movie(let movie):
                isHidden = !movie.isRecommended
            case .show(let show):
                isHidden = !show.isRecommended
            default:
                isHidden = true
            }
            invalidateCellIntrinsicContentSize()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onRecommendedChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isRecommended
                case .show(let show):
                    self.isHidden = !show.isRecommended
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)
    }
}
