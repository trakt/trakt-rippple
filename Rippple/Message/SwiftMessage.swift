//
//  SwiftMessage.swift
//  Rippple
//
//  Created by Kevin Cador on 11/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import UIKit

final class RipppleBannerMessage: UIView {
    @IBOutlet var message: UILabel!
    @IBOutlet var pillView: UIView!
    @IBOutlet var subtext: UILabel!

    private let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let dateFormatter = RelativeDateTimeFormatter()
        dateFormatter.unitsStyle = .abbreviated
        dateFormatter.dateTimeStyle = .named
        dateFormatter.formattingContext = .standalone
        return dateFormatter
    }()

    private var timer: Timer?

    var date: Date? {
        didSet {
            if let date = date {
                AppManager.shared.isUserInteractionEnabledWithLayer = false
                subtext.text = "Retrying \(relativeDateTimeFormatter.localizedString(for: date, relativeTo: Date()))"
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    if date < Date.now {
                        self.timer?.invalidate()
                        AppManager.shared.isUserInteractionEnabledWithLayer = true
                        return
                    }
                    AppManager.shared.isUserInteractionEnabledWithLayer = false
                    self.subtext.text = "Retrying \(self.relativeDateTimeFormatter.localizedString(for: date, relativeTo: Date()))"
                }
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        pillView.layer.cornerCurve = .circular
        pillView.layer.shadowColor = UIColor.darkGray.cgColor
        pillView.layer.shadowOffset = CGSize(width: 0, height: 0)
        pillView.layer.shadowRadius = 2
        pillView.layer.shadowOpacity = 0.2
        pillView.layer.cornerRadius = pillView.bounds.size.height / 2.0
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        pillView.layer.cornerRadius = pillView.bounds.size.height / 2.0
    }
}
