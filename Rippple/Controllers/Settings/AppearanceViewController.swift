//
//  AppearanceViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 15/05/2021.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

let (neverMinimizeTabBarTransmitter, neverMinimizeTabBarReceiver) = Receiver<Bool>.make(with: .hot)

final class AppearanceViewController: UITableViewController {
    private let disposeBag = DisposeBag()

    @IBOutlet var tintColorButton: UIButton!
    @IBOutlet var tintedAppearanceSwitch: UISwitch!
    @IBOutlet var neverMinimizeTabBarSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        tintColorButton.showsMenuAsPrimaryAction = true

        tintColorButton.setTitleColor(UIColor(asset: .globalTint), for: .normal)
        tintColorButton.setTitleColor(UIColor(asset: .globalTint), for: .focused)
        tintColorButton.setTitleColor(UIColor(asset: .globalTint), for: .highlighted)

        tintedAppearanceSwitch.isOn = UIApplication.shared.isTintedAppearanceEnabled
        neverMinimizeTabBarSwitch.isOn = UserDefaults.standard.bool(forKey: "MainTabBarController.neverMinimize")

        updateButton()

        registerForTraitChanges([UITraitUserInterfaceStyle.self],
                                action: #selector(updateButton))
    }

    @IBAction private func neverMinimizeTabBarValueChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "MainTabBarController.neverMinimize")
        UserDefaults.standard.synchronize()
        neverMinimizeTabBarTransmitter.broadcast(sender.isOn)
    }

    @IBAction private func tintedAppearanceValueChanged(_ sender: UISwitch) {
        UIApplication.shared.setTintedAppearance(enabled: sender.isOn)
    }

    @objc
    private func updateButton() {
        tintColorButton.setTitle(UIApplication.shared.currentTint.name.capitalized,
                                 for: .normal)
        var children = [UIAction]()
        for value in RipppleTintColor.allCases {
            let image = createRoundedImage(size: CGSize(width: 25, height: 25),
                                           backgroundColor: value.color)
            let action = UIAction(title: value.name.capitalized,
                                  image: image,
                                  state: value == UIApplication.shared.currentTint ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                UIApplication.shared.setTintColor(tint: value)
                self.updateButton()
            }
            children.append(action)
        }
        tintColorButton.menu = UIMenu(children: children)
    }

    private func createRoundedImage(size: CGSize, backgroundColor: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)

        // Create rounded rectangle path
        let roundedRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let roundedPath = UIBezierPath(roundedRect: roundedRect, cornerRadius: size.width / 2)

        // Set background color
        backgroundColor.setFill()
        roundedPath.fill()

        // Create image from the context
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()

        return roundedImage
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "Apply the app tint color to backgrounds and cards."
        }

        #if targetEnvironment(macCatalyst)
        if section == 1 {
            switch UIApplication.shared.currentUserInterfaceStyle {
            case .unspecified:
                return "Always two there are, no more, no less."
            case .light:
                return "In a dark place we find ourselves, and a little more knowledge LIGHTS our way."
            case .dark:
                return "Once you start down the DARK path, forever will it dominate your destiny."
            @unknown default:
                return "Always two there are, no more, no less."
            }
        } else {
            return nil
        }
        #else
        if section == 1 {
            switch UIApplication.shared.currentUserInterfaceStyle {
            case .unspecified:
                return "Always two there are, no more, no less."
            case .light:
                return "In a dark place we find ourselves, and a little more knowledge LIGHTS our way."
            case .dark:
                return "Once you start down the DARK path, forever will it dominate your destiny."
            @unknown default:
                return "Always two there are, no more, no less."
            }
        } else if section == 3 {
            switch UIDevice.current.userInterfaceIdiom {
            case .pad:
                return "Customize the bottom tab bar when Rippple is in a 'phone' kind of layout (eg in split view)."
            default:
                return nil
            }
        } else {
            return nil
        }
        #endif
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return "Your Side Choose <(-_-)>"
        } else if section == 0 {
            return "Tint Color"
        } else {
            return UIDevice.current.userInterfaceIdiom == .phone || UIDevice.current.userInterfaceIdiom == .pad ? "Tab bar" : nil
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        #if targetEnvironment(macCatalyst)
        return 1
        #else
        return 3
        #endif
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 2
        } else if section == 1 {
            return 3
        } else {
            return UIDevice.current.userInterfaceIdiom == .phone || UIDevice.current.userInterfaceIdiom == .pad ? 2 : 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        if indexPath.section == 1 {
            switch UIApplication.shared.currentUserInterfaceStyle {
            case .unspecified:
                if indexPath.row == 0 {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            case .light:
                if indexPath.row == 2 {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            case .dark:
                if indexPath.row == 1 {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            @unknown default:
                if indexPath.row == 0 {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                UIApplication.shared.setSystemMode()
            } else if indexPath.row == 1 {
                UIApplication.shared.setDarkMode()
            } else if indexPath.row == 2 {
                UIApplication.shared.setLightMode()
            }
            tableView.reloadData()
        }
    }

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 44.0
        }
        return 0.0
    }
    #endif

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            return super.tableView(tableView, heightForFooterInSection: section)
        } else {
            return 0
        }
    }
    #endif
}
