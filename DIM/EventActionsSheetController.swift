/*
this was gnenerated by Sonnet 4.6 with > 10 iterations. some hand tweeking.
*/
// EventActionsSheetController.swift
//
// Two-pane modal sheet (Option D). Entire view built in code; no IB outlets or
// prototype cells needed. Add one View Controller scene in Main.storyboard with
// Class = EventActionsSheetController and Storyboard ID = EventActionsSheet.
//
// Usage:
//   let vc = storyboard.instantiateController(withIdentifier: "EventActionsSheet")
//            as! EventActionsSheetController
//   vc.options        = [String: String]          // short-code → display label
//   vc.commands       = [String]                  // available commands
//   vc.commandHasName = [Bool]                    // parallel: does command take a name?
//   vc.allNames       = [String]                  // available names; "<current>" = none
//   vc.completion     = { result in ... }         // nil if cancelled
//   presentAsSheet(vc)
//
// Result: [String: (Double, [String])]  key=option, Double=delay, [String]=args
// Commands are saved with "--" prefix; "<current>" name is omitted from storage.

import Cocoa

// MARK: - Data types

/// One row in the command list: a chosen command and (optionally) a chosen name.
struct CommandEntry {
    var command: String   // element of `commands`
    var name:    String   // element of `allNames`; "" when commandHasName is false
}

private struct EventState {
    var enabled: Bool
    var delay:   Double
    var entries: [CommandEntry]
}

// MARK: - Controller

final class EventActionsSheetController: NSViewController {

    // MARK: Inputs — set before presentAsSheet
    var options:        [String: String] = [:]
    var commands:       [String]         = []
    var commandHasName: [Bool]           = []  // parallel to commands
    var allNames:       [String]         = []  // includes "<current>"
    var completion: (([String: (Double, [String])])?) -> Void = { _ in }

    // MARK: Views
    private var eventTableView: NSTableView!
    private var splitView:        NSSplitView!
    private var rightPane:        NSView!
    private var noSelLabel:       NSTextField!
    private var detailView:       NSView!      // shown when a row is selected
    private var enableCheckbox:   NSButton!
    private var delayField:       NSTextField!
    private var commandTableView: NSTableView!
    private var cmdScrollView:    NSScrollView!
    private var addButton:        NSButton!

    private var cancelButton: NSButton!
    private var saveButton:   NSButton!

    // MARK: State
    var sortedKeys:  [String] = []  // don't sort the keys, feed it in directly so we can specify order in list
    private var states:      [String: EventState] = [:]
    private var selectedKey: String?

    private let udKey = "helperData"

    // MARK: Layout
    private enum K {
        static let W:       CGFloat = 660
        static let H:       CGFloat = 460
        static let leftW:   CGFloat = 170
        static let pad:     CGFloat = 16
        static let rowH:    CGFloat = 28
        static let cmdRowH: CGFloat = 32
        static let fieldH:  CGFloat = 22
    }

    private weak var leftScrollView: NSScrollView?

    // MARK: - View construction

