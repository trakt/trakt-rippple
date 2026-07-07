//
//  LiveActivity.swift
//  Rippple
//
//  Created by Kevin Cador on 28/07/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

#if !targetEnvironment(macCatalyst)
import ActivityKit
import SwiftUI
import WidgetKit

private var appTint: Color {
    switch UserDefaults(suiteName: "group.tv.trakt.rippple")!.integer(forKey: "AppManager.currentTint") {
    case 0:
        return .purple
    case 1:
        return .red
    case 2:
        return .orange
    case 3:
        return .yellow
    case 4:
        return .green
    case 5:
        return .mint
    case 6:
        return .teal
    case 7:
        return .cyan
    case 8:
        return .blue
    case 9:
        return .indigo
    case 10:
        return .pink
    case 11:
        return .brown
    case 12:
        return .white
    default:
        return .purple
    }
}

@available(iOS 18.0, *)
struct RipppleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RipppleLiveActivityAttributes.self) { context in
            ActivityWidgetEntryView(progress: context.state.entry)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    let progress = context.state.entry
                    // let width: CGFloat = 20
                    HStack(alignment: .bottom) {
                        if let data = UserDefaults(suiteName: "group.tv.trakt.rippple")!.data(forKey: "LiveActivityManager.poster"), let uiImage = UIImage(data: data) {
                            if let deeplink = context.state.entry.deeplink, deeplink.path().localizedStandardContains("episodes") == true {
                                Link(destination: deeplink.deletingLastPathComponent().deletingLastPathComponent()) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .frame(width: 60)
                                }
                            } else {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .frame(width: 60)
                            }
                        }
                        VStack(alignment: .leading, spacing: 1.0) {
                            if let label = progress.label {
                                Text(label)
                                    .font(.caption.uppercaseSmallCaps())
                            }
                            if let title = progress.title {
                                Text(title)
                                    .font(.headline)
                                    .lineLimit(2)
                            }
                            if let subtitle = progress.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        ProgressView(timerInterval: progress.endDate!.addingTimeInterval(Double(-progress.runtime!))...progress.endDate!,
                                     countsDown: false,
                                     label: { EmptyView() },
                                     currentValueLabel: { EmptyView() })
                            .progressViewStyle(.circular)
                            .frame(width: 30, height: 30)
                            .tint(appTint)

                    }.padding([.leading, .trailing, .bottom], 5)
                }
            } compactLeading: {
                if let data = UserDefaults(suiteName: "group.tv.trakt.rippple")!.data(forKey: "LiveActivityManager.thumb"), let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                }
            } compactTrailing: {
                let progress = context.state.entry
                ProgressView(timerInterval: progress.endDate!.addingTimeInterval(Double(-progress.runtime!))...progress.endDate!,
                             countsDown: false,
                             label: { EmptyView() },
                             currentValueLabel: { EmptyView() })
                    .progressViewStyle(.circular)
                    .frame(width: 24, height: 24)
                    .tint(appTint)
            } minimal: {
                let progress = context.state.entry
                ProgressView(timerInterval: progress.endDate!.addingTimeInterval(Double(-progress.runtime!))...progress.endDate!,
                             countsDown: false,
                             label: { EmptyView() },
                             currentValueLabel: { EmptyView() })
                    .progressViewStyle(.circular)
                    .frame(width: 22, height: 22)
                    .tint(appTint)
            }.widgetURL(context.state.entry.deeplink)
        }.supplementalActivityFamilies([.small])
    }
}

@available(iOS 18.0, *)
struct ActivityWidgetEntryView: View {
    @Environment(\.activityFamily) var activityFamily

    var progress: WidgetModel

    var body: some View {
        switch activityFamily {
        case .small:
            SmallLiveActivityView(progress: progress)
        case .medium:
            MediumLiveActivityView(progress: progress)
        @unknown default:
            MediumLiveActivityView(progress: progress)
        }
    }
}

