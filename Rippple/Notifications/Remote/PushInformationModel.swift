//
//  PushInformationModel.swift
//  Rippple
//
//  Created by Kevin Cador on 25/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import AWSDynamoDB
import Foundation

final class PushInformationModel: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var traktId: String?
    @objc var enpointARN: String?
    @objc var environement: String?
    @objc var premium: String?

    @objc var commentNewLikes: NSNumber?
    @objc var commentNewReply: NSNumber?
    @objc var commentNewMention: NSNumber?
    @objc var activityNewFollower: NSNumber?

    static func dynamoDBTableName() -> String {
        return "Rippple"
    }

    static func hashKeyAttribute() -> String {
        return "enpointARN"
    }
}
