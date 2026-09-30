//
//  ListsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 31/07/2022.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver

let (onCustomListsChangedTransmitter, onCustomListsChangedReceiver) = Receiver<[List]>.make(with: .warm(upTo: 1))
let (onSmartListsChangedTransmitter, onSmartListsChangedReceiver) = Receiver<[List]>.make(with: .warm(upTo: 1))
/// Custom and smart lists owned by the current user.
let (onOwnedListsChangedTransmitter, onOwnedListsChangedReceiver) = Receiver<[List]>.make(with: .warm(upTo: 1))

final class ListsManager {
    private let disposeBag = DisposeBag()

    private init() {}

    var lists = [List]() {
        didSet {
            onCustomListsChangedTransmitter.broadcast(lists)
            onOwnedListsChangedTransmitter.broadcast(ownedLists)
            UserDefaults.standard.set(try? PropertyListEncoder().encode(lists), forKey: "ListsManager.lists")
            UserDefaults.standard.synchronize()
        }
    }

    private(set) var smartLists = [List]() {
        didSet {
            onSmartListsChangedTransmitter.broadcast(smartLists)
            onOwnedListsChangedTransmitter.broadcast(ownedLists)
            UserDefaults.standard.set(try? PropertyListEncoder().encode(smartLists), forKey: "ListsManager.smartLists")
            UserDefaults.standard.synchronize()
        }
    }

    var ownedLists: [List] {
        return lists + smartLists
    }

    static let shared = ListsManager()

    func setup() {
        if UserManager.shared.currentUser != nil {
            restore()
        }

        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshLists()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { [weak self] settings in
            guard let self = self else { return }
            if settings != nil {
                self.restore()
                self.refreshLists()
            } else {
                self.clear()
            }
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.clear()
        }.disposed(by: disposeBag)

        onListChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.refreshLists()
        }.disposed(by: disposeBag)

        listCreatedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.refreshLists()
        }.disposed(by: disposeBag)

        listUpdatedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.refreshLists()
        }.disposed(by: disposeBag)

        refreshLists()
    }

    func refresh() {
        refreshLists()
    }

    /// Inserts or replaces a smart list returned by Trakt after it was created or updated.
    func save(smartList: List) {
        guard smartList.isSmartList else { return }
        if let index = smartLists.firstIndex(of: smartList) {
            smartLists[index] = smartList
        } else {
            smartLists.append(smartList)
        }
    }

    func delete(smartList: List, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let slug = smartList.smartListSlug, SessionManager.shared.isLoggedOut == false else {
            completion(.failure(MoyaError.requestMapping("Missing smart list identifier")))
            return
        }
        TraktAPIProvider.provider.request(.deleteSmartList(slug: slug),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            let deletion = Result<Void, Error> {
                let response = try result.get()
                // A missing list has already been deleted, for example from another device.
                if response.statusCode != 404 {
                    _ = try response.filterSuccessfulStatusCodes()
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if case .success = deletion {
                    MovieToWatchSettings.shared.remove(list: smartList)
                    EpisodeToWatchSettings.shared.remove(list: smartList)
                    self.smartLists.removeAll { $0 == smartList }
                    let savedFilter = smartList.savedFilter
                    if savedFilter.isShelved {
                        savedFilter.unshelf()
                    }
                }
                completion(deletion)
            }
        }
    }
}

private extension ListsManager {
    private func restore() {
        let decoder = PropertyListDecoder()
        if let data = UserDefaults.standard.data(forKey: "ListsManager.lists"), let array = try? decoder.decode([List].self, from: data) {
            lists = array
        }
        if let data = UserDefaults.standard.data(forKey: "ListsManager.smartLists"), let array = try? decoder.decode([List].self, from: data) {
            smartLists = array
        }
    }

    private func clear() {
        lists.removeAll()
        smartLists.removeAll()
        UserDefaults.standard.removeObject(forKey: "ListsManager.lists")
        UserDefaults.standard.removeObject(forKey: "ListsManager.smartLists")
        UserDefaults.standard.synchronize()
    }

    private func refreshLists() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        refreshSmartLists()
        TraktAPIProvider.fetchAllCustomLists(provider: TraktAPIProvider.noChacheProvider) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let lists):
                DispatchQueue.main.async {
                    self.lists = lists
                }
            case .failure(let error):
                print("customLists request failure \(error)")
            }
        }
    }

    private func refreshSmartLists() {
        guard let user = UserManager.shared.currentUser else { return }
        TraktAPIProvider.fetchSmartLists(user: user, provider: TraktAPIProvider.noChacheProvider) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, UserManager.shared.currentUser == user else { return }
                switch result {
                case .success(let smartLists):
                    self.smartLists = smartLists
                case .failure(let error):
                    print("smartLists request failure \(error)")
                }
            }
        }
    }
}
