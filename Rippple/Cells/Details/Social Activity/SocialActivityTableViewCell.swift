//
//  SocialActivityTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 13/06/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Kingfisher
import UIKit

final class SocialActivityTableViewCell: UITableViewCell {
    @IBOutlet var card: CardView!

    @IBOutlet var titleLabel: UILabel!

    @IBOutlet var avatarsContainer: UIView!
    @IBOutlet var avatarsContainerWidthConstraint: NSLayoutConstraint!

    private let maxAvatars = 5
    private let loadingAvatarCount = 1
    private let avatarSize: CGFloat = 34.0
    private let avatarBorderWidth: CGFloat = 1.0
    private let avatarFanOutTranslation: CGFloat = 8.0
    private let contentTransitionDuration: TimeInterval = 0.3
    private var avatarStep: CGFloat {
        avatarSize * 0.7
    }

    private lazy var avatarFilter = RoundCornerImageProcessor(
        cornerRadius: avatarSize / 2.0,
        targetSize: CGSize(width: avatarSize, height: avatarSize)
    )

    private var avatarImageViews = [UIImageView]()
    private var overflowLabels = [UILabel]()
    private var socialTask: _Concurrency.Task<Void, Never>?
    private var loadIdentifier = UUID()
    private var isShowingLoadingState = false
    private var avatarTransitionSnapshot: UIView?

    var cardType: CardType = .alone {
        didSet {
            card.cardType = cardType
        }
    }

    private var representedMedia: MediaModel?

    var media: MediaModel! {
        didSet {
            guard let media else { return }
            switch media {
            case .movie, .show, .season, .episode:
                break
            case .list, .showProgress:
                fatalError("Social activities are not supported for this media type")
            }

            guard representedMedia != media else { return }
            representedMedia = media
            loadSocialActivities(for: media)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = .clear
        backgroundColor = .clear
        selectionStyle = .none
        maximumContentSizeCategory = .extraExtraExtraLarge

        titleLabel.textColor = .secondaryLabel
        titleLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        titleLabel.numberOfLines = 2

        avatarsContainer.setContentHuggingPriority(.required, for: .horizontal)
        avatarsContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        configureAvatarImageViews()
        renderLoading()
    }

    private func configureAvatarImageViews() {
        for index in 0..<maxAvatars {
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = avatarSize / 2.0
            imageView.layer.borderWidth = avatarBorderWidth
            imageView.layer.zPosition = CGFloat(index)
            imageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor
            imageView.backgroundColor = .tertiarySystemBackground.withAlphaComponent(1.0)

            let overflowLabel = UILabel()
            overflowLabel.translatesAutoresizingMaskIntoConstraints = false
            overflowLabel.adjustsFontForContentSizeCategory = true
            overflowLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
            overflowLabel.textAlignment = .center
            overflowLabel.textColor = .secondaryLabel
            overflowLabel.isHidden = true
            overflowLabel.layer.zPosition = CGFloat(index) + 0.5

            avatarsContainer.addSubview(imageView)
            avatarsContainer.addSubview(overflowLabel)
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: avatarsContainer.leadingAnchor,
                                                   constant: CGFloat(index) * avatarStep),
                imageView.centerYAnchor.constraint(equalTo: avatarsContainer.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: avatarSize),
                imageView.heightAnchor.constraint(equalToConstant: avatarSize),
                overflowLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                overflowLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
                overflowLabel.widthAnchor.constraint(equalTo: imageView.widthAnchor),
                overflowLabel.heightAnchor.constraint(equalTo: imageView.heightAnchor)
            ])

