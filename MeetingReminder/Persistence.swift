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
func fetchMeetings(_ completion: @escaping (([Meeting]) -> Void)) {
    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
        let userDefaults = UserDefaults.standard
        guard let rawMeetings = userDefaults.array(forKey: Defaults.Meetings.rawValue) as? [[String:AnyObject]] else {
            DispatchQueue.main.async {
                completion([])
            }
            return
        }
        DispatchQueue.main.async {
            completion(rawMeetings.map({
                return Meeting(dictionary: $0)
            }))
        }
    }
}

/// Saves all meetings into User Defaults asynchronously
func saveMeetings(fromArray meetings:[Meeting]) {
    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
        let serializedMeetings  = meetings.map {
            return $0.dictionaryRepresentation()
        }
        let userDefaults = UserDefaults.standard
        userDefaults.set(serializedMeetings, forKey: Defaults.Meetings.rawValue)
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
        guard let aDate = dictionary["date"] as? Date else {
            fatalError("Missing or invalid `date` key")
        }
        self.date = aDate
        guard let aStarted = dictionary["started"] as? NSNumber else {
            fatalError("Missing or invalid `started` key")
        }
        self.started = aStarted.boolValue
        guard let aUUIDString = dictionary["uuid"] as? String, let aUUID = Foundation.UUID(uuidString: aUUIDString) else {
            fatalError("Missing or invalid `uuid` key")
        }
        self.UUID = aUUID
    }

    func dictionaryRepresentation() -> [String:AnyObject] {
        return [
            "title": title as AnyObject,
            "date": date as AnyObject,
            "started": NSNumber(value: started as Bool),
            "uuid": UUID.uuidString as AnyObject
        ]
    }
}
