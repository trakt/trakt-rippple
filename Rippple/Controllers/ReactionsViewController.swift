//
//  LikesViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 14/07/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import UIKit

import NVActivityIndicatorView

import Moya
import SwiftUI

import Receiver

final class ReactionsViewController: UITableViewController {

    // Public
    var comment: Comment!

    // Private
    private var reactions = [CommentReaction]()

    // Reactions summary
    private var reactionSummary: ReactionSummary? {
        didSet {
            DispatchQueue.main.async {
                self.updateSubtitle()
                // refresh reactions row to show counts
                var snapshot = self.dataSource.snapshot()
                if snapshot.sectionIdentifiers.contains(.content) {
                    snapshot.reloadItems([.reactions])
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }

    private func updateSubtitle() {
        let count = currentPage?.itemCount ?? 0
        if let summary = reactionSummary {
            navigationItem.subtitle = "\(count) reaction\(count > 1 ? "s" : "") · score \(summary.distribution.score)"
        } else {
            navigationItem.subtitle = "\(count) reaction\(count > 1 ? "s" : "")"
        }
    }

    // Empty
    @IBOutlet private var emptyView: UIView!

    // Paging Management
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private weak var animationViewContainer: NVActivityIndicatorView!

    private var currentPage: PageInfo? {
        didSet {
            DispatchQueue.main.async {
                self.updateSubtitle()
            }
        }
    }

    // Error Management
    @IBOutlet private var errorView: UIView!
    private var error: Error?

    // Standard Footer
    @IBOutlet private var footerView: UIView!

    private enum Section: Int {
        case loading
        case error
        case content
        case footer
    }

    private enum Wrapper: Hashable {
        case reaction(CommentReaction)
        case reactions
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .reaction(let like):
            let cell = tableView.dequeueReusableCell(withIdentifier: "user") as! UserTableViewCell

            cell.user = like.user
            cell.commentReactions = like.reaction.emoji

            return cell
        case .reactions:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "reactions")
            cell.selectionStyle = .none
            cell.contentConfiguration = UIHostingConfiguration {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 6) {
                        ForEach(ReactionsManager.shared.possibleReactions) { reaction in
                            // compute count for this reaction from summary
                            let count: Int = {
                                guard let dist = self.reactionSummary?.distribution else { return 0 }
                                switch reaction.type {
                                case "like": return dist.like
                                case "dislike": return dist.dislike
                                case "love": return dist.love
                                case "laugh": return dist.laugh
                                case "shocked": return dist.shocked
                                case "bravo": return dist.bravo
                                case "spoiler": return dist.spoiler
                                default: return 0
                                }
                            }()

                            if self.comment.userReacted(with: reaction.emoji) {
                                VStack(alignment: .center, spacing: 2) {
                                    Button {
                                        self.comment.removeReaction(reaction: reaction)
                                    } label: {
                                        Text(reaction.emoji)
                                            .font(.title)
                                            .padding(5)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.circle)

                                    // label with count and type
                                    Text("\(reaction.type.capitalized) \(count > 0 ? "(\(count))" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                VStack(alignment: .center, spacing: 2) {
                                    Button {
                                        self.comment.addReaction(reaction: reaction)
                                        AppManager.shared.emitEmoji(emoji: reaction.emoji)
                                    } label: {
                                        Text(reaction.emoji)
                                            .font(.title)
                                            .padding(5)
                                    }
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.circle)

                                    // label with count and type
                                    Text("\(reaction.type.capitalized) \(count > 0 ? "(\(count))" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .scrollClipDisabled()
                .defaultScrollAnchor(.center, for: .alignment)
            }
            return cell
        }
    }

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.subtitle = "Loading..."

        precondition(comment != nil, "Likes list view controller must be fed with a comment object!")

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "UserInListTableViewCell", bundle: nil), forCellReuseIdentifier: "user")
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none

        dataSource.defaultRowAnimation = .none

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        navigationItem.title = "Reactions"
        navigationItem.largeTitleDisplayMode = .never

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

        reactionSummary = comment.reactions
        fetchReactionSummary()

        onCommentReactReceiver.listen { [weak self] commentId in
            guard let self = self else { return }
            guard let comment = self.comment else { return }
            if comment.identifier != commentId { return }

            self.currentPage = nil
            self.reactions.removeAll()
            self.fetchNext()
            self.fetchReactionSummary()
        }.disposed(by: disposeBag)
    }

    func fetchNext() {
        guard let currentPage = currentPage else {
            self.currentPage = PageInfo.firstPage(with: 30)
            fetch(pageInfo: self.currentPage!)
            return
        }
        fetch(pageInfo: currentPage.nextPage)
    }

    func fetch(pageInfo: PageInfo) {
        print("Fetching page \(pageInfo.page) for Reactions")

        TraktAPIProvider.provider.request(.commentReactions(id: comment.identifier, pageInfo: pageInfo), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let reactions = try response.map([CommentReaction].self, using: TraktAPIProvider.decoder)

                    // Paging support
                    if let response = response.response,
                        let pageInfo = PageInfo(headers: response.allHeaderFields) {
                        self.currentPage = pageInfo
                    }
                    self.error = nil

                    self.reactions.append(contentsOf: reactions)

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.content])
                    snapshot.appendItems([.reactions])
                    snapshot.appendItems(self.reactions.map { .reaction($0) })
                    if self.currentPage!.page < self.currentPage!.pageCount {
                        snapshot.appendSections([.loading])
                    }
                    snapshot.appendSections([.footer])
                    snapshot.reloadItems([.reactions])
                    DispatchQueue.main.async {
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                } catch {
                    print("Reaction request JSON mapping failed! \(error)")
                    self.error = error

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.content])
                    snapshot.appendItems([.reactions])
                    snapshot.appendItems(self.reactions.map { .reaction($0) })
                    snapshot.appendSections([.error])
                    DispatchQueue.main.async {
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            case let .failure(error):
                print("Reaction request failure \(error)")
                self.error = error

                var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                snapshot.appendSections([.content])
                snapshot.appendItems([.reactions])
                snapshot.appendItems(self.reactions.map { .reaction($0) })
                snapshot.appendSections([.error])
                DispatchQueue.main.async {
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }

    private func fetchReactionSummary() {
        TraktAPIProvider.provider.request(.commentReactionsSummary(id: comment.identifier), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    let reactions = try response.map(ReactionSummary.self, using: TraktAPIProvider.decoder)
                    self.reactionSummary = reactions
                } catch {
                    print(".commentReactionsSummary request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                if error.localizedDescription == "cancelled" { return }
                print(".commentReactionsSummary request failure \(error)")
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            let type = sender as! CommentsCoordinator.ListType
            commentsViewController.coordinator = CommentsCoordinator(type: type)
        }
    }
}

extension ReactionsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case let Wrapper.reaction(like) = item else { return }

        let nextType = CommentsCoordinator.ListType.user(like.user)

        performSegue(withIdentifier: "user", sender: nextType)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == dataSource.snapshot().indexOfSection(Section.error) {
            return errorView
        }

        if section == dataSource.snapshot().indexOfSection(Section.loading) {
            return loadingView
        }

        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return emptyView
        }

        if section == dataSource.snapshot().indexOfSection(Section.footer), dataSource.snapshot().numberOfItems != 0 {
            return footerView
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if section == dataSource.snapshot().indexOfSection(Section.loading) {
            fetchNext()
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == dataSource.snapshot().indexOfSection(Section.error) {
            return 100
        }

        if section == dataSource.snapshot().indexOfSection(Section.loading) {
            return 100
        }

        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return 100
        }

        if section == dataSource.snapshot().indexOfSection(Section.footer), dataSource.snapshot().numberOfItems != 0 {
            return 100
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
