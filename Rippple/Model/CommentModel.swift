//
//  CommentModel.swift
//  Rippple
//
//  Created by Kevin Cador on 23/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation

import Haring

import Receiver

import Emoji

import NaturalLanguage

enum SpoilerStrategy {
    case hideAllSpoilers
    case hideInlineSpoilers
    case showAllSpoilers
}

let (commentFilteredTransmitter, commentFilteredReceiver) = Receiver<Comment>.make(with: .hot)
let (userBlockedTransmitter, userBlockedReceiver) = Receiver<User>.make(with: .hot)
let (commentModelRefreshedTransmitter, commentModelRefreshedReceiver) = Receiver<CommentModel>.make(with: .hot)

final class CommentModel: Equatable, Hashable {

    static func == (lhs: CommentModel, rhs: CommentModel) -> Bool {
        return lhs.comment == rhs.comment && lhs.media == rhs.media && lhs.spoilerStrategy == rhs.spoilerStrategy
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(comment)
        hasher.combine(media)
        hasher.combine(spoilerStrategy)
    }

    let media: MediaModel
    let comment: Comment
    let spoilerStrategy: SpoilerStrategy

    var commentAttributedString: NSAttributedString?
    var commentWordCount: Int?
    var userAttributedString: NSAttributedString?

    private let disposeBag = DisposeBag()

    init(media: MediaModel, comment: Comment, spoilerStrategy: SpoilerStrategy) {
        self.comment = comment
        self.media = media

        if comment.user.isCurrentUser {
            self.spoilerStrategy = .showAllSpoilers
        } else {
            self.spoilerStrategy = spoilerStrategy
        }

        commonInit()
    }

    init(commentItem: CommentItem, spoilerStrategy: SpoilerStrategy) {
        self.comment = commentItem.comment
        switch commentItem.type {
        case .episode:
            self.media = .episode(commentItem.episode!, commentItem.show!)
        case .show:
            self.media = .show(commentItem.show!)
        case .movie:
            self.media = .movie(commentItem.movie!)
        case .list, .officiallist:
            self.media = .list(commentItem.list!)
        case .season:
            self.media = .season(commentItem.season!, commentItem.show!)
        case .unknown:
            fatalError("Unknow comment media type")
        }

        if comment.user.isCurrentUser {
            self.spoilerStrategy = .showAllSpoilers
        } else {
            self.spoilerStrategy = spoilerStrategy
        }

        commonInit()
    }