            avatarImageViews.append(imageView)
            overflowLabels.append(overflowLabel)
        }
    }

    private func loadSocialActivities(for media: MediaModel) {
        socialTask?.cancel()
        let loadIdentifier = UUID()
        self.loadIdentifier = loadIdentifier
        renderLoading()

        socialTask = _Concurrency.Task { [weak self] in
            do {
                let entries = try await TraktAPIProvider.fetchAllSocialEntriesAsync(for: media)

                await MainActor.run { [weak self] in
                    guard let self = self, self.loadIdentifier == loadIdentifier, self.representedMedia == media else { return }
                    self.render(entries: entries)
                }
            } catch {
                print("Failed fetching social activities \(error)")

                await MainActor.run { [weak self] in
                    guard let self = self, self.loadIdentifier == loadIdentifier, self.representedMedia == media else { return }
                    self.render(entries: [])
                }
            }
        }
    }

    private func renderLoading() {
        resetContentTransitionState()
        isShowingLoadingState = true
        titleLabel.text = "Loading..."
        renderLoadingAvatars()
    }

    private func render(entries: [SocialEntry]) {
        let activeEntries = entries.filter { socialActivityCount(for: $0) > 0 }
        let users = SocialActivityUserSummary.summaries(from: activeEntries).map(\.user)
        let titleText = titleText(for: activeEntries)

        guard isShowingLoadingState, window != nil else {
            titleLabel.text = titleText
            renderAvatars(for: users)
            isShowingLoadingState = false
            return
        }

        animateContentTransition(titleText: titleText, users: users)
        isShowingLoadingState = false
    }

    private func animateContentTransition(titleText: String, users: [User]) {
        contentView.layoutIfNeeded()
        let avatarSnapshot = avatarsContainer.snapshotView(afterScreenUpdates: false)

        if let avatarSnapshot {
            avatarTransitionSnapshot?.removeFromSuperview()
            avatarTransitionSnapshot = avatarSnapshot
            avatarSnapshot.frame = avatarsContainer.convert(avatarsContainer.bounds, to: contentView)
            contentView.addSubview(avatarSnapshot)
        }

        UIView.transition(with: titleLabel,
                          duration: contentTransitionDuration,
                          options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.titleLabel.text = titleText
        }

        renderAvatars(for: users)
        applyAvatarFanOutTransform(visibleAvatarCount: visibleAvatarCount(for: users))
        avatarsContainer.alpha = 0

        UIView.animate(withDuration: contentTransitionDuration,
                       delay: 0,
                       options: [.curveEaseOut, .allowUserInteraction]) {
            avatarSnapshot?.alpha = 0
            self.avatarsContainer.alpha = 1
            self.resetAvatarFanOutTransforms()
            self.contentView.layoutIfNeeded()
        } completion: { _ in
            avatarSnapshot?.removeFromSuperview()

            if let avatarSnapshot, self.avatarTransitionSnapshot === avatarSnapshot {
                self.avatarTransitionSnapshot = nil
            }

            self.avatarsContainer.alpha = 1
            self.resetAvatarFanOutTransforms()
        }
    }

    private func resetContentTransitionState() {
        avatarTransitionSnapshot?.removeFromSuperview()
        avatarTransitionSnapshot = nil
        avatarsContainer.alpha = 1
        resetAvatarFanOutTransforms()
    }

    private func renderLoadingAvatars() {
        avatarsContainer.isHiddenInStackView = false
        avatarsContainerWidthConstraint.constant = avatarContainerWidth(for: loadingAvatarCount)

        for (index, imageView) in avatarImageViews.enumerated() {
            imageView.kf.cancelDownloadTask()
            overflowLabels[index].isHidden = true

            guard index < loadingAvatarCount else {
                imageView.image = nil
                imageView.isHidden = true
                continue
            }

            imageView.isHidden = false
            imageView.image = nil
        }
    }

    private func renderAvatars(for users: [User]) {
        let hasOverflow = users.count > maxAvatars
        let avatarUsers = Array(users.prefix(hasOverflow ? maxAvatars - 1 : maxAvatars))
        let visibleAvatarCount = avatarUsers.count + (hasOverflow ? 1 : 0)
        avatarsContainer.isHiddenInStackView = visibleAvatarCount == 0
        avatarsContainerWidthConstraint.constant = avatarContainerWidth(for: visibleAvatarCount)

        for (index, imageView) in avatarImageViews.enumerated() {
            imageView.kf.cancelDownloadTask()
            overflowLabels[index].isHidden = true

            if hasOverflow, index == maxAvatars - 1 {
                imageView.isHidden = false
                imageView.image = nil
                overflowLabels[index].text = "+\(users.count - maxAvatars + 1)"
                overflowLabels[index].isHidden = false
                continue
            }

            guard index < avatarUsers.count else {
                imageView.image = nil
                imageView.isHidden = true
                continue
            }

            imageView.isHidden = false
            imageView.image = #imageLiteral(resourceName: "bg_placeholder_avatar_tiny")

            guard let imageURL = avatarUsers[index].images?.avatar.full else { continue }
            imageView.kf.setImage(with: imageURL,
                                  placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_tiny"),
                                  options: [.scaleFactor(traitCollection.displayScale), .processor(avatarFilter), .transition(.fade(contentTransitionDuration))])
        }
    }

    private func visibleAvatarCount(for users: [User]) -> Int {
        return min(users.count, maxAvatars)
    }

    private func applyAvatarFanOutTransform(visibleAvatarCount: Int) {
        for index in avatarImageViews.indices {
            let transform: CGAffineTransform

            if index < visibleAvatarCount {
                transform = CGAffineTransform(translationX: -CGFloat(index) * avatarFanOutTranslation, y: 0)
            } else {
                transform = .identity
            }

            avatarImageViews[index].transform = transform
            overflowLabels[index].transform = transform
        }
    }

    private func resetAvatarFanOutTransforms() {
        for index in avatarImageViews.indices {
            avatarImageViews[index].transform = .identity
            overflowLabels[index].transform = .identity
        }
    }

    private func avatarContainerWidth(for visibleAvatarCount: Int) -> CGFloat {
        guard visibleAvatarCount > 0 else { return 0 }
        return avatarSize + (CGFloat(visibleAvatarCount - 1) * avatarStep)
    }

    private func titleText(for entries: [SocialEntry]) -> String {
        let watchedCount = entries.filter { $0.watched != nil }.count
        let watchlistedCount = entries.filter { $0.watchlisted != nil }.count
        let ratedCount = entries.filter { $0.watched?.rating != nil }.count
        let commentedCount = entries.filter { $0.watched?.comment != nil }.count

        let activities = [
            (count: watchedCount, label: "watched", priority: 0),
            (count: watchlistedCount, label: "watchlisted", priority: 1),
            (count: ratedCount, label: "rated", priority: 2),
            (count: commentedCount, label: "commented", priority: 3)
        ]

        let parts = activities
            .filter { $0.count > 0 }
            .sorted {
                if $0.count == $1.count {
                    return $0.priority < $1.priority
                }

                return $0.count > $1.count
            }
            .map { activityText(count: $0.count, label: $0.label) }

        guard parts.isEmpty == false else { return "No one you follow has watched, or watchlisted this yet." }
        return parts.joined(separator: ", ")
    }

    private func activityText(count: Int, label: String) -> String {
        return "\(count) \(label)"
    }

    private func socialActivityCount(for entry: SocialEntry) -> Int {
        return SocialActivityUserSummary.activityTypes(for: entry).count
    }
}
