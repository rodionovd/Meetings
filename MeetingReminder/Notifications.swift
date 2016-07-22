//
//  Meeting+Notifications.swift
//  MeetingReminder
//
//  Created by Dmitry Rodionov on 22/07/16.
//  Copyright © 2016 Internals Exposed. All rights reserved.
//

import Foundation

/// Adds support for [un]scheduling meeting notifications in Notification Center
extension Meeting {
    /// Each notification is wired to its own meeting by this identifier (thus it's a 1:1 relation)
    var notificationIdentifier: String {
        return self.UUID.UUIDString
    }
    /// Notifications should arrive in advance before a meeting starts
    var notificationDate: NSDate {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        let offset = userDefaults.doubleForKey(Defaults.NotificationOffsetSeconds.rawValue)
        return self.date.dateByAddingTimeInterval(-1 * offset * 60)
    }
    
    /// Creates a new notification and schedules it to be delivered before the meeting starts
    func schedule() {
        // Don't allow to schedule more than one notification per meeting
        guard scheduledNotification() == nil else {
            return
        }
        let notification = NSUserNotification()
        notification.identifier = self.notificationIdentifier
        notification.title = NSLocalizedString("Meeting is coming!", comment: "Meeting notification's title")
        notification.informativeText = NSLocalizedString(NSString(format: "%@", self.title) as String,
                                                         comment: "Meeting notification's informative text template")
        notification.deliveryDate = self.notificationDate
        notification.actionButtonTitle = NSLocalizedString("Open", comment: "Meeting notification's action button title")
        notification.otherButtonTitle = NSLocalizedString("Dismiss", comment: "Meeting notification's other button title")

        let center = NSUserNotificationCenter.defaultUserNotificationCenter()
        center.scheduleNotification(notification)
    }

    /// Removes a scheduled notification from the notification queue
    func unschedule() {
        let center = NSUserNotificationCenter.defaultUserNotificationCenter()
        guard let notification = scheduledNotification() else {
            return
        }
        center.removeScheduledNotification(notification)
    }

    /// Fetches an already scheduled notification for this meeting (if any)
    func scheduledNotification() -> NSUserNotification? {
        let center = NSUserNotificationCenter.defaultUserNotificationCenter()
        let matched = center.scheduledNotifications.filter {
            return $0.identifier == self.notificationIdentifier
        }
        return matched.first
    }
}
