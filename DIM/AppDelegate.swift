//
//  AppDelegate.swift
//  DIM
//
//  Created by G.J. Parker on 19/1/17.
//  Copyright © 2021 G.J. Parker. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var exportMenuItem : NSMenuItem!
    @IBOutlet weak var checkUpdateMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.powerOff), name: NSWorkspace.willPowerOffNotification, object: nil)
        if !FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.path+"/Library/Preferences/com.parker9.DIM-4.plist") {
            exportMenuItem.isEnabled = false
        }
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
    
}

