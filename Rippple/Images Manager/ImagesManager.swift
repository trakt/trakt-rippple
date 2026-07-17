//
//  ImagesManager.swift
//  Rippple
//
//  Created by Kevin Cador on 31/12/2018.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
@preconcurrency import Kingfisher
import Moya
import Receiver
import UIKit
import Vision

public extension CGImage {
    func faceCrop(margin: CGFloat = 200, completion: @escaping (FaceCropResult) -> Void) {
        let req = VNDetectFaceRectanglesRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let results = request.results, !results.isEmpty else {
                completion(.notFound)
                return
            }

            var faces: [VNFaceObservation] = []
            for result in results {
                guard let face = result as? VNFaceObservation else { continue }
                faces.append(face)
            }

            let croppingRect = self.getCroppingRect(for: faces, margin: margin)
            let faceImage = self.cropping(to: croppingRect)

            guard let result = faceImage else {
                completion(.notFound)
                return
            }
            completion(.success(result))
        }

        do {
            try VNImageRequestHandler(cgImage: self, options: [:]).perform([req])
        } catch {
            completion(.failure(error))
        }
    }

    private func getCroppingRect(for faces: [VNFaceObservation], margin: CGFloat) -> CGRect {
        var totalX = CGFloat(0)
        var totalY = CGFloat(0)
        var totalW = CGFloat(0)
        var totalH = CGFloat(0)
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        let numFaces = CGFloat(faces.count)

        for face in faces {
            let w = face.boundingBox.width * CGFloat(width)
            let h = face.boundingBox.height * CGFloat(height)
            let x = face.boundingBox.origin.x * CGFloat(width)
            let y = (1 - face.boundingBox.origin.y) * CGFloat(height) - h
            totalX += x
            totalY += y
            totalW += w
            totalH += h
            minX = .minimum(minX, x)
            minY = .minimum(minY, y)
        }

        let avgX = totalX / numFaces
        let avgY = totalY / numFaces
        let avgW = totalW / numFaces
        let avgH = totalH / numFaces

        let offset = margin + avgX - minX

        return CGRect(x: avgX - offset, y: avgY - offset, width: avgW + (offset * 2), height: avgH + (offset * 2))
    }
}

public enum FaceCropResult {
    case success(CGImage)
    case notFound
    case failure(Error)
}

struct FaceFilter: ImageProcessor {
    var size: CGFloat

    var identifier: String {
        "com.rippple.FaceFilter.\(size)"
    }

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> Image? {
        switch item {
        case .image(let image):
            guard let cgImage = image.cgImage else { return image }
            let semaphore = DispatchSemaphore(value: 1)
            var newImage = image
            cgImage.faceCrop(margin: size) { result in
                switch result {
                case .success(let cgImage):
                    newImage = UIImage(cgImage: cgImage)
                case .notFound, .failure:
                    break
                }
                semaphore.signal()
            }
            semaphore.wait()
            return newImage
        case .data(let data):
            guard let image = KingfisherWrapper.image(data: data, options: ImageCreatingOptions()) else { return nil }
            guard let cgImage = image.cgImage else { return image }
            let semaphore = DispatchSemaphore(value: 1)
            var newImage = image
            cgImage.faceCrop(margin: size) { result in
                switch result {
                case .success(let cgImage):
                    newImage = UIImage(cgImage: cgImage)
                case .notFound, .failure:
                    break
                }
                semaphore.signal()
            }
            semaphore.wait()
            return newImage
        }
    }
}

struct SepiaFilter: CIImageProcessor {
    let identifier = "com.rippple.SepiaFilter"

    let filter = Filter { input in
        guard let filter = CIFilter(name: "CIPhotoEffectMono") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        return filter.outputImage
    }
}

final class ImagesManager {
    private let disposeBag = DisposeBag()

    struct CacheStats {
        let memoryExpirationDescription: String
        let diskExpirationDescription: String
        let diskSizeLimit: UInt
        let diskSize: UInt
    }

    private let movieCache = NSCache<NSString, NSString>()
    private let showCache = NSCache<NSString, NSString>()
    private let seasonCache = NSCache<NSString, NSString>()

    private let movieBackdropCache = NSCache<NSString, NSString>()
    private let showBackdropCache = NSCache<NSString, NSString>()

    private let movieLogoCache = NSCache<NSString, NSString>()
    private let showLogoCache = NSCache<NSString, NSString>()

    private let episodeStillsCache = NSCache<NSString, NSString>()

    private let peopleCache = NSCache<NSString, NSString>()

    enum CacheMode: CaseIterable, Hashable {
        case balanced
        case offlineFirst
        case alwaysFresh

        var name: String {
            switch self {
            case .balanced: return "Balanced"
            case .offlineFirst: return "Offline"
            case .alwaysFresh: return "Freshest"
            }
        }

        var description: String {
            switch self {
            case .balanced: return "Balances caching and freshness."
            case .offlineFirst: return "Prioritizes cached images."
            case .alwaysFresh: return "Prioritizes fresh (online) images."
            }
        }
    }

    enum ImageType {
        case poster
        case backdrop
        case profile
        case logo
    }

    private let configurationLock = NSLock()
    private var baseURL: URL = .init(string: "https://image.tmdb.org/t/p/")!

    private var posterSizes: [String] = ["w92", "w154", "w185", "w342", "w500", "w780", "original"]
    private var backdropSizes: [String] = ["w300", "w780", "w1280", "original"]
    private var profileSizes: [String] = ["w45", "w185", "h632", "original"]
    private var logoSizes: [String] = ["w45", "w92", "w154", "w185", "w300", "w500", "original"]

    private static let expirationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()

    private(set) var cacheMode: CacheMode = .balanced {
        didSet {
            if oldValue != cacheMode {
                applyCacheMode(bustCache: true, previousMode: oldValue)
            }
        }
    }

    private init() {
        applyCacheMode(bustCache: false, previousMode: nil)
    }

    static let shared = ImagesManager()

    func updateCacheMode(_ mode: CacheMode) {
        cacheMode = mode
    }

    private func applyCacheMode(bustCache: Bool, previousMode: CacheMode?) {
        let cache = ImageCache.default

        switch cacheMode {
        case .balanced:
            cache.memoryStorage.config.expiration = .seconds(12 * 60 * 60) // 12 hours
            cache.diskStorage.config.expiration = .days(30)
            cache.diskStorage.config.sizeLimit = 512 * 1024 * 1024 // 512 MB

        case .offlineFirst:
            cache.memoryStorage.config.expiration = .days(7)
            cache.diskStorage.config.expiration = .days(90)
            cache.diskStorage.config.sizeLimit = 1024 * 1024 * 1024 // 1 GB

        case .alwaysFresh:
            cache.memoryStorage.config.expiration = .seconds(10 * 60) // 10 minutes
            cache.diskStorage.config.expiration = .days(2)
            cache.diskStorage.config.sizeLimit = 256 * 1024 * 1024 // 256 MB
        }

        guard bustCache else {
            return
        }

        cache.clearMemoryCache()
        cache.clearDiskCache()
    }

