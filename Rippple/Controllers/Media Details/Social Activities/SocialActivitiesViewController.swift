//
//  SocialActivitiesViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 13/06/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class SocialActivitiesViewController: UITableViewController {
    var media: MediaModel!

    private var socialTask: _Concurrency.Task<Void, Never>?

    private enum Section: Int {
        case content
    }

    private enum Wrapper: Hashable {
        case loading
        case empty
        case error
        case header(SocialActivitiesHeaderSummary)
        case user(SocialActivityUserSummary)
        case comment(SocialActivityCommentSummary)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, _, item in
        switch item {
        case .loading:
            return tableView.dequeueReusableCell(withIdentifier: "loading")
        case .empty:
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty") as! EmptyTableViewCell
            cell.emoji.text = "👀"
            cell.title.text = "No Activity Yet"
            cell.subtitle.text = "No one you follow has watched, rated, commented on, or added this to their watchlist yet."
            cell.body.text = nil
            cell.body.isHidden = true
            cell.action.isHidden = true
            return cell
        case .error:
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty") as! EmptyTableViewCell
            cell.emoji.text = "😓"
            cell.title.text = "Unable to Load"
            cell.subtitle.text = "Social activities could not be loaded."
            cell.body.text = nil
            cell.body.isHidden = true
            cell.action.isHidden = true
            return cell
        case .header(let summary):
            let cell = tableView.dequeueReusableCell(withIdentifier: "social activity header") as! ActivityHeaderTableViewCell
            cell.title.text = summary.titleText
            cell.contentTrailingConstraint?.constant = 24
            if let averageRatingText = summary.averageRatingText,
               let averageRatingAttributedText = self?.averageRatingAttributedText(for: averageRatingText) {
                cell.subtitle?.attributedText = averageRatingAttributedText
                cell.subtitle?.isHidden = false
            } else {
                cell.subtitle?.attributedText = nil
                cell.subtitle?.text = nil
                cell.subtitle?.isHidden = true
            }
            cell.chevron?.isHidden = true
            return cell
        case .user(let summary):
            let cell = tableView.dequeueReusableCell(withIdentifier: "social activity user") as! SocialActivityUserTableViewCell
            cell.cardType = summary.comment == nil ? .alone : .top
            cell.summary = summary
            return cell
        case .comment(let comment):
            let cell = tableView.dequeueReusableCell(withIdentifier: "social activity comment") as! SocialActivityCommentTableViewCell
            cell.cardType = .bottom
            cell.comment = comment
            return cell
        }
    }

    deinit {
        socialTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        precondition(media != nil, "Social activities view controller must be fed with a MediaModel")

        switch media! {
        case .movie, .show, .season, .episode:
            break
        case .list, .showProgress:
            fatalError("Social activities are not supported for this media type")
        }

        navigationItem.style = .browser
        navigationItem.title = "Social Activity"
        navigationItem.subtitle = media.mediaTitle
        navigationItem.largeTitleDisplayMode = .never

        tableView.allowsFocus = false
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 20, right: 0)
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "social activity header")
        tableView.register(UINib(nibName: "SocialActivityUserTableViewCell", bundle: nil), forCellReuseIdentifier: "social activity user")
        tableView.register(UINib(nibName: "SocialActivityCommentTableViewCell", bundle: nil), forCellReuseIdentifier: "social activity comment")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.dataSource = dataSource

        dataSource.defaultRowAnimation = .fade

        renderLoading()
        loadSocialActivities()
    }

    private func loadSocialActivities() {
        socialTask?.cancel()
        let media = media!

        socialTask = _Concurrency.Task { [weak self] in
            do {
                let entries = try await TraktAPIProvider.fetchAllSocialEntriesAsync(for: media)
                let summaries = SocialActivityUserSummary.summaries(from: entries, media: media)

                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.render(summaries: summaries)
                }
            } catch {
                print("Failed fetching social activities \(error)")

                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.renderError()
                }
            }
        }
    }

    private func renderLoading() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])
        snapshot.appendItems([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func render(summaries: [SocialActivityUserSummary]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])

        if summaries.isEmpty {
            snapshot.appendItems([.empty])
        } else {
            snapshot.appendItems([.header(SocialActivitiesHeaderSummary(summaries: summaries))])
            snapshot.appendItems(items(for: summaries))
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func items(for summaries: [SocialActivityUserSummary]) -> [Wrapper] {
        return summaries.flatMap { summary in
            var items = [Wrapper.user(summary)]

            if let comment = summary.comment {
                items.append(.comment(comment))
            }

            return items
        }
    }

    private func renderError() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])
        snapshot.appendItems([.error])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func averageRatingAttributedText(for averageRatingText: String) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: averageRatingText, attributes: [
            .font: averageRatingNumberFont,
            .foregroundColor: UIColor.label
        ])
        let percentRange = (averageRatingText as NSString).range(of: "%", options: .backwards)
        if percentRange.location != NSNotFound {
            attributedText.addAttributes([
                .font: averageRatingSuffixFont,
                .foregroundColor: UIColor.secondaryLabel
            ], range: percentRange)
        }
        return attributedText
    }

    private var averageRatingNumberFont: UIFont {
        let font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .headline).pointSize,
                                     weight: .bold)
        return UIFontMetrics(forTextStyle: .headline).scaledFont(for: font)
    }

    private var averageRatingSuffixFont: UIFont {
        let font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
                                     weight: .semibold)
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: font)
    }
}

extension SocialActivitiesViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .user(let summary):
            let commentsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "CommentsViewController") as! CommentsViewController
            commentsViewController.coordinator = CommentsCoordinator(type: .user(summary.user))
            navigationController?.pushViewController(commentsViewController, animated: true)
        case .comment(let comment):
            let commentsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "CommentsViewController") as! CommentsViewController
            commentsViewController.coordinator = CommentsCoordinator(type: .replies(comment.commentModel, false))
            navigationController?.pushViewController(commentsViewController, animated: true)
        case .loading, .empty, .error, .header:
            return
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
