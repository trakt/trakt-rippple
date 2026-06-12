//
//  PushInformationModel.swift
//  Rippple
//
//  Created by Kevin Cador on 25/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Foundation

struct PushInformationModel: Codable {
    let traktId: String
    let enpointARN: String
    let environement: String
    let premium: String

    let commentNewLikes: Bool
    let commentNewReply: Bool
    let commentNewMention: Bool
    let activityNewFollower: Bool
}
