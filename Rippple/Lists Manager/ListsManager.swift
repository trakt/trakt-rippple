//
//  ListsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 31/07/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Foundation

import Receiver

let (onCustomListsChangedTransmitter, onCustomListsChangedReceiver) = Receiver<[List]>.make(with: .warm(upTo: 1))

final class ListsManager {

    private let disposeBag = DisposeBag()

    private init() { }

    public var lists = [List]() {
        didSet {
            onCustomListsChangedTransmitter.broadcast(lists)
            UserDefaults.standard.set(try? PropertyListEncoder().encode(lists), forKey: "ListsManager.lists")
            UserDefaults.standard.synchronize()
        }
    }

    static let shared = ListsManager()

    func setup() {
        if UserManager.shared.currentUser != nil {
            if let data = UserDefaults.standard.data(forKey: "ListsManager.lists"), let array = try? PropertyListDecoder().decode([List].self, from: data) {
                lists = array
            }
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
                if let data = UserDefaults.standard.data(forKey: "ListsManager.lists"), let array = try? PropertyListDecoder().decode([List].self, from: data) {
                    self.lists = array
                }
                self.refreshLists()
            } else {
                self.lists.removeAll()
            }
        }.disposed(by: disposeBag)

        onListChangedReceiver.listen { [weak self] lists in
            guard let self = self else { return }
            ListItemsMarkerManager.shared.invalidate(lists: lists)
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

    public func refresh() {
        refreshLists()
    }
}

private extension ListsManager {

    private func refreshLists() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.noChacheProvider.request(.customLists(),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let lists = try response.map([List].self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.lists = lists
                    }
                } catch {
                    print("customLists request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("customLists request failure \(error)")
            }
        }
    }
}
