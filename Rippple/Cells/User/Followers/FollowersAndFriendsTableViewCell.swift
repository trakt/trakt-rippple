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

    private var requests = [Cancellable]()
    private var loadGeneration = 0

    override func prepareForReuse() {
        super.prepareForReuse()
        user = nil
    }

    deinit {
        requests.forEach { $0.cancel() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onSettingsChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.loadCounts()
            }
        }.disposed(by: disposeBag)
        onVIPChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.loadCounts()
            }
        }.disposed(by: disposeBag)

        numberFormatter.numberStyle = .decimal

        followersCount.method = .easeInOut
        followersCount.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        followingCount.method = .easeInOut
        followingCount.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        friendsCount.method = .easeInOut
        friendsCount.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        blockedCount?.method = .easeInOut
        blockedCount?.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        for label in [followersCount, followingCount, friendsCount, blockedCount] {
            label?.countFrom(0, to: 0, withDuration: 0)
        }

        onUsersHiddenFromCommentsChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.user?.isCurrentUser == true else { return }
                self.loadCounts()
            }
        }.disposed(by: disposeBag)

        maximumContentSizeCategory = .extraExtraExtraLarge
    }

    var user: User! {
        didSet {
            loadCounts()
        }
    }

    private func loadCounts() {
        requests.forEach { $0.cancel() }
        requests.removeAll()
        loadGeneration += 1

        let isCurrentUser = user?.isCurrentUser == true
        blockedCount?.superview?.isHidden = !isCurrentUser
        blockedSeparator?.isHidden = !isCurrentUser
        for label in [followersCount, followingCount, friendsCount, blockedCount] {
            label?.countFrom(0, to: 0, withDuration: 0)
            label?.isHidden = false
        }

        guard let requestedUser = user, UserManager.shared.currentUser != nil else {
            for label in [followersCount, followingCount, friendsCount, blockedCount] {
                label?.text = "—"
            }
            return
        }

        if isCurrentUser ? UserManager.shared.isCurrentVIP : requestedUser.isTraktVIP {
            fetchStats(for: requestedUser)
        } else {
            fetchNetworkCounts(for: requestedUser)
        }
        if isCurrentUser {
            fetchCount(.blocked, for: requestedUser, label: blockedCount)
        }
    }

    private func fetchStats(for requestedUser: User) {
        let currentUser = UserManager.shared.currentUser
        let requestedGeneration = loadGeneration
        let request = TraktAPIProvider.provider.request(.stats(type: .user(slug: requestedUser.slug)),
                                                        callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            let statsResult = Result<UserStats?, Error> {
                let response = try result.get().filterSuccessfulStatusCodes()
                guard response.statusCode != 204 else { return nil }
                return try response.map(UserStats.self, using: TraktAPIProvider.decoder)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.user == requestedUser,
                      UserManager.shared.currentUser == currentUser,
                      self.loadGeneration == requestedGeneration else { return }
                switch statsResult {
                case .success(let stats):
                    guard let stats = stats else {
                        self.fetchNetworkCounts(for: requestedUser)
                        return
                    }
                    self.followersCount.countFromCurrentValueTo(CGFloat(stats.network.followers), withDuration: 0.7)
                    self.followingCount.countFromCurrentValueTo(CGFloat(stats.network.following), withDuration: 0.7)
                    self.friendsCount.countFromCurrentValueTo(CGFloat(stats.network.friends), withDuration: 0.7)
                case .failure(let error):
                    for label in [self.followersCount, self.followingCount, self.friendsCount] {
                        label?.text = "—"
                    }
                    print("Network stats request failed! \(error)")
                }
            }
        }
        requests.append(request)
    }

    private func fetchNetworkCounts(for requestedUser: User) {
        let counts: [(UserCountType, EFCountingLabel?)] = [
            (.followers, followersCount),
            (.following, followingCount),
            (.friends, friendsCount)
        ]
        for (type, label) in counts {
            fetchCount(type, for: requestedUser, label: label)
        }
    }

    private func fetchCount(_ type: UserCountType, for requestedUser: User, label: EFCountingLabel?) {
        let currentUser = UserManager.shared.currentUser
        let requestedGeneration = loadGeneration
        let request = TraktAPIProvider.fetchUserCount(slug: requestedUser.slug, type: type) { [weak self, weak label] result in
            DispatchQueue.main.async { [weak self, weak label] in
                guard let self = self,
                      self.user == requestedUser,
                      UserManager.shared.currentUser == currentUser,
                      self.loadGeneration == requestedGeneration else { return }
                switch result {
                case .success(let count):
                    label?.countFromCurrentValueTo(CGFloat(count), withDuration: 0.7)
                case .failure(let error):
                    label?.text = "—"
                    print("User count request failed! \(error)")
                }
            }
        }
        requests.append(request)
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
