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
    @objc var selectedRows: IndexSet = IndexSet()

    override var windowNibName: String {
        return "MeetingsWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // We're going to handle notifications in a special manner
        NSUserNotificationCenter.default.delegate = self

        // Fetch meetings from data source
        fetchMeetings() {
            self.meetings.append(contentsOf: $0)
            self.tableView.reloadData()
        }

        // Setup dates & co
        let userDefaults = UserDefaults.standard
        let offset = userDefaults.double(forKey: Defaults.DefaultMeetingDateOffset.rawValue)
        dataPicker.dateValue = Date(timeIntervalSinceNow: offset).dateWithZeroedSeconds
        dataPicker.minDate = Date().dateWithZeroedSeconds
    }

    func acceptUserNotification(_ notification: NSUserNotification) {
        // Select a meeting in the list when users clicks on a corresponding notification
        if let idx = meetings.index (where: { $0.notificationIdentifier == notification.identifier }) {
            window?.makeFirstResponder(tableView)
            tableView.selectRowIndexes(IndexSet(integer:idx), byExtendingSelection: false)
        }
    }

    @IBAction func addNewMeeting(_ sender: AnyObject?) {
        let date = dataPicker.dateValue
        let title = (newMeetingTitle as String).trimmed
        
        guard title.characters.count > 0 else {
            return
        }

        let model = Meeting(title: title, date: date)
        model.schedule()

        meetings.insert(model, at: 0)
        saveMeetings(fromArray: meetings)

        tableView.insertRows(at: IndexSet(integer: 0), withAnimation: .effectFade)
        newMeetingField.stringValue = ""
    }

    @IBAction func removeSelectedMeetings(_ sender: AnyObject?) {
        var modelsToRemove: [Meeting] = []
        for (_, idx) in selectedRows.enumerated() {
            let model = meetings[idx]
            model.unschedule()
            modelsToRemove.append(model)
        }
        meetings = meetings.filter {
            !modelsToRemove.contains($0)
        }
        tableView.removeRows(at: selectedRows, withAnimation: .effectFade)

        saveMeetings(fromArray: meetings)
    }

    @IBAction func markMeetingAsStarted(_ sender: AnyObject?) {
        guard let checkbox = sender as? NSButton else {
            return
        }
        let row = tableView.row(for: checkbox)
        guard row >= 0 && row < meetings.count else {
            return
        }

        let oldModel = meetings[row]
        guard let idx = meetings.index(of: oldModel) else {
            fatalError("Race conditions I guess ¯\\_(ツ)_/¯")
        }
        // Remove old model object and unschedule any related notifications
        meetings.remove(at: idx)
        oldModel.unschedule()

        let newModel = oldModel.startedMeeting()
        // Insert the updated model either before the last "started" one...
        let firstStartedIdx = meetings.index { $0.started == true }
        // ... or at the very end of the list (if there're no started meetings yet)
        let insertionIdx = firstStartedIdx ?? meetings.endIndex
        meetings.insert(newModel, at: insertionIdx)
        // and update the table view accordingly
        if (meetings.count == 0) {
            tableView.reloadData()
        } else {
            tableView.moveRow(at: idx, to: insertionIdx)
            tableView.reloadData(forRowIndexes: IndexSet(integer:insertionIdx),
                                              columnIndexes: tableView.columnIndexes)
        }

        saveMeetings(fromArray: meetings)
    }

    // MARK: - NSTableViewDataSource's -

    func numberOfRows(in tableView: NSTableView) -> Int {
        return meetings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        guard row >= 0 && row < meetings.count else {
            fatalError("It must be numberOfRowsInTableView() reporting an incorrent number of rows")
        }
        guard let column = tableColumn else {
            fatalError("Expected a column to work with")
        }

        // We have either a label, a date or a boolean value
        var text: String?
        var date: Date?
        var state: Bool?

        let model = meetings[row]
        // These are hardcoded but, well, they are hardcoded in IB too so why bother at least for now
        switch column.identifier {
        case "DateColumn":
            date = model.date as Date
        case "TitleColumn":
            text = model.title
        case "StartedColumn":
            state = model.started
        default:
            fatalError("Unknown column identifier: \(column.identifier)")
        }

        let cellIdentifier = column.identifier + "Cell"
        guard let view = tableView.make(withIdentifier: cellIdentifier, owner: self) else {
            return nil
        }
        // So we have two default cell views and one custom for checkbox. Probably this peice of code
        // could be beautified a bit but not too much I believe since all these optionals are here to be unwrapped
        if let cellView = view as? CheckboxCellView, let state = state {
            cellView.checkbox.state = state ? NSOnState : NSOffState
            if (state) {
                cellView.checkbox.isEnabled = false
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
                cellView.textField?.textColor = NSColor.disabledControlTextColor
            } else {
                cellView.textField?.textColor = NSColor.controlTextColor
            }
        }

        return view
    }
}

extension MeetingsWindowController: NSUserNotificationCenterDelegate {
    /// Always present notification even when we're the frontmost application
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    /// Select a meeting's row in the table view when user clicks on a related notification 
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        acceptUserNotification(notification)
    }
}

extension String {
    var trimmed: String {
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

extension NSTableView {
    var columnIndexes: IndexSet {
        return IndexSet(integersIn: NSMakeRange(0, self.tableColumns.count).toRange()!)
    }
}

extension Date {
    var dateWithZeroedSeconds: Date {
        let calendar = Calendar.current
        guard let result = (calendar as NSCalendar).date(bySettingUnit: .second, value: 0, of: self, options: .matchFirst) else {
            fatalError("Could not set seconds of the date to zero")
        }
        return result
    }
}
