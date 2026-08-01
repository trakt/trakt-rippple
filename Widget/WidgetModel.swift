//
//  WidgetModel.swift
//  Rippple
//
//  Created by Kevin Cador on 12/07/2022.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

enum WidgetType: String {
    case lastWatched = "widget.lastWatched"
    case lastWatchedMovie = "widget.lastWatchedMovie"
    case lastWatchedShow = "widget.lastWatchedShow"
    case showsToWatch = "widget.showsToWatch"
    case moviesToWatch = "widget.moviesToWatch"
    case showsComing = "widget.showsComing"
    case moviesComing = "widget.moviesComing"

    case recommendedMovie = "widget.recommendedMovie"
    case trendingMovie = "widget.trendingMovie"
    case recommendedShow = "widget.recommendedShow"
    case trendingShow = "widget.trendingShow"

    case custom = "widget.custom"
}

struct WidgetModel: Identifiable, Codable, Equatable, Hashable {
    var label: String?
    var title: String?
    var subtitle: String?
    var image: URL?
    var behind: String?
    var redacted = false
    var deeplink: URL?

    var progress: Double?
    var runtime: Int?
    var endDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(image)
        hasher.combine(behind)
        hasher.combine(redacted)
        hasher.combine(deeplink)
        hasher.combine(label)

        hasher.combine(progress)
        hasher.combine(runtime)
        hasher.combine(endDate)
    }

    var id: Int {
        return hashValue
    }
}

enum CalendarRelativeDateFormatter {
    static func string(for date: Date,
                       relativeTo referenceDate: Date = Date(),
                       unitsStyle: DateComponentsFormatter.UnitsStyle = .full,
                       uppercaseFirstLetter: Bool = false) -> String {
        let interval = date.timeIntervalSince(referenceDate)
        guard abs(interval) >= 1 else {
            return uppercaseFirstLetter ? "Now" : "now"
        }

        let component = completedComponent(for: date, relativeTo: referenceDate)
        let value = formattedValue(component.value, unit: component.unit, unitsStyle: unitsStyle)
        let formattedString = interval < 0 ? "\(value) ago" : "in \(value)"

        guard uppercaseFirstLetter else { return formattedString }
        return formattedString.prefix(1).uppercased() + String(formattedString.dropFirst())
    }

    private static func completedComponent(for date: Date, relativeTo referenceDate: Date) -> (value: Int, unit: NSCalendar.Unit) {
        let interval = date.timeIntervalSince(referenceDate)
        let absoluteInterval = abs(interval)

        let minute: TimeInterval = 60
        let hour = minute * 60
        let day = hour * 24

        if absoluteInterval < minute {
            return (max(1, Int(absoluteInterval)), .second)
        } else if absoluteInterval < hour * 2 {
            return (max(1, Int(absoluteInterval / minute)), .minute)
        } else if absoluteInterval < day * 2 {
            return (max(1, Int(absoluteInterval / hour)), .hour)
        } else if absoluteInterval < day * 14 {
            return (max(1, Int(absoluteInterval / day)), .day)
        }

        let earlierDate = interval < 0 ? date : referenceDate
        let laterDate = interval < 0 ? referenceDate : date
        let calendar = Calendar.current

        let years = calendar.dateComponents([.year], from: earlierDate, to: laterDate).year ?? 0
        if years >= 1 {
            return (years, .year)
        }

        let months = calendar.dateComponents([.month], from: earlierDate, to: laterDate).month ?? 0
        if months >= 1 {
            return (months, .month)
        }

        return (max(1, Int(absoluteInterval / (day * 7))), .weekOfMonth)
    }

    private static func formattedValue(_ value: Int,
                                       unit: NSCalendar.Unit,
                                       unitsStyle: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = unit
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = unitsStyle

        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar

        var components = DateComponents()
        switch unit {
        case .second:
            components.second = value
        case .minute:
            components.minute = value
        case .hour:
            components.hour = value
        case .day:
            components.day = value
        case .weekOfMonth:
            components.weekOfMonth = value
        case .month:
            components.month = value
        case .year:
            components.year = value
        default:
            break
        }

        return formatter.string(from: components) ?? "\(value)"
    }
}