    override func loadView() {
        // Root view uses a fixed frame; the sheet presenter sizes it from preferredContentSize.
        let root = NSView(frame: NSRect(x: 0, y: 0, width: K.W, height: K.H))

        let title = label("Event Actions:", size: 14, bold: true) // tweek
        root.addSubview(title)

        cancelButton = roundedButton("Cancel", action: #selector(cancelAction))
        cancelButton.keyEquivalent = "\u{1B}"

        saveButton = roundedButton("Save", action: #selector(saveAction))
        root.addSubview(cancelButton)
        root.addSubview(saveButton)

        splitView = NSSplitView()
        splitView.isVertical   = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = NSSplitView.AutosaveName("EventActionsSplit")
        splitView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(splitView)

        let leftScroll = NSScrollView()
        leftScroll.hasVerticalScroller = true
        leftScroll.autohidesScrollers  = true
        leftScroll.borderType          = .noBorder
        leftScroll.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(leftScroll)
        leftScrollView = leftScroll

        rightPane = NSView()
        rightPane.translatesAutoresizingMaskIntoConstraints = false
        buildRightPane()
        splitView.addArrangedSubview(rightPane)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: K.pad),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: K.pad),

            saveButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -K.pad),
            saveButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: saveButton.bottomAnchor),

            splitView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            splitView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -12),

    
            leftScroll.widthAnchor.constraint(equalToConstant: K.leftW),
        ])

        self.view = root
        preferredContentSize = NSSize(width: K.W, height: K.H)
    }

    private func buildRightPane() {
        noSelLabel = label("← Select an event", size: 13, bold: false)
        noSelLabel.textColor = .secondaryLabelColor
        rightPane.addSubview(noSelLabel)

        detailView = NSView()
        detailView.translatesAutoresizingMaskIntoConstraints = false
        detailView.isHidden = true
        rightPane.addSubview(detailView)
        buildDetailView()

        NSLayoutConstraint.activate([
            noSelLabel.centerXAnchor.constraint(equalTo: rightPane.centerXAnchor),
            noSelLabel.centerYAnchor.constraint(equalTo: rightPane.centerYAnchor),

            detailView.topAnchor.constraint(equalTo: rightPane.topAnchor),
            detailView.leadingAnchor.constraint(equalTo: rightPane.leadingAnchor),
            detailView.trailingAnchor.constraint(equalTo: rightPane.trailingAnchor),
            detailView.bottomAnchor.constraint(equalTo: rightPane.bottomAnchor),
        ])
    }

    private func buildDetailView() {
        let p = K.pad

        enableCheckbox = NSButton(checkboxWithTitle: "Enable this event",
                                  target: self, action: #selector(enableChanged))
        enableCheckbox.translatesAutoresizingMaskIntoConstraints = false
        detailView.addSubview(enableCheckbox)

        let delayLbl = label("Delay (seconds):", size: 13, bold: false)
        detailView.addSubview(delayLbl)

        delayField = NSTextField()
        delayField.placeholderString = "1.5"
        delayField.translatesAutoresizingMaskIntoConstraints = false
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimum = 0
        fmt.maximumFractionDigits = 2
        delayField.formatter = fmt
        detailView.addSubview(delayField)

        let cmdLbl = label("Actions:", size: 13, bold: false)
        detailView.addSubview(cmdLbl)

        commandTableView = NSTableView()
        commandTableView.headerView = nil
        commandTableView.selectionHighlightStyle = .none
        commandTableView.allowsEmptySelection    = true
        commandTableView.intercellSpacing        = NSSize(width: 0, height: 2)
        commandTableView.dataSource = self
        commandTableView.delegate   = self
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cmdRow"))
        col.resizingMask = .autoresizingMask
        commandTableView.addTableColumn(col)

        cmdScrollView = NSScrollView()
        cmdScrollView.documentView        = commandTableView
        cmdScrollView.hasVerticalScroller = true
        cmdScrollView.autohidesScrollers  = true
        cmdScrollView.borderType          = .bezelBorder
        cmdScrollView.translatesAutoresizingMaskIntoConstraints = false
        detailView.addSubview(cmdScrollView)

        addButton = roundedButton("＋  Add Command", action: #selector(addCommandAction))
        detailView.addSubview(addButton)

        NSLayoutConstraint.activate([
            enableCheckbox.topAnchor.constraint(equalTo: detailView.topAnchor, constant: p),
            enableCheckbox.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),

            delayLbl.topAnchor.constraint(equalTo: enableCheckbox.bottomAnchor, constant: p),
            delayLbl.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            delayLbl.centerYAnchor.constraint(equalTo: delayField.centerYAnchor),

            delayField.topAnchor.constraint(equalTo: delayLbl.topAnchor),
            delayField.leadingAnchor.constraint(equalTo: delayLbl.trailingAnchor, constant: 8),
            delayField.widthAnchor.constraint(equalToConstant: 72),
            delayField.heightAnchor.constraint(equalToConstant: K.fieldH),

            cmdLbl.topAnchor.constraint(equalTo: delayField.bottomAnchor, constant: p),
            cmdLbl.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),

            cmdScrollView.topAnchor.constraint(equalTo: cmdLbl.bottomAnchor, constant: 6),
            cmdScrollView.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            cmdScrollView.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -p),
            cmdScrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),

            addButton.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            addButton.bottomAnchor.constraint(equalTo: detailView.bottomAnchor, constant: -p),
        ])
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // If the IB outlet is missing, build a programmatic eventTableView as fallback.
        if eventTableView == nil {
            let tv = NSTableView()
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("eventCol"))
            col.resizingMask = .autoresizingMask
            tv.addTableColumn(col)
            eventTableView = tv
        }

        // Embed eventTableView into the left scroll view built in loadView().
        if let scroll = leftScrollView {
            eventTableView.dataSource = self
            eventTableView.delegate   = self
            eventTableView.headerView = nil
            eventTableView.selectionHighlightStyle = .regular
            eventTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
            eventTableView.tableColumns.first?.resizingMask = .autoresizingMask
            scroll.documentView = eventTableView
        }

        delayField.delegate = self

        // Set the left-pane width explicitly — NSSplitView autosave can
        // restore a stale zero-width position on first launch.
        splitView.setPosition(K.leftW, ofDividerAt: 0)

        loadFromUserDefaults()
        eventTableView.reloadData()
        showNoSelection()

        if !sortedKeys.isEmpty {
            eventTableView.selectRowIndexes(IndexSet(integer: 0),
                                             byExtendingSelection: false)
            selectEvent(at: 0)
        }
    }

    // MARK: - Data

    private func loadFromUserDefaults() {
        let defaults = UserDefaults(suiteName: bDIM.gUD)!
        var saved: [String: (Double, [String])] = [:]
        if defaults.object(forKey: udKey) != nil {  // special case for first time...
            let rawData  = defaults.dictionary(forKey: udKey) ?? [:]
            for (key, value) in rawData {
                if let entry = value as? [Any],
                   let delay = entry.first as? Double,
                   let args  = entry.last  as? [String] {
                    saved[key] = (delay, args)
                }
            }
        } else {    // otherwise default
            if saved.isEmpty { saved = [  "wake": (3.0, ["--restore", "--quit"]),
                                          "change": (1.5, ["--restore", "--quit"]),
                                          "startup": (0.0, ["--restore", "--quit"])]
            }
        }
        for key in sortedKeys {
            if let (delay, args) = saved[key] {
                states[key] = EventState(enabled: true,
                                         delay: delay,
                                         entries: parseArgs(args))
            } else {
                states[key] = EventState(enabled: false, delay: 1.5, entries: [])
            }
        }
    }

    private func parseArgs(_ args: [String]) -> [CommandEntry] {
        var result: [CommandEntry] = []
        var i = 0
        while i < args.count {
            // Commands are stored with a "--" prefix; strip it to get the bare command.
            let raw = args[i]; i += 1
            let cmd = raw.hasPrefix("--") ? String(raw.dropFirst(2)) : raw
            let idx = commands.firstIndex(of: cmd)
            let hasName = idx.map { commandHasName[$0] } ?? false
            var name: String
            if hasName, i < args.count, !args[i].hasPrefix("--") {
                // Next token is a name (not another command).
                name = args[i]; i += 1
            } else if hasName {
                // Command accepts a name but none was stored — show "<current>".
                name = "<current>"
            } else {
                name = ""
            }
            result.append(CommandEntry(command: cmd, name: name))
        }
        return result
    }

    private func serialiseEntries(_ entries: [CommandEntry]) -> [String] {
        var out: [String] = []
        for e in entries {
            // Commands are stored with a "--" prefix.
            out.append("--" + e.command)
            let idx = commands.firstIndex(of: e.command)
            if idx.map({ commandHasName[$0] }) == true {
                let name = e.name.isEmpty ? "<current>" : e.name
                // "<current>" means no name — omit it from storage.
                if name != "<current>" {
                    out.append(name)
                }
            }
        }
        return out
    }

    // MARK: - Selection

    private func showNoSelection() {
        noSelLabel.isHidden  = false
        detailView.isHidden  = true
        selectedKey = nil
    }

    private func selectEvent(at row: Int) {
        guard row >= 0, row < sortedKeys.count else { showNoSelection(); return }
        // Reload the previously selected row first so it loses bold/blue styling.
        if let oldKey = selectedKey, let oldRow = sortedKeys.firstIndex(of: oldKey) {
            selectedKey = nil
            eventTableView?.reloadData(forRowIndexes: IndexSet(integer: oldRow),
                                       columnIndexes: IndexSet(integer: 0))
        }
        selectedKey = sortedKeys[row]
        refreshDetail()
    }

    private func refreshDetail() {
        guard let key = selectedKey, let state = states[key] else {
            showNoSelection(); return
        }
        noSelLabel.isHidden  = true
        detailView.isHidden  = false

        enableCheckbox.state       = state.enabled ? .on : .off
        delayField.stringValue     = String(format: "%.1f", state.delay)
        delayField.isEnabled       = state.enabled
        addButton.isEnabled        = state.enabled
        commandTableView.isEnabled = state.enabled
        commandTableView.reloadData()

        // Update label colour in left pane
        if let row = sortedKeys.firstIndex(of: key) {
            eventTableView?.reloadData(forRowIndexes: IndexSet(integer: row),
                                       columnIndexes: IndexSet(integer: 0))
        }
    }

    private func commitDelayField() {
        guard let key = selectedKey else { return }
        let v = (delayField.formatter as? NumberFormatter)?
                    .number(from: delayField.stringValue)?.doubleValue
                ?? Double(delayField.stringValue)
                ?? states[key]?.delay ?? 0
        states[key]?.delay = max(0, v)
    }

    // MARK: - Actions

    @objc private func enableChanged(_ sender: NSButton) {
        guard let key = selectedKey else { return }
        states[key]?.enabled = (sender.state == .on)
        refreshDetail()
    }

    @objc private func addCommandAction() {
        guard let key = selectedKey, let firstCmd = commands.first else { return }
        let hasName     = commandHasName.first ?? false
        let defaultName = hasName ? (allNames.first ?? "<current>") : ""
        states[key]?.entries.append(CommandEntry(command: firstCmd, name: defaultName))
        commandTableView.reloadData()
    }

    @objc private func removeCommandRow(_ sender: NSButton) {
        guard let key = selectedKey else { return }
        let row = sender.tag
        guard row < (states[key]?.entries.count ?? 0) else { return }
        states[key]?.entries.remove(at: row)
        commandTableView.reloadData()
    }

    @objc private func commandPopUpChanged(_ sender: NSPopUpButton) {
        guard let key = selectedKey else { return }
        let row    = sender.tag
        guard row < (states[key]?.entries.count ?? 0) else { return }
        let newCmd  = sender.titleOfSelectedItem ?? commands.first ?? ""
        let idx     = commands.firstIndex(of: newCmd)
        let hasName = idx.map { commandHasName[$0] } ?? false
        states[key]?.entries[row].command = newCmd
        states[key]?.entries[row].name    = hasName ? (allNames.first ?? "<current>") : ""
        commandTableView.reloadData(forRowIndexes: IndexSet(integer: row),
                                    columnIndexes: IndexSet(integer: 0))
    }

    @objc private func namePopUpChanged(_ sender: NSPopUpButton) {
        guard let key = selectedKey else { return }
        let row = sender.tag
        guard row < (states[key]?.entries.count ?? 0) else { return }
        states[key]?.entries[row].name = sender.titleOfSelectedItem ?? ""
    }

    @objc private func cancelAction() {
        dismiss(self)
        completion(nil)
    }

    @objc private func saveAction() {
        commitDelayField()
        var result: [String: (Double, [String])] = [:]
        for key in sortedKeys {
            guard let s = states[key], s.enabled else { continue }
            result[key] = (s.delay, serialiseEntries(s.entries))
        }
        let defaults = UserDefaults(suiteName: bDIM.gUD)!
        var raw: [String: Any] = [:]
        for (key, (delay, args)) in result { raw[key] = [delay, args] as [Any] }
        defaults.set(raw, forKey: udKey)
        defaults.synchronize()
        dismiss(self)
        completion(result)
    }

    // MARK: - View helpers

    private func label(_ text: String, size: CGFloat, bold: Bool) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }

    private func roundedButton(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }
}

