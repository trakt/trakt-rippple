//
//  String+HTMLDecode.swift
//  Rippple
//
//  Created by Kevin Cador on 06/12/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation

import HTMLEntities

extension String {
    var htmlDecoded: String {
        return htmlUnescape()
    }
}
