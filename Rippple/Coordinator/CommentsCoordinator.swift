//
//  CommentsCoordinator.swift
//  Rippple
//
//  Created by Kevin Cador on 23/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = removingDuplicates()
    }
}

final class CommentsCoordinator {
    var copy: CommentsCoordinator {
        switch type! {
        case .user(let user):
            return CommentsCoordinator(type: .user(user))
        case .replies(let commentModel, let openKeyboard):
            return CommentsCoordinator(type: .replies(commentModel, openKeyboard))
        case .media(let mediaModel):
            return CommentsCoordinator(type: .media(mediaModel))
        case .feed:
            return CommentsCoordinator(type: .feed)
        case .forYou:
            return CommentsCoordinator(type: .forYou)
        case .preview(let commentModel):
            return CommentsCoordinator(type: .preview(commentModel))
        case .trending:
            return CommentsCoordinator(type: .trending)
        }
    }

    enum ListType: Equatable {
        static func == (lhs: CommentsCoordinator.ListType, rhs: CommentsCoordinator.ListType) -> Bool {
            switch (lhs, rhs) {
            case (.user(let left), .user(let right)): return left == right
            case (.replies(let left, _), .replies(let right, _)): return left == right
            case (.media(let left), .media(let right)): return left == right
            case (.feed, .feed): return true
            case (.forYou, .forYou): return true
            case (.trending, .trending): return true
            case (.preview(let left), .preview(let right)): return left == right
            default: return false
            }
        }

        case user(User)
        case replies(CommentModel, Bool) // Bool = should show keyboard after showing the reply view
        case media(MediaModel)
        case feed
        case trending
        case forYou
        case preview(CommentModel)

        var isReplies: Bool {
            switch self {
            case .replies: return true
            default: return false
            }
        }

        var isMedia: Bool {
            switch self {
            case .media: return true
            default: return false
            }
        }

        var isPreview: Bool {
            switch self {
            case .preview: return true
            default: return false
            }
        }

        var isPreviewReply: Bool {
            switch self {
            case .preview(let commentModel):
                if commentModel.comment.parentIdentifier != 0 {
                    return true
                }
                return false
            default: return false
            }
        }

        var isForYou: Bool {
            switch self {
            case .forYou: return true
            default: return false
            }
        }

        var isTrending: Bool {
            switch self {
            case .trending: return true
            default: return false
            }
        }

        var isFeed: Bool {
            switch self {
            case .feed: return true
            default: return false
            }
        }
    }

    private let disposeBag = DisposeBag()

    private var comments = [CommentModel]() {
        didSet {
            onCommentsChangedTransmitter.broadcast(comments.removingDuplicates())
        }
    }

    var commentCount: Int {
        return comments.count
    }

    let (onCommentsChangedTransmitter, onCommentsChangedReceiver) = Receiver<[CommentModel]?>.make(with: .hot)

    var type: ListType! {
        didSet {
            if type != oldValue {
                if let request = request {
                    request.cancel()
                }
                request = nil
                isLoading = false
                currentPage = nil
                error = nil
                comments = [CommentModel]()
            }
            switch type! {
            case .user:
                spoilerStrategy = .hideAllSpoilers
            case .replies:
                spoilerStrategy = .showAllSpoilers
            case .media:
                spoilerStrategy = .hideAllSpoilers
            case .feed:
                spoilerStrategy = .hideAllSpoilers
            case .forYou:
                spoilerStrategy = .hideAllSpoilers
            case .preview:
                spoilerStrategy = .hideInlineSpoilers
            case .trending:
                spoilerStrategy = .hideAllSpoilers
            }
        }
    }

    var spoilerStrategy = SpoilerStrategy.showAllSpoilers

    deinit {
        print("DEINITING COORDINATOR OF COMMENTS")
    }

    /// Empty
    var showEmpty: Bool {
        if type.isPreview { return false }

        guard let currentPage = currentPage else {
            return false
        }

        if currentPage.itemCount == 0 {
            return true
        }

        return false
    }

    // Paging Management
    private var isLoading = false
    private let firstPage = PageInfo.firstPage
    private var currentPage: PageInfo?
    var showLoading: Bool {
        if type.isPreview { return false }

        if showError {
            return false
        }

        // first page hasn't been loaded yet
        guard let currentPage = currentPage else {
            return true
        }

        // all page not loaded yet
        if currentPage.page < currentPage.pageCount {
            return true
        }

        return false
    }

