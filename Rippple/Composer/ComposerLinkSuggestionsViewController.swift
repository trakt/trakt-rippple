//
//  ComposerLinkSuggestionsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class ComposerLinkSuggestionsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var hint = "Type to search people"
    var castTitle = "Cast"
    var resultsTitle: String?

    var scrollView: UIScrollView {
        tableView
    }

    var onSelect: ((ComposerLink) -> Void)?
    var onRetry: (() -> Void)?

    /// Grouped so section titles scroll with the results instead of sticking to the top.
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var suggestions = ComposerLinkSuggestions()
    private var resultsHeader: ComposerSectionHeader.Status?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .none
        tableView.separatorStyle = .none
        // Fixed header heights: self-sized ones were cached between result sets and kept stale, oversized gaps.
        tableView.sectionHeaderTopPadding = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        tableView.estimatedRowHeight = 56
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        tableView.register(ComposerLinkSuggestionCell.self, forCellReuseIdentifier: "link")
        tableView.register(ComposerTableSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: "header")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func apply(_ suggestions: ComposerLinkSuggestions, query: String) {
        self.suggestions = suggestions
        resultsHeader = resultsHeader(for: query)
        guard isViewLoaded else { return }
        tableView.reloadData()
    }

    private func resultsHeader(for query: String) -> ComposerSectionHeader.Status? {
        let searching = ComposerSectionHeader.Status(text: "Searching Trakt…", isLoading: true)
        guard let resultsTitle = resultsTitle, query.count >= 2 else {
            guard suggestions.cast.isEmpty else { return nil }
            if suggestions.isLoadingCast {
                return searching
            }
            return ComposerSectionHeader.Status(text: query.isEmpty || resultsTitle != nil ? hint : "No match for “\(query)”")
        }
        if suggestions.isSearching {
            return searching
        }
        if suggestions.didFail {
            return ComposerSectionHeader.Status(text: "Error searching for “\(query)” on Trakt", isRetryable: true)
        }
        if suggestions.results.isEmpty {
            return suggestions.cast.isEmpty ? ComposerSectionHeader.Status(text: "No match for “\(query)”") : nil
        }
        return ComposerSectionHeader.Status(text: resultsTitle)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        links(in: section).count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        header(for: section) == nil ? .leastNonzeroMagnitude : ComposerSectionHeader.height
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let state = header(for: section),
              let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as? ComposerTableSectionHeaderView else { return nil }
        header.content.status = state
        header.content.onTap = { [weak self] in
            guard let self = self else { return }
            self.onRetry?()
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNonzeroMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "link", for: indexPath) as! ComposerLinkSuggestionCell
        if let link = link(at: indexPath) {
            cell.configure(with: link)
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let link = link(at: indexPath) else { return }
        onSelect?(link)
    }

    // MARK: - Private

    private func links(in section: Int) -> [ComposerLink] {
        section == 0 ? suggestions.cast : suggestions.results
    }

    private func header(for section: Int) -> ComposerSectionHeader.Status? {
        guard section == 0 else { return resultsHeader }
        return suggestions.cast.isEmpty ? nil : ComposerSectionHeader.Status(text: castTitle)
    }

    private func link(at indexPath: IndexPath) -> ComposerLink? {
        let links = links(in: indexPath.section)
        return links.indices.contains(indexPath.row) ? links[indexPath.row] : nil
    }
}

final class ComposerSectionHeader: UIControl {
    struct Status: Equatable {
        var text: String
        var isLoading = false
        var isRetryable = false
    }

    static let height: CGFloat = 30

    var status = Status(text: "") {
        didSet {
            guard status != oldValue else { return }
            render()
        }
    }

    var onTap: (() -> Void)?

    private let label = UILabel()
    private let indicator = UIActivityIndicatorView(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .preferredFont(forTextStyle: .caption1).bold()
        label.adjustsFontForContentSizeCategory = true
        indicator.hidesWhenStopped = true
        indicator.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)

        let stack = UIStackView(arrangedSubviews: [indicator, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1)
        ])

        isAccessibilityElement = true
        addAction(UIAction { [weak self] _ in
            guard let self = self, self.status.isRetryable else { return }
            self.onTap?()
        }, for: .primaryActionTriggered)
        render()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A header leaving the screen stops its spinner; one coming back, still loading, starts it again.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, status.isLoading {
            indicator.startAnimating()
        }
    }

    private func render() {
        label.text = status.text
        label.textColor = status.isRetryable ? UIColor(asset: .globalTint) : .secondaryLabel
        if status.isLoading {
            indicator.startAnimating()
        } else {
            indicator.stopAnimating()
        }
        isUserInteractionEnabled = status.isRetryable
        accessibilityLabel = status.text
        accessibilityTraits = status.isRetryable ? [.header, .button] : .header
        accessibilityHint = status.isRetryable ? "Double-tap to try again." : nil
    }
}

final class ComposerTableSectionHeaderView: UITableViewHeaderFooterView {
    let content = ComposerSectionHeader()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = .clear
        backgroundConfiguration = background
        content.pin(in: contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ComposerSectionHeader {
    func pin(in container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            leadingAnchor.constraint(equalTo: container.leadingAnchor),
            trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

final class ComposerLinkSuggestionCell: UITableViewCell {
    private let poster = PosterImageView()
    private let avatar = PeopleProfileImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundConfiguration = .clear()

        poster.layer.cornerRadius = 4
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        avatar.layer.cornerRadius = 18
        avatar.layer.masksToBounds = true

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 1

        let imageContainer = UIView()
        let labels = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 1
        let row = UIStackView(arrangedSubviews: [imageContainer, labels])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        for view in [poster, avatar, imageContainer, labels, row] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        imageContainer.addSubview(poster)
        imageContainer.addSubview(avatar)
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            imageContainer.widthAnchor.constraint(equalToConstant: 36),
            imageContainer.heightAnchor.constraint(equalToConstant: 48),
            poster.widthAnchor.constraint(equalToConstant: 32),
            poster.heightAnchor.constraint(equalToConstant: 48),
            poster.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            poster.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 36),
            avatar.heightAnchor.constraint(equalToConstant: 36),
            avatar.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with link: ComposerLink) {
        titleLabel.text = link.title
        detailLabel.text = link.detail
        accessibilityLabel = "\(link.title), \(link.detail)"
        accessibilityHint = "Inserts a link."

        if let person = link.person {
            poster.isHidden = true
            avatar.isHidden = false
            if avatar.person != person {
                // PeopleProfileImageView sizes its downsampling from its bounds, which are fixed here.
                avatar.bounds.size = CGSize(width: 36, height: 36)
                avatar.person = person
            }
            return
        }
        avatar.isHidden = true
        poster.isHidden = false
        switch link.media {
        case .movie(let movie):
            poster.movie = movie
        case .season(let season, let show):
            poster.season = (show, season)
        case .show(let show), .episode(_, let show), .showProgress(let show, _):
            poster.show = show
        case .list, .none:
            poster.image = nil
        }
    }
}
