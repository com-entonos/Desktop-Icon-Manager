//
//  AppDelegate.swift
//  DIM
//
//  Created by G.J. Parker on 19/1/17.
//  Copyright © 2021 G.J. Parker. All rights reserved.
//

import Cocoa
import OSLog

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var exportMenuItem : NSMenuItem!
    @IBOutlet weak var checkUpdateMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.powerOff), name: NSWorkspace.willPowerOffNotification, object: nil)
        if !FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.path+"/Library/Preferences/com.parker9.DIM-4.plist") {
            exportMenuItem.isEnabled = false
        }
        /** //place holder if we ever want to deal w/ the dock 
        print("contentView=\(NSApp.dockTile.contentView)")
            print(NSApp.dockTile)
        let x = NSApp.applicationIconImage!
        x.backgroundColor = .systemRed
        print(x.backgroundColor)
        print(x)
        NSApp.dockTile.contentView = NSImageView(image: x)
        
        NSApp.dockTile.badgeLabel = "2 (0)"
        NSApp.dockTile.showsApplicationBadge = true
        NSApp.dockTile.display()
        print("contentView=\(NSApp.dockTile.contentView)")
        let imageView = NSApp.dockTile.contentView as! NSImageView
        print(imageView.isEditable,imageView.image?.size)
        print("image=\(imageView.image?.backgroundColor.hueComponent)")
        imageView.image?.backgroundColor.hueComponent
         */
    }
    func applicationWillTerminate(_ aNotification: Notification) {
        NotificationCenter.default.post(name: NSNotification.Name("atEnd"), object: nil)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    @objc func powerOff(notification: NSNotification) { // does this catch logoff, restart and shutdown?
        NSApplication.shared.terminate(self)
    }
    
    // do applicationDockMenu?
    let dockHelper = DockHelper()
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        if #available(macOS 11.0, *) { Logger(subsystem: "DIMDTP", category: "info").log("in applicationDockMenu") }
        return dockHelper.setMenu()
    }
/*
    
    let BundleID = Bundle.main.bundleIdentifier ?? "com.parker9.DIM-4"
    var allArrangements = [String]()
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        allArrangements.removeAll()
        if #available(macOS 11.0, *) { Logger.diag.info("applicationDockMenu called \(self.BundleID, privacy: .public)") }
        print("applicationDockMenu called \(BundleID)")
        CFPreferencesAppSynchronize(BundleID as CFString)
        if let arrangements = CFPreferencesCopyAppValue("orderedArrangements" as CFString, BundleID as CFString) as? [String] {
            if #available(macOS 11.0, *) { Logger.diag.info("applicationDockMenu created menu: \(arrangements.count, privacy: .public) \(arrangements, privacy: .public)") }
            print("applicationDockMenu created menu: \(arrangements.count) \(arrangements)")
            allArrangements = arrangements
            
            let menu = NSMenu()
            for index in -1..<(arrangements.count > 1 ? arrangements.count : 0) {
                let it = NSMenuItem(title: "Restore\(index < 0 ? "" : (" " + arrangements[index]))", action: #selector(selectDMI(_:)), keyEquivalent: ""); it.target = self; it.tag = index; menu.addItem(it)
            }
            menu.addItem(NSMenuItem.separator())
            for index in -1..<(arrangements.count > 1 ? arrangements.count : 0) {
                let it = NSMenuItem(title: "Memorize\(index < 0 ? "" : (" " + arrangements[index]))", action: #selector(selectDMI(_:)), keyEquivalent: ""); it.target = self; it.tag = index; menu.addItem(it)
            }
            return menu
        }
        return nil
    }
    @objc func selectDMI(_ sender: NSMenuItem) { // send notification to do the corresponding menu item selected
        let name = sender.tag < 0 ? "<current>" : allArrangements[sender.tag]
        print("applicationDockMenu custom item called, send notification \(sender.title) \(sender.tag) ->\(sender.title.hasPrefix("Memorize") ? ".doMemorize" : ".doRestore") \(sender.tag < 0 ? "" : name)<-")
        if #available(macOS 11.0, *) { Logger.diag.info("applicationDockMenu custom item called, send notifiction \(sender.title, privacy: .public) \(sender.tag, privacy: .public) ->\(sender.title.hasPrefix("Memorize") ? ".doMemorize" : ".doRestore", privacy: .public), obj=\(sender.tag < 0 ? "" : name, privacy: .public)<-") }
        NSWorkspace.shared.notificationCenter.post(name: sender.title.hasPrefix("Memorize") ? .doMemorize : .doRestore, object: sender.tag < 0 ? nil : name)
        
        let cmd0 = "open -b \(BundleID) --args " + (sender.title.hasPrefix("Memorize") ? "--memorize" : "--restore") + (sender.tag < 0 ? "" : (#" ""# + name + #"""#)) + " --quit"
        if #available(macOS 11.0, *) { Logger.diag.info("would be zsh: ->\(cmd0, privacy: .public)<-")}
    }
*/
}

