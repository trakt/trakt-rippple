//
//  PeopleBioTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 12/01/2019.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class PeopleBioTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var biography: LinkEnabledLabel!

    private let markdownParser: SpoilerMarkdownParser = {
        let parser = SpoilerMarkdownParser(font: UIFont.preferredFont(forTextStyle: .body), color: .secondaryLabel)
        parser.spoilerStrategy = .showAllSpoilers
        return parser
    }()

    var person: Person! {
        didSet {
            biography.attributedText = markdownParser.parse(person.biography ?? "")
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
}
