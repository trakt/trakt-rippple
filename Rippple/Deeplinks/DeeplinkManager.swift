//
//  DeeplinkManager.swift
//  Rippple
//
//  Created by Kevin Cador on 29/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Foundation

final class DeeplinkManager {
    static let shared = DeeplinkManager()
    fileprivate init() {}

    private var deeplinkType: DeeplinkType?

    private var isProcessingDeeplink = false

    @discardableResult
    func registerDeeplink(url: URL) -> Bool {
        let deeplinkType = DeeplinkParser.shared.parseDeepLink(url)
        if deeplinkType != self.deeplinkType {
            self.deeplinkType = deeplinkType
        }
        if self.deeplinkType != nil {
            isProcessingDeeplink = false
            return true
        } else {
            return false
        }
    }

    func shouldOpenDeeplink() -> Bool {
        if AppManager.shared.mainAppIsDisplayed == false { return false }
        if isProcessingDeeplink == true { return false }
        if self.deeplinkType != nil {
            isProcessingDeeplink = true
            return true
        } else {
            return false
        }
    }

    func handleDeeplink() -> DeeplinkType? {
        guard let deeplink = deeplinkType else { return nil }

        deeplinkType = nil
        isProcessingDeeplink = false

        return deeplink
    }
}
