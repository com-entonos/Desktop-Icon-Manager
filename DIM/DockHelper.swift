//
//  DockHelper.swift
//  DIM
//
//  Created by G.J. Parker on 5/14/25.
//  Copyright © 2025 G.J. Parker. All rights reserved.
//

import Foundation
import AppKit
import OSLog

class DockHelper {
    let BundleID = "com.parker9.DIM-4" //"com.parker9.DIMDockTilePlugin"
    var allArrangements = [String]()
    var isMain = false
    
    let subsystem = "DIMDTP"
    
    init(_ bundle : String = "com.parker9.DIM-4") { isMain = (BundleID == Bundle(for: DockHelper.self).bundleIdentifier ?? bundle) }
    
    func setDockTile(_ dockTile: NSDockTile?) {
        print("bundlID=\(self.BundleID)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing")<- \(dockTile == nil ? "no dockTile":dockTile!.className,)< \(self.isMain)")
        if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("bundleID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)<- \(dockTile == nil ? "no dockTile":dockTile!.className, privacy: .public)< isMain? \(self.isMain, privacy: .public)") }
    }
    
    func setMenu(_ arrangements : [String]? = nil) -> NSMenu? {
        if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("isMain? \(self.isMain, privacy: .public), bundlID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)< \(self.isMain, privacy: .public)<") }
        allArrangements.removeAll()
        if arrangements != nil { allArrangements = arrangements! } else {
            CFPreferencesAppSynchronize(BundleID as CFString)
            if let a = CFPreferencesCopyAppValue("orderedArrangements" as CFString, BundleID as CFString) as? [String] {
                allArrangements = a
                if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("\(self.allArrangements.count,privacy: .public) orderedArrangements=\(self.allArrangements, privacy: .public)<") }
            } else {
                if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("no orderedArrangements in \(self.BundleID, privacy: .public)") }
                return nil
            }
        }
        
        let menu = NSMenu()
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: "Restore\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(selectDMI(_:)), keyEquivalent: ""); it.target = self; it.tag = index
            menu.addItem(it)
        }
        menu.addItem(NSMenuItem.separator())
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: "Memorize\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(selectDMI(_:)), keyEquivalent: "");it.target = self; it.tag = index
            menu.addItem(it)
        }
        if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("return menu: \(menu.numberOfItems, privacy: .public)") }
        return menu
    }
    @objc func selectDMI(_ sender: NSMenuItem) {
        let name = sender.tag < 0 ? "<current>" : allArrangements[sender.tag]
        print("dockMenu custom item called \(sender.title) \(sender.tag) \(name)")
        if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("item called \(sender.title, privacy: .public) \(sender.tag, privacy: .public) \(name, privacy: .public)") }
        if NSWorkspace.shared.runningApplications.first(where: { app in app.bundleIdentifier == BundleID}) != nil {
            let cmd0 = sender.title.hasPrefix("Memorize") ? "doMemorize" : "doRestore"
            print("send notification \(sender.title) \(sender.tag) ->\(cmd0), obj=\(sender.tag < 0 ? "nil" : name)<-")
            if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("send notification \(sender.title, privacy: .public) ->\(cmd0, privacy: .public), obj=\(sender.tag < 0 ? "nil" : name, privacy: .public)<-") }
            NSWorkspace.shared.notificationCenter.post(name: NSNotification.Name(cmd0), object: sender.tag < 0 ? nil : name)
        } else {
            let cmd0 = "open -b \(BundleID) --args " + (sender.title.hasPrefix("Memorize") ? "--memorize" : "--restore") + (sender.tag < 0 ? "" : (#" ""# + name + #"""#)) + " --quit"
            print("send zsh command \(sender.title) ->\(cmd0)<-")
            if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("send zsh command ->\(cmd0, privacy: .public)<-") }
            try? saveShell(cmd0)
        }
    }
    func saveShell(_ command: String) throws {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe; task.standardError = pipe; task.standardInput = nil
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        try task.run()
        
        return
    }
}