    /// Error Management
    private var error: Error? {
        didSet {
            if let error = error {
                print("CommentsCoordinator Error \(error)")
            }
        }
    }

    var showError: Bool {
        return error != nil
    }

    var errorMessage: String {
        let errorMessage = error?.localizedDescription ?? ""
        if let moyaError = error as? MoyaError, let response = moyaError.response {
            if response.statusCode == 401, case .user = type! {
                return "This profile is private.\nFollow this profile on trakt and you'll be able to see this profile once your follow request is accepted."
            }
            return errorMessage + " (\(response.statusCode))"
        }
        return errorMessage
    }

    /// request
    private var request: Cancellable?

    convenience init(type: ListType) {
        self.init()

        if let rawValue = UserDefaults.standard.string(forKey: "CommentsCoordinator.sort"), let savedSort = CommentsSort(rawValue: rawValue) {
            sort = savedSort
        }

        self.type = type
        switch self.type! {
        case .user(let user):
            spoilerStrategy = .hideAllSpoilers
            if user.isBlocked {
                isLoading = false
                currentPage = PageInfo(page: 0, limit: 0, pageCount: 0, itemCount: 0)
            }
        case .replies(let commentModel, _):
            spoilerStrategy = .showAllSpoilers
            if commentModel.comment.user.isBlocked || commentModel.comment.isFiltered {
                isLoading = false
                currentPage = PageInfo(page: 0, limit: 0, pageCount: 0, itemCount: 0)
            }
        case .media:
            spoilerStrategy = .hideAllSpoilers
        case .feed:
            spoilerStrategy = .hideAllSpoilers
        case .forYou:
            spoilerStrategy = .hideAllSpoilers
        case .preview:
            spoilerStrategy = .hideInlineSpoilers
        case .trending:
            spoilerStrategy = .hideAllSpoilers
        }

        // skip the first one
        onOwnCommentsChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }

            switch self.type! {
            case .user(let user):
                if user.isCurrentUser {
                    self.reset()
                }
            case .replies:
                self.reset()
            case .media:
                self.reset()
            case .feed:
                break
            case .forYou:
                break
            case .preview:
                break
            case .trending:
                break
            }
        }

        commentModelRefreshedReceiver.listen { [weak self] commentModel in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let index = self.comments.firstIndex(of: commentModel) {
                    self.comments[index] = commentModel
                }
            }
        }.disposed(by: disposeBag)

        userBlockedReceiver.listen { [weak self] unblockedUser in
            guard let self = self else { return }
            switch self.type! {
            case .user(let user):
                if user == unblockedUser {
                    self.reset()
                }
            case .replies, .media, .feed, .forYou, .preview, .trending:
                break
            }
        }.disposed(by: disposeBag)
    }

    func reset() {
        if let request = request {
            request.cancel()
        }
        request = nil
        isLoading = false
        currentPage = nil
        error = nil
        comments = [CommentModel]()
        fetchNext()
    }

    /// Sorting
    var sort = CommentsSort.likes {
        didSet {
            UserDefaults.standard.set(sort.rawValue, forKey: "CommentsCoordinator.sort")
            UserDefaults.standard.synchronize()

            reset()
        }
    }
}

