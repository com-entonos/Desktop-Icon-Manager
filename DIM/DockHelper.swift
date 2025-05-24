//
//  DockerHelper.swift
//  DIM
//
//  Created by G.J. Parker on 5/17/25.
//  Copyright © 2025 G.J. Parker. All rights reserved.
//


import AppKit
import OSLog

extension Notification.Name {
    static let doRestore = Notification.Name("doRestore")
    static let doMemorize = Notification.Name("doMemorize")
    static let doAdd = Notification.Name("doAdd")
    static let newArrangement = Notification.Name("newArrangement")
}
@available(macOS 11.0, *)
extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// All logs related to tracking and analytics.
    static let diag = Logger(subsystem: subsystem, category: "info")
    static let err = Logger(subsystem: subsystem, category: "error")
}

class DockHelper {
    let BundleID = "com.parker9.DIM-4"
    var allArrangements = [String]()
    var nameList : [String]? = nil
    
    var optionHeld = false

    init() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { self.myFlagsChanged(with: $0); return $0} // capture if option key is being held

        NotificationCenter.default.addObserver(forName: .newArrangement, object: nil, queue: .main, using: { notice in  // listen for new arrangment list -> newList
            self.nameList = notice.object as? [String] ?? nil
            if #available(macOS 11.0, *) { Logger.diag.log("notice recieved: \(notice.name.rawValue, privacy: .public) nameList=\(self.nameList ?? [], privacy: .private(mask: .hash))<") }
        })
    }
   
    func dockMenu() -> NSMenu? {
        allArrangements.removeAll()
        if let a = nameList {
            allArrangements = a
            if #available(macOS 11.0, *) { Logger.diag.log("  from nameList: \(self.allArrangements.count,privacy: .public) nameList=\(self.allArrangements, privacy: .private(mask: .hash))<>\(self.BundleID, privacy: .public)<>\(Bundle.main.bundleIdentifier!, privacy: .public)<") }
        } else if let a = UserDefaults.standard.array(forKey: "orderedArrangements") as? [String] {
            allArrangements = a
            if #available(macOS 11.0, *) { Logger.diag.log("  from UserDefaults: \(self.allArrangements.count,privacy: .public) allArrangements=\(self.allArrangements, privacy: .private(mask: .hash))<>\(self.BundleID, privacy: .public)<>\(Bundle.main.bundleIdentifier!, privacy: .public)<") }
        } else if let a = CFPreferencesCopyAppValue("orderedArrangements" as CFString, BundleID as CFString) as? [String] {
            allArrangements = a
            if #available(macOS 11.0, *) { Logger.diag.log("  from CFPrefs: \(self.allArrangements.count,privacy: .public) allArrangements=\(self.allArrangements, privacy: .private(mask: .hash))<>\(self.BundleID, privacy: .public)<>\(Bundle.main.bundleIdentifier!, privacy: .public)<") }
        } else {
            if #available(macOS 11.0, *) { Logger.diag.log("  no orderedArrangements in >\(self.BundleID, privacy: .public)<>\(Bundle.main.bundleIdentifier!, privacy: .public)<") }
            //allArrangements = ["must be one"]
            return nil
        }
        
        let menu = NSMenu()
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: "Restore\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(self.selectDMI(_:)), keyEquivalent: ""); it.target = self; it.tag = index
            menu.addItem(it)
        }
        menu.addItem(NSMenuItem.separator())
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: (!optionHeld ? "Memorize" : "Purge") + "\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(self.selectDMI(_:)), keyEquivalent: "");it.target = self; it.tag = index
            menu.addItem(it)
        }
        return menu
    }
    @objc func selectDMI(_ sender: NSMenuItem) {
        let name = sender.tag < 0 ? "<current>" : allArrangements[sender.tag]
        let noticeName: Notification.Name = sender.title.hasPrefix("Purge") ? .doMemorize : (sender.title.hasPrefix("Memorize") ? .doAdd : .doRestore)
        if #available(macOS 11.0, *) { Logger.diag.log("DockHelper.selectDMI sending notice: \(sender.tag, privacy: .public) \(noticeName.rawValue, privacy: .public) name=\(name, privacy: .private(mask: .hash))< <") }
        NotificationCenter.default.post(name: noticeName, object: sender.tag < 0 ? nil : name)
    }
    
    func myFlagsChanged(with event: NSEvent) {
        optionHeld = event.modifierFlags.contains(.option)
        //if #available(macOS 11.0, *) { Logger.diag.log("DockHelper.myFlagsChanged optionHeld=\(self.optionHeld, privacy: .public)")}
    }
}
