// EventActionsSheetController.swift
//
// Two-pane modal sheet. All views built in code; only a storyboard scene with
// Class=EventActionsSheetController and Storyboard ID=EventActionsSheet is needed.
//
// Usage:
//   vc.options        = ["key": "Display Label", …]
//   vc.commands       = ["cmd1", "cmd2", …]
//   vc.commandHasName = [true, false, …]          // parallel to commands
//   vc.allNames       = ["<current>", "Name A", …] // <current> = no name
//   vc.completion     = { result in … }
//   presentAsSheet(vc)
//
// Assumptions: at least one option, command, and name always exist.
// Storage: UserDefaults suite bDIM.gUD, key "helperData"
//   Format: [String: [delay: Double, args: [String]]]
//   Args:   ["--cmd", "optionalName", "--cmd2", …]  (<current> omitted)

import Cocoa

struct CommandEntry { var command: String; var name: String }
private struct EventState { var enabled: Bool; var delay: Double; var entries: [CommandEntry] }

final class EventActionsSheetController: NSViewController {

    // MARK: - Inputs
    var options:        [String: String] = [:]
    var commands:       [String]         = []
    var commandHasName: [Bool]           = []
    var allNames:       [String]         = []
    var completion: ([String: (Double, [String])]) -> Void = { _ in }

    // MARK: - Views
    private var eventTableView:   NSTableView!
    private var splitView:        NSSplitView!
    private var rightPane:        NSView!
    private var noSelLabel:       NSTextField!
    private var detailView:       NSView!
    private var enableCheckbox:   NSButton!
    private var delayLabel:       NSTextField!
    private var delayField:        NSTextField!
    private var commandTableView: NSTableView!
    private var cmdScrollView:    NSScrollView!
    private var addButton:        NSButton!
    private var doneButton:       NSButton!
    private weak var leftScrollView: NSScrollView?

    // MARK: - State
    var sortedKeys:  [String] = []
    private var states:      [String: EventState] = [:]
    private var selectedKey: String?
    private let udKey = "helperData"

    private enum K {
        static let W: CGFloat = 660;  static let H: CGFloat = 460
        static let leftW: CGFloat = 170; static let pad: CGFloat = 16
        static let rowH: CGFloat = 28;  static let cmdRowH: CGFloat = 32
        static let fieldH: CGFloat = 22; static let handleW: CGFloat = 20
    }

