//
//  AppDelegate.swift
//  MeetingReminder
//
//  Created by Dmitry Rodionov on 21/07/16.
//  Copyright © 2016 Internals Exposed. All rights reserved.
//

import Cocoa
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var meetingsWindowController: MeetingsWindowController?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Register Defaults
        let userDefaults = NSUserDefaults.standardUserDefaults()
        if let defaultsURL = NSBundle.mainBundle().URLForResource("Defaults", withExtension: "plist"),
            let dictionary = NSDictionary(contentsOfURL:defaultsURL) as? [String:AnyObject]
        {
            userDefaults.registerDefaults(dictionary)
        }
        // Create a main window controller
        meetingsWindowController = MeetingsWindowController()
        meetingsWindowController?.showWindow(self)
        // Maybe we were launched from a user notification?
        let userNotificationMaybe = aNotification.userInfo?[NSApplicationLaunchUserNotificationKey]
        if let notification = userNotificationMaybe as? NSUserNotification {
            meetingsWindowController?.acceptUserNotification(notification)
        }
    }
}