    private func expirationDescription(_ expiration: StorageExpiration) -> String {
        switch expiration {
        case .never:
            return "Never"
        case .expired:
            return "Expired"
        case .seconds(let seconds):
            let interval = TimeInterval(seconds)
            return ImagesManager.expirationFormatter.string(from: interval) ?? "\(Int(seconds)) seconds"
        case .days(let days):
            if days == 1 {
                return "1 day"
            }
            return "\(days) days"
        default:
            return ""
        }
    }

    func loadCacheStats(completion: @escaping (CacheStats) -> Void) {
        let cache = ImageCache.default

        let memoryExpirationDescription = expirationDescription(cache.memoryStorage.config.expiration)
        let diskExpirationDescription = expirationDescription(cache.diskStorage.config.expiration)
        let diskSizeLimit = cache.diskStorage.config.sizeLimit

        cache.calculateDiskStorageSize { result in
            let diskSize: UInt
            switch result {
            case .success(let size):
                diskSize = size
            case .failure:
                diskSize = 0
            }

            let stats = CacheStats(memoryExpirationDescription: memoryExpirationDescription,
                                   diskExpirationDescription: diskExpirationDescription,
                                   diskSizeLimit: diskSizeLimit,
                                   diskSize: diskSize)
            completion(stats)
        }
    }

    func options(adding extra: KingfisherOptionsInfo = []) -> KingfisherOptionsInfo {
        var base: KingfisherOptionsInfo = []

        switch cacheMode {
        case .balanced:
            break
        case .offlineFirst:
            base.append(.cacheOriginalImage)
        case .alwaysFresh:
            base.append(.fromMemoryCacheOrRefresh)
        }

        base.append(contentsOf: extra)
        return base
    }

    func imageURL(for providerLogoURL: String) -> URL? {
        let baseURL = withConfigurationLock { self.baseURL }
        return URL(string: "\(baseURL)original/\(providerLogoURL)")
    }

    func imageURL(with filePath: String, with size: CGSize, for type: ImageType) -> URL? {
        let (baseURL, posterSizes, backdropSizes, profileSizes) = withConfigurationLock {
            (self.baseURL, self.posterSizes, self.backdropSizes, self.profileSizes)
        }

        switch type {
        case .poster:
            for posterSize in posterSizes where posterSize.hasPrefix("w") {
                if let posterWidth = Float(posterSize.dropFirst()) {
                    if posterWidth > Float(size.width) {
                        return URL(string: "\(baseURL)\(posterSize)/\(filePath)")
                    }
                }
            }
            return URL(string: "\(baseURL)original/\(filePath)")
        case .backdrop:
            for posterSize in backdropSizes where posterSize.hasPrefix("w") {
                if let posterWidth = Float(posterSize.dropFirst()) {
                    if posterWidth > Float(size.width) {
                        return URL(string: "\(baseURL)\(posterSize)/\(filePath)")
                    }
                }
            }
            return URL(string: "\(baseURL)original/\(filePath)")
        case .profile:
            for posterSize in profileSizes {
                if posterSize.hasPrefix("w") {
                    if let posterWidth = Float(posterSize.dropFirst()) {
                        if posterWidth > Float(size.width) {
                            return URL(string: "\(baseURL)\(posterSize)/\(filePath)")
                        }
                    }
                }
                if posterSize.hasPrefix("h") {
                    if let posterHeight = Float(posterSize.dropFirst()) {
                        if posterHeight > Float(size.height) {
                            return URL(string: "\(baseURL)\(posterSize)/\(filePath)")
                        }
                    }
                }
            }
            return URL(string: "\(baseURL)original/\(filePath)")
        case .logo:
            for logoSize in logoSizes where logoSize.hasPrefix("w") {
                if let logoWidth = Float(logoSize.dropFirst()) {
                    if logoWidth > Float(size.width) {
                        return URL(string: "\(baseURL)\(logoSize)/\(filePath)")
                    }
                }
            }
            return URL(string: "\(baseURL)w500/\(filePath)")
        }
    }

    private func withConfigurationLock<T>(_ work: () -> T) -> T {
        configurationLock.lock()
        defer { configurationLock.unlock() }
        return work()
    }

    fileprivate func cachedShowPoster(with identifiers: Identifiers, for size: CGSize) -> URL? {
        guard let tmdb = identifiers.tmdb else { return nil }
        if let imagePath = showCache.object(forKey: String(tmdb) as NSString) {
            return imageURL(with: imagePath as String, with: size, for: .poster)
        } else {
            return nil
        }
    }

    fileprivate func cachedMoviePoster(with identifiers: Identifiers, for size: CGSize) -> URL? {
        guard let tmdb = identifiers.tmdb else { return nil }
        if let imagePath = movieCache.object(forKey: String(tmdb) as NSString) {
            return imageURL(with: imagePath as String, with: size, for: .poster)
        } else {
            return nil
        }
    }

    fileprivate func cachedShowLogo(with identifiers: Identifiers, for size: CGSize) -> URL? {
        guard let tmdb = identifiers.tmdb else { return nil }
        if let imagePath = showLogoCache.object(forKey: String(tmdb) as NSString) {
            return imageURL(with: imagePath as String, with: size, for: .logo)
        } else {
            return nil
        }
    }

    fileprivate func cachedMovieLogo(with identifiers: Identifiers, for size: CGSize) -> URL? {
        guard let tmdb = identifiers.tmdb else { return nil }
        if let imagePath = movieLogoCache.object(forKey: String(tmdb) as NSString) {
            return imageURL(with: imagePath as String, with: size, for: .logo)
        } else {
            return nil
        }
    }

    fileprivate func cachedShowBackdrop(with identifiers: Identifiers, for size: CGSize) -> URL? {
        guard let tmdb = identifiers.tmdb else { return nil }
        if let imagePath = showBackdropCache.object(forKey: String(tmdb) as NSString) {
            return imageURL(with: imagePath as String, with: size, for: .backdrop)
        } else {
            return nil
        }
    }

    fileprivate func cachedMovieBackdrop(with identifiers: Identifiers, for size: CGSize) -> URL? {
        guard let tmdb = identifiers.tmdb else { return nil }
        if let imagePath = movieBackdropCache.object(forKey: String(tmdb) as NSString) {
            return imageURL(with: imagePath as String, with: size, for: .backdrop)
        } else {
            return nil
        }
    }

    fileprivate func cachedPeopleImage(with identifiers: Identifiers, for size: CGSize) -> URL? {
        guard let tmdb = identifiers.tmdb else { return nil }
        if let imagePath = peopleCache.object(forKey: String(tmdb) as NSString) {
            return imageURL(with: imagePath as String, with: size, for: .profile)
        } else {
            return nil
        }
    }

    fileprivate func cachedEpisodeImage(with identifiers: Identifiers, for size: CGSize) -> URL? {
        guard let tmdb = identifiers.tmdb else { return nil }
        if let imagePath = episodeStillsCache.object(forKey: String(tmdb) as NSString) {
            return imageURL(with: imagePath as String, with: size, for: .backdrop)
        } else {
            return nil
        }
    }

    fileprivate func cachedSeasonPoster(with identifiers: Identifiers, season: Int, for size: CGSize) -> URL? {
        guard let tmdb = identifiers.tmdb else { return nil }
        if let imagePath = seasonCache.object(forKey: "\(tmdb)-\(season)" as NSString) {
            return imageURL(with: imagePath as String, with: size, for: .poster)
        } else {
            return nil
        }
    }