    // MARK: - View construction

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: K.W, height: K.H))

        let title = lbl("Event Actions:", size: 14, bold: true)
        root.addSubview(title)

        doneButton = btn("Done", #selector(doneAction))
        root.addSubview(doneButton)

        splitView = NSSplitView()
        splitView.isVertical = true; splitView.dividerStyle = .thin
        splitView.autosaveName = NSSplitView.AutosaveName("EventActionsSplit")
        splitView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(splitView)

        let leftScroll = NSScrollView()
        leftScroll.hasVerticalScroller = true; leftScroll.autohidesScrollers = true
        leftScroll.borderType = .noBorder
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
            doneButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -K.pad),
            doneButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            splitView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            splitView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -12),
            leftScroll.widthAnchor.constraint(equalToConstant: K.leftW),
        ])
        self.view = root
        preferredContentSize = NSSize(width: K.W, height: K.H)
    }

    private func buildRightPane() {
        noSelLabel = lbl("← Select an event", size: 13, bold: false)
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
        enableCheckbox = NSButton(checkboxWithTitle: "Enable this Event",
                                  target: self, action: #selector(enableChanged))
        enableCheckbox.translatesAutoresizingMaskIntoConstraints = false
        detailView.addSubview(enableCheckbox)

        delayLabel = lbl("Delay (seconds):", size: 13, bold: false)
        let delayLbl = delayLabel!
        detailView.addSubview(delayLbl)

        delayField = NSTextField()
        delayField.placeholderString = "1.5"
        delayField.translatesAutoresizingMaskIntoConstraints = false
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal; fmt.minimum = 0; fmt.maximumFractionDigits = 2
        delayField.formatter = fmt
        detailView.addSubview(delayField)

        let cmdLbl = lbl("Actions:", size: 13, bold: false)
        detailView.addSubview(cmdLbl)

        commandTableView = NSTableView()
        commandTableView.headerView = nil
        commandTableView.selectionHighlightStyle = .none
        commandTableView.allowsEmptySelection = true
        commandTableView.intercellSpacing = NSSize(width: 0, height: 2)
        commandTableView.dataSource = self; commandTableView.delegate = self
        commandTableView.registerForDraggedTypes([.string])
        commandTableView.setDraggingSourceOperationMask(.move, forLocal: true)
        let col = NSTableColumn(identifier: .init("cmdRow"))
        col.resizingMask = .autoresizingMask
        commandTableView.addTableColumn(col)

        cmdScrollView = NSScrollView()
        cmdScrollView.documentView = commandTableView
        cmdScrollView.hasVerticalScroller = true; cmdScrollView.autohidesScrollers = true
        cmdScrollView.borderType = .bezelBorder
        cmdScrollView.translatesAutoresizingMaskIntoConstraints = false
        detailView.addSubview(cmdScrollView)

        addButton = btn("＋  Add Action", #selector(addCommandAction))
        detailView.addSubview(addButton)
        
        // from google ai fix for moving delay/interval input box
        NSLayoutConstraint.activate([
            enableCheckbox.topAnchor.constraint(equalTo: detailView.topAnchor, constant: p),
            enableCheckbox.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            
            // 1. Position the label relative to the left edge
            delayLbl.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            delayLbl.centerYAnchor.constraint(equalTo: delayField.centerYAnchor),
            
            // 2. Position the input field exactly 'p' points after the label
            delayField.topAnchor.constraint(equalTo: enableCheckbox.bottomAnchor, constant: p),
            delayField.leadingAnchor.constraint(equalTo: delayLbl.trailingAnchor, constant: 8), // <-- Changed here
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

        /*
        NSLayoutConstraint.activate([
            enableCheckbox.topAnchor.constraint(equalTo: detailView.topAnchor, constant: p),
            enableCheckbox.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            delayField.topAnchor.constraint(equalTo: enableCheckbox.bottomAnchor, constant: p),
            delayField.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p + 110),
            delayField.widthAnchor.constraint(equalToConstant: 72),
            delayField.heightAnchor.constraint(equalToConstant: K.fieldH),
            delayLbl.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            delayLbl.centerYAnchor.constraint(equalTo: delayField.centerYAnchor),
            cmdLbl.topAnchor.constraint(equalTo: delayField.bottomAnchor, constant: p),
            cmdLbl.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            cmdScrollView.topAnchor.constraint(equalTo: cmdLbl.bottomAnchor, constant: 6),
            cmdScrollView.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            cmdScrollView.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -p),
            cmdScrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),
            addButton.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: p),
            addButton.bottomAnchor.constraint(equalTo: detailView.bottomAnchor, constant: -p),
        ]) */
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Build left-pane table programmatically (no storyboard prototype needed).
        let tv = NSTableView()
        let col = NSTableColumn(identifier: .init("eventCol"))
        col.resizingMask = .autoresizingMask
        tv.addTableColumn(col)
        eventTableView = tv

        if let scroll = leftScrollView {
            eventTableView.dataSource = self; eventTableView.delegate = self
            eventTableView.headerView = nil
            eventTableView.selectionHighlightStyle = .regular
            eventTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
            eventTableView.tableColumns.first?.resizingMask = .autoresizingMask
            scroll.documentView = eventTableView
        }

        delayField.delegate = self
        // Explicit position overrides any stale autosaved divider value.
        splitView.setPosition(K.leftW, ofDividerAt: 0)

        loadFromUserDefaults()
        eventTableView.reloadData()
        eventTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        selectEvent(at: 0)
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        let defaults = UserDefaults(suiteName: bDIM.gUD)!
        var saved: [String: (Double, [String])] = [:]

        for (key, value) in defaults.dictionary(forKey: udKey)! {
            let e = value as! [Any]
            saved[key] = (e[0] as! Double, e[1] as! [String])
        }
        /*
        if defaults.object(forKey: udKey) != nil {
            for (key, value) in defaults.dictionary(forKey: udKey)! {
                let e = value as! [Any]
                saved[key] = (e[0] as! Double, e[1] as! [String])
            }
        } else {
            // First launch — write defaults so UserDefaults is not initially.
            saved = ["wake":    (3.0, ["--restore", "--quit"]),
                     "change":  (1.5, ["--restore", "--quit"]),
                     "startup": (0.0, ["--restore", "--quit"])]
            persistToDisk(saved)
        }
        */

        for key in sortedKeys {
            if let (delay, args) = saved[key] {
                states[key] = EventState(enabled: true, delay: delay, entries: parseArgs(args))
            } else {
                states[key] = EventState(enabled: false, delay: key != "interval" ? 1.5 : 15, entries: [])
            }
        }
    }

    // Rebuilds the storable dictionary from current state and writes to UserDefaults.
    private func persist() {
        var result: [String: (Double, [String])] = [:]
        for key in sortedKeys {
            guard let s = states[key], s.enabled else { continue }
            result[key] = (s.delay, serialise(s.entries))
        }
        persistToDisk(result)
    }

    private func persistToDisk(_ data: [String: (Double, [String])]) {
        let defaults = UserDefaults(suiteName: bDIM.gUD)!
        defaults.set(Dictionary(uniqueKeysWithValues: data.map { ($0, [$1.0, $1.1] as [Any]) }),
                     forKey: udKey)
        defaults.synchronize()
    }

    // MARK: - Serialisation

    private func parseArgs(_ args: [String]) -> [CommandEntry] {
        var result: [CommandEntry] = []; var i = 0
        while i < args.count {
            let raw = args[i]; i += 1
            let cmd = raw.hasPrefix("--") ? String(raw.dropFirst(2)) : raw
            let hasName = commands.firstIndex(of: cmd).map { commandHasName[$0] } ?? false
            var name = ""
            if hasName {
                if i < args.count && !args[i].hasPrefix("--") { name = args[i]; i += 1 }
                else { name = "<current>" }
            }
            result.append(CommandEntry(command: cmd, name: name))
        }
        return result
    }

    private func serialise(_ entries: [CommandEntry]) -> [String] {
        entries.flatMap { e -> [String] in
            var out = ["--" + e.command]
            if commands.firstIndex(of: e.command).map({ commandHasName[$0] }) == true {
                if (e.name.isEmpty ? "<current>" : e.name) != "<current>" { out.append(e.name) }
            }
            return out
        }
    }

    // MARK: - Selection

    private func selectEvent(at row: Int) {
        // Deselect previous row to remove bold/blue styling.
        if let old = selectedKey, let oldRow = sortedKeys.firstIndex(of: old) {
            selectedKey = nil
            eventTableView.reloadData(forRowIndexes: IndexSet(integer: oldRow),
                                      columnIndexes: IndexSet(integer: 0))
        }
        selectedKey = sortedKeys[row]
        refreshDetail()
    }

    private func refreshDetail() {
        let s = states[selectedKey!]!
        noSelLabel.isHidden = true; detailView.isHidden = false
        enableCheckbox.state = s.enabled ? .on : .off
        delayLabel.stringValue = selectedKey == "interval" ? "Interval (minutes):" : "Delay (seconds):"
        delayField.stringValue = String(format: "%.1f", s.delay)
        delayField.isEnabled = s.enabled; addButton.isEnabled = s.enabled
        commandTableView.isEnabled = s.enabled; commandTableView.reloadData()
        let row = sortedKeys.firstIndex(of: selectedKey!)!
        eventTableView.reloadData(forRowIndexes: IndexSet(integer: row),
                                  columnIndexes: IndexSet(integer: 0))
    }

    private func commitDelayField() {
        guard let key = selectedKey else { return }
        let v = max(0, (delayField.formatter as? NumberFormatter)?
                        .number(from: delayField.stringValue)?.doubleValue
                      ?? Double(delayField.stringValue) ?? states[key]!.delay)
        guard states[key]!.delay != v else { return }
        states[key]!.delay = v; persist()
    }

    // MARK: - Actions

    @objc private func enableChanged(_ sender: NSButton) {
        states[selectedKey!]!.enabled = sender.state == .on; persist(); refreshDetail()
    }

    @objc private func addCommandAction() {
        let name = commandHasName[0] ? allNames[0] : ""
        states[selectedKey!]!.entries.append(CommandEntry(command: commands[0], name: name))
        persist(); commandTableView.reloadData()
    }

    @objc private func removeCommandRow(_ sender: NSButton) {
        states[selectedKey!]!.entries.remove(at: sender.tag)
        persist(); commandTableView.reloadData()
    }

    @objc private func commandPopUpChanged(_ sender: NSPopUpButton) {
        let cmd = sender.titleOfSelectedItem!
        let hasName = commands.firstIndex(of: cmd).map { commandHasName[$0] } ?? false
        states[selectedKey!]!.entries[sender.tag] =
            CommandEntry(command: cmd, name: hasName ? allNames[0] : "")
        persist()
        commandTableView.reloadData(forRowIndexes: IndexSet(integer: sender.tag),
                                    columnIndexes: IndexSet(integer: 0))
    }

    @objc private func namePopUpChanged(_ sender: NSPopUpButton) {
        states[selectedKey!]!.entries[sender.tag].name = sender.titleOfSelectedItem!
        persist()
    }

    @objc private func doneAction() {
        commitDelayField()
        var result: [String: (Double, [String])] = [:]
        for key in sortedKeys {
            guard let s = states[key], s.enabled else { continue }
            result[key] = (s.delay, serialise(s.entries))
        }
        dismiss(self); completion(result)
    }

    // MARK: - View helpers

    private func lbl(_ text: String, size: CGFloat, bold: Bool) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        tf.translatesAutoresizingMaskIntoConstraints = false; return tf
    }

    private func btn(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded; b.translatesAutoresizingMaskIntoConstraints = false; return b
    }

    private func dragHandleImage() -> NSImage {
        let img = NSImage(size: NSSize(width: 10, height: 14))
        img.lockFocus()
        NSColor.tertiaryLabelColor.setFill()
        let lineH: CGFloat = 1.5, gap: CGFloat = 3.5
        let startY = (14 - (3 * lineH + 2 * gap)) / 2
        for i in 0..<3 {
            NSBezierPath(roundedRect: NSRect(x: 0, y: startY + CGFloat(i) * (lineH + gap),
                                             width: 10, height: lineH),
                         xRadius: 0.75, yRadius: 0.75).fill()
        }
        img.unlockFocus(); return img
    }
}

// MARK: - NSTableViewDataSource

extension EventActionsSheetController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === eventTableView ? sortedKeys.count
            : states[selectedKey ?? ""]?.entries.count ?? 0
    }

    func tableView(_ tableView: NSTableView,
                   pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard tableView === commandTableView else { return nil }
        return NSPasteboardItem(pasteboardPropertyList: row, ofType: .string)
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation op: NSTableView.DropOperation) -> NSDragOperation {
        guard tableView === commandTableView else { return [] }
        if op == .on { tableView.setDropRow(row, dropOperation: .above) }
        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                   row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard tableView === commandTableView,
              let srcRow = info.draggingPasteboard.pasteboardItems?.first?
                  .propertyList(forType: .string) as? Int else { return false }
        var entries = states[selectedKey!]!.entries
        let entry = entries.remove(at: srcRow)
        entries.insert(entry, at: srcRow < row ? row - 1 : row)
        states[selectedKey!]!.entries = entries
        persist(); commandTableView.reloadData(); return true
    }
}

