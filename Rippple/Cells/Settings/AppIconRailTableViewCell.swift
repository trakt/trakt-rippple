//
//  AppIconRailTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 06/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

extension AppIcon {
    var alternateIconName: String? {
        switch identifier {
        case .original:
            return nil
        default:
            return identifier.rawValue
        }
    }
}

final class AppIconRailTableViewCell: UITableViewCell {
    @IBOutlet weak var collectionView: UICollectionView!

    var items: [AppIcon]? {
        didSet {
            collectionView.reloadData()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView?.allowsFocus = false
        collectionView.collectionViewLayout = collectionViewLayout()

        collectionView.register(UINib(nibName: "AppIconCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "cell")
    }

    private func collectionViewLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(100),
                                              heightDimension: .absolute(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(collectionView.bounds.width),
                                               heightDimension: .fractionalHeight(1))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                       subitems: [item])
        group.interItemSpacing = .fixed(10)

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 10
        section.contentInsets = .init(top: 10, leading: 16, bottom: 10, trailing: 16)

        let layout = UICollectionViewCompositionalLayout(section: section)

        return layout
    }
}

extension AppIconRailTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let items = items {
            return items.count
        }

        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! AppIconCollectionViewCell

        cell.appIcon = items![indexPath.row]

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let appIcon = items?[indexPath.row] else { return }

        WidgetManager.shared.storeAppIconForWidget(appIcon: appIcon)

        #if targetEnvironment(macCatalyst)

        let alertController = UIAlertController(title: "Not Supported (yet)",
                                                message: "Unfortunately, setting a custom icon on the Mac is not supported yet. As soon as it will be possible, Rippple will support the same icons on iPhone, iPad and on the Mac. In the meantime, you can add the \"Splash\" Widget on your Mac and use this menu to configure it.",
                                                preferredStyle: .alert)

        let cancel = UIAlertAction(title: "Okay", style: .cancel)
        alertController.addAction(cancel)

        AppManager.shared.present(viewController: alertController, animated: true)

        #else

        for tint in RipppleTintColor.allCases {
            if let alternateIconName = appIcon.alternateIconName, alternateIconName.localizedCaseInsensitiveContains(tint.name) {
                if UIApplication.shared.currentTint == tint {
                    setAppIcon(alternateIconName: appIcon.alternateIconName)
                } else {
                    let alert = UIAlertController(title: "App Tint Color",
                                                  message: "Do you want to set the icon only? Or set the icon and apply the same tint color for the app?",
                                                  preferredStyle: .alert)

                    let iconAction = UIAlertAction(title: "Set Icon Only", style: .default) { _ in
                        self.setAppIcon(alternateIconName: appIcon.alternateIconName)
                    }
                    alert.addAction(iconAction)

                    let iconAndTintAction = UIAlertAction(title: "Set Icon and Tint", style: .default) { _ in
                        self.setAppIcon(alternateIconName: appIcon.alternateIconName)
                        UIApplication.shared.setTintColor(tint: tint)
                    }
                    alert.addAction(iconAndTintAction)

                    AppManager.shared.present(viewController: alert, animated: true)
                }

                return
            } else if appIcon.identifier == .original || appIcon.identifier == .color || appIcon.identifier == .dark || appIcon.identifier == .desktop || appIcon.identifier == .dark_purple || appIcon.identifier == .color_purple || appIcon.identifier == .light_purple || appIcon.identifier == .seven_dark_purple || appIcon.identifier == .seven_neon_purple || appIcon.identifier == .dark_purple_border || appIcon.identifier == .seven_color_purple || appIcon.identifier == .seven_light_purple || appIcon.identifier == .color_purple_border || appIcon.identifier == .light_purple_border {
                if UIApplication.shared.currentTint == .original {
                    setAppIcon(alternateIconName: appIcon.alternateIconName)
                } else {
                    let alert = UIAlertController(title: "App Tint Color",
                                                  message: "Do you want to set the icon only? Or set the icon and apply the same tint color for the app?",
                                                  preferredStyle: .alert)

                    let iconAction = UIAlertAction(title: "Set Icon Only", style: .default) { _ in
                        self.setAppIcon(alternateIconName: appIcon.alternateIconName)
                    }
                    alert.addAction(iconAction)

                    let iconAndTintAction = UIAlertAction(title: "Set Icon and Tint", style: .default) { _ in
                        self.setAppIcon(alternateIconName: appIcon.alternateIconName)
                        UIApplication.shared.setTintColor(tint: .original)
                    }
                    alert.addAction(iconAndTintAction)

                    AppManager.shared.present(viewController: alert, animated: true)
                }

                return
            }
        }

        setAppIcon(alternateIconName: appIcon.alternateIconName)

        #endif
    }

    private func setAppIcon(alternateIconName: String?) {
        UIApplication.shared.setAlternateIconName(alternateIconName) { error in
            if let error = error {
                let alert = UIAlertController(title: "Error setting the Icon",
                                              message: "\(error.localizedDescription)\n\nHint: restarting your device can sometimes help.",
                                              preferredStyle: .alert)

                let cancel = UIAlertAction(title: "Okay", style: .cancel)
                alert.addAction(cancel)
                AppManager.shared.present(viewController: alert, animated: true)
            }
        }
    }
}