    @MainActor private var markdownParser: SpoilerMarkdownParser {
        SpoilerMarkdownParser(font: UIFont.preferredFont(forTextStyle: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge))),
                                     automaticLinkDetectionEnabled: true)
    }
    @MainActor private var markdownUserParser: BoldMarkdownParser {
        BoldMarkdownParser(font: UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge))),
                                                                     color: .secondaryLabel,
                                                                     automaticLinkDetectionEnabled: true)
    }

    private func commonInit() {
        commentFilteredReceiver.listen { [weak self] comment in
            guard let self = self else { return }
            if comment == self.comment {
                Task.init {
                    await self.processComment()
                }
            }
        }.disposed(by: disposeBag)

        onWatchedShowsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            Task.init {
                await self.processComment()
            }
        }.disposed(by: disposeBag)

        onWatchedMoviesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            Task.init {
                await self.processComment()
            }
        }.disposed(by: disposeBag)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(preferredContentSizeChanged(_:)),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)

        Task.init {
            await processComment()
        }
    }

    @objc func preferredContentSizeChanged(_ notification: Notification) {
        Task.init {
            await processComment()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension CommentModel {
    private enum CommentLabel: String {
        case review = "Review"
        case hype = "Hype"
        case hotTake = "Hot take"
        case shout = "Shout"
    }

    private static let releaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private var commentLabel: CommentLabel {
        if comment.isReview {
            return .review
        }

        guard let releaseDate = releaseDate,
              let oneMonthBeforeRelease = Calendar.current.date(byAdding: .month,
                                                                value: -1,
                                                                to: releaseDate),
              let twoWeeksAfterRelease = Calendar.current.date(byAdding: .day,
                                                               value: 14,
                                                               to: releaseDate) else {
            return .shout
        }

        if comment.createDate < oneMonthBeforeRelease {
            return .hype
        }
        if comment.createDate <= twoWeeksAfterRelease {
            return .hotTake
        }
        return .shout
    }

    private var releaseDate: Date? {
        switch media {
        case .movie(let movie):
            guard let released = movie.released else { return nil }
            return CommentModel.releaseDateFormatter.date(from: released)
        case .show(let show):
            return show.firstAired
        case .episode(let episode, _):
            return episode.firstAired
        case .season(let season, _):
            return season.firstAired
        case .list, .showProgress:
            return nil
        }
    }

    private func processComment() async {
        commentAttributedString = await attributedString(markdownParser: markdownParser)

        commentWordCount = comment.body.wordCount

        if comment.parentIdentifier != 0 {
            userAttributedString = await markdownUserParser.parse("by **\(comment.user.name)**")
        } else {
            userAttributedString = await markdownUserParser.parse("\(commentLabel.rawValue) by **\(comment.user.name)**")
        }

        commentModelRefreshedTransmitter.broadcast(self)
    }

    private func attributedString(markdownParser: SpoilerMarkdownParser) async -> NSAttributedString {
        markdownParser.color = .label
        markdownParser.strike.strikeColor = .label
        markdownParser.strike.color = .label
        markdownParser.highlight.color = .label
        markdownParser.highlight.highlightColor = UIColor(asset: .globalTint).withAlphaComponent(0.4)
        markdownParser.spoiler.color = .label
        markdownParser.allSpoiler.color = .label
        markdownParser.displaySpoiler.color = .label
        markdownParser.mention.color = .label

        if comment.isFiltered {
            markdownParser.spoilerStrategy = .hideAllSpoilers
        } else {
            switch media {
            case .movie(let movie):
                if movie.isWatched {
                    markdownParser.spoilerStrategy = .showAllSpoilers
                } else {
                    switch spoilerStrategy {
                    case .hideAllSpoilers:
                        if comment.containsSpoiler {
                            markdownParser.spoilerStrategy = .hideAllSpoilers
                        } else {
                            markdownParser.spoilerStrategy = .hideInlineSpoilers
                        }
                    case .hideInlineSpoilers:
                        markdownParser.spoilerStrategy = .hideInlineSpoilers
                    case .showAllSpoilers:
                        markdownParser.spoilerStrategy = .showAllSpoilers
                    }
                }
            case .show(let show):
                if show.isCompleted {
                    markdownParser.spoilerStrategy = .showAllSpoilers
                } else {
                    switch spoilerStrategy {
                    case .hideAllSpoilers:
                        if comment.containsSpoiler {
                            markdownParser.spoilerStrategy = .hideAllSpoilers
                        } else {
                            markdownParser.spoilerStrategy = .hideInlineSpoilers
                        }
                    case .hideInlineSpoilers:
                        markdownParser.spoilerStrategy = .hideInlineSpoilers
                    case .showAllSpoilers:
                        markdownParser.spoilerStrategy = .showAllSpoilers
                    }
                }
            case .episode(let episode, let show):
                if show.isCompleted {
                    markdownParser.spoilerStrategy = .showAllSpoilers
                } else {
                    if episode.isRecentlyWatched {
                        markdownParser.spoilerStrategy = .showAllSpoilers
                    } else {
                        switch spoilerStrategy {
                        case .hideAllSpoilers:
                            if comment.containsSpoiler {
                                markdownParser.spoilerStrategy = .hideAllSpoilers
                            } else {
                                markdownParser.spoilerStrategy = .hideInlineSpoilers
                            }
                        case .hideInlineSpoilers:
                            markdownParser.spoilerStrategy = .hideInlineSpoilers
                        case .showAllSpoilers:
                            markdownParser.spoilerStrategy = .showAllSpoilers
                        }
                    }
                }
            case .season(_, let show):
                if show.isCompleted {
                    markdownParser.spoilerStrategy = .showAllSpoilers
                } else {
                    switch spoilerStrategy {
                    case .hideAllSpoilers:
                        if comment.containsSpoiler {
                            markdownParser.spoilerStrategy = .hideAllSpoilers
                        } else {
                            markdownParser.spoilerStrategy = .hideInlineSpoilers
                        }
                    case .hideInlineSpoilers:
                        markdownParser.spoilerStrategy = .hideInlineSpoilers
                    case .showAllSpoilers:
                        markdownParser.spoilerStrategy = .showAllSpoilers
                    }
                }
            default:
                switch spoilerStrategy {
                case .hideAllSpoilers:
                    if comment.containsSpoiler {
                        markdownParser.spoilerStrategy = .hideAllSpoilers
                    } else {
                        markdownParser.spoilerStrategy = .hideInlineSpoilers
                    }
                case .hideInlineSpoilers:
                    markdownParser.spoilerStrategy = .hideInlineSpoilers
                case .showAllSpoilers:
                    markdownParser.spoilerStrategy = .showAllSpoilers
                }
            }
        }

        return markdownParser.parse(comment.body.htmlDecoded.emojiUnescapedString)
    }
}

private extension String {
    var containsOnlyDigits: Bool {
        let notDigits = NSCharacterSet.decimalDigits.inverted
        return rangeOfCharacter(from: notDigits, options: String.CompareOptions.literal, range: nil) == nil
    }

    var containsOnlyLetters: Bool {
        let notLetters = NSCharacterSet.letters.inverted
        return rangeOfCharacter(from: notLetters, options: String.CompareOptions.literal, range: nil) == nil
    }

    var isAlphanumeric: Bool {
        let notAlphanumeric = NSCharacterSet.decimalDigits.union(NSCharacterSet.letters).inverted
        return rangeOfCharacter(from: notAlphanumeric, options: String.CompareOptions.literal, range: nil) == nil
    }
}