    fileprivate func storeShowPoster(with path: String, for identifiers: Identifiers) {
        guard let tmdb = identifiers.tmdb else { return }
        showCache.setObject(path as NSString, forKey: String(tmdb) as NSString)
    }

    fileprivate func storeSeasonPoster(with path: String, for identifiers: Identifiers, season: Int) {
        guard let tmdb = identifiers.tmdb else { return }
        seasonCache.setObject(path as NSString, forKey: "\(tmdb)-\(season)" as NSString)
    }

    fileprivate func storeMoviePoster(with path: String, for identifiers: Identifiers) {
        guard let tmdb = identifiers.tmdb else { return }
        movieCache.setObject(path as NSString, forKey: String(tmdb) as NSString)
    }

    fileprivate func storeShowBackdrop(with path: String, for identifiers: Identifiers) {
        guard let tmdb = identifiers.tmdb else { return }
        showBackdropCache.setObject(path as NSString, forKey: String(tmdb) as NSString)
    }

    fileprivate func storeMovieBackdrop(with path: String, for identifiers: Identifiers) {
        guard let tmdb = identifiers.tmdb else { return }
        movieBackdropCache.setObject(path as NSString, forKey: String(tmdb) as NSString)
    }

    fileprivate func storeShowLogo(with path: String, for identifiers: Identifiers) {
        guard let tmdb = identifiers.tmdb else { return }
        showLogoCache.setObject(path as NSString, forKey: String(tmdb) as NSString)
    }

    fileprivate func storeMovieLogo(with path: String, for identifiers: Identifiers) {
        guard let tmdb = identifiers.tmdb else { return }
        movieLogoCache.setObject(path as NSString, forKey: String(tmdb) as NSString)
    }

    fileprivate func storePeopleImage(with path: String, for identifiers: Identifiers) {
        guard let tmdb = identifiers.tmdb else { return }
        peopleCache.setObject(path as NSString, forKey: String(tmdb) as NSString)
    }

    fileprivate func storeEpisodeImage(with path: String, for identifiers: Identifiers) {
        guard let tmdb = identifiers.tmdb else { return }
        episodeStillsCache.setObject(path as NSString, forKey: String(tmdb) as NSString)
    }

    func setup() {
        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.movieCache.removeAllObjects()
            self.showCache.removeAllObjects()
            self.seasonCache.removeAllObjects()
            self.movieBackdropCache.removeAllObjects()
            self.showBackdropCache.removeAllObjects()
            self.movieLogoCache.removeAllObjects()
            self.showLogoCache.removeAllObjects()
            self.episodeStillsCache.removeAllObjects()
            self.peopleCache.removeAllObjects()
            ImageCache.default.clearMemoryCache()
        }.disposed(by: disposeBag)

        TmdbAPIProvider.provider.request(TmdbAPIService.configuration, callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let configuration = try response.map(Configuration.self, using: TmdbAPIProvider.decoder)

                    self.withConfigurationLock {
                        if let baseURL = URL(string: configuration.images.baseURL) {
                            self.baseURL = baseURL
                        }

                        self.posterSizes = configuration.images.posterSizes
                        self.backdropSizes = configuration.images.backdropSizes
                        self.profileSizes = configuration.images.profileSizes
                    }

                } catch {
                    print("TmdbAPIService.configuration Error: \(error)")
                }
            case .failure(let error):
                print("TmdbAPIService.configuration Failure: \(error)")
            }
        }
    }
}

extension MediaModel {
    func backdropURL(with completion: @escaping (_ url: URL?) -> Void) {
        let size = CGSize(width: 780, height: 0)

        switch self {
        case .movie(let movie):
            guard let tmdbId = movie.identifiers.tmdb else {
                completion(nil)
                return
            }

            if let cachedURL = ImagesManager.shared.cachedMovieBackdrop(with: movie.identifiers, for: size) {
                completion(cachedURL)
                return
            }

            TmdbAPIProvider.provider.request(TmdbAPIService.movieImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                        if images.backdrops.isEmpty {
                            completion(nil)
                            return
                        } // no posters

                        var imagePath = images.backdrops.first!.filePath // take the first image
                        for image in images.backdrops where image.language == nil { // try to find the first nil one!
                            imagePath = image.filePath
                            break
                        }

                        guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: size, for: .backdrop) else { return }
                        ImagesManager.shared.storeMovieBackdrop(with: imagePath, for: movie.identifiers)
                        completion(imageURL)
                    } catch {
                        print("Movie posters Error: \(error)")
                        completion(nil)
                    }
                case .failure(let error):
                    print("Movie posters Failure: \(error)")
                    completion(nil)
                }
            }
        case .show(let show), .episode(_, let show):
            guard let tmdbId = show.identifiers.tmdb else {
                completion(nil)
                return
            }

            if let cachedURL = ImagesManager.shared.cachedShowBackdrop(with: show.identifiers, for: size) {
                completion(cachedURL)
                return
            }

            TmdbAPIProvider.provider.request(TmdbAPIService.tvImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                        if images.backdrops.isEmpty {
                            completion(nil)
                            return
                        } // no posters

                        var imagePath = images.backdrops.first!.filePath // take the first image
                        for image in images.backdrops where image.language == nil { // try to find the first nil one!
                            imagePath = image.filePath
                            break
                        }

                        guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: size, for: .backdrop) else { return }
                        ImagesManager.shared.storeShowBackdrop(with: imagePath, for: show.identifiers)
                        completion(imageURL)
                    } catch {
                        print("Movie posters Error: \(error)")
                        completion(nil)
                    }
                case .failure(let error):
                    print("Movie posters Failure: \(error)")
                    completion(nil)
                }
            }
        case .season:
            completion(nil)
        case .list:
            completion(nil)
        case .showProgress:
            completion(nil)
        }
    }

    func posterURL(targetSize size: CGSize, with completion: @escaping (_ url: URL?) -> Void) {
        switch self {
        case .movie(let movie):
            guard let tmdbId = movie.identifiers.tmdb else {
                completion(nil)
                return
            }

            if let cachedURL = ImagesManager.shared.cachedMoviePoster(with: movie.identifiers, for: size) {
                completion(cachedURL)
                return
            }

            TmdbAPIProvider.provider.request(TmdbAPIService.movieImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                        if images.posters.isEmpty {
                            completion(nil)
                            return
                        } // no posters

                        var imagePath = images.posters.first!.filePath // take the first image
                        for image in images.posters where image.language == "en" { // try to find the first "en" one!
                            imagePath = image.filePath
                            break
                        }

                        guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: size, for: .poster) else { return }
                        ImagesManager.shared.storeMoviePoster(with: imagePath, for: movie.identifiers)
                        completion(imageURL)
                    } catch {
                        print("Movie posters Error: \(error)")
                        completion(nil)
                    }
                case .failure(let error):
                    print("Movie posters Failure: \(error)")
                    completion(nil)
                }
            }
        case .show(let show):
            guard let tmdbId = show.identifiers.tmdb else {
                completion(nil)
                return
            }

            if let cachedURL = ImagesManager.shared.cachedShowPoster(with: show.identifiers, for: size) {
                completion(cachedURL)
                return
            }

            TmdbAPIProvider.provider.request(TmdbAPIService.tvImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                        if images.posters.isEmpty {
                            completion(nil)
                            return
                        } // no posters

                        var imagePath = images.posters.first!.filePath // take the first image
                        for image in images.posters where image.language == "en" { // try to find the first "en" one!
                            imagePath = image.filePath
                            break
                        }

                        guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: size, for: .poster) else { return }
                        ImagesManager.shared.storeShowPoster(with: imagePath, for: show.identifiers)
                        completion(imageURL)
                    } catch {
                        print("Movie posters Error: \(error)")
                        completion(nil)
                    }
                case .failure(let error):
                    print("Movie posters Failure: \(error)")
                    completion(nil)
                }
            }
        case .episode:
            completion(nil)
        case .season:
            completion(nil)
        case .list:
            completion(nil)
        case .showProgress:
            completion(nil)
        }
    }
}

