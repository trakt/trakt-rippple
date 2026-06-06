//
//  PinnedMoviesManager.swift
//  Rippple
//
//  Created by Assistant on 18/11/2025.
//

import Foundation
import Moya
import Receiver
import UIKit

// MARK: - Pinned Movies Signals

let (onPinnedMoviesToWatchChangedTransmitter, onPinnedMoviesToWatchChangedReceiver) = Receiver<[Movie]>.make(with: .warm(upTo: 1))
let (onPinnedMovieToWatchAddedTransmitter, onPinnedMovieToWatchAddedReceiver) = Receiver<Movie>.make(with: .hot)
let (onPinnedMovieToWatchRemovedTransmitter, onPinnedMovieToWatchRemovedReceiver) = Receiver<Movie>.make(with: .hot)

final class PinnedMoviesManager {
    static let shared = PinnedMoviesManager()

    private let disposeBag = DisposeBag()

    private var debouncedCleanup: Debouncer!

    private init() {
        debouncedCleanup = Debouncer(delay: 5.0) {
            var fullPinnedMovies = Set<Movie>()
            for movie in self.pinnedMovies where movie.isWatched == false {
                fullPinnedMovies.insert(movie)
            }
            self.pinnedMovies = fullPinnedMovies
        }

        if let encodedMovies = NSUbiquitousKeyValueStore.default.object(forKey: "MovieToWatchManager.pinnedMovies") as? Data {
            if let pinnedMovies = try? JSONDecoder().decode(Set<Movie>.self, from: encodedMovies) {
                self.pinnedMovies = Set<Movie>(pinnedMovies)
            } else {
                pinnedMovies = Set<Movie>()
            }
        } else {
            pinnedMovies = Set<Movie>()
        }

        onPinnedMoviesToWatchChangedTransmitter.broadcast([Movie](pinnedMovies.filter { !$0.isHiddenFromCalendar }))

        onWatchedMoviesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedCleanup.call()
        }.disposed(by: disposeBag)
    }

    var pinnedMovies = Set<Movie>() {
        didSet {
            if pinnedMovies != oldValue {
                _Concurrency.Task {
                    var fullPinnedMovies = Set<Movie>()
                    for movie in pinnedMovies {
                        if movie.rating == nil {
                            let fullMovie = await fetchMovie(movie: movie)
                            fullPinnedMovies.insert(fullMovie)
                        } else {
                            fullPinnedMovies.insert(movie)
                        }
                    }
                    pinnedMovies = fullPinnedMovies
                    storeAndTransmit(pinnedMovies: pinnedMovies)
                }
            }
        }
    }

    private func storeAndTransmit(pinnedMovies: Set<Movie>) {
        DispatchQueue.main.async {
            onPinnedMoviesToWatchChangedTransmitter.broadcast([Movie](pinnedMovies.filter { !$0.isHiddenFromCalendar }))
        }
        if let encoded = try? JSONEncoder().encode(pinnedMovies) {
            NSUbiquitousKeyValueStore.default.set(encoded, forKey: "MovieToWatchManager.pinnedMovies")
        }
    }

    func setup() {
        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if UserManager.shared.currentUser != nil {
                self.loadPinnedMovies()

                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(self.loadPinnedMovies),
                                                       name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                       object: nil)
            }
        }.disposed(by: disposeBag)
    }

    @objc private func loadPinnedMovies() {
        if let encodedMovies = NSUbiquitousKeyValueStore.default.object(forKey: "MovieToWatchManager.pinnedMovies") as? Data {
            if let pinnedMovies = try? JSONDecoder().decode(Set<Movie>.self, from: encodedMovies) {
                self.pinnedMovies = Set<Movie>(pinnedMovies)
                return
            }
        }
        pinnedMovies = Set<Movie>()
    }

    /// Fetch the full movie async + return the old Movie if there's an error to not lose it
    private func fetchMovie(movie: Movie) async -> Movie {
        return await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.movie(id: movie.identifiers.traktIdOrSlug, extended: .full), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let fullMovie = try response.map(Movie.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: fullMovie)
                    } catch {
                        continuation.resume(returning: movie)
                    }
                case .failure:
                    continuation.resume(returning: movie)
                }
            }
        }
    }
}

extension Movie {
    func pin() {
        if !PurchaseManager.shared.purchased {
            UIApplication.shared.switchToPurchase()
            return
        }
        PinnedMoviesManager.shared.pinnedMovies.insert(self)
        onPinnedMovieToWatchAddedTransmitter.broadcast(self)
        SwiftMessages.show(message: "📌 Pinned")
    }

    func unpin() {
        PinnedMoviesManager.shared.pinnedMovies.remove(self)
        onPinnedMovieToWatchRemovedTransmitter.broadcast(self)
        SwiftMessages.show(message: "📌 Unpinned")
    }

    var isPinned: Bool {
        return PinnedMoviesManager.shared.pinnedMovies.contains(self)
    }
}
