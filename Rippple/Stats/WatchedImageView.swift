//
//  WatchedImageView.swift
//  Rippple
//
//  Created by Kevin Cador on 09/12/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver
import UIKit

final class WatchedImageView: UIImageView {
    private let disposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()

        onMarkWatchedReceiver.hotOnly().listen { [weak self] media in
            guard let self = self else { return }
            if media == self.media {
                self.reset()
            }
        }.disposed(by: disposeBag)

        onRemoveWatchMediaReceiver.hotOnly().listen { [weak self] media in
            guard let self = self else { return }
            if media == self.media {
                self.reset()
            }
        }.disposed(by: disposeBag)

        onCompletedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if case .show(let show) = self.media {
                DispatchQueue.main.async {
                    if show.isCompleted {
                        self.isHidden = false
                    } else {
                        self.isHidden = true
                    }
                }
            }
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.reset()
        }.disposed(by: disposeBag)
    }

    private func reset() {
        switch media {
        case .movie(let movie):
            cancellable = fetch(type: .movies, traktId: movie.identifiers.trakt!)
        case .episode(let episode, _):
            cancellable = fetch(type: .episodes, traktId: episode.identifiers.trakt!)
        default:
            isHidden = true
        }
    }

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        cancelCancellable()
    }

    var media: MediaModel? {
        willSet {
            cancelCancellable()
        }
        didSet {
            defer {
                invalidateCellIntrinsicContentSize()
            }
            isHidden = true
            switch media {
            case .movie(let movie):
                if movie.isWatched {
                    isHidden = false
                    return
                }
                cancellable = fetch(type: .movies, traktId: movie.identifiers.trakt!)
            case .episode(let episode, _):
                if episode.isRecentlyWatched {
                    isHidden = false
                    return
                }
                cancellable = fetch(type: .episodes, traktId: episode.identifiers.trakt!)
            case .show(let show):
                if show.isCompleted {
                    isHidden = false
                } else {
                    isHidden = true
                }
            default:
                isHidden = true
            }
        }
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    private func fetch(type: HistoryMediaType, traktId: Int64) -> Cancellable {
        return TraktAPIProvider.provider.request(.isWatched(type: type, id: traktId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    if let response = response.response {
                        let allHTTPHeaders = response.allHeaderFields
                        if let itemCount = allHTTPHeaders["x-pagination-item-count"] as? String {
                            DispatchQueue.main.async {
                                if Int(itemCount)! > 0 {
                                    self.isHidden = false
                                } else {
                                    self.isHidden = true
                                }
                                self.invalidateCellIntrinsicContentSize()
                            }
                        }
                    }
                } catch {
                    print("Stats request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                if error.localizedDescription == "cancelled" { return }
                print("Stats request failure \(error)")
            }
        }
    }
}
