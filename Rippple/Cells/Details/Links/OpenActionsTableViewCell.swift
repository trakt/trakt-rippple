//
//  OpenActionsTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 18/03/2026.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

protocol OpenInRowTableViewCellDelegate: AnyObject {
    func openInRowCell(_ cell: OpenActionsTableViewCell, didSelectURL url: URL, for item: CustomOpenAction)
    func openInRowCellDidTapSettings(_ cell: OpenActionsTableViewCell)
}

final class OpenActionsTableViewCell: TintedCanvasTableViewCell, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    weak var delegate: OpenInRowTableViewCellDelegate?

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var moreAction: UIButton!

    @IBOutlet var collectionView: UICollectionView!

    private let disposeBag = DisposeBag()

    private var openInEntries: [(action: CustomOpenAction, url: URL)] = []
    var media: MediaModel? {
        didSet {
            rebuildEntries()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        contentView.backgroundColor = .clear

        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.register(OpenInActionCollectionViewCell.self,
                                forCellWithReuseIdentifier: OpenInActionCollectionViewCell.reuseIdentifier)

        onCustomOpenActionsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.rebuildEntries()
            }
        }.disposed(by: disposeBag)

        onBuiltInOpenActionsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.rebuildEntries()
            }
        }.disposed(by: disposeBag)
    }

    private func rebuildEntries() {
        guard let media = media else {
            openInEntries = []
            collectionView.reloadData()
            return
        }

        openInEntries = OpenActionManager.shared.actions(for: media)
        collectionView.reloadData()
    }

    @IBAction func settings(_ sender: Any) {
        delegate?.openInRowCellDidTapSettings(self)
    }

    // MARK: - Collection view

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        openInEntries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OpenInActionCollectionViewCell.reuseIdentifier, for: indexPath) as! OpenInActionCollectionViewCell
        let entry = openInEntries[indexPath.item]
        cell.configure(with: entry.action)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let entry = openInEntries[indexPath.item]
        delegate?.openInRowCell(self, didSelectURL: entry.url, for: entry.action)
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item < openInEntries.count else { return nil }
        let entry = openInEntries[indexPath.item]

        return UIContextMenuConfiguration(identifier: nil,
                                          previewProvider: nil) { _ in
            let openAction = UIAction(title: "Open",
                                      image: UIImage(systemName: "safari")) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.openInRowCell(self, didSelectURL: entry.url, for: entry.action)
            }

            let copyAction = UIAction(title: "Copy Link",
                                      image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.url = entry.url
            }

            let shareAction = UIAction(title: "Share...",
                                       image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let activity = UIActivityViewController(activityItems: [entry.url],
                                                        applicationActivities: nil)
                UIApplication.shared.present(activity)
            }

            return UIMenu(title: "", children: [openAction, copyAction, shareAction])
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height: CGFloat = 70
        return CGSize(width: 50, height: height)
    }
}

// MARK: - Collection view cell for actions

final class OpenInActionCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "OpenInActionCollectionViewCell"

    private let stackView: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .center
        s.spacing = 4
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let iconBackground: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = ViewRadius.medium.rawValue
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.quaternarySystemFill.cgColor
        v.backgroundColor = .ripppleTertiaryBackground
        return v
    }()

    private let iconView: UIImageView = {
        let i = UIImageView()
        i.translatesAutoresizingMaskIntoConstraints = false
        i.contentMode = .scaleAspectFit
        i.tintColor = UIColor(asset: .globalTint)
        return i
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.preferredFont(forTextStyle: .caption2)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 1
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentView.addSubview(stackView)
        stackView.addArrangedSubview(iconBackground)
        stackView.addArrangedSubview(titleLabel)

        iconBackground.addSubview(iconView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            iconBackground.widthAnchor.constraint(equalToConstant: 50),
            iconBackground.heightAnchor.constraint(equalToConstant: 50),

            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    func configure(with item: CustomOpenAction) {
        iconView.image = UIImage(systemName: item.systemImageName)
        titleLabel.text = item.name
    }
}