struct MediumLiveActivityView: View {
    var progress: WidgetModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(alignment: .bottom) {
                if let data = UserDefaults(suiteName: "group.tv.trakt.rippple")!.data(forKey: "LiveActivityManager.poster"), let uiImage = UIImage(data: data) {
                    if let deeplink = progress.deeplink, deeplink.path().localizedStandardContains("episodes") == true {
                        Link(destination: deeplink.deletingLastPathComponent().deletingLastPathComponent()) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .frame(width: 60)
                        }
                    } else {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(width: 60)
                    }
                }
                VStack(alignment: .leading) {
                    if let label = progress.label {
                        Text(label)
                            .font(.caption.uppercaseSmallCaps())
                    }
                    if let title = progress.title {
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    if let subtitle = progress.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                ProgressView(timerInterval: progress.endDate!.addingTimeInterval(Double(-progress.runtime!))...progress.endDate!,
                             countsDown: false,
                             label: { EmptyView() },
                             currentValueLabel: { EmptyView() })
                    .progressViewStyle(.circular)
                    .frame(width: 30, height: 30)
                    .tint(.primary)
            }.padding()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(progress.deeplink)
    }
}

struct SmallLiveActivityView: View {
    var progress: WidgetModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(alignment: .bottom, spacing: 6.0) {
                if let data = UserDefaults(suiteName: "group.tv.trakt.rippple")!.data(forKey: "LiveActivityManager.poster"), let uiImage = UIImage(data: data) {
                    if let deeplink = progress.deeplink, deeplink.path().localizedStandardContains("episodes") == true {
                        Link(destination: deeplink.deletingLastPathComponent().deletingLastPathComponent()) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                    } else {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                } /* else {
                    Rectangle()
                        .fill(.blue)
                        .aspectRatio(50/75, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                 } */
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    if let label = progress.label {
                        Text(label)
                            .font(.caption.uppercaseSmallCaps())
                    }
                    if let title = progress.title {
                        Text(title)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        if let subtitle = progress.subtitle {
                            Text(subtitle)
                                .foregroundColor(.secondary)
                                .font(.body)
                                .fontWeight(.light)
                        }
                        Spacer(minLength: 0)
                        ProgressView(timerInterval: progress.endDate!.addingTimeInterval(Double(-progress.runtime!))...progress.endDate!,
                                     countsDown: false,
                                     label: { EmptyView() },
                                     currentValueLabel: { EmptyView() })
                            .progressViewStyle(.circular)
                            .tint(appTint)
                            .frame(width: 18, height: 18)
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(progress.deeplink)
            .padding(7)
    }
}

struct ActivityWidgetEntryViewLegacy: View {
    var progress: WidgetModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(alignment: .bottom) {
                if let data = UserDefaults(suiteName: "group.tv.trakt.rippple")!.data(forKey: "LiveActivityManager.poster"), let uiImage = UIImage(data: data) {
                    if let deeplink = progress.deeplink, deeplink.path().localizedStandardContains("episodes") == true {
                        Link(destination: deeplink.deletingLastPathComponent().deletingLastPathComponent()) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .frame(width: 60)
                        }
                    } else {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(width: 60)
                    }
                }
                VStack(alignment: .leading, spacing: 2.0) {
                    if let label = progress.label {
                        Text(label)
                            .font(.caption.uppercaseSmallCaps())
                    }
                    if let title = progress.title {
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    if let subtitle = progress.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                ProgressView(timerInterval: progress.endDate!.addingTimeInterval(Double(-progress.runtime!))...progress.endDate!,
                             countsDown: false,
                             label: { EmptyView() },
                             currentValueLabel: { EmptyView() })
                    .progressViewStyle(.circular)
                    .frame(width: 30, height: 30)
                    .tint(.primary)
            }.padding()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(progress.deeplink)
    }
}

extension RipppleLiveActivityAttributes.ContentState {
    static var theRoom: RipppleLiveActivityAttributes.ContentState {
        .init(entry: WidgetModel(label: "Now Watching",
                                 title: "The Room",
                                 subtitle: "S04E08",
                                 image: nil,
                                 behind: "2 behind",
                                 redacted: true,
                                 deeplink: URL(string: "http://"),
                                 progress: 0.5,
                                 runtime: 4000,
                                 endDate: Date.now.advanced(by: 3600)))
    }
}

@available(iOS 18.0, *)
#Preview("Content",
         as: .content,
         using: RipppleLiveActivityAttributes()) {
    return RipppleLiveActivityWidget()
} contentStates: {
    RipppleLiveActivityAttributes.ContentState.theRoom
}

#endif
