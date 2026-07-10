//
//  LikeManager.swift
//  Rippple
//
//  Created by Kevin Cador on 05/12/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation
import Receiver

let (onListLikedTransmitter, onListLikedReceiver) = Receiver<Identifiers>.make(with: .hot)
let (onLikedListsChangedTransmitter, onLikedListsChangedReceiver) = Receiver<[List]>.make(with: .warm(upTo: 1))

final class LikeManager {
    private let disposeBag = DisposeBag()

    private init() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refreshListLikes()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshListLikes()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { _ in
            self.refreshListLikes()
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.listLikes.removeAll()
        }.disposed(by: disposeBag)
    }

    static let shared = LikeManager()

    func startManaging() {}

    private var listLikes = [List]() {
        didSet {
            if listLikes == oldValue { return }
            onLikedListsChangedTransmitter.broadcast(listLikes)
        }
    }

    func liked(list: List) -> Bool {
        return listLikes.contains(list)
    }

    func like(list: List) {
        func add(list: List) {
            if listLikes.firstIndex(of: list) == nil {
                listLikes.append(list)
            }
        }

        func remove(list: List) {
            if let index = listLikes.firstIndex(of: list) {
                listLikes.remove(at: index)
            }
        }

        if liked(list: list) {
            // Remove it from the list directly
            remove(list: list)
            TraktAPIProvider.provider.request(.unlikeList(slug: list.user.slug, id: list.identifiers.trakt!)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        _ = try moyaResponse.filterSuccessfulStatusCodes()
                        remove(list: list)
                        SwiftMessages.show(message: "👍 Like removed")
                        onListLikedTransmitter.broadcast(list.identifiers)
                    } catch {
                        add(list: list)
                        SwiftMessages.show(message: "😓 Unlike failed", style: .error(error))
                    }
                case .failure(let error):
                    add(list: list)
                    SwiftMessages.show(message: "😓 Unlike failed", style: .error(error))
                }
            }
        } else {
            // Add it to the list directly
            add(list: list)
            TraktAPIProvider.provider.request(.likeList(slug: list.user.slug, id: list.identifiers.trakt!)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        _ = try moyaResponse.filterSuccessfulStatusCodes()

                        add(list: list)
                        SwiftMessages.show(message: "👍 List liked")
                        onListLikedTransmitter.broadcast(list.identifiers)
                    } catch {
                        remove(list: list)
                        SwiftMessages.show(message: "😓 Like failed", style: .error(error))
                    }
                case .failure(let error):
                    remove(list: list)
                    SwiftMessages.show(message: "😓 Like failed", style: .error(error))
                }
            }
        }
    }
}

private extension LikeManager {
    private func refreshListLikes(pageInfo: PageInfo = PageInfo.firstPage(with: 50),
                                  likes: [ListLike] = [ListLike]()) {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.likes(type: .lists, pageInfo: pageInfo), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let likedItems = try response.map([ListLike].self, using: TraktAPIProvider.decoder)

                    if let response = response.response,
                       let pageInfo = PageInfo(headers: response.allHeaderFields)?.nextPage {
                        DispatchQueue.main.async {
                            if pageInfo.page <= pageInfo.pageCount {
                                self.refreshListLikes(pageInfo: pageInfo,
                                                      likes: likes + likedItems)
                            } else {
                                self.listLikes = (likes + likedItems).sorted { $0.likedAt > $1.likedAt }.map { $0.list }
                            }
                        }
                    }
                } catch {
                    print("Likes request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("Likes request failure \(error)")
            }
        }
    }
}

extension List {
    var liked: Bool {
        return LikeManager.shared.liked(list: self)
    }

    func like() {
        LikeManager.shared.like(list: self)
    }
}