// MARK: - NSTableViewDelegate

extension EventActionsSheetController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === eventTableView {
            let key = sortedKeys[row]
            return makeEventRow(label: options[key]!, enabled: states[key]!.enabled,
                                selected: key == selectedKey)
        }
        return makeCommandRow(entry: states[selectedKey!]!.entries[row], row: row)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTableView,
              tv === eventTableView else { return }
        commitDelayField(); selectEvent(at: tv.selectedRow)
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
    func controlTextDidEndEditing(_ obj: Notification) { commitDelayField() }
}

// MARK: - Row builders

private extension EventActionsSheetController {

    func makeEventRow(label text: String, enabled: Bool, selected: Bool) -> NSView {
        let container = NSView(); container.translatesAutoresizingMaskIntoConstraints = false
        let tf = NSTextField(labelWithString: text)
        tf.font      = selected ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 13)
        tf.textColor = selected ? NSColor(calibratedRed: 0.05, green: 0.20, blue: 0.55, alpha: 1)
                                : (enabled ? .labelColor : .secondaryLabelColor)
        tf.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tf)
        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            tf.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            tf.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    // Row layout: [≡ handle] [command popup] [name popup, hidden if n/a] [× button]
    func makeCommandRow(entry: CommandEntry, row: Int) -> NSView {
        let container = NSView(); container.translatesAutoresizingMaskIntoConstraints = false
        let hasName = commands.firstIndex(of: entry.command).map { commandHasName[$0] } ?? false

        let handle = NSImageView()
        handle.image = dragHandleImage(); handle.toolTip = "Drag to reorder"
        handle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(handle)

        let cmdPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        cmdPopup.addItems(withTitles: commands)
        cmdPopup.selectItem(withTitle: entry.command)
        cmdPopup.tag = row; cmdPopup.target = self
        cmdPopup.action = #selector(commandPopUpChanged(_:))
        cmdPopup.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cmdPopup)

        let namePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        namePopup.addItems(withTitles: allNames)
        namePopup.selectItem(withTitle: entry.name.isEmpty ? allNames[0] : entry.name)
        namePopup.tag = row; namePopup.target = self
        namePopup.action = #selector(namePopUpChanged(_:))
        namePopup.isHidden = !hasName
        namePopup.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(namePopup)

        let rm = NSButton(title: "×", target: self, action: #selector(removeCommandRow(_:)))
        rm.bezelStyle = .circular; rm.tag = row
        rm.translatesAutoresizingMaskIntoConstraints = false
        rm.widthAnchor.constraint(equalToConstant: 22).isActive  = true
        rm.heightAnchor.constraint(equalToConstant: 22).isActive = true
        container.addSubview(rm)

        let v: CGFloat = 3
        var c: [NSLayoutConstraint] = [
            handle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            handle.widthAnchor.constraint(equalToConstant: K.handleW),
            handle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            cmdPopup.leadingAnchor.constraint(equalTo: handle.trailingAnchor, constant: 2),
            cmdPopup.topAnchor.constraint(equalTo: container.topAnchor, constant: v),
            cmdPopup.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -v),
            rm.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            rm.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
        ]
        if hasName {
            c += [
                cmdPopup.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.38),
                namePopup.leadingAnchor.constraint(equalTo: cmdPopup.trailingAnchor, constant: 4),
                namePopup.topAnchor.constraint(equalTo: container.topAnchor, constant: v),
                namePopup.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -v),
                namePopup.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.34),
                rm.leadingAnchor.constraint(equalTo: namePopup.trailingAnchor, constant: 4),
            ]
        } else {
            c += [
                cmdPopup.trailingAnchor.constraint(equalTo: rm.leadingAnchor, constant: -4),
                namePopup.widthAnchor.constraint(equalToConstant: 0),
                namePopup.leadingAnchor.constraint(equalTo: cmdPopup.trailingAnchor),
                namePopup.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ]
        }
        NSLayoutConstraint.activate(c)
        return container
    }
}

