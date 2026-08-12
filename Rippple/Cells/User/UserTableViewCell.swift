//
//  UserTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import Kingfisher
import Moya
import Receiver
import UIKit

final class UserTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var fanartImageViewHeightConstraint: NSLayoutConstraint?

    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var commentReactionsLabel: UILabel?

    @IBOutlet var avatarImageView: UIImageView?
    @IBOutlet var fanartImageView: UIImageView?

    @IBOutlet var memberSinceLabel: UILabel?
    @IBOutlet var VIPView: UIView?
    @IBOutlet var VIPLabel: UILabel?

    @IBOutlet var privateStatus: UIImageView?

    private let disposeBag = DisposeBag()

    @IBOutlet var cardView: CardView?

    private let dateFormatter = DateFormatter()

    /// request
    private var request: Cancellable?

    private let profileFilter = RoundCornerImageProcessor(
        cornerRadius: 45.0,
        targetSize: CGSize(width: 90.0, height: 90.0)
    )

    private let listFilter = RoundCornerImageProcessor(
        cornerRadius: 30.0,
        targetSize: CGSize(width: 60.0, height: 60.0)
    )

    override func awakeFromNib() {
        super.awakeFromNib()

        commentReactionsLabel?.isHidden = true

        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.setLocalizedDateFormatFromTemplate("MMM yyyy")

        memberSinceLabel?.textColor = .label
        fanartImageView?.backgroundColor = .tertiarySystemFill

        if let avatarImageView = avatarImageView {
            if VIPView != nil { // only add the border if on profile
                avatarImageView.layer.borderColor = UIColor.white.cgColor
                avatarImageView.layer.borderWidth = 2
                avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2.0
                avatarImageView.layer.shadowColor = UIColor(asset: .shadow).cgColor
                avatarImageView.layer.shadowOpacity = 0.6
                avatarImageView.layer.shadowRadius = 5
                avatarImageView.layer.shadowOffset = CGSize(width: 0, height: 0)
                avatarImageView.layer.shadowPath = UIBezierPath(roundedRect: avatarImageView.bounds,
                                                                cornerRadius: avatarImageView.layer.cornerRadius).cgPath
                avatarImageView.backgroundColor = .ripppleTertiaryBackground
                avatarImageView.clipsToBounds = true

                maximumContentSizeCategory = .extraExtraLarge
            } else {
                avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2.0
                avatarImageView.layer.borderWidth = 1
                avatarImageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor
                avatarImageView.clipsToBounds = true
            }
        }

        if let VIPLabel = VIPView {
            VIPLabel.layer.cornerCurve = .circular
            VIPLabel.layer.cornerRadius = VIPLabel.bounds.height / 2.0
            VIPLabel.clipsToBounds = true
        }
    }

    var commentReactions: String? {
        didSet {
            if let reactions = commentReactions {
                commentReactionsLabel?.isHidden = false
                commentReactionsLabel?.text = reactions
            }
        }
    }

    var user: User? {
        didSet {
            guard let user = user else { return }
            usernameLabel.text = user.username
            nameLabel.text = user.name
            avatarImageView?.image = #imageLiteral(resourceName: "bg_placeholder_avatar_big")

            privateStatus?.isHidden = !user.isPrivate

            if let date = user.joinDate {
                memberSinceLabel?.text = "Member since \(dateFormatter.string(from: date))"
            } else {
                memberSinceLabel?.text = ""
            }

            if user.isDirector ?? false {
                VIPLabel?.text = "DIRECTOR"
                VIPView?.isHidden = false
            } else {
                if user.isVip ?? false {
                    if user.isVipEp ?? false, user.isVipOg ?? false {
                        VIPLabel?.text = "VIP+EP+OG"
                    } else if user.isVipOg ?? false {
                        VIPLabel?.text = "VIP+OG"
                    } else if user.isVipEp ?? false {
                        VIPLabel?.text = "VIP+EP"
                    } else {
                        VIPLabel?.text = "VIP"
                    }

                    VIPView?.isHidden = false
                } else {
                    VIPView?.isHidden = true
                }
            }

            if let imageURL = user.images?.avatar.full {
                avatarImageView?.kf.setImage(with: imageURL,
                                             placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_big"),
                                             options: [.scaleFactor(traitCollection.displayScale), .processor(VIPView == nil ? listFilter : profileFilter)])
            } else if user.isCurrentUser, let imageURL = UserManager.shared.currentUser?.images?.avatar.full {
                avatarImageView?.kf.setImage(with: imageURL,
                                             placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_big"),
                                             options: [.scaleFactor(traitCollection.displayScale), .processor(VIPView == nil ? listFilter : profileFilter)])
            }

            if let imageURL = user.vipCoverImage {
                fanartImageView?.kf.setImage(with: imageURL,
                                             options: [.scaleFactor(traitCollection.displayScale),
                                                       .processor(DownsamplingImageProcessor(size: fanartImageView!.bounds.size))]) { [weak self] _ in
                    guard let self = self else { return }
                    self.applyGradient()
                }
            } else if user.isCurrentUser, let imageURL = UserManager.shared.coverImageURL {
                fanartImageView?.kf.setImage(with: imageURL,
                                             options: [.scaleFactor(traitCollection.displayScale),
                                                       .processor(DownsamplingImageProcessor(size: fanartImageView!.bounds.size))]) { [weak self] _ in
                    guard let self = self else { return }
                    self.applyGradient()
                }
            } else {
                fetchUser(with: user.username)
            }
        }
    }

    private var fetchedUser: User! {
        didSet {
            if let date = fetchedUser.joinDate {
                memberSinceLabel?.text = "Member since \(dateFormatter.string(from: date))"
            } else {
                memberSinceLabel?.text = ""
            }

            privateStatus?.isHidden = !fetchedUser.isPrivate

            if fetchedUser.isDirector ?? false {
                VIPLabel?.text = "DIRECTOR"
                VIPView?.isHidden = false
            } else {
                if fetchedUser.isVip ?? false {
                    if fetchedUser.isVipEp ?? false, fetchedUser.isVipOg ?? false {
                        VIPLabel?.text = "VIP+EP+OG"
                    } else if fetchedUser.isVipOg ?? false {
                        VIPLabel?.text = "VIP+OG"
                    } else if fetchedUser.isVipEp ?? false {
                        VIPLabel?.text = "VIP+EP"
                    } else {
                        VIPLabel?.text = "VIP"
                    }

                    VIPView?.isHidden = false
                } else {
                    VIPView?.isHidden = true
                }
            }

            if let imageURL = fetchedUser.vipCoverImage {
                fanartImageView?.kf.setImage(with: imageURL,
                                             options: [.scaleFactor(traitCollection.displayScale),
                                                       .processor(DownsamplingImageProcessor(size: fanartImageView!.bounds.size))]) { [weak self] _ in
                    guard let self = self else { return }
                    self.applyGradient()
                }
            }
        }
    }

    func fetchUser(with id: String) {
        if let request = request {
            request.cancel()
        }
        request = TraktAPIProvider.fetchUser(with: id, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let user = try response.map(User.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.fetchedUser = user
                    }
                } catch {
                    print("User fetch failed \(error)")
                }
            case .failure(let error):
                print("User fetch failed \(error)")
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        DispatchQueue.main.async {
            self.applyGradient()
        }
    }

    private func applyGradient() {
        if let fanartImageView = fanartImageView, fanartImageView.image != nil {
            if let gradientLayer = fanartImageView.layer.sublayers?.first, gradientLayer.isKind(of: CAGradientLayer.self) {
                gradientLayer.removeFromSuperlayer()
            }

            let colorTop = UIColor.clear.cgColor
            let colorBottom = UIColor.black.cgColor

            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [colorTop, colorBottom]
            gradientLayer.locations = [0.6, 1.0]
            gradientLayer.frame = fanartImageView.bounds

            fanartImageView.layer.insertSublayer(gradientLayer, at: 0)

            memberSinceLabel?.textColor = .white
        }
    }
}
