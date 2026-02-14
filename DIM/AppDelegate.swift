//
//  AppDelegate.swift
//  DIM
//
//  Created by G.J. Parker on 19/1/17.
//  Copyright © 2021 G.J. Parker. All rights reserved.
//

import Cocoa
import OSLog

extension Notification.Name {
    static let doMemorizeButton = Notification.Name("doMemorizeButton")
    static let atEnd = NSNotification.Name("atEnd")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var exportMenuItem : NSMenuItem!
    @IBOutlet weak var checkUpdateMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if UserDefaults.standard.object(forKey: "startHidden") != nil ? UserDefaults.standard.bool(forKey: "startHidden") : false { NSApplication.shared.hide(self) }
      //NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main, using: { note in NSApplication.shared.mainWindow?.performClose(nil)})
        NSApplication.shared.disableRelaunchOnLogin()
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
        NotificationCenter.default.post(name: .atEnd, object: nil)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        return false
    }
    
    /*  do applicationDockMenu? */
    let dockHelper = DockHelper()
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        //if #available(macOS 11.0, *) { Logger(subsystem: "DIMDTP", category: "info").log("applicationDockMenu called, return dockHelper.setMenu()") }
        return dockHelper.dockMenu()
    }/**/
}

/* try to keep Memorize/Purge button display correctly */
extension AppDelegate: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {  NotificationCenter.default.post(name: .doMemorizeButton, object: nil) } // in case menu is dismissed
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) { NotificationCenter.default.post(name: .doMemorizeButton, object: nil) } // update button as we select different menu items- can't seem to catch key down when menu open
}
/**/
