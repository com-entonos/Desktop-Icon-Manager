//
//  AppDelegate.swift
//  DIMHelper
//
//  Created by G.J. Parker on 4/15/26.
//  Copyright © 2026 G.J. Parker. All rights reserved.
//


import Cocoa
import OSLog

class AppDelegate: NSObject, NSApplicationDelegate {

    private var eventMonitor: SystemEventMonitor?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger.log("about to spawn SystemEventMonitor", level: .debug)
        NSApp.setActivationPolicy(.prohibited)
        eventMonitor = SystemEventMonitor()
        eventMonitor?.start()
        if eventMonitor == nil {Logger.log("FAILED to spawn SystemEventMonitor", level: .debug)}
    }
}
