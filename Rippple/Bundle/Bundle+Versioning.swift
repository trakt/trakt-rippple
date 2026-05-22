//
//  Bundle+Versioning.swift
//  Rippple
//
//  Created by Kevin Cador on 22/12/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}
