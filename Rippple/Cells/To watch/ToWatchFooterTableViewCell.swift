//
//  ToWatchFooterTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/04/2021.
//  Copyright © 2021 Trakt. All rights reserved.
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
                    for model in models {
                        switch model {
                        case .showProgress(let show, let progress):
                            let runtime = show.runtime ?? progress.nextEpisodeToWatch?.runtime ?? 1000
                            if progress.toRewatchCount > 0 {
                                episodeCount += progress.toRewatchCount
                                timeToWatch += progress.toRewatchCount * runtime
                            } else {
                                episodeCount += max(1, progress.behind)
                                timeToWatch += max(1, progress.behind) * runtime
                            }
                        default:
                            break
                        }
                    }
                    let dateFormatter = DateComponentsFormatter()
                    dateFormatter.unitsStyle = .short
                    dateFormatter.allowedUnits = [.day, .hour, .minute]
                    var calendar = Calendar.current
                    calendar.locale = Locale(identifier: "en_US")
                    dateFormatter.calendar = calendar

                    let attributes = [NSAttributedString.Key.foregroundColor: UIColor.label]

                    let totalShowsChecked = EpisodeToWatchManager.shared.shows?.count ?? 0
                    let hiddenShows = HiddenMediaManager.shared.showsHiddenFromProgressCount
                    let completedShows = CompletedShowsManager.shared.completedShowCount
                    let droppedShows = DroppedShowsManager.shared.droppedShowsCount

                    if models.isEmpty {
                        let attributtedString = NSMutableAttributedString(string: "We checked the progress for ")
                        attributtedString.append(NSAttributedString(string: "\(totalShowsChecked) show\(totalShowsChecked > 1 ? "s" : "")", attributes: attributes))
                        if let showsInList = EpisodeToWatchManager.shared.showsInList {
                            attributtedString.append(NSAttributedString(string: " from your "))
                            var listCount = 0
                            for group in showsInList.filter({ PinnedShowsManager.shared.pinnedShows.count != 0 ||
                                    $0.name != "Pinned" }) {
                                // it's the first one
                                if listCount == 0 {
                                    attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                    listCount += 1
                                } else if showsInList.last?.name == group.name,
                                          showsInList.last?.order == group.order {
                                    attributtedString.append(NSMutableAttributedString(string: " and "))
                                    attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                    listCount += 1
                                } else {
                                    attributtedString.append(NSMutableAttributedString(string: ", "))
                                    attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                    listCount += 1
                                }
                            }
                            attributtedString.append(NSAttributedString(string: " list\(listCount > 1 ? "s." : ".")"))
                        }
                        if hiddenShows == 0, completedShows == 0, droppedShows == 0 {
                            attributtedString.append(NSMutableAttributedString(string: "\nWe"))
                        } else {
                            attributtedString.append(NSMutableAttributedString(string: "\nAfter removing "))
                            var stuff = [NSAttributedString]()
                            if hiddenShows > 0 {
                                stuff.append(NSAttributedString(string: "\(hiddenShows) hidden show\(hiddenShows > 1 ? "s" : "")", attributes: attributes))
                            }
                            if completedShows > 0 {
                                stuff.append(NSAttributedString(string: "\(completedShows) completed show\(completedShows > 1 ? "s" : "")", attributes: attributes))
                            }
                            if droppedShows > 0 {
                                stuff.append(NSAttributedString(string: "\(droppedShows) dropped show\(droppedShows > 1 ? "s" : "")", attributes: attributes))
                            }
                            for s in stuff {
                                if stuff.first != s {
                                    if stuff.last == s {
                                        attributtedString.append(NSMutableAttributedString(string: " and "))
                                    } else {
                                        attributtedString.append(NSMutableAttributedString(string: ", "))
                                    }
                                }
                                attributtedString.append(s)
                            }
                            attributtedString.append(NSMutableAttributedString(string: ", we"))
                        }
                        attributtedString.append(NSAttributedString(string: " couldn't find episodes for you to watch right now."))

                        let strLength = attributtedString.length
                        let style = NSMutableParagraphStyle()
                        style.paragraphSpacing = 4
                        attributtedString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: strLength))

                        DispatchQueue.main.async {
                            UIView.performWithoutAnimation {
                                self.emoji.text = "🍃"
                                self.emoji.isHidden = false
                                self.title.text = "You did it!"
                                self.label.attributedText = attributtedString
                                self.invalidateIntrinsicContentSize()
                            }
                        }
                        return
                    }

                    let attributtedString = NSMutableAttributedString(string: "We checked the progress for ")
                    attributtedString.append(NSAttributedString(string: "\(totalShowsChecked) show\(totalShowsChecked > 1 ? "s" : "")", attributes: attributes))
                    if let showsInList = EpisodeToWatchManager.shared.showsInList {
                        attributtedString.append(NSAttributedString(string: " from your "))
                        var listCount = 0
                        for group in showsInList.filter({ PinnedShowsManager.shared.pinnedShows.count != 0 ||
                                $0.name != "Pinned" }) {
                            // it's the first one
                            if listCount == 0 {
                                attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                listCount += 1
                            } else if showsInList.last?.name == group.name,
                                      showsInList.last?.order == group.order {
                                attributtedString.append(NSMutableAttributedString(string: " and "))
                                attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                listCount += 1
                            } else {
                                attributtedString.append(NSMutableAttributedString(string: ", "))
                                attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                listCount += 1
                            }
                        }
                        attributtedString.append(NSAttributedString(string: " list\(listCount > 1 ? "s." : ".")"))
                    }
                    if hiddenShows == 0, completedShows == 0, droppedShows == 0 {
                        attributtedString.append(NSMutableAttributedString(string: "\nWe"))
                    } else {
                        attributtedString.append(NSMutableAttributedString(string: "\nAfter removing "))
                        var stuff = [NSAttributedString]()
                        if hiddenShows > 0 {
                            stuff.append(NSAttributedString(string: "\(hiddenShows) hidden show\(hiddenShows > 1 ? "s" : "")", attributes: attributes))
                        }
                        if completedShows > 0 {
                            stuff.append(NSAttributedString(string: "\(completedShows) completed show\(completedShows > 1 ? "s" : "")", attributes: attributes))
                        }
                        if droppedShows > 0 {
                            stuff.append(NSAttributedString(string: "\(droppedShows) dropped show\(droppedShows > 1 ? "s" : "")", attributes: attributes))
                        }
                        for s in stuff {
                            if stuff.first != s {
                                if stuff.last == s {
                                    attributtedString.append(NSMutableAttributedString(string: " and "))
                                } else {
                                    attributtedString.append(NSMutableAttributedString(string: ", "))
                                }
                            }
                            attributtedString.append(s)
                        }
                        attributtedString.append(NSMutableAttributedString(string: ", we"))
                    }
                    attributtedString.append(NSAttributedString(string: " found a total of "))
                    attributtedString.append(NSAttributedString(string: "\(showCount) show\(showCount > 1 ? "s" : "")", attributes: attributes))
                    attributtedString.append(NSAttributedString(string: " for you to watch. \nThis gives you "))
                    attributtedString.append(NSMutableAttributedString(string: "\(episodeCount) episode\(episodeCount > 1 ? "s" : "")", attributes: attributes))
                    attributtedString.append(NSAttributedString(string: " or around "))
                    attributtedString.append(NSAttributedString(string: "\(dateFormatter.string(from: TimeInterval(timeToWatch * 60))!)", attributes: attributes))
                    attributtedString.append(NSAttributedString(string: " of episodes to watch."))

                    let strLength = attributtedString.length
                    let style = NSMutableParagraphStyle()
                    style.paragraphSpacing = 4
                    attributtedString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: strLength))

                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation {
                            self.emoji.text = nil
                            self.emoji.isHidden = true
                            self.title.text = "\(episodeCount) episode\(episodeCount > 1 ? "s" : "") to watch"
                            self.label.attributedText = attributtedString
                            self.invalidateIntrinsicContentSize()
                        }
                    }
                }.disposed(by: disposeBag)
            } else {
                onMovieToWatchChangedReceiver.listen { [weak self] models in
                    guard let self = self else { return }
                    let movieCount = models.count
                    var timeToWatch = 0
                    for model in models {
                        switch model {
                        case .movie(let movie):
                            let runtime = movie.runtime ?? 0
                            timeToWatch += runtime
                        default:
                            break
                        }
                    }
                    let dateFormatter = DateComponentsFormatter()
                    dateFormatter.unitsStyle = .short
                    dateFormatter.allowedUnits = [.day, .hour, .minute]
                    var calendar = Calendar.current
                    calendar.locale = Locale(identifier: "en_US")
                    dateFormatter.calendar = calendar

                    let attributes = [NSAttributedString.Key.foregroundColor: UIColor.label]

                    if models.isEmpty {
                        let attributtedString = NSMutableAttributedString(string: "We checked movies from your ")
                        if let moviesInList = MovieToWatchManager.shared.moviesInList {
                            var listCount = 0
                            for group in moviesInList {
                                // it's the first one
                                if listCount == 0 {
                                    attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                    listCount += 1
                                } else if moviesInList.last?.name == group.name,
                                          moviesInList.last?.order == group.order {
                                    attributtedString.append(NSMutableAttributedString(string: " and "))
                                    attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                    listCount += 1
                                } else {
                                    attributtedString.append(NSMutableAttributedString(string: ", "))
                                    attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                    listCount += 1
                                }
                            }
                            attributtedString.append(NSAttributedString(string: " list\(listCount > 1 ? "s." : ".")"))
                        }
                        attributtedString.append(NSAttributedString(string: "\nWe couldn't find movies for you to watch right now."))

                        DispatchQueue.main.async {
                            UIView.performWithoutAnimation {
                                self.emoji.text = "☕️"
                                self.emoji.isHidden = false
                                self.title.text = "You did it!"
                                self.label.attributedText = attributtedString
                                self.invalidateIntrinsicContentSize()
                            }
                        }
                        return
                    }

                    let attributtedString = NSMutableAttributedString(string: "We checked movies from your ")
                    if let moviesInList = MovieToWatchManager.shared.moviesInList {
                        var listCount = 0
                        for group in moviesInList {
                            // it's the first one
                            if listCount == 0 {
                                attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                listCount += 1
                            } else if moviesInList.last?.name == group.name,
                                      moviesInList.last?.order == group.order {
                                attributtedString.append(NSMutableAttributedString(string: " and "))
                                attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                listCount += 1
                            } else {
                                attributtedString.append(NSMutableAttributedString(string: ", "))
                                attributtedString.append(NSAttributedString(string: "\(group.name.emojiUnescapedString)", attributes: attributes))
                                listCount += 1
                            }
                        }
                        attributtedString.append(NSAttributedString(string: " list\(listCount > 1 ? "s." : ".")"))
                    }
                    attributtedString.append(NSAttributedString(string: "\nWe found a total of "))
                    attributtedString.append(NSAttributedString(string: "\(movieCount) movie\(movieCount > 1 ? "s" : "")", attributes: attributes))
                    attributtedString.append(NSAttributedString(string: " for you to watch. \nThis gives you around "))
                    attributtedString.append(NSAttributedString(string: "\(dateFormatter.string(from: TimeInterval(timeToWatch * 60))!)", attributes: attributes))
                    attributtedString.append(NSAttributedString(string: " of movies to watch."))

                    let strLength = attributtedString.length
                    let style = NSMutableParagraphStyle()
                    style.paragraphSpacing = 4
                    attributtedString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: strLength))

                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation {
                            self.emoji.text = nil
                            self.emoji.isHidden = true
                            self.title.text = "\(movieCount) movie\(movieCount > 1 ? "s" : "") to watch"
                            self.label.attributedText = attributtedString
                            self.invalidateIntrinsicContentSize()
                        }
                    }
                }.disposed(by: disposeBag)
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        label.text = nil
        title.text = nil
        emoji.text = nil
    }
}
