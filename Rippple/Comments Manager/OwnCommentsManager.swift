//
//  CommentsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 18/08/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation

import Receiver

let (onOwnCommentsChangedTransmitter, onOwnCommentsChangedReceiver) = Receiver<[CommentItem]>.make(with: .hot)

final class OwnCommentsManager {

    private let disposeBag = DisposeBag()

    private init() { }

    func setup() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refreshOwnComments()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshOwnComments()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { settings in
            if settings != nil {
                self.refreshOwnComments()
            } else {
                self.latestOwnComments.removeAll()
            }
        }.disposed(by: disposeBag)

        commentPostedReceiver.listen { _ in
            self.refreshOwnComments()
        }.disposed(by: disposeBag)

        refreshOwnComments()
    }

    static let shared = OwnCommentsManager()

//    func refresh() {
//        refreshOwnComments()
//    }

    fileprivate var latestOwnComments = [CommentItem]() {
        didSet {
            onOwnCommentsChangedTransmitter.broadcast(latestOwnComments)
            print("Own comments count: \(latestOwnComments.count)")
        }
    }
}

private extension OwnCommentsManager {

    private func refreshOwnComments(pageInfo: PageInfo = PageInfo.firstPage(with: 10),
                                    latestOwnComments: [CommentItem] = [CommentItem]()) {
        if SessionManager.shared.isLoggedOut { return }
        guard let slug = UserManager.shared.currentUser?.slug else { return }

        TraktAPIProvider.provider.request(.comments(type: .user(slug: slug),
                                                    pageInfo: pageInfo,
                                                    sortBy: .newest,
                                                    replies: nil),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let commentItems = try response.map([CommentItem].self, using: TraktAPIProvider.decoder)

                    if let response = response.response,
                    let pageInfo = PageInfo(headers: response.allHeaderFields)?.nextPage {
                        DispatchQueue.main.async {
                            if pageInfo.page <= pageInfo.pageCount {
                                self.refreshOwnComments(pageInfo: pageInfo.nextPage,
                                                        latestOwnComments: latestOwnComments + commentItems)
                            } else {
                                self.latestOwnComments = latestOwnComments + commentItems
                            }
                        }
                    }
                } catch {
                    print("refreshOwnComments request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("refreshOwnComments request failure \(error)")
            }
        }
    }
}

extension MediaModel {
    var ownCommentItem: CommentItem? {
        switch self {
        case .movie(let movie):
            return movie.ownCommentItem
        case .show(let show):
            return show.ownCommentItem
        case .episode(let episode, _):
            return episode.ownCommentItem
        case .season(let season, _):
            return season.ownCommentItem
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    var ownCommentItems: [CommentItem] {
        var commentItems = [CommentItem]()
        for commentItem in OwnCommentsManager.shared.latestOwnComments {
            switch self {
            case .movie(let movie):
                if commentItem.movie == movie {
                    commentItems.append(commentItem)
                }
            case .show(let show):
                if commentItem.show == show {
                    commentItems.append(commentItem)
                }
            case .episode(let episode, _):
                if commentItem.episode == episode {
                    commentItems.append(commentItem)
                }
            case .season(let season, _):
                if commentItem.season == season {
                    commentItems.append(commentItem)
                }
            case .list:
                continue
            case .showProgress:
                continue
            }
        }
        return commentItems
    }
}

extension Movie {
    var ownCommentItem: CommentItem? {
        for commentItem in OwnCommentsManager.shared.latestOwnComments {
            if let movie = commentItem.movie, movie == self {
                return commentItem
            }
        }
        return nil
    }
}

extension Show {
    var ownCommentItem: CommentItem? {
        for commentItem in OwnCommentsManager.shared.latestOwnComments {
            if let show = commentItem.show, show == self, commentItem.episode == nil, commentItem.season == nil {
                return commentItem
            }
        }
        return nil
    }
}

extension Season {
    var ownCommentItem: CommentItem? {
        for commentItem in OwnCommentsManager.shared.latestOwnComments {
            if let season = commentItem.season, season == self {
                return commentItem
            }
        }
        return nil
    }
}

extension Episode {
    var ownCommentItem: CommentItem? {
        for commentItem in OwnCommentsManager.shared.latestOwnComments {
            if let episode = commentItem.episode, episode == self {
                return commentItem
            }
        }
        return nil
    }
}
