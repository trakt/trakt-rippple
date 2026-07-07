//
//  UserManager.swift
//  Rippple
//
//  Created by Kevin Cador on 12/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver
import UIKit

let (onSettingsChangedTransmitter, onSettingsChangedReceiver) = Receiver<Settings?>.make(with: .warm(upTo: 1))
let (onSettingsRefreshedTransmitter, onSettingsRefreshedReceiver) = Receiver<Bool>.make(with: .hot)
let (onVIPChangedTransmitter, onVIPChangedReceiver) = Receiver<Bool>.make(with: .hot)

extension URL {
    func slurmified() -> URL {
        if let slurm = UserManager.shared.slurm {
            return appending(queryItems: [URLQueryItem(name: "slurm", value: slurm)])
        } else {
            return self
        }
    }
}

final class UserManager {
    static let shared = UserManager()

    var currentUser: User?

    fileprivate var slurm: String? {
        return settings?.account.slurm
    }

    private var settings: Settings? {
        didSet {
            guard let settings = settings else {
                currentUser = nil
                UserDefaults.standard.removeObject(forKey: "Rippple.currentUser")
                UserDefaults.standard.synchronize()
                onSettingsChangedTransmitter.broadcast(nil)
                return
            }
            currentUser = settings.user
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            if let user = try? encoder.encode(settings.user) {
                UserDefaults.standard.set(user, forKey: "Rippple.currentUser")
                UserDefaults.standard.synchronize()
            }
            if settings != oldValue {
                onSettingsChangedTransmitter.broadcast(settings)
            }

            // check for new VIP status
            if oldValue?.user.isTraktVIP != settings.user.isTraktVIP {
                onVIPChangedTransmitter.broadcast(settings.user.isTraktVIP)
            }
        }
    }

    var currentUserCanWatchOnlyOnce: Bool {
        return settings?.browsing.watchOnlyOnce ?? false
    }

    var currentUserCanComment: Bool {
        return settings?.permissions.commenting ?? false
    }

    var currentUserListLimit: Int {
        return settings?.limits.list.count ?? 0
    }

    var currentUserNotesLimit: Int {
        return settings?.limits.notes.itemCount ?? 0
    }

    private init() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "Rippple.currentUser"),
           let user = try? decoder.decode(User.self, from: data) {
            currentUser = user
        }
    }

    func startManaging() {}

    func reloadSettings(transmitRefreshed: Bool = false) {
        fetchSettings(transmitRefreshed: transmitRefreshed)
    }

    func logout() {
        settings = nil
    }

    private func fetchSettings(retryAttempt: Int = 0, transmitRefreshed: Bool = false) {
        TraktAPIProvider.provider.request(.settings,
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    print("Fetch Settings status code (retry attempt: \(retryAttempt)): \(moyaResponse.statusCode)")
                    if moyaResponse.statusCode == 401 {
                        let retryDelays: [TimeInterval] = [1, 2, 3]
                        if retryAttempt < retryDelays.count {
                            let delay = retryDelays[retryAttempt]
                            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
                                self.fetchSettings(retryAttempt: retryAttempt + 1)
                            }
                        } else {
                            DispatchQueue.main.async {
                                UIApplication.shared.switchToLogin401()
                            }
                        }
                    } else {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let settings = try response.map(Settings.self, using: TraktAPIProvider.decoder)

                        print("Set Settings to \(settings)")
                        DispatchQueue.main.async {
                            self.settings = settings
                            if transmitRefreshed == true {
                                onSettingsRefreshedTransmitter.broadcast(true)
                            }
                        }
                    }
                } catch {
                    print("Settings request JSON mapping failed! \(error)")
                    DispatchQueue.main.async {
                        self.promptShowSettingsError(error: error)
                    }
                }
            case .failure(let error):
                print("Settings request failed! \(error)")
                DispatchQueue.main.async {
                    self.promptShowSettingsError(error: error)
                }
            }
        }
    }

    private func promptShowSettingsError(error: Error) {
        let alert = UIAlertController(title: "Unable to Restore Session",
                                      message: "An error occurred when restoring your session with Trakt.\nYou can ‘Retry‘ now, ‘Sign Out‘ or get more information on Trakt's Status page or on the Forums.\n\n\(error.localizedDescription)",
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Trakt Status", style: .default, handler: { _ in
            if let url = URL(string: "https://status.trakt.tv"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }))

        alert.addAction(UIAlertAction(title: "Trakt Forums", style: .default, handler: { _ in
            if let url = URL(string: "https://forums.trakt.tv"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }))

        let retry = UIAlertAction(title: "Retry Now", style: .default) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.fetchSettings()
            }
        }
        alert.addAction(retry)

        let signOut = UIAlertAction(title: "Sign Out", style: .destructive) { _ in
            DispatchQueue.main.async {
                UIApplication.shared.switchToLogin()
            }
        }
        alert.addAction(signOut)

        UIApplication.shared.present(alert)
    }

    func isCurrent(user: User) -> Bool {
        if let currentUser = currentUser {
            return currentUser == user
        }
        return false
    }

    var isCurrentVIP: Bool {
        guard let currentUser = currentUser else { return false }
        return currentUser.isVip ?? false || currentUser.isVipEp ?? false || currentUser.isVipOg ?? false
    }

    var coverImageURL: URL? {
        guard let settings = settings else { return nil }
        return settings.account.coverImageURL
    }
}

extension User {
    var isCurrentUser: Bool {
        return UserManager.shared.isCurrent(user: self)
    }
}

extension CommentModel {
    var isOwnComment: Bool {
        return UserManager.shared.isCurrent(user: comment.user)
    }
}