// MARK: - NSTableViewDataSource

extension EventActionsSheetController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === eventTableView   { return sortedKeys.count }
        if tableView === commandTableView {
            return selectedKey.flatMap { states[$0]?.entries.count } ?? 0
        }
        return 0
    }
}

// MARK: - NSTableViewDelegate

extension EventActionsSheetController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {

        if tableView === eventTableView {
            let key     = sortedKeys[row]
            let enabled = states[key]?.enabled ?? false
            let selected = (key == selectedKey)
            return makeEventRow(label: options[key] ?? key, enabled: enabled, selected: selected)
        }

        if tableView === commandTableView,
           let key = selectedKey,
           row < (states[key]?.entries.count ?? 0) {
            return makeCommandRow(entry: states[key]!.entries[row], row: row)
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTableView,
              tv === eventTableView else { return }
        commitDelayField()
        selectEvent(at: tv.selectedRow)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        tableView === eventTableView ? K.rowH : K.cmdRowH
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        tableView === eventTableView
    }
}

// MARK: - NSTextFieldDelegate

extension EventActionsSheetController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        commitDelayField()
    }
}

// MARK: - Programmatic command-row builder

private extension EventActionsSheetController {

    func makeEventRow(label text: String, enabled: Bool, selected: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let tf = NSTextField(labelWithString: text)
        if selected {
            tf.font      = NSFont.boldSystemFont(ofSize: 13)
            tf.textColor = NSColor(calibratedRed: 0.05, green: 0.20, blue: 0.55, alpha: 1.0)
        } else {
            tf.font      = NSFont.systemFont(ofSize: 13)
            tf.textColor = enabled ? .labelColor : .secondaryLabelColor
        }
        tf.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tf)

        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            tf.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            tf.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    func makeCommandRow(entry: CommandEntry, row: Int) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let idx     = commands.firstIndex(of: entry.command)
        let hasName = idx.map { commandHasName[$0] } ?? false

