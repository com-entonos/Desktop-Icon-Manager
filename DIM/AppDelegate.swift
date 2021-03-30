//
//  AppDelegate.swift
//  DIM 3.0
//
//  Created by G.J. Parker on 19/1/17.
//  Copyright © 2019 G.J. Parker. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    //var dim = DIM()     // AppleScriptObjC bridge
    let hider = Hider() // class is now listening for toggle
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //print("in applicationDidFinishLaunching")
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.powerOff), name: NSWorkspace.willPowerOffNotification, object: nil)
    }
    func applicationWillTerminate(_ aNotification: Notification) {
        //print("in applicationWillTerminate")
        NotificationCenter.default.post(name: NSNotification.Name("atEnd"), object: nil)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    @objc func powerOff(notification: NSNotification) { // does this catch logoff, restart and shutdown?
        //print("in powerOff")
        NSApplication.shared.terminate(self)
    }
    
}

