//
//  FollowersAndFriendsTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 19/01/2022.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

protocol FollowersAndFriendsTableViewCellDelegate: AnyObject {
    func cell(_ cell: FollowersAndFriendsTableViewCell, action: FollowersAndFriendsTableViewCell.Action)
}

final class FollowersAndFriendsTableViewCell: TintedCanvasTableViewCell {
    enum Action {
        case followers
        case following
        case friends
        case blocked
    }

    weak var delegate: FollowersAndFriendsTableViewCellDelegate?

    @IBOutlet var followersCount: EFCountingLabel!
    @IBOutlet var followingCount: EFCountingLabel!
    @IBOutlet var friendsCount: EFCountingLabel!

    @IBOutlet var blockedSeparator: UIView?
    @IBOutlet var blockedCount: EFCountingLabel?

    private let disposeBag = DisposeBag()

    @IBOutlet var cardView: CardView?

    private let numberFormatter = NumberFormatter()

    /// request
    private var request: Cancellable?

    override func prepareForReuse() {
        super.prepareForReuse()
        request?.cancel()
        user = nil
    }

    deinit {
        request?.cancel()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.loadCounts()
        }.disposed(by: disposeBag)
        onVIPChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.loadCounts()
        }.disposed(by: disposeBag)

        numberFormatter.numberStyle = .decimal

        followersCount.text = "0"
        followersCount.method = .easeInOut
        followersCount.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        followingCount.text = "0"
        followingCount.method = .easeInOut
        followingCount.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        friendsCount.text = "0"
        friendsCount.method = .easeInOut
        friendsCount.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        blockedCount?.text = "0"
        blockedCount?.method = .easeInOut
        blockedCount?.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        onUsersHiddenFromCommentsChangedReceiver.listen { [weak self] users in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.blockedCount?.countFromCurrentValueTo(CGFloat(users.count), withDuration: 0.7)
            }
        }.disposed(by: disposeBag)

        maximumContentSizeCategory = .extraExtraExtraLarge
    }

    var user: User! {
        didSet {
            guard let user = user else { return }
            blockedCount?.superview?.isHidden = !user.isCurrentUser
            blockedSeparator?.isHidden = !user.isCurrentUser
            loadCounts()
        }
    }

    private func loadCounts() {
        request?.cancel()
        let canAccessStats = UserManager.shared.canAccessStats(for: user)
        blockedCount?.isHidden = !canAccessStats
        for label in [followersCount, followingCount, friendsCount] {
            label?.countFrom(0, to: 0, withDuration: 0)
            label?.isHidden = !canAccessStats
        }
        guard canAccessStats, let requestedUser = user else { return }
        request = TraktAPIProvider.provider.request(.stats(type: .user(slug: requestedUser.slug)),
                                                    callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    guard response.statusCode != 204 else { return }
                    let stats = try response.map(UserStats.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.user == requestedUser, UserManager.shared.canAccessStats(for: self.user) else { return }
                        self.followersCount.countFromCurrentValueTo(CGFloat(stats.network.followers), withDuration: 0.7)
                        self.followingCount.countFromCurrentValueTo(CGFloat(stats.network.following), withDuration: 0.7)
                        self.friendsCount.countFromCurrentValueTo(CGFloat(stats.network.friends), withDuration: 0.7)
                    }
                } catch {
                    print("/stats request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("/stats request failure \(error)")
            }
        }
    }

    @IBAction func friends(_ sender: Any) {
        if let delegate = delegate {
            delegate.cell(self,
                          action: .friends)
        }
    }

    @IBAction func following(_ sender: Any) {
        if let delegate = delegate {
            delegate.cell(self,
                          action: .following)
        }
    }

    @IBAction func followers(_ sender: Any) {
        if let delegate = delegate {
            delegate.cell(self,
                          action: .followers)
        }
    }

    @IBAction func blocked(_ sender: Any) {
        if let delegate = delegate {
            delegate.cell(self,
                          action: .blocked)
        }
    }
}
