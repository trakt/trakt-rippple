//
//  LiveActivityManager.swift
//  Rippple
//
//  Created by Kevin Cador on 28/07/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import BackgroundTasks
import Foundation
import Receiver
#if !targetEnvironment(macCatalyst)
import ActivityKit
import WidgetKit

final class LiveActivityManager {
    private let disposeBag = DisposeBag()

    private init() {}

    func setup() {
        // just to make sure no activity are running when we restart the app
        Task {
            await self.stopActivity()
        }

        WatchingManager.shared.onWatchingItemChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if let watchingItem = WatchingManager.shared.watchingItem {
                if let movie = watchingItem.movie {
                    movie.mediaModel.posterURL(targetSize: CGSize(width: 200, height: 300)) { [weak self] url in
                        guard let self = self else { return }
                        self.fetchImageAndSetActivity(widgetModel: WidgetModel(label: "Now Watching",
                                                                               title: movie.title,
                                                                               subtitle: (movie.releaseYear != nil) ? "\(movie.releaseYear!)" : "",
                                                                               behind: nil,
                                                                               redacted: false,
                                                                               deeplink: movie.mediaModel.deeplink,
                                                                               progress: WatchingManager.shared.progress,
                                                                               runtime: Int(watchingItem.expireDate.timeIntervalSinceReferenceDate - watchingItem.startDate.timeIntervalSinceReferenceDate),
                                                                               endDate: watchingItem.expireDate),
                                                      url: url)
                    }
                } else if let show = watchingItem.show {
                    show.mediaModel.posterURL(targetSize: CGSize(width: 200, height: 300)) { [weak self] url in
                        guard let self = self else { return }
                        self.fetchImageAndSetActivity(widgetModel: WidgetModel(label: "Now Watching",
                                                                               title: show.title,
                                                                               subtitle: watchingItem.episode?.localizedEpisodeNumber,
                                                                               behind: nil,
                                                                               redacted: false,
                                                                               deeplink: watchingItem.episode?.mediaModel(given: show).deeplink,
                                                                               progress: WatchingManager.shared.progress,
                                                                               runtime: Int(watchingItem.expireDate.timeIntervalSinceReferenceDate - watchingItem.startDate.timeIntervalSinceReferenceDate),
                                                                               endDate: watchingItem.expireDate),
                                                      url: url)
                    }
                }
            } else {
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
    }

    private func fetchImageAndSetActivity(widgetModel: WidgetModel, url: URL?) {
        DispatchQueue.main.async {
            let scale = AppManager.shared.scale
            DispatchQueue.global(qos: .background).async {
                if let url = url {
                    do {
                        let data = try Data(contentsOf: url)
                        if let image = UIImage(data: data) {
                            let poster = self.downscaleImage(image: image,
                                                             toSize: CGSize(width: 60, height: 60 * 1.5),
                                                             scale: scale)
                            UserDefaults(suiteName: "group.tv.trakt.rippple")!.setValue(poster.jpegData(compressionQuality: 1.0), forKey: "LiveActivityManager.poster")

                            let thumb = self.downscaleImage(image: image,
                                                            toSize: CGSize(width: 28, height: 28 * 1.5),
                                                            scale: scale)
                            UserDefaults(suiteName: "group.tv.trakt.rippple")!.setValue(thumb.jpegData(compressionQuality: 1.0), forKey: "LiveActivityManager.thumb")
                        } else {
                            UserDefaults(suiteName: "group.tv.trakt.rippple")!.removeObject(forKey: "LiveActivityManager.poster")
                            UserDefaults(suiteName: "group.tv.trakt.rippple")!.removeObject(forKey: "LiveActivityManager.thumb")
                        }
                        DispatchQueue.main.async {
                            Task {
                                await self.startActivity(model: widgetModel)
                            }
                        }
                    } catch {
                        UserDefaults(suiteName: "group.tv.trakt.rippple")!.removeObject(forKey: "LiveActivityManager.poster")
                        UserDefaults(suiteName: "group.tv.trakt.rippple")!.removeObject(forKey: "LiveActivityManager.thumb")
                        DispatchQueue.main.async {
                            Task {
                                await self.startActivity(model: widgetModel)
                            }
                        }
                    }
                } else {
                    UserDefaults(suiteName: "group.tv.trakt.rippple")!.removeObject(forKey: "LiveActivityManager.poster")
                    UserDefaults(suiteName: "group.tv.trakt.rippple")!.removeObject(forKey: "LiveActivityManager.thumb")
                    DispatchQueue.main.async {
                        Task {
                            await self.startActivity(model: widgetModel)
                        }
                    }
                }
            }
        }
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

    private func startActivity(model: WidgetModel) async {
        for activity in Activity<RipppleLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
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
            print("Error requesting Live Activity \(error.localizedDescription)")
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

    private func stopActivity() async {
        for activity in Activity<RipppleLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func stopActivityIfNeeded() async {
        for activity in Activity<RipppleLiveActivityAttributes>.activities {
            if let endDate = activity.content.state.entry.endDate, endDate >= .now {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