final class PosterImageView: UIImageView {
    private var filter: ImageProcessor!
    private var size: CGSize!

    var scale: CGFloat = 1.0
    var isRounded = false
    var isBlurred = false
    var transitionDuration: TimeInterval?

    var completion: ((Bool) -> Void)?
    var overrideBackgroundColor: UIColor?

    var movie: Movie? {
        didSet {
            if movie == oldValue { return }
            if movie != nil {
                show = nil
                season = nil
                loadMoviePoster()
            }
        }
    }

    var show: Show? {
        didSet {
            if show == oldValue { return }
            if show != nil {
                movie = nil
                season = nil
                loadShowPoster()
            }
        }
    }

    var season: (Show, Season)? {
        didSet {
            if season?.0 == oldValue?.0, season?.1 == oldValue?.1 { return }
            if season != nil {
                movie = nil
                show = nil
                loadSeasonPoster()
            }
        }
    }

    private func setup() {
        size = if bounds.size.width == 0 {
            CGSize(width: 300, height: 300 * 1.5)
        } else {
            bounds.size
        }
        size = if size.width == size.height {
            CGSize(width: bounds.size.width, height: bounds.size.width * 1.5)
        } else {
            size
        }

        size = size.applying(CGAffineTransform(scaleX: scale, y: scale))
        #if targetEnvironment(macCatalyst)
        size = size.applying(CGAffineTransform(scaleX: 2.0, y: 2.0))
        #else
        size = size.applying(CGAffineTransform(scaleX: AppManager.shared.scale,
                                               y: AppManager.shared.scale))
        #endif
        contentMode = .scaleAspectFill
        if isRounded {
            if isBlurred {
                filter = RoundCornerImageProcessor(cornerRadius: bounds.size.height / 2.0,
                                                   targetSize: size) |>
                    BlurImageProcessor(blurRadius: 10)
            } else {
                filter = RoundCornerImageProcessor(cornerRadius: bounds.size.height / 2.0,
                                                   targetSize: size)
            }
        } else {
            if isBlurred {
                filter = DownsamplingImageProcessor(size: size) |>
                    BlurImageProcessor(blurRadius: 10)
            } else {
                filter = DownsamplingImageProcessor(size: size)
            }
        }
        backgroundColor = overrideBackgroundColor ?? UIColor.tertiarySystemFill
    }

    private var imageOptions: KingfisherOptionsInfo {
        var options: KingfisherOptionsInfo = [
            .processor(filter),
            .loadDiskFileSynchronously
        ]

        if let transitionDuration = transitionDuration {
            options.append(.forceTransition)
            options.append(.transition(.fade(transitionDuration)))
        }

        return ImagesManager.shared.options(adding: options)
    }

    private func setPosterImage(with imageURL: URL, ifCurrent isCurrent: @escaping () -> Bool) {
        kf.setImage(with: imageURL,
                    placeholder: nil,
                    options: imageOptions) { [weak self] result in
            guard let self = self, isCurrent() else { return }

            switch result {
            case .success:
                if let completion = self.completion { completion(true) }
            case .failure(let error):
                if error.isTaskCancelled || error.isNotCurrentTask { return }
                if let completion = self.completion { completion(false) }
            }
        }
    }

    private func loadMoviePoster() {
        setup()

        guard let movie = movie else { return }

        image = nil

        guard let tmdbId = movie.identifiers.tmdb else {
            if let completion = completion { completion(false) }
            return
        }

        if let imageURL = ImagesManager.shared.cachedMoviePoster(with: movie.identifiers,
                                                                 for: size) {
            setPosterImage(with: imageURL) { [weak self] in
                guard let self = self else { return false }
                return movie == self.movie
            }
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.movieImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                    if images.posters.isEmpty {
                        DispatchQueue.main.async {
                            if movie != self.movie { return }
                            self.image = nil
                            if let completion = self.completion { completion(false) }
                        }
                        return
                    } // no posters

                    var imagePath = images.posters.first!.filePath // take the first image
                    for image in images.posters where image.language == "en" { // try to find the first en one!
                        imagePath = image.filePath
                        break
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .poster) else { return }
                    ImagesManager.shared.storeMoviePoster(with: imagePath, for: movie.identifiers)

                    DispatchQueue.main.async {
                        if movie != self.movie { return }
                        self.setPosterImage(with: imageURL) { [weak self] in
                            guard let self = self else { return false }
                            return movie == self.movie
                        }
                    }

                } catch {
                    print("Movie posters Error: \(error)")
                    DispatchQueue.main.async {
                        if movie != self.movie { return }
                        self.image = nil
                        if let completion = self.completion { completion(false) }
                    }
                }
            case .failure(let error):
                print("Movie posters Failure: \(error)")
                DispatchQueue.main.async {
                    if movie != self.movie { return }
                    self.image = nil
                    if let completion = self.completion { completion(false) }
                }
            }
        }
    }

    private func loadShowPoster() {
        setup()

        guard let show = show else { return }

        image = nil

        guard let tmdbId = show.identifiers.tmdb else {
            if let completion = completion { completion(false) }
            return
        }

        if let imageURL = ImagesManager.shared.cachedShowPoster(with: show.identifiers,
                                                                for: size) {
            setPosterImage(with: imageURL) { [weak self] in
                guard let self = self else { return false }
                return show == self.show
            }
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.tvImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                    if images.posters.isEmpty {
                        DispatchQueue.main.async {
                            if show != self.show { return }
                            self.image = nil
                            if let completion = self.completion { completion(false) }
                        }
                        return
                    } // no posters

                    var imagePath = images.posters.first!.filePath // take the first image
                    for image in images.posters where image.language == "en" { // try to find the first "en" one!
                        imagePath = image.filePath
                        break
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .poster) else { return }
                    ImagesManager.shared.storeShowPoster(with: imagePath, for: show.identifiers)

                    DispatchQueue.main.async {
                        if show != self.show { return }
                        self.setPosterImage(with: imageURL) { [weak self] in
                            guard let self = self else { return false }
                            return show == self.show
                        }
                    }

                } catch {
                    print("Tv posters Error: \(error)")
                    DispatchQueue.main.async {
                        if show != self.show { return }
                        self.image = nil
                        if let completion = self.completion { completion(false) }
                    }
                }
            case .failure(let error):
                print("Tv posters Failure: \(error)")
                DispatchQueue.main.async {
                    if show != self.show { return }
                    self.image = nil
                    if let completion = self.completion { completion(false) }
                }
            }
        }
    }

    private func loadSeasonPoster() {
        setup()

        guard let season = season else { return }

        image = nil

        guard let tmdbId = season.0.identifiers.tmdb else {
            if let completion = completion { completion(false) }
            return
        }

        if let imageURL = ImagesManager.shared.cachedSeasonPoster(with: season.0.identifiers,
                                                                  season: season.1.number,
                                                                  for: size) {
            setPosterImage(with: imageURL) { [weak self] in
                guard let self = self else { return false }
                return season.0 == self.season?.0 && season.1 == self.season?.1
            }
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.season(tmdbId, season.1.number), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersOnlyImages.self, using: TmdbAPIProvider.decoder)

                    if images.posters.isEmpty {
                        DispatchQueue.main.async {
                            if season.0 != self.season?.0 || season.1 != self.season?.1 { return }
                            self.image = nil
                            if let completion = self.completion { completion(false) }
                        }
                        return
                    } // no posters

                    var imagePath = images.posters.first!.filePath // take the first image
                    for image in images.posters where image.language == "en" { // try to find the first en one!
                        imagePath = image.filePath
                        break
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .poster) else { return }
                    ImagesManager.shared.storeSeasonPoster(with: imagePath, for: season.0.identifiers, season: season.1.number)

                    DispatchQueue.main.async {
                        if season.0 != self.season?.0 || season.1 != self.season?.1 { return }
                        self.setPosterImage(with: imageURL) { [weak self] in
                            guard let self = self else { return false }
                            return season.0 == self.season?.0 && season.1 == self.season?.1
                        }
                    }

                } catch {
                    print("Season posters Error: \(error)")
                    DispatchQueue.main.async {
                        if season.0 != self.season?.0 || season.1 != self.season?.1 { return }
                        self.image = nil
                        if let completion = self.completion { completion(false) }
                    }
                }
            case .failure(let error):
                print("Season posters Failure: \(error)")
                DispatchQueue.main.async {
                    if season.0 != self.season?.0 || season.1 != self.season?.1 { return }
                    self.image = nil
                    if let completion = self.completion { completion(false) }
                }
            }
        }
    }
}

