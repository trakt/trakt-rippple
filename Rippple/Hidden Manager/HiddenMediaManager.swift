//
//  HiddenMediaManager.swift
//  Rippple
//
//  Created by Kevin Cador on 12/07/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation

import Receiver

import TinyStorage

let (onShowsHiddenFromProgressMediaChangedTransmitter, onShowsHiddenFromProgressMediaChangedReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
let (onShowsHiddenFromCalendarMediaChangedTransmitter, onShowsHiddenFromCalendarMediaChangedReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
let (onMoviesHiddenFromCalendarMediaChangedTransmitter, onMoviesHiddenFromCalendarMediaChangedReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
let (onUsersHiddenFromCommentsChangedTransmitter, onUsersHiddenFromCommentsChangedReceiver) = Receiver<[User]>.make(with: .warm(upTo: 1))
let (onShowsDroppedMediaChangedTransmitter, onShowsDroppedMediaChangedReceiver) = Receiver<[HiddenShow]>.make(with: .warm(upTo: 1))

final class HiddenMediaManager {

    private let disposeBag = DisposeBag()

    private init() { }

    private var lastShowsCheck: Date = .now

    func setup() {
        if let array = TinyStorage.cache.retrieve(type: [MediaModel].self, forKey: "HiddenMediaManager.hiddenMediaList") {
            showsHiddenFromProgressMediaList = array
        }

        if let array = TinyStorage.cache.retrieve(type: [MediaModel].self, forKey: "HiddenMediaManager.showsHiddenFromCalendarMediaList") {
            showsHiddenFromCalendarMediaList = array
        }

        if let array = TinyStorage.cache.retrieve(type: [MediaModel].self, forKey: "HiddenMediaManager.moviesHiddenFromCalendarMediaList") {
            moviesHiddenFromCalendarMediaList = array
        }

        if let array = TinyStorage.cache.retrieve(type: [User].self, forKey: "HiddenMediaManager.usersHiddenFromCommentsList") {
            usersHiddenFromCommentsList = array
        }

        if let array = TinyStorage.cache.retrieve(type: [HiddenShow].self, forKey: "HiddenMediaManager.showsDroppedList") {
            showsDroppedList = array
        }

        onLastDroppedShowActivitiesChangedReceiver.listen { _ in
            self.refreshDroppedShows()
        }.disposed(by: disposeBag)

        onLastHiddenShowActivitiesChangedReceiver.listen { lastShowsActivities in
            if self.lastShowsCheck < lastShowsActivities.hiddenAt {
                self.lastShowsCheck = .now
                self.refreshHiddenShowsFromProgress()
            }
        }.disposed(by: disposeBag)

        onLastHiddenUsersFromCommentsActivitiesChangedReceiver.listen { _ in
            self.refreshHiddenUsersFromComments()
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshHiddenShowsFromCalendar()
                    self.refreshHiddenMoviesFromCalendar()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { _ in
            self.refresh()
        }.disposed(by: disposeBag)

        refresh()
    }

    static let shared = HiddenMediaManager()

    func refresh() {
        lastShowsCheck = .now
        refreshHiddenShowsFromProgress()
        refreshHiddenShowsFromCalendar()
        refreshHiddenMoviesFromCalendar()
        refreshHiddenUsersFromComments()
        refreshDroppedShows()
    }

    fileprivate var showsHiddenFromProgressSet = Set<Int64>()
    fileprivate var seasonsHiddenFromProgressSet = Set<Int64>()
    private var showsHiddenFromProgressMediaList: [MediaModel]? {
        didSet {
            guard let showsHiddenFromProgressMediaList = showsHiddenFromProgressMediaList else { return }
            if showsHiddenFromProgressMediaList == oldValue { return }

            if let array = TinyStorage.cache.retrieve(type: [MediaModel].self, forKey: "HiddenMediaManager.hiddenMediaList"),
                array != showsHiddenFromProgressMediaList {
                for season in Set(showsHiddenFromProgressMediaList).symmetricDifference(Set(oldValue ?? [MediaModel]())).filter({ $0.season != nil }) {
                    ProgressManager.shared.refreshProgress(for: season.show!)
                }
            }

            seasonsHiddenFromProgressSet = Set(showsHiddenFromProgressMediaList.compactMap { $0.season?.identifiers.trakt })
            showsHiddenFromProgressSet = Set(showsHiddenFromProgressMediaList.compactMap { $0.showShow?.identifiers.trakt })
            onShowsHiddenFromProgressMediaChangedTransmitter.broadcast(showsHiddenFromProgressMediaList)

            TinyStorage.cache.store(showsHiddenFromProgressMediaList, forKey: "HiddenMediaManager.hiddenMediaList")
        }
    }
    var showsHiddenFromProgressCount: Int {
        return showsHiddenFromProgressSet.count
    }

    var showsHiddenFromCalendarMediaList: [MediaModel]? {
        didSet {
            guard let showsHiddenFromCalendarMediaList = showsHiddenFromCalendarMediaList else { return }
            if showsHiddenFromCalendarMediaList == oldValue { return }
            onShowsHiddenFromCalendarMediaChangedTransmitter.broadcast(showsHiddenFromCalendarMediaList)
            TinyStorage.cache.store(showsHiddenFromCalendarMediaList, forKey: "HiddenMediaManager.showsHiddenFromCalendarMediaList")
        }
    }

    var showsDroppedList: [HiddenShow]? {
        didSet {
            guard let showsDroppedList = showsDroppedList else { return }
            if showsDroppedList == oldValue { return }
            onShowsDroppedMediaChangedTransmitter.broadcast(showsDroppedList)
            TinyStorage.cache.store(showsDroppedList, forKey: "HiddenMediaManager.showsDroppedList")
        }
    }

    var moviesHiddenFromCalendarMediaList: [MediaModel]? {
        didSet {
            guard let moviesHiddenFromCalendarMediaList = moviesHiddenFromCalendarMediaList else { return }
            if moviesHiddenFromCalendarMediaList == oldValue { return }
            onMoviesHiddenFromCalendarMediaChangedTransmitter.broadcast(moviesHiddenFromCalendarMediaList)
            TinyStorage.cache.store(moviesHiddenFromCalendarMediaList, forKey: "HiddenMediaManager.moviesHiddenFromCalendarMediaList")
        }
    }

    var usersHiddenFromCommentsList: [User]? {
        didSet {
            guard let usersHiddenFromCommentsList = usersHiddenFromCommentsList else { return }
            if usersHiddenFromCommentsList == oldValue { return }
            onUsersHiddenFromCommentsChangedTransmitter.broadcast(usersHiddenFromCommentsList)
            TinyStorage.cache.store(usersHiddenFromCommentsList, forKey: "HiddenMediaManager.usersHiddenFromCommentsList")
        }
    }
}

private extension HiddenMediaManager {

    private func refreshHiddenShowsFromProgress(pageInfo: PageInfo = PageInfo.firstPage(with: 50), hiddenMedia: [MediaItem] = [MediaItem]()) {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.hidden(section: .progressWatched,
                                                  type: nil,
                                                  extended: .full,
                                                  pageInfo: pageInfo),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let items = try response.map([MediaItem].self, using: TraktAPIProvider.decoder)

                    if let response = response.response,
                    let pageInfo = PageInfo(headers: response.allHeaderFields)?.nextPage {
                        DispatchQueue.main.async {
                            if pageInfo.page <= pageInfo.pageCount {
                                self.refreshHiddenShowsFromProgress(pageInfo: pageInfo, hiddenMedia: hiddenMedia + items)
                            } else {
                                self.showsHiddenFromProgressMediaList = (hiddenMedia + items)
                                    .sorted { ($0.hiddenAt ?? .distantPast) > ($1.hiddenAt ?? .distantPast) }
                                    .map { MediaModel(item: $0) }
                            }
                        }
                    }
                } catch {
                    print("refreshHiddenShowsFromProgress request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("refreshHiddenShowsFromProgress request failure \(error)")
            }
        }
    }

    private func refreshDroppedShows(pageInfo: PageInfo = PageInfo.firstPage(with: 50), droppedMedia: [HiddenShow] = [HiddenShow]()) {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.hidden(section: .dropped,
                                                  type: .show,
                                                  extended: .full,
                                                  pageInfo: pageInfo),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let items = try response.map([HiddenShow].self, using: TraktAPIProvider.decoder)

                    if let response = response.response,
                    let pageInfo = PageInfo(headers: response.allHeaderFields)?.nextPage {
                        DispatchQueue.main.async {
                            if pageInfo.page <= pageInfo.pageCount {
                                self.refreshDroppedShows(pageInfo: pageInfo, droppedMedia: droppedMedia + items)
                            } else {
                                self.showsDroppedList = droppedMedia + items
                            }
                        }
                    }
                } catch {
                    print("refreshDroppedShows request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("refreshDroppedShows request failure \(error)")
            }
        }
    }

    private func refreshHiddenShowsFromCalendar(pageInfo: PageInfo = PageInfo.firstPage(with: 50), hiddenMedia: [MediaModel] = [MediaModel]()) {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.hidden(section: .calendar,
                                                  type: .show,
                                                  extended: nil,
                                                  pageInfo: pageInfo),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let items = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).map { MediaModel(item: $0) }

                    if let response = response.response,
                    let pageInfo = PageInfo(headers: response.allHeaderFields)?.nextPage {
                        DispatchQueue.main.async {
                            if pageInfo.page <= pageInfo.pageCount {
                                self.refreshHiddenShowsFromCalendar(pageInfo: pageInfo, hiddenMedia: hiddenMedia + items)
                            } else {
                                self.showsHiddenFromCalendarMediaList = hiddenMedia + items
                            }
                        }
                    }
                } catch {
                    print("refreshHiddenShowsFromCalendar request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("refreshHiddenShowsFromCalendar request failure \(error)")
            }
        }
    }

    private func refreshHiddenMoviesFromCalendar(pageInfo: PageInfo = PageInfo.firstPage(with: 50), hiddenMedia: [MediaModel] = [MediaModel]()) {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.hidden(section: .calendar,
                                                  type: .movie,
                                                  extended: nil,
                                                  pageInfo: pageInfo),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let items = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).map { MediaModel(item: $0) }

                    if let response = response.response,
                    let pageInfo = PageInfo(headers: response.allHeaderFields)?.nextPage {
                        DispatchQueue.main.async {
                            if pageInfo.page <= pageInfo.pageCount {
                                self.refreshHiddenMoviesFromCalendar(pageInfo: pageInfo, hiddenMedia: hiddenMedia + items)
                            } else {
                                self.moviesHiddenFromCalendarMediaList = hiddenMedia + items
                            }
                        }
                    }
                } catch {
                    print("refreshHiddenMoviesFromCalendar request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("refreshHiddenMoviesFromCalendar request failure \(error)")
            }
        }
    }

    private func refreshHiddenUsersFromComments(pageInfo: PageInfo = PageInfo.firstPage(with: 50), hiddenMedia: [User] = [User]()) {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.hidden(section: .comments,
                                                  type: .user,
                                                  extended: nil,
                                                  pageInfo: pageInfo),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let items = try response.map([BlockedUser].self, using: TraktAPIProvider.decoder).map { $0.user }

                    if let response = response.response,
                    let pageInfo = PageInfo(headers: response.allHeaderFields)?.nextPage {
                        DispatchQueue.main.async {
                            if pageInfo.page <= pageInfo.pageCount {
                                self.refreshHiddenUsersFromComments(pageInfo: pageInfo, hiddenMedia: hiddenMedia + items)
                            } else {
                                self.usersHiddenFromCommentsList = hiddenMedia + items
                            }
                        }
                    }
                } catch {
                    print("refreshHiddenUsersFromComments request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("refreshHiddenUsersFromComments request failure \(error)")
            }
        }
    }
}

