//
//  CustomTableView.swift
//  Rippple
//
//  Created by Kevin Cador on 02/04/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import UIKit

import Receiver

class CustomTableView: UITableView {

    private let customTableViewDisposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()

        dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")
        dragDelegate = self

        dragEnabledReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")
        }.disposed(by: customTableViewDisposeBag)
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {

        if view is UIControl
            && !(view is UITextInput)
            && !(view is UISlider)
            && !(view is UISwitch) {
            return true
        }

        return super.touchesShouldCancel(in: view)
    }
}

extension CustomTableView: UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell else { return [] }
        guard let media = cell.media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func tableView(_ tableView: UITableView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        guard let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell else { return [] }
        guard let media = cell.media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell else { return nil }
        let poster = cell.poster!

        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: poster.convert(poster.frame, to: cell), cornerRadius: poster.layer.cornerRadius)
        return parameters
    }
}