final class PeopleProfileImageView: UIImageView {
    private var filter: ImageProcessor!
    private var size: CGSize!

    var scale: CGFloat = 1.0

    var person: Person? {
        didSet {
            loadProfileImage()
        }
    }

    private func setup() {
        size = bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
        #if targetEnvironment(macCatalyst)
        size = size.applying(CGAffineTransform(scaleX: 2.0, y: 2.0))
        #else
        size = size.applying(CGAffineTransform(scaleX: AppManager.shared.scale,
                                               y: AppManager.shared.scale))
        #endif
        contentMode = .scaleAspectFill
        filter = FaceFilter(size: size.width / 2) |>
            DownsamplingImageProcessor(size: size) |>
            SepiaFilter()
        backgroundColor = UIColor.tertiarySystemFill
    }

    private func loadProfileImage() {
        setup()

        guard let person = person else { return }

        image = nil

        guard let tmdbId = person.ids.tmdb else { return }

        if let imageURL = ImagesManager.shared.cachedPeopleImage(with: person.ids, for: size) {
            kf.setImage(with: imageURL,
                        placeholder: nil,
                        options: ImagesManager.shared.options(adding: [.processor(filter)]))
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.people(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(ProfilesImages.self, using: TmdbAPIProvider.decoder)

                    if images.profiles.isEmpty {
                        DispatchQueue.main.async {
                            if person.ids != self.person?.ids { return }
                            self.image = nil
                        }
                        return
                    } // no posters

                    var profile = images.profiles.first! // take the ffirst profile
                    for aProfile in images.profiles where profile.voteAverage ?? 0 < aProfile.voteAverage ?? 0 {
                        profile = aProfile
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: profile.filePath, with: self.size, for: .profile) else { return }
                    ImagesManager.shared.storePeopleImage(with: profile.filePath, for: person.ids)

                    DispatchQueue.main.async {
                        if person.ids != self.person?.ids { return }
                        self.kf.setImage(with: imageURL,
                                         placeholder: nil,
                                         options: ImagesManager.shared.options(adding: [.processor(self.filter)]))
                    }

                } catch {
                    print("Tv posters Error: \(error)")
                    DispatchQueue.main.async {
                        if person.ids != self.person?.ids { return }
                        self.image = nil
                    }
                }
            case .failure(let error):
                print("Tv posters Failure: \(error)")
                DispatchQueue.main.async {
                    if person.ids != self.person?.ids { return }
                    self.image = nil
                }
            }
        }
    }
}

final class BigPeopleProfileImageView: UIImageView {
    private var filter: ImageProcessor!
    private var size: CGSize!

    var scale: CGFloat = 1.0
    var transitionDuration: TimeInterval?

    var person: Person? {
        didSet {
            loadProfileImage()
        }
    }

    private func setup() {
        size = bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
        #if targetEnvironment(macCatalyst)
        size = size.applying(CGAffineTransform(scaleX: 2.0, y: 2.0))
        #else
        size = size.applying(CGAffineTransform(scaleX: AppManager.shared.scale,
                                               y: AppManager.shared.scale))
        #endif
        contentMode = .scaleAspectFill
        filter = DownsamplingImageProcessor(size: size)
        backgroundColor = UIColor.tertiarySystemFill
    }

    private var imageOptions: KingfisherOptionsInfo {
        var options: KingfisherOptionsInfo = [
            .processor(filter),
            .loadDiskFileSynchronously
        ]

        if let transitionDuration = transitionDuration {
            options.append(.forceTransition)
            options.append(.transition(.fade(transitionDuration)))
        }

        return ImagesManager.shared.options(adding: options)
    }

    private func setProfileImage(with imageURL: URL, ifCurrent isCurrent: @escaping () -> Bool) {
        kf.setImage(with: imageURL,
                    placeholder: nil,
                    options: imageOptions) { [weak self] result in
            guard let self = self, isCurrent() else { return }

            if case .failure(let error) = result,
               !error.isTaskCancelled,
               !error.isNotCurrentTask {
                self.image = nil
            }
        }
    }

    private func loadProfileImage() {
        setup()

        guard let person = person else { return }

        image = nil

        guard let tmdbId = person.ids.tmdb else { return }

        if let imageURL = ImagesManager.shared.cachedPeopleImage(with: person.ids, for: size) {
            setProfileImage(with: imageURL) { [weak self] in
                guard let self = self else { return false }
                return person.ids == self.person?.ids
            }
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.people(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(ProfilesImages.self, using: TmdbAPIProvider.decoder)

                    if images.profiles.isEmpty {
                        DispatchQueue.main.async {
                            if person.ids != self.person?.ids { return }
                            self.image = nil
                        }
                        return
                    } // no posters

                    var profile = images.profiles.first! // take the ffirst profile
                    for aProfile in images.profiles where profile.voteAverage ?? 0 < aProfile.voteAverage ?? 0 {
                        profile = aProfile
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: profile.filePath, with: self.size, for: .profile) else { return }
                    ImagesManager.shared.storePeopleImage(with: profile.filePath, for: person.ids)

                    DispatchQueue.main.async {
                        if person.ids != self.person?.ids { return }
                        self.setProfileImage(with: imageURL) { [weak self] in
                            guard let self = self else { return false }
                            return person.ids == self.person?.ids
                        }
                    }

                } catch {
                    print("Tv posters Error: \(error)")
                    DispatchQueue.main.async {
                        if person.ids != self.person?.ids { return }
                        self.image = nil
                    }
                }
            case .failure(let error):
                print("Tv posters Failure: \(error)")
                DispatchQueue.main.async {
                    if person.ids != self.person?.ids { return }
                    self.image = nil
                }
            }
        }
    }
}

