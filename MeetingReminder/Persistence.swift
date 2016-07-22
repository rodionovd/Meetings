//
//  Persistance.swift
//  MeetingReminder
//
//  Created by Dmitry Rodionov on 22/07/16.
//  Copyright © 2016 Internals Exposed. All rights reserved.
//

import Foundation

/// This file contains a dummy implementation of this app's persistence stack. In a real-word scenario
/// one should probably use CoreData or any other proper solution instead of User Defaults used here for simplicity.

enum Defaults: String {
    case Meetings = "MeetingsKey"
    case NotificationOffsetSeconds = "NotificationOffsetSecondsKey"
    case DefaultMeetingDateOffset = "DefaultMeetingDateOffsetKey"
}

/// Fetches all meetings from User Defaults asynchronously
func fetchMeetings(completion: ([Meeting] -> Void)) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        guard let rawMeetings = userDefaults.arrayForKey(Defaults.Meetings.rawValue) as? [[String:AnyObject]] else {
            dispatch_async(dispatch_get_main_queue()) {
                completion([])
            }
            return
        }
        dispatch_async(dispatch_get_main_queue()) {
            completion(rawMeetings.map({
                return Meeting(dictionary: $0)
            }))
        }
    }
}

/// Saves all meetings into User Defaults asynchronously
func saveMeetings(fromArray meetings:[Meeting]) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
        let serializedMeetings  = meetings.map {
            return $0.dictionaryRepresentation()
        }
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(serializedMeetings, forKey: Defaults.Meetings.rawValue)
    }
}


/// [De]serialization
extension Meeting {

    init(dictionary: [String:AnyObject]) {
        precondition(dictionary["title"] != nil)
        precondition(dictionary["date"] != nil)
        precondition(dictionary["started"] != nil)
        precondition(dictionary["uuid"] != nil)

        guard let aTitle = dictionary["title"] as? String else {
            fatalError("Missing or invalid `title` key")
        }
        self.title = aTitle
        guard let aDate = dictionary["date"] as? NSDate else {
            fatalError("Missing or invalid `date` key")
        }
        self.date = aDate
        guard let aStarted = dictionary["started"] as? NSNumber else {
            fatalError("Missing or invalid `started` key")
        }
        self.started = aStarted.boolValue
        guard let aUUIDString = dictionary["uuid"] as? String, aUUID = NSUUID(UUIDString: aUUIDString) else {
            fatalError("Missing or invalid `uuid` key")
        }
        self.UUID = aUUID
    }

    func dictionaryRepresentation() -> [String:AnyObject] {
        return [
            "title": title,
            "date": date,
            "started": NSNumber(bool: started),
            "uuid": UUID.UUIDString
        ]
    }
}
