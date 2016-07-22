//
//  MeetingsWindowController.swift
//  MeetingReminder
//
//  Created by Dmitry Rodionov on 22/07/16.
//  Copyright © 2016 Internals Exposed. All rights reserved.
//

import Cocoa

class MeetingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    var meetings: [Meeting] = []
    // Outlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var dataPicker: NSDatePicker!
    @IBOutlet weak var newMeetingField: NSTextField!
    // Bindings
    @objc var newMeetingTitle: NSString = ""
    @objc var selectedRows: NSIndexSet = NSIndexSet()

    override var windowNibName: String {
        return "MeetingsWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // We're going to handle notifications in a special manner
        NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self

        // Fetch meetings from data source
        fetchMeetings() {
            self.meetings.appendContentsOf($0)
            self.tableView.reloadData()
        }

        // Setup dates & co
        let userDefaults = NSUserDefaults.standardUserDefaults()
        let offset = userDefaults.doubleForKey(Defaults.DefaultMeetingDateOffset.rawValue)
        dataPicker.dateValue = NSDate(timeIntervalSinceNow: offset).dateWithZeroedSeconds
        dataPicker.minDate = NSDate().dateWithZeroedSeconds
    }

    func acceptUserNotification(notification: NSUserNotification) {
        // Select a meeting in the list when users clicks on a corresponding notification
        if let idx = meetings.indexOf ({ return $0.notificationIdentifier == notification.identifier }) {
            window?.makeFirstResponder(tableView)
            tableView.selectRowIndexes(NSIndexSet(index:idx), byExtendingSelection: false)
        }
    }

    @IBAction func addNewMeeting(sender: AnyObject?) {
        let date = dataPicker.dateValue
        let title = (newMeetingTitle as String).trimmed
        
        guard title.characters.count > 0 else {
            return
        }

        let model = Meeting(title: title, date: date)
        model.schedule()

        meetings.insert(model, atIndex: 0)
        saveMeetings(fromArray: meetings)

        tableView.insertRowsAtIndexes(NSIndexSet(index: 0), withAnimation: .EffectFade)
        newMeetingField.stringValue = ""
    }

    @IBAction func removeSelectedMeetings(sender: AnyObject?) {
        var modelsToRemove: [Meeting] = []
        for (_, idx) in selectedRows.enumerate() {
            let model = meetings[idx]
            model.unschedule()
            modelsToRemove.append(model)
        }
        meetings = meetings.filter {
            !modelsToRemove.contains($0)
        }
        tableView.removeRowsAtIndexes(selectedRows, withAnimation: .EffectFade)

        saveMeetings(fromArray: meetings)
    }

    @IBAction func markMeetingAsStarted(sender: AnyObject?) {
        guard let checkbox = sender as? NSButton else {
            return
        }
        let row = tableView.rowForView(checkbox)
        guard row >= 0 && row < meetings.count else {
            return
        }

        let oldModel = meetings[row]
        guard let idx = meetings.indexOf(oldModel) else {
            fatalError("Race conditions I guess ¯\\_(ツ)_/¯")
        }
        // Remove old model object and unschedule any related notifications
        meetings.removeAtIndex(idx)
        oldModel.unschedule()

        let newModel = oldModel.startedMeeting()
        // Insert the updated model either before the last "started" one...
        let firstStartedIdx = meetings.indexOf { (meeting) -> Bool in
            return meeting.started
        }
        // ... or at the very end of the list (if there're no started meetings yet)
        let insertionIdx = firstStartedIdx ?? meetings.endIndex
        meetings.insert(newModel, atIndex: insertionIdx)
        // and update the table view accordingly
        if (meetings.count == 0) {
            tableView.reloadData()
        } else {
            tableView.moveRowAtIndex(idx, toIndex: insertionIdx)
            tableView.reloadDataForRowIndexes(NSIndexSet(index:insertionIdx),
                                              columnIndexes: tableView.columnIndexes)
        }

        saveMeetings(fromArray: meetings)
    }

    // MARK: - NSTableViewDataSource's -

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return meetings.count
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {

        guard row >= 0 && row < meetings.count else {
            fatalError("It must be numberOfRowsInTableView() reporting an incorrent number of rows")
        }
        guard let column = tableColumn else {
            fatalError("Expected a column to work with")
        }

        // We have either a label, a date or a boolean value
        var text: String?
        var date: NSDate?
        var state: Bool?

        let model = meetings[row]
        // These are hardcoded but, well, they are hardcoded in IB too so why bother at least for now
        switch column.identifier {
        case "DateColumn":
            date = model.date
        case "TitleColumn":
            text = model.title
        case "StartedColumn":
            state = model.started
        default:
            fatalError("Unknown column identifier: \(column.identifier)")
        }

        let cellIdentifier = column.identifier + "Cell"
        guard let view = tableView.makeViewWithIdentifier(cellIdentifier, owner: self) else {
            return nil
        }
        // So we have two default cell views and one custom for checkbox. Probably this peice of code
        // could be beautified a bit but not too much I believe since all these optionals are here to be unwrapped
        if let cellView = view as? CheckboxCellView, state = state {
            cellView.checkbox.state = state ? NSOnState : NSOffState
            if (state) {
                cellView.checkbox.enabled = false
            }
        } else if let cellView = view as? NSTableCellView {
            if let text = text {
                cellView.textField?.stringValue = text
            } else if let date = date {
                // Let this text field's NSDateFormatter do its job
                cellView.textField?.objectValue = date
            }
            // "Disable" meetings that have been started already 
            if (model.started) {
                cellView.textField?.textColor = NSColor.disabledControlTextColor()
            } else {
                cellView.textField?.textColor = NSColor.controlTextColor()
            }
        }

        return view
    }
}

extension MeetingsWindowController: NSUserNotificationCenterDelegate {
    /// Always present notification even when we're the frontmost application
    func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool {
        return true
    }
    /// Immidiately remove the delivered notification from the notification center
    func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
        acceptUserNotification(notification)
    }
}

extension String {
    var trimmed: String {
        return self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }
}

extension NSTableView {
    var columnIndexes: NSIndexSet {
        return NSIndexSet(indexesInRange: NSMakeRange(0, self.tableColumns.count))
    }
}

extension NSDate {
    var dateWithZeroedSeconds: NSDate {
        let calendar = NSCalendar.currentCalendar()
        guard let result = calendar.dateBySettingUnit(.Second, value: 0, ofDate: self, options: .MatchFirst) else {
            fatalError("Could not set seconds of the date to zero")
        }
        return result
    }
}