final class PosterButton: UIButton {
    private var filter: ImageProcessor!
    private var size: CGSize!

    var scale: CGFloat = 1.0
    var isRounded = false

    var movie: Movie? {
        didSet {
            if movie == oldValue { return }
            if movie != nil {
                show = nil
                season = nil
                loadMoviePoster()
            }
        }
    }

    var show: Show? {
        didSet {
            if show == oldValue { return }
            if show != nil {
                movie = nil
                season = nil
                loadShowPoster()
            }
        }
    }

    var season: (Show, Season)? {
        didSet {
            if season?.0 == oldValue?.0, season?.1 == oldValue?.1 { return }
            if season != nil {
                movie = nil
                show = nil
                loadSeasonPoster()
            }
        }
    }

    private func setup() {
        size = bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
        #if targetEnvironment(macCatalyst)
        size = size.applying(CGAffineTransform(scaleX: 2.0, y: 2.0))
        #else
        size = size.applying(CGAffineTransform(scaleX: AppManager.shared.scale,
                                               y: AppManager.shared.scale))
        #endif
        contentMode = .scaleAspectFill
        if isRounded {
            filter = RoundCornerImageProcessor(cornerRadius: bounds.size.height / 2.0,
                                               targetSize: size)
        } else {
            filter = DownsamplingImageProcessor(size: size)
        }
        backgroundColor = UIColor.tertiarySystemFill
    }

    private func loadMoviePoster() {
        setup()

        guard let movie = movie else { return }

        setImage(nil, for: .normal)

        guard let tmdbId = movie.identifiers.tmdb else { return }

        if let imageURL = ImagesManager.shared.cachedMoviePoster(with: movie.identifiers,
                                                                 for: size) {
            kf.setImage(with: imageURL,
                        for: .normal,
                        placeholder: nil,
                        options: ImagesManager.shared.options(adding: [.processor(filter)]))
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.movieImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                    if images.posters.isEmpty {
                        DispatchQueue.main.async {
                            if movie != self.movie { return }
                            self.setImage(nil, for: .normal)
                        }
                        return
                    } // no posters

                    var imagePath = images.posters.first!.filePath // take the first image
                    for image in images.posters where image.language == "en" { // try to find the first en one!
                        imagePath = image.filePath
                        break
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .poster) else { return }
                    ImagesManager.shared.storeMoviePoster(with: imagePath, for: movie.identifiers)

                    DispatchQueue.main.async {
                        if movie != self.movie { return }
                        self.kf.setImage(with: imageURL,
                                         for: .normal,
                                         placeholder: nil,
                                         options: ImagesManager.shared.options(adding: [.processor(self.filter)]))
                    }

                } catch {
                    print("Movie posters Error: \(error)")
                    DispatchQueue.main.async {
                        if movie != self.movie { return }
                        self.setImage(nil, for: .normal)
                    }
                }
            case .failure(let error):
                print("Movie posters Failure: \(error)")
                DispatchQueue.main.async {
                    if movie != self.movie { return }
                    self.setImage(nil, for: .normal)
                }
            }
        }
    }

    private func loadShowPoster() {
        setup()

        guard let show = show else { return }

        setImage(nil, for: .normal)

        guard let tmdbId = show.identifiers.tmdb else { return }

        if let imageURL = ImagesManager.shared.cachedShowPoster(with: show.identifiers,
                                                                for: size) {
            kf.setImage(with: imageURL,
                        for: .normal,
                        placeholder: nil,
                        options: ImagesManager.shared.options(adding: [.processor(filter)]))
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.tvImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                    if images.posters.isEmpty {
                        DispatchQueue.main.async {
                            if show != self.show { return }
                            self.setImage(nil, for: .normal)
                        }
                        return
                    } // no posters

                    var imagePath = images.posters.first!.filePath // take the first image
                    for image in images.posters where image.language == "en" { // try to find the first "en" one!
                        imagePath = image.filePath
                        break
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .poster) else { return }
                    ImagesManager.shared.storeShowPoster(with: imagePath, for: show.identifiers)

                    DispatchQueue.main.async {
                        if show != self.show { return }
                        self.kf.setImage(with: imageURL,
                                         for: .normal,
                                         placeholder: nil,
                                         options: ImagesManager.shared.options(adding: [.processor(self.filter)]))
                    }

                } catch {
                    print("Tv posters Error: \(error)")
                    DispatchQueue.main.async {
                        if show != self.show { return }
                        self.setImage(nil, for: .normal)
                    }
                }
            case .failure(let error):
                print("Tv posters Failure: \(error)")
                DispatchQueue.main.async {
                    if show != self.show { return }
                    self.setImage(nil, for: .normal)
                }
            }
        }
    }

    private func loadSeasonPoster() {
        setup()

        guard let season = season else { return }

        setImage(nil, for: .normal)

        guard let tmdbId = season.0.identifiers.tmdb else { return }

        if let imageURL = ImagesManager.shared.cachedSeasonPoster(with: season.0.identifiers,
                                                                  season: season.1.number,
                                                                  for: size) {
            kf.setImage(with: imageURL,
                        for: .normal,
                        placeholder: nil,
                        options: ImagesManager.shared.options(adding: [.processor(filter)]))
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.season(tmdbId, season.1.number), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersOnlyImages.self, using: TmdbAPIProvider.decoder)

                    if images.posters.isEmpty {
                        DispatchQueue.main.async {
                            if season.0 != self.season?.0 || season.1 != self.season?.1 { return }
                            self.setImage(nil, for: .normal)
                        }
                        return
                    } // no posters

                    var imagePath = images.posters.first!.filePath // take the first image
                    for image in images.posters where image.language == "en" { // try to find the first en one!
                        imagePath = image.filePath
                        break
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .poster) else { return }
                    ImagesManager.shared.storeSeasonPoster(with: imagePath, for: season.0.identifiers, season: season.1.number)

                    DispatchQueue.main.async {
                        if season.0 != self.season?.0 || season.1 != self.season?.1 { return }
                        self.kf.setImage(with: imageURL,
                                         for: .normal,
                                         placeholder: nil,
                                         options: ImagesManager.shared.options(adding: [.processor(self.filter)]))
                    }

                } catch {
                    print("Season posters Error: \(error)")
                    DispatchQueue.main.async {
                        if season.0 != self.season?.0 || season.1 != self.season?.1 { return }
                        self.setImage(nil, for: .normal)
                    }
                }
            case .failure(let error):
                print("Season posters Failure: \(error)")
                DispatchQueue.main.async {
                    if season.0 != self.season?.0 || season.1 != self.season?.1 { return }
                    self.setImage(nil, for: .normal)
                }
            }
        }
    }
}

// MARK: String Helper

