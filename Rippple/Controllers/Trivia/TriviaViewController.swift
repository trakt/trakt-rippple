//
//  TriviaViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 04/11/2026.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import UIKit

final class TriviaViewController: UITableViewController {
    var media: MediaModel?

    private var trivia: Trivia?
    private var triviaLoading = false
    private var triviaFailed = false
    private var triviaRequest: Cancellable?
    private var requestID = UUID()
    private var revealedItems = Set<Wrapper>()

    private enum Section: Hashable {
        case content
    }

    private enum Wrapper: Hashable {
        case summary
        case fact(String)
        case empty(emoji: String, title: String, subtitle: String, body: String)
    }

    private lazy var loadingView: UIView = {
        let container = UIView()
        let loading = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 60, height: 60),
                                              type: .ballScaleMultiple,
                                              color: UIColor(asset: .globalTint))
        loading.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(loading)
        NSLayoutConstraint.activate([
            loading.widthAnchor.constraint(equalToConstant: 60),
            loading.heightAnchor.constraint(equalToConstant: 60),
            loading.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        loading.startAnimating()
        return container
    }()

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, indexPath, item in
        guard let self = self else { return nil }
        return self.cell(in: tableView, at: indexPath, for: item)
    }

    deinit {
        triviaRequest?.cancel()
    }

    override func loadView() {
        tableView = TintedPlainTableView(frame: .zero, style: .plain)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.title = "Trivia"
        navigationItem.subtitle = media?.mediaTitle
        navigationItem.largeTitleDisplayMode = .never

        tableView.backgroundColor = .ripppleViewBackground
        tableView.allowsFocus = false
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 20, right: 0)
        tableView.register(TriviaTableViewCell.self, forCellReuseIdentifier: "trivia")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.dataSource = dataSource

        dataSource.defaultRowAnimation = .none

        refresh()
    }

    private func refresh() {
        triviaRequest?.cancel()
        requestID = UUID()
        let requestID = requestID
        triviaFailed = false

        guard let target = MediaInfoTarget(media: media) else {
            triviaLoading = false
            reloadContent()
            return
        }

        triviaLoading = true
        reloadContent()

        triviaRequest = TraktAPIProvider.provider.request(.trivia(target: target), callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            var trivia: Trivia?
            var failed = false
            switch result {
            case .success(let moyaResponse):
                do {
                    if moyaResponse.statusCode != 204, moyaResponse.statusCode != 404 {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        trivia = try response.map(Trivia.self, using: TraktAPIProvider.decoder)
                    }
                } catch {
                    failed = true
                }
            case .failure:
                failed = true
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.requestID == requestID else { return }
                self.triviaLoading = false
                self.triviaFailed = failed
                self.trivia = trivia
                self.reloadContent()
            }
        }
    }

    private func reloadContent() {
        tableView.backgroundView = triviaLoading ? loadingView : nil

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])

        if triviaLoading {
            dataSource.apply(snapshot, animatingDifferences: false)
            return
        }

        if let emptyState = emptyState {
            snapshot.appendItems([emptyState])
        } else if let trivia = trivia {
            if trivia.summary.isEmpty == false {
                snapshot.appendItems([.summary])
            }
            snapshot.appendItems(trivia.items.map { .fact($0.factId) })
        }

        let existingItems = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { existingItems.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private var emptyState: Wrapper? {
        if triviaFailed {
            return .empty(emoji: "😓", title: "Unable to Load", subtitle: "Trivia could not be loaded", body: "Please try again later.")
        }
        guard let trivia = trivia, trivia.summary.isEmpty == false || trivia.items.isEmpty == false else {
            return .empty(emoji: "💡", title: "No Trivia Yet", subtitle: "There is no trivia for this title yet", body: "When trivia is available, you will find it here.")
        }
        return nil
    }

    private func fact(withID id: String) -> Trivia.Item? {
        return trivia?.items.first { $0.factId == id }
    }

    private func cell(in tableView: UITableView, at indexPath: IndexPath, for item: Wrapper) -> UITableViewCell {
        switch item {
        case .summary:
            let cell = tableView.dequeueReusableCell(withIdentifier: "trivia", for: indexPath) as! TriviaTableViewCell
            let summary = (trivia?.summary ?? []).map { "• \($0)" }.joined(separator: "\n")
            let visibility: TriviaTableViewCell.Visibility = revealedItems.contains(item) ? .spoilerRevealed : .visible
            cell.configure(header: "Trivia Highlights", icon: "lightbulb", text: summary, meta: [], visibility: visibility)
            return cell
        case .fact(let id):
            let cell = tableView.dequeueReusableCell(withIdentifier: "trivia", for: indexPath) as! TriviaTableViewCell
            guard let fact = fact(withID: id) else { return cell }
            let isRevealed = revealedItems.contains(item)
            if fact.spoiler {
                cell.configure(header: nil, icon: nil, text: fact.text, meta: ["Spoiler Alert!"], visibility: isRevealed ? .spoilerRevealed : .spoilerHidden)
                cell.accessibilityHint = isRevealed ? nil : "Reveals the spoiler"
            } else {
                cell.configure(header: nil, icon: nil, text: fact.text, meta: [], visibility: isRevealed ? .spoilerRevealed : .visible)
            }
            return cell
        case .empty(let emoji, let title, let subtitle, let body):
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty", for: indexPath) as! EmptyTableViewCell
            cell.emoji.text = emoji
            cell.title.text = title
            cell.subtitle.text = subtitle
            cell.body.text = body
            cell.action.isHidden = true
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath),
              let cell = tableView.cellForRow(at: indexPath) as? TriviaTableViewCell,
              cell.hasHiddenSpoiler,
              revealedItems.insert(item).inserted else { return }

        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems([item])
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

private final class TriviaTableViewCell: TintedCanvasTableViewCell {
    private let card = CardView()
    private let iconView = UIImageView()
    private let headerLabel = UILabel()
    private let bodyLabel = LinkEnabledLabel()
    private let metaLabel = UILabel()
    private let headerContainer = UIStackView()

    private(set) var hasHiddenSpoiler = false

    enum Visibility {
        case visible
        case spoilerHidden
        case spoilerRevealed
    }

    private let markdownParser: SpoilerMarkdownParser = {
        let category = min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge)
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        return SpoilerMarkdownParser(font: .preferredFont(forTextStyle: .body, compatibleWith: traits), color: .label)
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        maximumContentSizeCategory = .large

        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)

        headerLabel.font = .preferredFont(forTextStyle: .footnote)
        headerLabel.textColor = .secondaryLabel
        headerLabel.adjustsFontForContentSizeCategory = true

        let headerStack = UIStackView(arrangedSubviews: [iconView, headerLabel])
        headerStack.spacing = 5
        headerStack.alignment = .center

        bodyLabel.numberOfLines = 0
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.adjustsFontForContentSizeCategory = true

        metaLabel.font = .preferredFont(forTextStyle: .footnote)
        metaLabel.textColor = .secondaryLabel
        metaLabel.numberOfLines = 0
        metaLabel.adjustsFontForContentSizeCategory = true

        headerContainer.addArrangedSubview(headerStack)
        headerContainer.axis = .vertical
        headerContainer.alignment = .leading

        let stack = UIStackView(arrangedSubviews: [headerContainer, metaLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        card.cardType = .alone
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(header: String?, icon: String?, text: String, meta: [String], visibility: Visibility) {
        headerLabel.text = header
        iconView.image = icon.flatMap { UIImage(systemName: $0) }
        headerContainer.isHidden = header == nil
        metaLabel.text = meta.joined(separator: " · ")
        metaLabel.isHidden = meta.isEmpty
        accessibilityHint = nil

        let isHidden = visibility == .spoilerHidden
        let attributedText = attributedString(for: text, hidesSpoilers: visibility == .visible)
        let textRange = NSRange(location: 0, length: attributedText.length)
        hasHiddenSpoiler = isHidden
        if isHidden {
            markdownParser.hideSpoiler(in: attributedText, range: textRange)
        } else {
            attributedText.enumerateAttribute(MarkdownSpoiler.hiddenAttribute, in: textRange) { value, _, stop in
                guard value != nil else { return }
                hasHiddenSpoiler = true
                stop.pointee = true
            }
        }
        bodyLabel.attributedText = attributedText

        bodyLabel.isAccessibilityElement = isHidden == false
        isAccessibilityElement = isHidden
        accessibilityLabel = isHidden ? (meta + ["Hidden trivia"]).joined(separator: ", ") : nil
    }

    private func attributedString(for text: String, hidesSpoilers: Bool) -> NSMutableAttributedString {
        markdownParser.highlight.highlightColor = UIColor(asset: .globalTint).withAlphaComponent(0.4)
        markdownParser.spoilerStrategy = hidesSpoilers ? .hideInlineSpoilers : .showAllSpoilers

        let attributedText = NSMutableAttributedString(attributedString: markdownParser.parse(text.htmlDecoded.emojiUnescapedString))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 6
        attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedText.length))
        return attributedText
    }
}
