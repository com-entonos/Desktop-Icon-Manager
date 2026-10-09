//
//  AppDelegate.swift
//  DIM
//
//  Created by G.J. Parker on 19/1/17.
//  Copyright © 2026 G.J. Parker. All rights reserved.
//

import Cocoa

extension Notification.Name {
    static let doMemorizeButton = Notification.Name("doMemorizeButton")
    static let atEnd = NSNotification.Name("atEnd")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var exportMenuItem : NSMenuItem!
    @IBOutlet weak var checkUpdateMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "startHidden") != nil ? defaults.bool(forKey: "startHidden") : false { NSApplication.shared.hide(self) }
        NSApplication.shared.disableRelaunchOnLogin()
        if !FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.path+"/Library/Preferences/" + bDIM.bID + ".plist") {
            exportMenuItem.isEnabled = false
        }
    }
    func applicationWillTerminate(_ aNotification: Notification) {
        NotificationCenter.default.post(name: .atEnd, object: nil)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        return true
    }
    
    /*  do applicationDockMenu? */
    let dockHelper = DockHelper()
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return dockHelper.dockMenu()
    }/**/
}

/* try to keep Memorize/Purge button display correctly */
extension AppDelegate: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {  NotificationCenter.default.post(name: .doMemorizeButton, object: nil) } // in case menu is dismissed
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) { NotificationCenter.default.post(name: .doMemorizeButton, object: nil) } // update button as we select different menu items- can't seem to catch key down when menu open
}
/**/
