//
//  ToWatchFooterTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/04/2021.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class ToWatchFooterTableViewCell: UITableViewCell {
    @IBOutlet var emoji: UILabel!
    @IBOutlet var title: UILabel!
    @IBOutlet var label: UILabel!

    private let disposeBag = DisposeBag()

    enum Mode {
        case episodes
        case movies
    }

    var mode: Mode! {
        didSet {
            emoji.text = nil
            label.text = nil
            title.text = nil
            if mode == .episodes {
                onEpisodeToWatchChangedReceiver.listen { [weak self] models in
                    guard let self = self else { return }

                    let showCount = models.count
                    var episodeCount = 0
                    var timeToWatch = 0
                    var hasCompleteRuntimeEstimate = true
                    for model in models {
                        switch model {
                        case .showProgress(let show, let progress):
                            let runtime = show.runtime ?? progress.nextEpisodeToWatch?.runtime
                            let episodesForShow: Int
                            if progress.toRewatchCount > 0 {
                                episodesForShow = progress.toRewatchCount
                            } else {
                                episodesForShow = max(1, progress.behind)
                            }
                            episodeCount += episodesForShow
                            if let runtime {
                                timeToWatch += episodesForShow * runtime
                            } else {
                                hasCompleteRuntimeEstimate = false
                            }
                        default:
                            break
                        }
                    }
                    let dateFormatter = DateComponentsFormatter()
                    dateFormatter.unitsStyle = .full
                    dateFormatter.allowedUnits = [.day, .hour, .minute]
                    var calendar = Calendar.current
                    calendar.locale = Locale(identifier: "en_US")
                    dateFormatter.calendar = calendar

                    let totalShowsChecked = EpisodeToWatchManager.shared.shows?.count ?? 0
                    let hiddenShows = HiddenMediaManager.shared.showsHiddenFromProgressCount
                    let completedShows = CompletedShowsManager.shared.completedShowCount
                    let droppedShows = DroppedShowsManager.shared.droppedShowsCount
                    let showsToWatchCount = EpisodeToWatchManager.shared.shows?.filter { show in
                        show.isHiddenFromProgress != true &&
                            show.isCompleted != true &&
                            show.isDropped != true
                    }.count ?? showCount
                    let sourceNames = EpisodeToWatchManager.shared.showsInList?
                        .filter { PinnedShowsManager.shared.pinnedShows.isEmpty == false || $0.name != "Pinned" }
                        .filter { $0.shows.isEmpty == false }
                        .map { $0.name.emojiUnescapedString } ?? []

                    let checkedShows = Self.counted(totalShowsChecked, singular: "show")
                    var lines = ["We checked \(checkedShows)\(Self.sourceSuffix(sourceNames))."]
                    var highlightedText = [checkedShows] + sourceNames

                    var excludedShows = [String]()
                    if hiddenShows > 0 {
                        excludedShows.append("\(hiddenShows) hidden \(Self.pluralized("show", count: hiddenShows))")
                        highlightedText.append("\(hiddenShows) hidden")
                    }
                    if completedShows > 0 {
                        excludedShows.append("\(completedShows) completed \(Self.pluralized("show", count: completedShows))")
                        highlightedText.append("\(completedShows) completed")
                    }
                    if droppedShows > 0 {
                        excludedShows.append("\(droppedShows) dropped \(Self.pluralized("show", count: droppedShows))")
                        highlightedText.append("\(droppedShows) dropped")
                    }

                    let remainingShows = Self.remaining(count: showsToWatchCount, singular: "show")
                    let repeatsCheckedShowCount = showsToWatchCount == totalShowsChecked
                    var availabilitySentences = [String]()
                    if excludedShows.isEmpty == false {
                        if repeatsCheckedShowCount {
                            availabilitySentences.append("We excluded \(Self.joined(excludedShows)).")
                        } else {
                            availabilitySentences.append("After excluding \(Self.joined(excludedShows)), \(remainingShows.lowercased()).")
                        }
                    } else if repeatsCheckedShowCount == false {
                        availabilitySentences.append("\(remainingShows).")
                    }
                    highlightedText.append(Self.counted(showsToWatchCount, singular: "show"))

                    if models.isEmpty {
                        if showsToWatchCount > 0 {
                            availabilitySentences.append("There are no episodes ready to watch right now.")
                        }
                    } else if repeatsCheckedShowCount, excludedShows.isEmpty == false {
                        availabilitySentences.append("\(Self.counted(showCount, singular: "show")) \(showCount == 1 ? "has" : "have") episodes ready to watch.")
                        highlightedText.append(Self.counted(showCount, singular: "show"))
                    } else if showsToWatchCount == 1, showCount == 1 {
                        availabilitySentences.append("It has episodes ready to watch.")
                    } else if showCount == 1 {
                        availabilitySentences.append("One of them has episodes ready to watch.")
                    } else {
                        availabilitySentences.append("Of those, \(showCount) have episodes ready to watch.")
                        highlightedText.append("\(showCount)")
                    }
                    if availabilitySentences.isEmpty == false {
                        lines.append(availabilitySentences.joined(separator: " "))
                    }

                    if models.isEmpty == false,
                       hasCompleteRuntimeEstimate,
                       let duration = dateFormatter.string(from: TimeInterval(timeToWatch * 60)) {
                        lines.append("About \(duration) in total.")
                        highlightedText.append(duration)
                    }

                    let attributedString = Self.footerText(lines: lines, highlightedText: highlightedText)

                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation {
                            self.emoji.text = models.isEmpty ? "🍃" : nil
                            self.emoji.isHidden = models.isEmpty == false
                            self.title.text = models.isEmpty ? "You're all caught up!" : "\(Self.counted(episodeCount, singular: "episode")) to watch"
                            self.label.attributedText = attributedString
                            self.invalidateIntrinsicContentSize()
                        }
                    }
                }.disposed(by: disposeBag)
            } else {
                onMovieToWatchChangedReceiver.listen { [weak self] models in
                    guard let self = self else { return }
                    let movieCount = models.count
                    var timeToWatch = 0
                    var hasCompleteRuntimeEstimate = true
                    for model in models {
                        switch model {
                        case .movie(let movie):
                            if let runtime = movie.runtime {
                                timeToWatch += runtime
                            } else {
                                hasCompleteRuntimeEstimate = false
                            }
                        default:
                            break
                        }
                    }
                    let dateFormatter = DateComponentsFormatter()
                    dateFormatter.unitsStyle = .full
                    dateFormatter.allowedUnits = [.day, .hour, .minute]
                    var calendar = Calendar.current
                    calendar.locale = Locale(identifier: "en_US")
                    dateFormatter.calendar = calendar

                    let sourceNames = MovieToWatchManager.shared.moviesInList?
                        .filter { $0.shows.isEmpty == false }
                        .map { $0.name.emojiUnescapedString } ?? []
                    var highlightedText = sourceNames
                    let lines: [String]

                    if models.isEmpty {
                        let checkedSources = sourceNames.isEmpty
                            ? "We checked for movies."
                            : "We checked your \(Self.joined(sourceNames)) \(Self.pluralized("list", count: sourceNames.count))."
                        lines = [checkedSources, "There are no movies ready to watch right now."]
                    } else {
                        let movies = Self.counted(movieCount, singular: "movie")
                        var resultLines = ["We found \(movies)\(Self.sourceSuffix(sourceNames))."]
                        highlightedText.append(movies)
                        if hasCompleteRuntimeEstimate,
                           let duration = dateFormatter.string(from: TimeInterval(timeToWatch * 60)) {
                            resultLines.append("About \(duration) in total.")
                            highlightedText.append(duration)
                        }
                        lines = resultLines
                    }

                    let attributedString = Self.footerText(lines: lines, highlightedText: highlightedText)

                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation {
                            self.emoji.text = models.isEmpty ? "☕️" : nil
                            self.emoji.isHidden = models.isEmpty == false
                            self.title.text = models.isEmpty ? "You're all caught up!" : "\(Self.counted(movieCount, singular: "movie")) to watch"
                            self.label.attributedText = attributedString
                            self.invalidateIntrinsicContentSize()
                        }
                    }
                }.disposed(by: disposeBag)
            }
        }
    }

    private static func pluralized(_ singular: String, count: Int) -> String {
        count == 1 ? singular : "\(singular)s"
    }

    private static func counted(_ count: Int, singular: String) -> String {
        "\(count) \(pluralized(singular, count: count))"
    }

    private static func remaining(count: Int, singular: String) -> String {
        switch count {
        case 0:
            return "No \(pluralized(singular, count: count)) remain"
        case 1:
            return "\(counted(count, singular: singular)) remains"
        default:
            return "\(counted(count, singular: singular)) remain"
        }
    }

    private static func joined(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            return "\(values.dropLast().joined(separator: ", ")), and \(values.last!)"
        }
    }

    private static func sourceSuffix(_ sourceNames: [String]) -> String {
        guard sourceNames.isEmpty == false else { return "" }
        return " from your \(joined(sourceNames)) \(pluralized("list", count: sourceNames.count))"
    }

    private static func footerText(lines: [String], highlightedText: [String]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: lines.joined(separator: "\n"))
        let fullRange = NSRange(location: 0, length: attributedString.length)

        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 4
        attributedString.addAttribute(.paragraphStyle, value: style, range: fullRange)

        let attributes = [NSAttributedString.Key.foregroundColor: UIColor.label]
        let text = attributedString.string as NSString
        for highlightedString in Set(highlightedText).filter({ $0.isEmpty == false }) {
            var searchRange = fullRange
            while searchRange.length > 0 {
                let range = text.range(of: highlightedString, options: [], range: searchRange)
                guard range.location != NSNotFound else { break }
                attributedString.addAttributes(attributes, range: range)
                let nextLocation = range.location + range.length
                searchRange = NSRange(location: nextLocation, length: fullRange.length - nextLocation)
            }
        }

        return attributedString
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        label.text = nil
        title.text = nil
        emoji.text = nil
    }
}
