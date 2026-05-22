//
//  ListedImageView.swift
//  Rippple
//
//  Created by Kevin Cador on 07/05/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver

final class ListedImageView: UIImageView {
    private let disposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()

        onListChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.reset()
        }.disposed(by: disposeBag)
    }

    private func reset() {
        guard media != nil else { return }
        cancellable = fetch()
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
            reset()
        }
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    private func fetch() -> Cancellable {
        let service: TraktAPIService = {
            switch self.media! {
            case .movie(let movie):
                return .movieListed(id: movie.identifiers.trakt!)
            case .show(let show):
                return .showListed(id: show.identifiers.trakt!)
            case .episode(let episode, let show):
                return .episodeListed(id: show.identifiers.trakt!,
                                      season: episode.season,
                                      episode: episode.number)
            case .season(let season, let show):
                return .seasonListed(id: show.identifiers.trakt!,
                                     season: season.number)
            case .list:
                fatalError("List not handled for fetching listed")
            case .showProgress:
                fatalError("showProgress not handled for fetching listed")
            }
        }()

        return TraktAPIProvider.noChacheProvider.request(service,
                                                         callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let lists = try response.map([List].self, using: TraktAPIProvider.decoder).filter { $0.type == "personal" }

                    DispatchQueue.main.async {
                        if lists.count > 0 {
                            self.isHidden = false
                        } else {
                            self.isHidden = true
                        }
                        self.invalidateCellIntrinsicContentSize()
                    }
                } catch {
                    print("Listed request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("Listed request failure \(error)")
            }
        }
    }
}