        let cmdPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        cmdPopup.addItems(withTitles: commands)
        cmdPopup.selectItem(withTitle: entry.command)
        cmdPopup.tag    = row
        cmdPopup.target = self
        cmdPopup.action = #selector(commandPopUpChanged(_:))
        cmdPopup.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cmdPopup)

        let namePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        namePopup.addItems(withTitles: allNames)
        namePopup.selectItem(withTitle: entry.name.isEmpty
                             ? (allNames.first ?? "<current>") : entry.name)
        namePopup.tag      = row
        namePopup.target   = self
        namePopup.action   = #selector(namePopUpChanged(_:))
        namePopup.isHidden = !hasName
        namePopup.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(namePopup)

        let removeBtn = NSButton(title: "×", target: self,
                                 action: #selector(removeCommandRow(_:)))
        removeBtn.bezelStyle = .circular
        removeBtn.tag        = row
        removeBtn.translatesAutoresizingMaskIntoConstraints = false
        removeBtn.setContentHuggingPriority(.required, for: .horizontal)
        removeBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
        container.addSubview(removeBtn)

        let vPad: CGFloat = 3

        if hasName {
            NSLayoutConstraint.activate([
                cmdPopup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                cmdPopup.topAnchor.constraint(equalTo: container.topAnchor, constant: vPad),
                cmdPopup.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPad),
                        cmdPopup.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.42),

                namePopup.leadingAnchor.constraint(equalTo: cmdPopup.trailingAnchor, constant: 4),
                namePopup.topAnchor.constraint(equalTo: container.topAnchor, constant: vPad),
                namePopup.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPad),
                        namePopup.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.38),

                removeBtn.leadingAnchor.constraint(equalTo: namePopup.trailingAnchor, constant: 4),
                removeBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                removeBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
        } else {
                NSLayoutConstraint.activate([
                cmdPopup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                cmdPopup.topAnchor.constraint(equalTo: container.topAnchor, constant: vPad),
                cmdPopup.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPad),
                cmdPopup.trailingAnchor.constraint(equalTo: removeBtn.leadingAnchor, constant: -4),

                        namePopup.widthAnchor.constraint(equalToConstant: 0),
                namePopup.leadingAnchor.constraint(equalTo: cmdPopup.trailingAnchor),
                namePopup.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                removeBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                removeBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
        }

        return container
    }
}
