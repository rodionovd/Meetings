//
//  Meeting.swift
//  MeetingReminder
//
//  Created by Dmitry Rodionov on 22/07/16.
//  Copyright © 2016 Internals Exposed. All rights reserved.
//

import Foundation

/// A simple structure that represents a single meeting event. It has a title and an assigned date.
/// Each meeting is unique in terms of identifiers: NSUUID is used to link meetings and their
/// notifications together.
struct Meeting {
    let title: String
    let date: Date
    let started: Bool
    let UUID: Foundation.UUID

    init(title: String, date: Date) {
        self.title = title
        self.date = date
        self.started = false
        self.UUID = Foundation.UUID()
    }

    init(title: String, date: Date, started: Bool, UUID: Foundation.UUID) {
        self.title = title
        self.date = date
        self.started = started
        self.UUID = UUID
    }

    func startedMeeting() -> Meeting {
        return Meeting(title: title, date: date, started: true, UUID: UUID)
    }
}

extension Meeting: Equatable {}

func ==(lhs: Meeting, rhs: Meeting) -> Bool {
    return (lhs.UUID as NSUUID).isEqual(to: rhs.UUID) && lhs.title == rhs.title && lhs.date == rhs.date &&
        lhs.started == rhs.started
}
