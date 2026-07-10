//
//  CollaborationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 23/11/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Foundation
import Receiver

let (onCollaborationsChangedTransmitter, onCollaborationsChangedReceiver) = Receiver<[List]>.make(with: .warm(upTo: 1))

final class CollaborationsManager {
    private let disposeBag = DisposeBag()

    private init() {}

    var collaborations = [List]() {
        didSet {
            onCollaborationsChangedTransmitter.broadcast(collaborations)
            UserDefaults.standard.set(try? PropertyListEncoder().encode(collaborations), forKey: "CollaborationsManager.collaborations")
            UserDefaults.standard.synchronize()
        }
    }

    static let shared = CollaborationsManager()

    func setup() {
        if UserManager.shared.currentUser != nil {
            if let data = UserDefaults.standard.data(forKey: "CollaborationsManager.collaborations"), let array = try? PropertyListDecoder().decode([List].self, from: data) {
                collaborations = array
            }
        }

        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshCollaborations()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { [weak self] settings in
            guard let self = self else { return }
            if settings != nil {
                if let data = UserDefaults.standard.data(forKey: "CollaborationsManager.collaborations"), let array = try? PropertyListDecoder().decode([List].self, from: data) {
                    self.collaborations = array
                }
                self.refreshCollaborations()
            } else {
                self.collaborations.removeAll()
                UserDefaults.standard.removeObject(forKey: "CollaborationsManager.collaborations")
                UserDefaults.standard.synchronize()
            }
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.collaborations.removeAll()
            UserDefaults.standard.removeObject(forKey: "CollaborationsManager.collaborations")
            UserDefaults.standard.synchronize()
        }.disposed(by: disposeBag)

        refreshCollaborations()
    }

    func refresh() {
        refreshCollaborations()
    }
}

private extension CollaborationsManager {
    private func refreshCollaborations() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.noChacheProvider.request(.collaborations(),
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let lists = try response.map([List].self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.collaborations = lists
                    }
                } catch {
                    print("collaborations request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("collaborations request failure \(error)")
            }
        }
    }
}
