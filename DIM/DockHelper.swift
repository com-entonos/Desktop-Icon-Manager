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
    
  //  var isMain = false
  //  let subsystem = "DIMDTP" //"com.parker9.DIMDockTilePlugin" //"DIMDockTilePlugin.docktileplugin"
    
  //  init() {
  //      isMain = (BundleID == Bundle(for: DockHelper.self).bundleIdentifier ?? BundleID)
        //if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("DockHelper.init: isMain? \(self.isMain, privacy: .public) >bundleID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)<") }
  //  }
 /*   init(_ bundle : String = "com.parker9.DIM-4") {
        super.init()
        isMain = (BundleID == Bundle(for: DockHelper.self).bundleIdentifier ?? bundle)
        if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("DockHelper.init: isMain? \(self.isMain, privacy: .public) >bundleID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)<") }
    } */
    
    func setDockTile(_ dockTile: NSDockTile?) {
        //if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("DockHelper.setDockTile: bundleID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)<- \(dockTile == nil ? "no dockTile":dockTile!.className, privacy: .public)< isMain? \(self.isMain, privacy: .public)") }
    }
    
    func setMenu(_ arrangements : [String]? = nil) -> NSMenu? {
        //if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("DockHelper.setMenu: isMain? \(self.isMain, privacy: .public), bundlID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)< ") }
        allArrangements.removeAll()
        if arrangements != nil && !(arrangements?.isEmpty ?? true) { allArrangements = arrangements! } else {
            CFPreferencesAppSynchronize(BundleID as CFString)
            
            //if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("  'orderedArrangements' exist?\(UserDefaults.standard.array(forKey: "orderedArrangements") != nil ,privacy: .public) [String]? \(UserDefaults.standard.array(forKey: "orderedArrangements") as? [String] ?? [" "],privacy: .public) Bunldle.main.ID=\(Bundle.main.bundleIdentifier ?? "nothing", privacy: .public)<") }
            //if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("  suiteName exist? \(UserDefaults(suiteName: self.BundleID)?.array(forKey: "orderedArrangements") != nil,privacy: .public)<=\(UserDefaults(suiteName: self.BundleID)?.array(forKey: "orderedArrangements") as? [String] != nil, privacy: .public)<>\(self.BundleID, privacy: .public)<") }
            //if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("  CFPreferencesCopyAppValue exist? \(CFPreferencesCopyAppValue("orderedArrangements" as CFString, self.BundleID as CFString) != nil,privacy: .public) [String]? \(CFPreferencesCopyAppValue("orderedArrangements" as CFString, self.BundleID as CFString) as? [String] ?? [" "], privacy: .public)<>\(self.BundleID, privacy: .public)<") }
            //let aa = CFPreferencesCopyAppValue("orderedArrangements" as CFString, BundleID as CFString) as Any?
            //if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("  casting Any? \(aa != nil,privacy: .public) aa as [String]=\(aa as? [String] ?? ["nil"], privacy: .public)<>\(self.BundleID, privacy: .public)<") }
            
            if let a = UserDefaults.standard.array(forKey: "orderedArrangements") as? [String] {
                allArrangements = a
                if #available(macOS 11.0, *) { Logger.diag.log("  from UserDefaults: \(self.allArrangements.count,privacy: .public) orderedArrangements=\(self.allArrangements, privacy: .private(mask: .hash))<>\(self.BundleID, privacy: .public)<") }
            } else if let a = CFPreferencesCopyAppValue("orderedArrangements" as CFString, BundleID as CFString) as? [String] {
                    allArrangements = a
                if #available(macOS 11.0, *) { Logger.diag.log("  from CFPrefs: \(self.allArrangements.count,privacy: .public) orderedArrangements=\(self.allArrangements, privacy: .private(mask: .hash))<>\(self.BundleID, privacy: .public)<") }
            } else {
                if #available(macOS 11.0, *) { Logger.diag.log("  no orderedArrangements in \(self.BundleID, privacy: .public)") }
                //allArrangements = ["Default", "Default 1"]
                allArrangements = ["must be one"]
                //return nil
            }
        }
        
        let menu = NSMenu()
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: "Restore\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(self.selectDMI(_:)), keyEquivalent: ""); it.target = self; it.tag = index
            menu.addItem(it)
        }
        menu.addItem(NSMenuItem.separator())
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: "Memorize\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(self.selectDMI(_:)), keyEquivalent: "");it.target = self; it.tag = index
            menu.addItem(it)
        }
        return menu
    }
    @objc func selectDMI(_ sender: NSMenuItem) {
        let name = sender.tag < 0 ? "<current>" : allArrangements[sender.tag]
        if #available(macOS 11.0, *) { Logger.diag.log("DockHelper.selectDMI sending notice: \(sender.tag, privacy: .public) \(sender.title.hasPrefix("Memorize") ? ".doMemorize" : ".doRestore", privacy: .public) name=\(name, privacy: .private(mask: .hash))< <") }
        NSWorkspace.shared.notificationCenter.post(name: sender.title.hasPrefix("Memorize") ? .doMemorize : .doRestore , object: sender.tag < 0 ? nil : name)
    }
}
