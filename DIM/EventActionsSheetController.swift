// EventActionsSheetController.swift
//
// Option D: two-pane modal sheet — right pane and all chrome built in code.
// The left pane NSTableView still needs ONE storyboard prototype cell (see
// "STORYBOARD REQUIREMENTS" below) so that makeView(withIdentifier:owner:)
// works without a registered Nib.  Everything else — split view, right pane,
// all controls — is created in loadView() / viewDidLoad().
//
// ─── STORYBOARD REQUIREMENTS (minimal) ───────────────────────────────────────
//
//  1. Add a NEW View Controller scene in Main.storyboard.
//       Class:         EventActionsSheetController
//       Storyboard ID: EventActionsSheet
//       (The scene's root view size does not matter; preferredContentSize
//        is set in code and loadView() replaces the root view entirely.)
//
//  2. Inside that scene's root view, add an NSScrollView pinned to all edges.
//     Place an NSTableView as its document view.
//       • Wire the NSTableView → eventTableView outlet on File's Owner.
//       • One column, identifier "eventCol", no header.
//       • Add ONE NSTableCellView prototype inside the column:
//           - Identifier: "EventCell"
//           - Contains a single NSTextField wired to the cell's `textField`
//             outlet (the default NSTableCellView outlet — IB sets this up
//             automatically when you drop a Table Cell View).
//           - No other subviews or outlets needed.
//
//  That is the complete storyboard setup.  No other outlets or actions need
//  to be wired in IB; everything else is connected in code.
//
// ─── PRESENTING ──────────────────────────────────────────────────────────────
//
//  let sb = NSStoryboard(name: "Main", bundle: nil)
//  let vc = sb.instantiateController(withIdentifier: "EventActionsSheet")
//             as! EventActionsSheetController
//  vc.options        = myOptionsDict          // [String: String]
//  vc.commands       = myCommandsArray        // [String]
//  vc.commandHasName = myHasBoolArray         // [Bool]  parallel to commands
//  vc.allNames       = myNamesArray           // [String] includes "<current>"
//  vc.completion     = { result in
//      // result is [String:(Double,[String])]?  — nil if user cancelled
//  }
//  presentAsSheet(vc)
//
// ─────────────────────────────────────────────────────────────────────────────

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

    // ── Public inputs (set before presentAsSheet) ─────────────────────────
    var options:        [String: String] = [:]
    var commands:       [String]         = []
    var commandHasName: [Bool]           = []  // parallel to commands
    var allNames:       [String]         = []  // includes "<current>"
    var completion: (([String: (Double, [String])])?) -> Void = { _ in }

    // ── Left-pane outlet (storyboard – needed only for prototype cell) ─────
    @IBOutlet private weak var eventTableView: NSTableView!

    // ── Right-pane controls (all built in code) ───────────────────────────
    private var splitView:        NSSplitView!
    private var rightPane:        NSView!
    private var noSelLabel:       NSTextField!
    private var detailView:       NSView!      // shown when a row is selected
    private var enableCheckbox:   NSButton!
    private var delayField:       NSTextField!
    private var commandTableView: NSTableView!
    private var cmdScrollView:    NSScrollView!
    private var addButton:        NSButton!

    // Bottom buttons (also built in code)
    private var cancelButton: NSButton!
    private var saveButton:   NSButton!

    // ── Internal state ────────────────────────────────────────────────────
    private var sortedKeys:  [String] = []
    private var states:      [String: EventState] = [:]
    private var selectedKey: String?

    private let udKey = "helperData"

    // ── Layout constants ──────────────────────────────────────────────────
    private enum K {
        static let W:       CGFloat = 660
        static let H:       CGFloat = 460
        static let leftW:   CGFloat = 170
        static let pad:     CGFloat = 16
        static let rowH:    CGFloat = 28
        static let cmdRowH: CGFloat = 32
        static let fieldH:  CGFloat = 22
    }

    // Bridge between loadView and viewDidLoad — lets us embed eventTableView
    // into the scroll view that loadView creates, once the IB outlet is live.
    private weak var leftScrollView: NSScrollView?

    // MARK: - View construction (loadView replaces the storyboard root view)

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let title = label("Event Actions", size: 15, bold: true)
        root.addSubview(title)

        // Cancel / Save buttons
        cancelButton = roundedButton("Cancel", action: #selector(cancelAction))
        cancelButton.keyEquivalent = "\u{1B}"
        saveButton   = roundedButton("Save",   action: #selector(saveAction))
        saveButton.keyEquivalent = "\r"
        root.addSubview(cancelButton)
        root.addSubview(saveButton)

        // Split view
        splitView = NSSplitView()
        splitView.isVertical   = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = NSSplitView.AutosaveName("EventActionsSplit")
        splitView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(splitView)

        // Left scroll view (document view = eventTableView, set in viewDidLoad)
        let leftScroll = NSScrollView()
        leftScroll.hasVerticalScroller = true
        leftScroll.autohidesScrollers  = true
        leftScroll.borderType          = .noBorder
        leftScroll.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(leftScroll)
        leftScrollView = leftScroll

        // Right pane
        rightPane = NSView()
        rightPane.translatesAutoresizingMaskIntoConstraints = false
        buildRightPane()
        splitView.addArrangedSubview(rightPane)

        // Constraints
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: K.pad),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: K.pad),

            splitView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            splitView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -12),

            saveButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -K.pad),
            saveButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -K.pad),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: saveButton.bottomAnchor),

            leftScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: K.leftW),

            root.widthAnchor.constraint(greaterThanOrEqualToConstant: K.W),
            root.heightAnchor.constraint(greaterThanOrEqualToConstant: K.H),
        ])

        self.view = root
        preferredContentSize = NSSize(width: K.W, height: K.H)
    }

    // Populates rightPane with all detail subviews.
    private func buildRightPane() {
        // "No selection" placeholder
        noSelLabel = label("← Select an event", size: 13, bold: false)
        noSelLabel.textColor = .secondaryLabelColor
        rightPane.addSubview(noSelLabel)

        // Detail container
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

    // Builds all controls inside detailView.
    private func buildDetailView() {
        let p = K.pad

        // Enable checkbox
        enableCheckbox = NSButton(checkboxWithTitle: "Enable this event",
                                  target: self, action: #selector(enableChanged))
        enableCheckbox.translatesAutoresizingMaskIntoConstraints = false
        detailView.addSubview(enableCheckbox)

        // Delay label + field
        let delayLbl = label("Delay (seconds):", size: 13, bold: false)
        detailView.addSubview(delayLbl)

        delayField = NSTextField()
        delayField.placeholderString = "0.0"
        delayField.translatesAutoresizingMaskIntoConstraints = false
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimum = 0
        fmt.maximumFractionDigits = 2
        delayField.formatter = fmt
        detailView.addSubview(delayField)

        // "Commands" section label
        let cmdLbl = label("Commands:", size: 13, bold: false)
        detailView.addSubview(cmdLbl)

        // Command NSTableView (one column, no header)
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

        // Add command button
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

        // Embed the storyboard-registered eventTableView into our left scroll view.
        if let tv = eventTableView, let scroll = leftScrollView {
            tv.dataSource = self
            tv.delegate   = self
            tv.headerView = nil
            tv.selectionHighlightStyle = .regular
            tv.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
            tv.tableColumns.first?.resizingMask = .autoresizingMask
            scroll.documentView = tv
        }

        delayField.delegate = self

        buildSortedKeys()
        loadFromUserDefaults()
        eventTableView?.reloadData()
        showNoSelection()

        if !sortedKeys.isEmpty {
            eventTableView?.selectRowIndexes(IndexSet(integer: 0),
                                              byExtendingSelection: false)
            selectEvent(at: 0)
        }
    }

    // MARK: - Data helpers

    private func buildSortedKeys() {
        sortedKeys = options.keys.sorted { (options[$0] ?? $0) < (options[$1] ?? $1) }
    }

    private func loadFromUserDefaults() {
        let defaults = UserDefaults(suiteName: bDIM.gUD)!
        let rawData  = defaults.dictionary(forKey: udKey) ?? [:]
        var saved: [String: (Double, [String])] = [:]
        for (key, value) in rawData {
            if let entry = value as? [Any],
               let delay = entry.first as? Double,
               let args  = entry.last  as? [String] {
                saved[key] = (delay, args)
            }
        }
        for key in sortedKeys {
            if let (delay, args) = saved[key] {
                states[key] = EventState(enabled: true,
                                         delay: delay,
                                         entries: parseArgs(args))
            } else {
                states[key] = EventState(enabled: false, delay: 0.0, entries: [])
            }
        }
    }

    private func parseArgs(_ args: [String]) -> [CommandEntry] {
        var result: [CommandEntry] = []
        var i = 0
        while i < args.count {
            let cmd = args[i]; i += 1
            let idx = commands.firstIndex(of: cmd)
            let hasName = idx.map { commandHasName[$0] } ?? false
            let name: String
            if hasName, i < args.count { name = args[i]; i += 1 } else { name = "" }
            result.append(CommandEntry(command: cmd, name: name))
        }
        return result
    }

    private func serialiseEntries(_ entries: [CommandEntry]) -> [String] {
        var out: [String] = []
        for e in entries {
            out.append(e.command)
            let idx = commands.firstIndex(of: e.command)
            if idx.map({ commandHasName[$0] }) == true {
                out.append(e.name.isEmpty ? (allNames.first ?? "<current>") : e.name)
            }
        }
        return out
    }

    // MARK: - Right-pane state

    private func showNoSelection() {
        noSelLabel.isHidden  = false
        detailView.isHidden  = true
        selectedKey = nil
    }

    private func selectEvent(at row: Int) {
        guard row >= 0, row < sortedKeys.count else { showNoSelection(); return }
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

    // MARK: - View factory helpers

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

        // Left pane — plain label cell (prototype registered in storyboard)
        if tableView === eventTableView {
            let key     = sortedKeys[row]
            let enabled = states[key]?.enabled ?? false
            let id      = NSUserInterfaceItemIdentifier("EventCell")
            let cell    = tableView.makeView(withIdentifier: id, owner: self)
                          as? NSTableCellView ?? NSTableCellView()
            cell.textField?.stringValue = options[key] ?? key
            cell.textField?.textColor   = enabled ? .labelColor : .secondaryLabelColor
            return cell
        }

        // Right pane — fully programmatic command row
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
        // Only the left-pane list supports row selection
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

    /// Builds one row for the command table entirely in code.
    ///
    /// Layout (left → right):
    ///   [command NSPopUpButton]  [name NSPopUpButton, hidden if !hasName]  [× NSButton]
    ///
    /// The row view is a plain NSView — no custom class, no IB prototype needed.
    func makeCommandRow(entry: CommandEntry, row: Int) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let idx     = commands.firstIndex(of: entry.command)
        let hasName = idx.map { commandHasName[$0] } ?? false

        // ── Command popup ─────────────────────────────────────────────────
        let cmdPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        cmdPopup.addItems(withTitles: commands)
        cmdPopup.selectItem(withTitle: entry.command)
        cmdPopup.tag    = row
        cmdPopup.target = self
        cmdPopup.action = #selector(commandPopUpChanged(_:))
        cmdPopup.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cmdPopup)

        // ── Name popup ────────────────────────────────────────────────────
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

        // ── Remove button ─────────────────────────────────────────────────
        let removeBtn = NSButton(title: "×", target: self,
                                 action: #selector(removeCommandRow(_:)))
        removeBtn.bezelStyle = .circular
        removeBtn.tag        = row
        removeBtn.translatesAutoresizingMaskIntoConstraints = false
        removeBtn.setContentHuggingPriority(.required, for: .horizontal)
        removeBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
        container.addSubview(removeBtn)

        // ── Constraints ───────────────────────────────────────────────────
        let vPad: CGFloat = 3

        if hasName {
            NSLayoutConstraint.activate([
                cmdPopup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                cmdPopup.topAnchor.constraint(equalTo: container.topAnchor, constant: vPad),
                cmdPopup.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPad),
                // command popup takes ~42 % of the row width
                cmdPopup.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.42),

                namePopup.leadingAnchor.constraint(equalTo: cmdPopup.trailingAnchor, constant: 4),
                namePopup.topAnchor.constraint(equalTo: container.topAnchor, constant: vPad),
                namePopup.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPad),
                // name popup takes ~38 % of the row width
                namePopup.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.38),

                removeBtn.leadingAnchor.constraint(equalTo: namePopup.trailingAnchor, constant: 4),
                removeBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                removeBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
        } else {
            // No name popup: command popup expands to fill available space
            NSLayoutConstraint.activate([
                cmdPopup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                cmdPopup.topAnchor.constraint(equalTo: container.topAnchor, constant: vPad),
                cmdPopup.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPad),
                cmdPopup.trailingAnchor.constraint(equalTo: removeBtn.leadingAnchor, constant: -4),

                // Keep namePopup in the hierarchy but collapsed to zero width
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
