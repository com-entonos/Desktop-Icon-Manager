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
        //if #available(macOS 11.0, *) { Logger(subsystem: "DIMDTP", category: "info").log("applicationDockMenu called, return dockHelper.setMenu()") }
        return dockHelper.setMenu()
    }
}
