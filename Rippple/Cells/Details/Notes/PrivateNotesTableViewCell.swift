//
//  PrivateNotesTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 25/09/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import Receiver

final class PrivateNotesTableViewCell: UITableViewCell {

    @IBOutlet weak var notes: NotesLabel!

    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            updateText()
        }
    }

    var person: Person? {
        didSet {
            updateText()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onNotesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.updateText()
        }.disposed(by: disposeBag)
    }

    private func updateText() {
        if let media = media {
            let noteItem = media.noteItem
            notes.noteItem = noteItem
        } else if let person = person {
            let noteItem = person.noteItem
            notes.noteItem = noteItem
        }
    }
}
