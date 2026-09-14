//
//  LiveActivityManager.swift
//  Rippple
//
//  Created by Kevin Cador on 28/07/2022.
//  Copyright © Trakt. All rights reserved.
//

import BackgroundTasks
import Foundation
import Receiver
import UIKit
#if !targetEnvironment(macCatalyst)
import ActivityKit
import WidgetKit

final class LiveActivityManager {
    private let disposeBag = DisposeBag()
    private var currentImageIdentifier: String?
    private var imageRequestIdentifier: String?

    private init() {}

    func setup() {
        WatchingManager.shared.onWatchingItemChangedReceiver.listen { [weak self] watchingItem, _ in
            guard let self = self else { return }
            if let watchingItem = watchingItem {
                let imageMedia: MediaModel
                let widgetModel: WidgetModel
                if let movie = watchingItem.movie {
                    imageMedia = movie.mediaModel
                    widgetModel = WidgetModel(label: "Now Watching",
                                              title: movie.title,
                                              subtitle: movie.releaseYear.map(String.init) ?? "",
                                              behind: nil,
                                              redacted: false,
                                              deeplink: imageMedia.deeplink,
                                              progress: WatchingManager.shared.progress,
                                              runtime: Int(watchingItem.expireDate.timeIntervalSinceReferenceDate - watchingItem.startDate.timeIntervalSinceReferenceDate),
                                              endDate: watchingItem.expireDate)
                } else if let show = watchingItem.show {
                    imageMedia = show.mediaModel
                    widgetModel = WidgetModel(label: "Now Watching",
                                              title: show.title,
                                              subtitle: watchingItem.episode?.localizedEpisodeNumber,
                                              behind: nil,
                                              redacted: false,
                                              deeplink: watchingItem.episode?.mediaModel(given: show).deeplink,
                                              progress: WatchingManager.shared.progress,
                                              runtime: Int(watchingItem.expireDate.timeIntervalSinceReferenceDate - watchingItem.startDate.timeIntervalSinceReferenceDate),
                                              endDate: watchingItem.expireDate)
                } else {
                    return
                }
                Task {
                    await self.ensureActivity(model: widgetModel)
                }
                self.requestImageIfNeeded(for: imageMedia, widgetModel: widgetModel)
            } else {
                self.currentImageIdentifier = nil
                self.imageRequestIdentifier = nil
                self.clearCachedImages()
                Task {
                    await self.stopActivity()
                }
            }
        }.disposed(by: disposeBag)

        WatchingManager.shared.onProgressChangedReceiver.hotOnly().listen { [weak self] progress in
            guard let self = self else { return }
            Task {
                if progress >= 1.0 {
                    await self.stopActivity()
                }
            }
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.currentImageIdentifier = nil
            self.imageRequestIdentifier = nil
            self.clearCachedImages()
            Task {
                await self.stopActivity()
            }
        }.disposed(by: disposeBag)
    }

