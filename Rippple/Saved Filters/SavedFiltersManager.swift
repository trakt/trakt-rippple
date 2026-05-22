//
//  SavedFiltersManager.swift
//  Rippple
//
//  Created by Kevin Cador on 06/01/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Foundation
import Receiver

let (onSavedFiltersChangedTransmitter, onSavedFiltersChangedReceiver) = Receiver<[SavedFilter]>.make(with: .warm(upTo: 1))

final class SavedFiltersManager {
    private let disposeBag = DisposeBag()

    private init() {}

    static let shared = SavedFiltersManager()

    private var savedFilters = [SavedFilter]() {
        didSet {
            if savedFilters != oldValue {
                savedFilters.removeDuplicates()

                onSavedFiltersChangedTransmitter.broadcast(savedFilters)
                UserDefaults.standard.set(try? PropertyListEncoder().encode(savedFilters), forKey: "SavedFiltersManager.savedFilters")
                UserDefaults.standard.synchronize()
            }
        }
    }

    func setup() {
        if let data = UserDefaults.standard.data(forKey: "SavedFiltersManager.savedFilters"), let array = try? PropertyListDecoder().decode([SavedFilter].self, from: data) {
            savedFilters = array
        }

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 3600 {
                    guard let self = self else { return }
                    self.refresh()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.refresh()
        }.disposed(by: disposeBag)

        refresh()
    }

    private func refresh() {
        if SessionManager.shared.isLoggedIn == false {
            savedFilters = [SavedFilter]()
            return
        }
        TraktAPIProvider.provider.request(.savedFilters,
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let results = try response.map([SavedFilter].self, using: TmdbAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.savedFilters = results
                    }
                } catch {
                    print("TraktAPI.savedFilters Error: \(error)")
                }
            case .failure(let error):
                print("TraktAPI.savedFilters Failure: \(error)")
            }
        }
    }
}
