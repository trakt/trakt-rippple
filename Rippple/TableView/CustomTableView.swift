//
//  CustomTableView.swift
//  Rippple
//
//  Created by Kevin Cador on 02/04/2018.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

class TintedView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .ripppleViewBackground
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .ripppleViewBackground
    }
}

class TintedTableView: UITableView {
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        applyBackground()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        applyBackground()
    }

    fileprivate func applyBackground() {
        backgroundColor = style == .plain ? .ripppleViewBackground : .ripppleGroupedViewBackground
    }
}

final class TintedPlainTableView: TintedTableView {
    override fileprivate func applyBackground() {
        backgroundColor = .ripppleViewBackground
    }
}

final class TintedCollectionView: UICollectionView {
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        backgroundColor = .ripppleViewBackground
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .ripppleViewBackground
    }
}

class TintedCanvasTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        applyBackground()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        applyBackground()
    }

    private func applyBackground() {
        backgroundColor = .ripppleViewBackground
        contentView.backgroundColor = .clear
    }
}

class TintedRowTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        applyBackground()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        applyBackground()
    }

    private func applyBackground() {
        backgroundColor = .ripppleSystemCardBackground
        contentView.backgroundColor = .clear
    }
}

final class TintedTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        applyBackground()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        applyBackground()
    }

    private func applyBackground() {
        backgroundColor = .ripppleGroupedCardBackground
        contentView.backgroundColor = .clear
    }
}

class CustomTableView: TintedTableView {
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