    private func requestImageIfNeeded(for media: MediaModel, widgetModel: WidgetModel) {
        guard let identifier = media.deeplink?.absoluteString else { return }
        currentImageIdentifier = identifier

        let defaults = UserDefaults(suiteName: "group.tv.trakt.rippple")!
        let hasCachedImage = defaults.data(forKey: "LiveActivityManager.poster") != nil &&
            defaults.data(forKey: "LiveActivityManager.thumb") != nil &&
            defaults.string(forKey: "LiveActivityManager.imageIdentifier") == identifier
        guard hasCachedImage == false, imageRequestIdentifier != identifier else { return }

        clearCachedImages()
        imageRequestIdentifier = identifier
        media.posterURL(targetSize: CGSize(width: 200, height: 300)) { [weak self] url in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard self.imageRequestIdentifier == identifier else { return }
                guard let url = url else {
                    self.imageRequestIdentifier = nil
                    return
                }
                self.fetchImageAndUpdateActivity(widgetModel: widgetModel,
                                                 url: url,
                                                 identifier: identifier)
            }
        }
    }

    private func fetchImageAndUpdateActivity(widgetModel: WidgetModel, url: URL, identifier: String) {
        let scale = AppManager.shared.scale

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let image = (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
            let poster = image.map {
                self.downscaleImage(image: $0,
                                    toSize: CGSize(width: 60, height: 60 * 1.5),
                                    scale: scale)
            }
            let thumb = image.map {
                self.downscaleImage(image: $0,
                                    toSize: CGSize(width: 28, height: 28 * 1.5),
                                    scale: scale)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard self.imageRequestIdentifier == identifier else { return }
                self.imageRequestIdentifier = nil
                guard self.currentImageIdentifier == identifier else { return }
                guard let poster = poster, let thumb = thumb else { return }

                let defaults = UserDefaults(suiteName: "group.tv.trakt.rippple")!
                defaults.setValue(poster.jpegData(compressionQuality: 1.0), forKey: "LiveActivityManager.poster")
                defaults.setValue(thumb.jpegData(compressionQuality: 1.0), forKey: "LiveActivityManager.thumb")
                defaults.setValue(identifier, forKey: "LiveActivityManager.imageIdentifier")
                Task {
                    await self.refreshActivity(model: widgetModel)
                }
            }
        }
    }

    private func clearCachedImages() {
        let defaults = UserDefaults(suiteName: "group.tv.trakt.rippple")!
        defaults.removeObject(forKey: "LiveActivityManager.poster")
        defaults.removeObject(forKey: "LiveActivityManager.thumb")
        defaults.removeObject(forKey: "LiveActivityManager.imageIdentifier")
    }

    private func downscaleImage(image: UIImage, toSize targetSize: CGSize, scale: CGFloat = 1.0) -> UIImage {
        let actualScaleFactor = scale
        let size = image.size
        let imageScaleFactor = image.scale
        let imagePixelSize = CGSize(width: size.width * imageScaleFactor, height: size.height * imageScaleFactor)

        let requiredMinPixelSize = CGSize(width: targetSize.width * actualScaleFactor, height: targetSize.height * actualScaleFactor)
        let canBeDownscaled = (requiredMinPixelSize.width < imagePixelSize.width) && (requiredMinPixelSize.height < imagePixelSize.height)

        if !canBeDownscaled {
            return image
        }

        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        // This part is based on https://gist.github.com/hcatlin/180e81cd961573e3c54d
        // but it fixes the bug with wrong ratio used
        let downscaledImageSize: CGSize
        if widthRatio > heightRatio {
            downscaledImageSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        } else {
            downscaledImageSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        }

        let imageRect: CGRect
        if CGSizeEqualToSize(downscaledImageSize, targetSize) {
            imageRect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        } else {
            let xDiff = (downscaledImageSize.width > targetSize.width) ? 0.5 * (downscaledImageSize.width - targetSize.width) : 0.0
            let yDiff = (downscaledImageSize.height > targetSize.height) ? 0.5 * (downscaledImageSize.height - targetSize.height) : 0.0
            imageRect = CGRect(x: -xDiff, y: -yDiff, width: downscaledImageSize.width, height: downscaledImageSize.height)
        }

        UIGraphicsBeginImageContextWithOptions(targetSize, false, scale)
        image.draw(in: imageRect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }

    static let shared = LiveActivityManager()

    private func ensureActivity(model: WidgetModel) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are disabled")
            return
        }

        if Activity<RipppleLiveActivityAttributes>.activities.isEmpty == false {
            await refreshActivity(model: model)
            return
        }

        do {
            let pizzaDeliveryAttributes = RipppleLiveActivityAttributes()

            let initialContentState = RipppleLiveActivityAttributes.LiveActivityStatus(entry: model)
            let content = ActivityContent(state: initialContentState, staleDate: model.endDate)

            _ = try Activity.request(attributes: pizzaDeliveryAttributes,
                                     content: content)

            await AppManager.shared.scheduleNewBackgroundRefresh()
            /*
             let activity = try Activity<RipppleLiveActivityAttributes>.request(attributes: pizzaDeliveryAttributes,
                                                                             contentState: initialContentState)
             if let endDate = model.endDate {
                 await activity.end(using: initialContentState,
                                    dismissalPolicy: .after(endDate))
             }
             */
            print("Live Activity started...")
        } catch {
            print("Error requesting Live Activity: \(error)")
        }
    }

    private func updateActivity(progress: Double) async {
        for activity in Activity<RipppleLiveActivityAttributes>.activities {
            var model = activity.content.state.entry
            model.progress = progress

            let updatedDeliveryStatus = RipppleLiveActivityAttributes.LiveActivityStatus(entry: model)
            let content = ActivityContent(state: updatedDeliveryStatus, staleDate: model.endDate)

            await activity.update(content)
        }
    }

    private func refreshActivity(model: WidgetModel) async {
        let state = RipppleLiveActivityAttributes.LiveActivityStatus(entry: model)
        let content = ActivityContent(state: state, staleDate: model.endDate)
        for activity in Activity<RipppleLiveActivityAttributes>.activities {
            await activity.update(content)
        }
    }

    private func stopActivity() async {
        for activity in Activity<RipppleLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func stopActivityIfNeeded() async {
        for activity in Activity<RipppleLiveActivityAttributes>.activities {
            if let endDate = activity.content.state.entry.endDate, endDate <= .now {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