extension Show {
    var isHiddenFromProgress: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return HiddenMediaManager.shared.showsHiddenFromProgressSet.contains(traktId)
    }

    var isHiddenFromCalendar: Bool {
        return HiddenMediaManager.shared.showsHiddenFromCalendarMediaList?.contains(self.mediaModel) == true
    }
}

extension Movie {
    var isHiddenFromCalendar: Bool {
        return HiddenMediaManager.shared.moviesHiddenFromCalendarMediaList?.contains(self.mediaModel) == true
    }
}

extension Season {
    var isHiddenFromProgress: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return HiddenMediaManager.shared.seasonsHiddenFromProgressSet.contains(traktId)
    }
}

extension MediaModel {
    var isHiddenFromProgress: Bool {
        switch self {
        case .movie:
            return false
        case .show(let show):
            return show.isHiddenFromProgress
        case .episode:
            return false
        case .season(let season, _):
            return season.isHiddenFromProgress
        case .list:
            return false
        case .showProgress:
            return false
        }

    }
}

final class HiddenImageView: UIImageView {

    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            isHidden = !(media?.isHiddenFromProgress ?? false)
            invalidateCellIntrinsicContentSize()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onShowsHiddenFromProgressMediaChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isHidden = !(self.media?.isHiddenFromProgress ?? false)
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)
    }
}
