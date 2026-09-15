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

class TintedTableViewCell: UITableViewCell {
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

final class TintedSettingsTableViewCell: TintedTableViewCell {
    private var originalTextColor: UIColor?
    private var originalContentTextColor: UIColor?
    private var isTintedTextVisible = false

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = .clear
        self.selectedBackgroundView = selectedBackgroundView

        let multipleSelectionBackgroundView = UIView()
        multipleSelectionBackgroundView.backgroundColor = .clear
        self.multipleSelectionBackgroundView = multipleSelectionBackgroundView
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        updateTextColor()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        updateTextColor()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        restoreTextColor()
        originalTextColor = nil
        originalContentTextColor = nil
    }

    private func updateTextColor() {
        let shouldShowTintedText = isSelected || isHighlighted
        guard shouldShowTintedText != isTintedTextVisible else { return }

        if shouldShowTintedText {
            originalTextColor = textLabel?.textColor
            textLabel?.textColor = UIColor(asset: .globalTint)

            if var content = contentConfiguration as? UIListContentConfiguration {
                originalContentTextColor = content.textProperties.color
                content.textProperties.color = UIColor(asset: .globalTint)
                contentConfiguration = content
            }

            isTintedTextVisible = true
        } else {
            restoreTextColor()
        }
    }

    private func restoreTextColor() {
        guard isTintedTextVisible else { return }

        textLabel?.textColor = originalTextColor
        if var content = contentConfiguration as? UIListContentConfiguration,
           let originalContentTextColor = originalContentTextColor {
            content.textProperties.color = originalContentTextColor
            contentConfiguration = content
        }

        isTintedTextVisible = false
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
        return UIDragItem.mediaItems(from: tableView.cellForRow(at: indexPath) as? MediaDragSource)
    }

    func tableView(_ tableView: UITableView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return UIDragItem.mediaItems(from: tableView.cellForRow(at: indexPath) as? MediaDragSource)
    }

    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell else { return nil }
        let poster = cell.poster!

        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: poster.convert(poster.bounds, to: cell), cornerRadius: poster.layer.cornerRadius)
        return parameters
    }
}

// MARK: - Media drops

final class MediaTableViewDropDelegate: NSObject, UITableViewDropDelegate {
    private let canDrop: () -> Bool
    private let onDrop: ([MediaModel]) -> Void

    init(canDrop: @escaping () -> Bool, onDrop: @escaping ([MediaModel]) -> Void) {
        self.canDrop = canDrop
        self.onDrop = onDrop
        super.init()
    }

    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        guard !tableView.hasActiveDrag else { return false }
        return SessionManager.shared.isLoggedIn && canDrop()
            && !session.items.isEmpty && session.items.allSatisfy { $0.hasMedia }
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        return UITableViewDropProposal(operation: self.tableView(tableView, canHandle: session) ? .copy : .cancel)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard self.tableView(tableView, canHandle: coordinator.session),
              coordinator.items.allSatisfy({ $0.sourceIndexPath == nil }) else { return }
        let userSlug = UserManager.shared.currentUser?.slug
        UIDragItem.loadMedia(from: coordinator.items.map { $0.dragItem }) { [weak self] result in
            guard let self = self else { return }
            guard SessionManager.shared.isLoggedIn,
                  UserManager.shared.currentUser?.slug == userSlug,
                  self.canDrop() else { return }
            switch result {
            case .success(let models):
                guard !models.isEmpty else { return }
                self.onDrop(models)
            case .failure(let error):
                SwiftMessages.show(message: "Could not load dropped media", style: .error(error))
            }
        }
    }
}