extension CommentsCoordinator {
    private func service(with pageInfo: PageInfo) -> TraktAPIService {
        switch type! {
        case .media(let media):
            switch media {
            case .movie(let movie):
                return .comments(type: .movie(movieId: movie.identifiers.trakt!),
                                 pageInfo: pageInfo,
                                 sortBy: sort,
                                 replies: nil)
            case .show(let show):
                return .comments(type: .show(showId: show.identifiers.trakt!),
                                 pageInfo: pageInfo,
                                 sortBy: sort,
                                 replies: nil)
            case .episode(let episode, let show):
                return .comments(type: .episode(showId: show.identifiers.trakt!,
                                                season: episode.season,
                                                episode: episode.number),
                                 pageInfo: pageInfo,
                                 sortBy: sort,
                                 replies: nil)
            case .season(let season, let show):
                return .comments(type: .season(showId: show.identifiers.trakt!,
                                               season: season.number),
                                 pageInfo: pageInfo,
                                 sortBy: sort,
                                 replies: nil)
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
        case .user(let user):
            return .comments(type: .user(slug: user.slug),
                             pageInfo: pageInfo,
                             sortBy: nil,
                             replies: .include)
        case .replies(let commentModel, _):
            return .comments(type: .comment(commentId: commentModel.comment.identifier),
                             pageInfo: pageInfo,
                             sortBy: nil,
                             replies: nil)
        case .feed:
            return .comments(type: .all,
                             pageInfo: pageInfo,
                             sortBy: nil,
                             replies: nil)
        case .forYou:
            return .comments(type: .all,
                             pageInfo: pageInfo,
                             sortBy: nil,
                             replies: nil)
        case .preview:
            fatalError()
        case .trending:
            return .comments(type: .trending,
                             pageInfo: pageInfo,
                             sortBy: nil,
                             replies: nil)
        }
    }
}

extension CommentsCoordinator {
    func fetchFirst() {
        switch type! {
        case .user:
            fetchComments(pageInfo: PageInfo.firstPage(with: 25))
        case .replies:
            fetchComments(pageInfo: PageInfo.firstPage(with: 25))
        case .media:
            fetchComments(pageInfo: PageInfo.firstPage(with: 25))
        case .forYou:
            fetchComments(pageInfo: PageInfo.firstPage(with: 25))
        case .feed, .trending:
            fetchComments(pageInfo: PageInfo.firstPage(with: 25))
        case .preview:
            processPreviewComment()
        }
    }

    func fetchNext() {
        guard let currentPage = currentPage else {
            fetchFirst()
            return
        }

        fetchComments(pageInfo: currentPage.nextPage)
    }

    func retry() {
        error = nil
        fetchNext()
    }
}

extension CommentsCoordinator {
    private func processPreviewComment() {
        precondition(type.isReplies == false)

        switch type! {
        case .preview(let commentModel):
            comments = [commentModel]
        default:
            fatalError()
        }

        currentPage = PageInfo(page: 1, limit: 1, pageCount: 1, itemCount: 1)
    }

    private func appendComments(comments: [Comment], media: MediaModel) {
        self.comments.append(contentsOf: comments.map { CommentModel(media: media, comment: $0, spoilerStrategy: spoilerStrategy) })
    }

    private func appendComments(comments: [CommentItem]) {
        self.comments.append(contentsOf: comments.filter { $0.type != .list }.map { CommentModel(commentItem: $0, spoilerStrategy: spoilerStrategy) })
    }

    private func fetchComments(pageInfo: PageInfo) {
        if pageInfo.page > pageInfo.nextPage.page {
            return
        }

        if isLoading {
            return
        }
        isLoading = true

        print("Fetching page \(pageInfo.page) for service \(service(with: pageInfo))")

        request = TraktAPIProvider.provider.request(service(with: pageInfo), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            defer {
                self.isLoading = false
                self.request = nil
            }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    do {
                        if let response = response.response,
                           let pageInfo = PageInfo(headers: response.allHeaderFields) {
                            self.currentPage = pageInfo
                        }
                        self.error = nil
                        self.isLoading = false

                        switch self.type! {
                        case .media(let media):
                            let comments = try response.map([Comment].self, using: TraktAPIProvider.decoder)
                            self.appendComments(comments: comments, media: media)
                        case .replies(let commentModel, _):
                            let comments = try response.map([Comment].self, using: TraktAPIProvider.decoder)
                            self.appendComments(comments: comments, media: commentModel.media)
                        case .user, .feed, .trending:
                            let commentItems = try response.map([CommentItem].self, using: TraktAPIProvider.decoder).filter { $0.type != .list && $0.type != .officiallist && $0.type != .unknown }
                            self.appendComments(comments: commentItems)
                        case .forYou:
                            let commentItems = try response.map([CommentItem].self, using: TraktAPIProvider.decoder).filter { $0.type != .list && $0.type != .officiallist && $0.type != .unknown }
                            let filteredCommentItems = ForYouManager.shared.filterForYou(comments: commentItems)
                            self.appendComments(comments: filteredCommentItems)
                        case .preview:
                            fatalError()
                        }
                    } catch {
                        print("Error while decoding comment: \(error)")
                    }
                } catch {
                    self.error = error
                    self.onCommentsChangedTransmitter.broadcast(nil)
                }
            case .failure(let error):
                if let request = self.request, request.isCancelled == false {
                    self.error = error
                    self.onCommentsChangedTransmitter.broadcast(nil)
                }
            }
        }
    }
}