/// Example = Ex
/// For Example = FE
/// for example = fe
/// "" = DP
public extension String {
    var initials: String {
        let words = components(separatedBy: .whitespacesAndNewlines)

        // to identify letters
        let letters = CharacterSet.letters
        var firstChar = ""
        var secondChar = ""
        var firstCharFoundIndex: Int = -1
        var firstCharFound = false
        var secondCharFound = false

        for (index, item) in words.enumerated() {
            if item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            // browse through the rest of the word
            for char in item.unicodeScalars where letters.contains(char) { // check if its a aplha
                if !firstCharFound {
                    firstChar = String(char)
                    firstCharFound = true
                    firstCharFoundIndex = index

                } else if !secondCharFound {
                    secondChar = String(char)
                    if firstCharFoundIndex != index {
                        secondCharFound = true
                    }

                    break
                } else {
                    break
                }
            }
        }

        if firstChar.isEmpty && secondChar.isEmpty {
            firstChar = ""
            secondChar = ""
        }

        return firstChar + secondChar
    }
}

final class BackdropImageView: UIImageView {
    private var filter: ImageProcessor!
    private var size: CGSize!

    var scale: CGFloat = 1.0
    var isRounded = false
    var transitionDuration: TimeInterval?

    var completion: ((Bool) -> Void)?
    var overrideBackgroundColor: UIColor?

    var showEpisodeSpoilers = true

    var media: MediaModel? {
        didSet {
            if media == oldValue { return }
            if media != nil {
                switch media! {
                case .movie:
                    loadMovieBackdrop()
                case .show:
                    loadShowBackdrop()
                case .episode:
                    if showEpisodeSpoilers == true {
                        loadEpisodeBackdrop()
                    } else {
                        loadShowBackdrop()
                    }
                case .season:
                    break
                case .list:
                    break
                case .showProgress:
                    break
                }
            }
        }
    }

    private func setup() {
        size = bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
        #if targetEnvironment(macCatalyst)
        size = size.applying(CGAffineTransform(scaleX: 2.0, y: 2.0))
        #else
        size = size.applying(CGAffineTransform(scaleX: AppManager.shared.scale,
                                               y: AppManager.shared.scale))
        #endif
        contentMode = .scaleAspectFill
        if isRounded {
            filter = RoundCornerImageProcessor(cornerRadius: bounds.size.height / 2.0,
                                               targetSize: size)
        } else {
            filter = DownsamplingImageProcessor(size: size)
        }
        backgroundColor = overrideBackgroundColor ?? UIColor.tertiarySystemFill
    }

    private func imageOptions(defaultTransitionDuration: TimeInterval? = nil) -> KingfisherOptionsInfo {
        var options: KingfisherOptionsInfo = [
            .processor(filter),
            .loadDiskFileSynchronously
        ]

        if let duration = transitionDuration ?? defaultTransitionDuration {
            options.append(.forceTransition)
            options.append(.transition(.fade(duration)))
        }

        return ImagesManager.shared.options(adding: options)
    }

    private func setBackdropImage(with imageURL: URL,
                                  defaultTransitionDuration: TimeInterval? = nil,
                                  ifCurrent isCurrent: @escaping () -> Bool) {
        kf.setImage(with: imageURL,
                    placeholder: nil,
                    options: imageOptions(defaultTransitionDuration: defaultTransitionDuration)) { [weak self] result in
            guard let self = self, isCurrent() else { return }

            switch result {
            case .success:
                if let completion = self.completion { completion(true) }
            case .failure(let error):
                if error.isTaskCancelled || error.isNotCurrentTask { return }
                if let completion = self.completion { completion(false) }
            }
        }
    }

    private func loadMovieBackdrop() {
        setup()

        guard let movie = media!.movie else { return }

        image = nil

        guard let tmdbId = movie.identifiers.tmdb else {
            if let completion = completion { completion(false) }
            return
        }

        if let imageURL = ImagesManager.shared.cachedMovieBackdrop(with: movie.identifiers,
                                                                   for: size) {
            setBackdropImage(with: imageURL) { [weak self] in
                guard let self = self else { return false }
                return movie == self.media?.movie
            }
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.movieImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                    if images.backdrops.isEmpty {
                        DispatchQueue.main.async {
                            if movie != self.media?.movie { return }
                            self.image = nil
                            if let completion = self.completion { completion(false) }
                        }
                        return
                    } // no posters

                    var imagePath = images.backdrops.first!.filePath // take the first image
                    for image in images.backdrops where image.language == nil { // try to find the first nil one!
                        imagePath = image.filePath
                        break
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .backdrop) else { return }
                    ImagesManager.shared.storeMovieBackdrop(with: imagePath, for: movie.identifiers)

                    DispatchQueue.main.async {
                        if movie != self.media?.movie { return }
                        self.setBackdropImage(with: imageURL) { [weak self] in
                            guard let self = self else { return false }
                            return movie == self.media?.movie
                        }
                    }

                } catch {
                    print("Movie posters Error: \(error)")
                    DispatchQueue.main.async {
                        if movie != self.media?.movie { return }
                        self.image = nil
                        if let completion = self.completion { completion(false) }
                    }
                }
            case .failure(let error):
                print("Movie posters Failure: \(error)")
                DispatchQueue.main.async {
                    if movie != self.media?.movie { return }
                    self.image = nil
                    if let completion = self.completion { completion(false) }
                }
            }
        }
    }

    private func loadShowBackdrop() {
        setup()

        guard let show = media!.show else { return }

        image = nil

        guard let tmdbId = show.identifiers.tmdb else {
            if let completion = completion { completion(false) }
            return
        }

        if let imageURL = ImagesManager.shared.cachedShowBackdrop(with: show.identifiers,
                                                                  for: size) {
            setBackdropImage(with: imageURL) { [weak self] in
                guard let self = self else { return false }
                return show == self.media?.show
            }
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.tvImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                    if images.backdrops.isEmpty {
                        DispatchQueue.main.async {
                            if show != self.media?.show { return }
                            self.image = nil
                            if let completion = self.completion { completion(false) }
                        }
                        return
                    } // no posters

                    var imagePath = images.backdrops.first!.filePath // take the first image
                    for image in images.backdrops where image.language == nil { // try to find the first nil one!
                        imagePath = image.filePath
                        break
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .backdrop) else { return }
                    ImagesManager.shared.storeShowBackdrop(with: imagePath, for: show.identifiers)

                    DispatchQueue.main.async {
                        if show != self.media?.show { return }
                        self.setBackdropImage(with: imageURL) { [weak self] in
                            guard let self = self else { return false }
                            return show == self.media?.show
                        }
                    }

                } catch {
                    print("Tv posters Error: \(error)")
                    DispatchQueue.main.async {
                        if show != self.media?.show { return }
                        self.image = nil
                        if let completion = self.completion { completion(false) }
                    }
                }
            case .failure(let error):
                print("Tv posters Failure: \(error)")
                DispatchQueue.main.async {
                    if show != self.media?.show { return }
                    self.image = nil
                    if let completion = self.completion { completion(false) }
                }
            }
        }
    }

    private func loadEpisodeBackdrop() {
        setup()

        guard case .episode(let episode, let show) = media else { return }

        image = nil

        guard let tmdbId = show.identifiers.tmdb else {
            if let completion = completion { completion(false) }
            return
        }

        if let imageURL = ImagesManager.shared.cachedEpisodeImage(with: episode.identifiers,
                                                                  for: size) {
            setBackdropImage(with: imageURL,
                             defaultTransitionDuration: 0.6) { [weak self] in
                guard let self = self else { return false }
                return episode == self.media?.episode
            }
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.episode(tmdbId, episode.season, episode.number), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(StillsImages.self, using: TmdbAPIProvider.decoder)

                    if images.stills.isEmpty {
                        DispatchQueue.main.async {
                            if episode != self.media?.episode { return }
                            self.image = nil
                            if let completion = self.completion { completion(false) }
                        }
                        return
                    } // no posters

                    let imagePath = images.stills.first!.filePath // take the first image

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .backdrop) else { return }
                    ImagesManager.shared.storeEpisodeImage(with: imagePath, for: episode.identifiers)

                    DispatchQueue.main.async {
                        if episode != self.media?.episode { return }
                        self.setBackdropImage(with: imageURL,
                                              defaultTransitionDuration: 0.6) { [weak self] in
                            guard let self = self else { return false }
                            return episode == self.media?.episode
                        }
                    }

                } catch {
                    print("Tv posters Error: \(error)")
                    DispatchQueue.main.async {
                        if episode != self.media?.episode { return }
                        self.image = nil
                        if let completion = self.completion { completion(false) }
                    }
                }
            case .failure(let error):
                print("Tv posters Failure: \(error)")
                DispatchQueue.main.async {
                    if episode != self.media?.episode { return }
                    self.image = nil
                    if let completion = self.completion { completion(false) }
                }
            }
        }
    }
}

