//
//  ListFormViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/12/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

import Receiver

let (listCreatedTransmitter, listCreatedReceiver) = Receiver<Bool>.make(with: .hot)
let (listUpdatedTransmitter, listUpdatedReceiver) = Receiver<List>.make(with: .hot)

final class ListFormViewController: UITableViewController {

    var list: List?

    @IBOutlet weak var listNameTextField: UITextField!
    @IBOutlet weak var listDescriptionTextField: UITextField!
    @IBOutlet weak var privacySegmentedControl: UISegmentedControl!
    @IBOutlet weak var allowCommentsSwitch: UISwitch!
    @IBOutlet weak var displayRankSwitch: UISwitch!

    @IBOutlet var addButton: UIBarButtonItem!
    @IBOutlet weak var cancelButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        isModalInPresentation = true

        if let list = list {
            listNameTextField.text = list.name.emojiUnescapedString
            listDescriptionTextField.text = list.description?.emojiUnescapedString
            switch list.privacy {
            case .all:
                privacySegmentedControl.selectedSegmentIndex = 3
            case .me:
                privacySegmentedControl.selectedSegmentIndex = 0
            case .friends:
                privacySegmentedControl.selectedSegmentIndex = 2
            case .link:
                privacySegmentedControl.selectedSegmentIndex = 1
            case .unknown:
                privacySegmentedControl.selectedSegmentIndex = 0
            }
            allowCommentsSwitch.isOn = list.commentsAllowed
            displayRankSwitch.isOn = list.displayRank

            addButton.title = "Update"
            title = "Update your list"
        } else {
            addButton.title = "Add"
            title = "Add a list"
        }

        addButton.isEnabled = !listNameTextField.text!.isEmpty
        listNameTextField.addTarget(self,
                                    action: #selector(textFieldDidChange(_:)),
                                    for: UIControl.Event.editingChanged)
    }

    private var privacy: ListPrivacy {
        switch privacySegmentedControl.selectedSegmentIndex {
        case 0: return ListPrivacy.me
        case 1: return ListPrivacy.link
        case 2: return ListPrivacy.friends
        default: return ListPrivacy.all
        }
    }

    private func showLoader() {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        let activityItem = UIBarButtonItem(customView: activityIndicator)
        navigationItem.rightBarButtonItem = activityItem
    }

    @IBAction func add(_ sender: Any) {
        if list != nil {
            updateList()
        } else {
            addList()
        }
    }

    private func updateList() {
        guard let list = list else { return }
        guard let window = view.window else { return }
        window.isUserInteractionEnabled = false
        cancelButton.isEnabled = false
        showLoader()

        TraktAPIProvider.provider.request(.updateList(id: list.identifiers.trakt!,
                                                      name: listNameTextField.text ?? "",
                                                      description: listDescriptionTextField.text ?? "",
                                                      privacy: self.privacy,
                                                      displayNumbers: displayRankSwitch.isOn,
                                                      allowComments: allowCommentsSwitch.isOn),
                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else {
                window.isUserInteractionEnabled = true
                return
            }
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let list = try response.map(List.self, using: TraktAPIProvider.decoder)

                    listUpdatedTransmitter.broadcast(list)

                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "👍 List updated")

                        self.dismiss(animated: true, completion: nil)
                        window.isUserInteractionEnabled = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Error updating", style: .error(error))
                        window.isUserInteractionEnabled = true
                        self.navigationItem.rightBarButtonItem = self.addButton
                        self.cancelButton.isEnabled = true
                    }
                }
            case let .failure(error):
                print("Comment post failed! \(error)")
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Error updating", style: .error(error))
                    window.isUserInteractionEnabled = true
                    self.navigationItem.rightBarButtonItem = self.addButton
                    self.cancelButton.isEnabled = true
                }
            }
        }
    }

    private func addList() {
        guard let window = view.window else { return }
        window.isUserInteractionEnabled = false
        cancelButton.isEnabled = false
        showLoader()

        TraktAPIProvider.provider.request(.createList(name: listNameTextField.text ?? "",
                                                      description: listDescriptionTextField.text ?? "",
                                                      privacy: self.privacy,
                                                      displayNumbers: displayRankSwitch.isOn,
                                                      allowComments: allowCommentsSwitch.isOn),
                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else {
                window.isUserInteractionEnabled = true
                return
            }
            switch result {
            case let .success(moyaResponse):
                do {
                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                    listCreatedTransmitter.broadcast(true)

                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "👍 New list created")

                        self.dismiss(animated: true, completion: nil)
                        window.isUserInteractionEnabled = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Error creating", style: .error(error))
                        window.isUserInteractionEnabled = true
                        self.navigationItem.rightBarButtonItem = self.addButton
                        self.cancelButton.isEnabled = true
                    }
                }
            case let .failure(error):
                print("Comment post failed! \(error)")
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Error creating", style: .error(error))
                    window.isUserInteractionEnabled = true
                    self.navigationItem.rightBarButtonItem = self.addButton
                    self.cancelButton.isEnabled = true
                }
            }
        }
    }

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension ListFormViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            listNameTextField.becomeFirstResponder()
            tableView.deselectRow(at: indexPath, animated: true)
        case 1:
            listDescriptionTextField.becomeFirstResponder()
            tableView.deselectRow(at: indexPath, animated: true)
        default:
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}

extension ListFormViewController {
    @objc func textFieldDidChange(_ textField: UITextField) {
        addButton.isEnabled = !textField.text!.isEmpty
    }
}
