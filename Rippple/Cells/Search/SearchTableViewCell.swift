//
//  SearchTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 12/08/2020.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class SearchTableViewCell: TintedCanvasTableViewCell {
    private var text: String!
    private var subtext: String?
    private var searchQuery: String?
    func setup(with text: String, and subtext: String? = nil, searchQuery: String? = nil) {
        self.text = text
        self.subtext = subtext
        self.searchQuery = searchQuery

        renderLabel(with: nil)
    }

    private func renderLabel(with color: UIColor?) {
        title.textColor = color ?? .label
        if let subtext = subtext {
            let attributedString = NSMutableAttributedString(string: text + subtext)
            attributedString.addAttribute(.foregroundColor,
                                          value: color?.withAlphaComponent(0.7) ?? .secondaryLabel,
                                          range: (attributedString.string as NSString).range(of: subtext))
            if let searchQuery = searchQuery {
                attributedString.addAttribute(.font,
                                              value: UIFont(descriptor: title.font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: title.font.pointSize),
                                              range: (attributedString.string as NSString).range(of: searchQuery, options: .caseInsensitive))
                attributedString.addAttribute(.underlineStyle,
                                              value: NSUnderlineStyle.single.rawValue,
                                              range: (attributedString.string as NSString).range(of: searchQuery, options: .caseInsensitive))
                for query in searchQuery.split(separator: " ").map({ String($0) }) {
                    var searchRange = NSRange(location: 0, length: text.count)
                    var foundRange = NSRange()
                    while searchRange.location < text.count {
                        searchRange.length = text.count - searchRange.location
                        foundRange = (text as NSString).range(of: query, options: NSString.CompareOptions.caseInsensitive, range: searchRange)
                        if foundRange.location != NSNotFound {
                            attributedString.addAttribute(.font,
                                                          value: UIFont(descriptor: title.font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: title.font.pointSize),
                                                          range: foundRange)
                            attributedString.addAttribute(.underlineStyle,
                                                          value: NSUnderlineStyle.single.rawValue,
                                                          range: foundRange)

                            searchRange.location = foundRange.location + foundRange.length
                        } else {
                            break
                        }
                    }
                }
            }
            title.attributedText = attributedString
        } else {
            title.text = text
        }
    }

    @IBOutlet var title: UILabel!

    @IBOutlet var card: CardView!
    @IBOutlet var activity: UIActivityIndicatorView!
    @IBOutlet var chevron: UIView!

    var shouldShowActivityIndicator = false

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            renderLabel(with: UIColor(asset: .globalTint))
            activity.isHidden = !shouldShowActivityIndicator
            activity.startAnimating()
        } else {
            renderLabel(with: nil)
            activity.isHidden = true
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            renderLabel(with: UIColor(asset: .globalTint))
            activity.isHidden = !shouldShowActivityIndicator
            activity.startAnimating()
        } else {
            renderLabel(with: nil)
            activity.isHidden = true
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = .clear
        backgroundColor = .clear

        activity.isHidden = true
        chevron.isHidden = false
    }
}

final class SearchHeaderView: UITableViewHeaderFooterView {
    @IBOutlet var title: UILabel!
    @IBOutlet var button: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = .clear
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)

        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = .ripppleViewBackground
        backgroundConfiguration = background

        maximumContentSizeCategory = .extraExtraLarge
    }
}