final class LogoImageView: UIImageView {
    private var filter: ImageProcessor!
    private var size: CGSize!

    var scale: CGFloat = 1.0

    var completion: ((Bool) -> Void)?

    var media: MediaModel? {
        didSet {
            if media == oldValue { return }
            if media != nil {
                switch media! {
                case .movie:
                    loadMovieLogo()
                case .show:
                    loadShowLogo()
                case .episode:
                    image = nil
                case .season:
                    image = nil
                case .list:
                    image = nil
                case .showProgress:
                    image = nil
                }
            } else {
                image = nil
            }
        }
    }

    private func setup() {
        size = bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
        #if targetEnvironment(macCatalyst)
        size = size.applying(CGAffineTransform(scaleX: 2.0, y: 2.0))
        #else
        size = size.applying(CGAffineTransform(scaleX: AppManager.shared.scale,
                                               y: AppManager.shared.scale))
        #endif

        backgroundColor = UIColor.clear

        filter = DownsamplingImageProcessor(size: size)
    }

    private func loadMovieLogo() {
        setup()

        guard let movie = media!.movie else { return }

        image = nil

        guard let tmdbId = movie.identifiers.tmdb else {
            if let completion = completion { completion(false) }
            return
        }

        if let imageURL = ImagesManager.shared.cachedMovieLogo(with: movie.identifiers,
                                                               for: size) {
            kf.setImage(with: imageURL,
                        placeholder: nil,
                        options: ImagesManager.shared.options(adding: [.processor(filter)]))
            if let completion = completion { completion(true) }
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.movieImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                    var imagePath: String?
                    for image in images.logos where image.language == "en" && image.filePath.hasSuffix(".png") { // try to find the first English one!
                        imagePath = image.filePath
                        break
                    }

                    if imagePath == nil {
                        for image in images.logos where image.language == nil && image.filePath.hasSuffix(".png") { // otherwise try to find the first without language set!
                            imagePath = image.filePath
                            break
                        }
                    }

                    // If no english and no no-language, don't show anything!
                    guard let imagePath = imagePath else {
                        DispatchQueue.main.async {
                            if movie != self.media?.movie { return }
                            self.image = nil
                            if let completion = self.completion { completion(false) }
                        }
                        return
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .logo) else { return }
                    ImagesManager.shared.storeMovieLogo(with: imagePath, for: movie.identifiers)

                    DispatchQueue.main.async {
                        if movie != self.media?.movie { return }
                        self.kf.setImage(with: imageURL,
                                         placeholder: nil,
                                         options: ImagesManager.shared.options(adding: [.processor(self.filter)])) { [weak self] _ in
                            guard let self = self else { return }
                            if let completion = self.completion { completion(true) }
                        }
                    }

                } catch {
                    print("Movie Logo Error: \(error)")
                    DispatchQueue.main.async {
                        if movie != self.media?.movie { return }
                        self.image = nil
                        if let completion = self.completion { completion(false) }
                    }
                }
            case .failure(let error):
                print("Movie Logo Failure: \(error)")
                DispatchQueue.main.async {
                    if movie != self.media?.movie { return }
                    self.image = nil
                    if let completion = self.completion { completion(false) }
                }
            }
        }
    }

    private func loadShowLogo() {
        setup()

        guard let show = media!.show else { return }

        image = nil

        guard let tmdbId = show.identifiers.tmdb else {
            if let completion = completion { completion(false) }
            return
        }

        if let imageURL = ImagesManager.shared.cachedShowLogo(with: show.identifiers,
                                                              for: size) {
            kf.setImage(with: imageURL,
                        placeholder: nil,
                        options: ImagesManager.shared.options(adding: [.processor(filter)]))
            if let completion = completion { completion(true) }
            return
        }

        TmdbAPIProvider.provider.request(TmdbAPIService.tvImages(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let images = try response.map(PostersImages.self, using: TmdbAPIProvider.decoder)

                    var imagePath: String?
                    for image in images.logos where image.language == "en" && image.filePath.hasSuffix(".png") { // try to find the first en one!
                        imagePath = image.filePath
                        break
                    }

                    if imagePath == nil {
                        for image in images.logos where image.language == nil && image.filePath.hasSuffix(".png") { // otherwise try to find the first without language set!
                            imagePath = image.filePath
                            break
                        }
                    }

                    // If no english and no no-language, don't show anything!
                    guard let imagePath = imagePath else {
                        DispatchQueue.main.async {
                            if show != self.media?.show { return }
                            self.image = nil
                            if let completion = self.completion { completion(false) }
                        }
                        return
                    }

                    guard let imageURL = ImagesManager.shared.imageURL(with: imagePath, with: self.size, for: .logo) else { return }
                    ImagesManager.shared.storeShowLogo(with: imagePath, for: show.identifiers)

                    DispatchQueue.main.async {
                        if show != self.media?.show { return }
                        self.kf.setImage(with: imageURL,
                                         placeholder: nil,
                                         options: ImagesManager.shared.options(adding: [.processor(self.filter)])) { [weak self] _ in
                            guard let self = self else { return }
                            if let completion = self.completion { completion(true) }
                        }
                    }

                } catch {
                    print("Tv Logo Error: \(error)")
                    DispatchQueue.main.async {
                        if show != self.media?.show { return }
                        self.image = nil
                        if let completion = self.completion { completion(false) }
                    }
                }
            case .failure(let error):
                print("Tv Logo Failure: \(error)")
                DispatchQueue.main.async {
                    if show != self.media?.show { return }
                    self.image = nil
                    if let completion = self.completion { completion(false) }
                }
            }
        }
    }
}
