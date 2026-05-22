//
//  SystemEventMonitor.swift
//  DIMHelper
//
//  Created by G.J. Parker on 4/14/26.
//  Copyright © 2026 G.J. Parker. All rights reserved.
//

import Cocoa
import OSLog


extension Notification.Name {
    static let doHelperTimer = Notification.Name("doHelperTimer")
}

final class SystemEventMonitor {
    
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    
    private var isMainAppRunning: Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: bDIM.bID
        ).isEmpty
    }
    
    func start() {

        let ws = NSWorkspace.shared.notificationCenter
        let nc = NotificationCenter.default
        let dc = DistributedNotificationCenter.default()
        let cn:[ String: [(NotificationCenter, NSNotification.Name)]] = [
                   "wake": [(ws, NSWorkspace.didWakeNotification)],
             "screenWake": [(ws, NSWorkspace.screensDidWakeNotification)],
                 "change": [(nc, NSApplication.didChangeScreenParametersNotification)],
                  "sleep": [(ws, NSWorkspace.willSleepNotification)],
            "screenSleep": [(ws, NSWorkspace.screensDidSleepNotification)],
                  "mount": [(ws, NSWorkspace.didMountNotification)],
                "unmount": [(ws, NSWorkspace.didUnmountNotification)],
                 "unlock": [(ws, NSWorkspace.sessionDidBecomeActiveNotification),
                            (dc, NSNotification.Name("com.apple.screenIsUnlocked")),
                            (dc, NSNotification.Name("com.apple.screensaver.didstop"))], // "com.apple.screenIsLocked", "com.apple.screensaver.didstart" and "com.apple.screensaver.willstop" also available?
                  "power": [(ws, NSWorkspace.willPowerOffNotification)],
               "interval": [(nc, .doHelperTimer)]
        ]
        
        // what is requested?
        let defaults = UserDefaults(suiteName: bDIM.gUD)!
        let rawData = defaults.dictionary(forKey: "helperData") ?? [:]
        var data: [String: (Double, [String])] = [:]
        for (key, value) in rawData {
            if let entry = value as? [Any],
               let delay = entry.first as? Double,
               let args = entry.last as? [String] {
                data[key] = (delay, args)
            }
        }
      /*UserDefaults(suiteName: bDIM.gUD)!.set(plistCompatibleDict, forKey: "helperData")
        UserDefaults(suiteName: bDIM.gUD)!.synchronize()
        UserDefaults(suiteName: bDIM.gUD)!.removeObject(forKey: "helperData") */
        
        //data["interval"] = (1.0, ["--restore", "--quit"]); Logger.log("added \"timer\": delay=\(data["timer"]!.0) args=\(data["timer"]!.1) )",category: .lifecycle, level: .debug)
        //data["startup"] = (0.0, ["--quit"])
        
        var events: [(NotificationCenter, NSNotification.Name, Double, [String])] = []
        for (key, (delay, args)) in data {
            if let actions = cn[key] {
                for (c,n) in actions {
                    events.append((c, n, delay, args))
                    //Logger.log("events: nc:\(c) name:\(n) delay:\(delay) args:\(args)", category: .lifecycle, level: .debug)
                }
            }
        }
        //Logger.log("events: \(events)", category: .lifecycle, level: .debug)
        if events.isEmpty {
            Logger.log("no events to observe!", category: .lifecycle, level: .debug)
            return
        }
    
        for (center, name, time, args) in events {
            //Logger.log("observing for name:\(name) delay:\(time) args:\(args) )",category: .lifecycle, level: .debug)
            Logger.diag.log("observing for name:\(name.rawValue , privacy: .public) delay:\(time,privacy: .public) args:\(args, privacy: .private(mask: .hash))")
            let obs = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.handleEvent(time:  name == .doHelperTimer ? 0.0 : time, args: args, note: name.rawValue)
            }
            observers.append((center,obs))
        }
        // start any timer...
        if let (interval, _) = data["interval"] { timer(interval: interval * 60) }
        
        // assume this is login if main app is not running
        if let (delay, args) = data["startup"], !isMainAppRunning { handleEvent(time: delay, args: args, note: "startup") }
    }

    private func handleEvent(time: Double, args: [String], note: String) {
        guard let appURl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bDIM.bID) else {
            Logger.log("failed handleEvent: url for \(bDIM.gUD) failed" ,category: .lifecycle, level: .debug)
            return
        }
        
        Logger.log("going to \(note) in \(time) seconds...",category: .lifecycle, level: .debug)
        let GDefaults = UserDefaults(suiteName: bDIM.gUD)!
        Timer.scheduledTimer(withTimeInterval: time, repeats: false) { _ in
            if !self.isMainAppRunning {
                GDefaults.set(args, forKey: "helperArgs")
                GDefaults.synchronize()
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = args
                config.activates = false
                Logger.log("about to open DIM with \(config.arguments)",category: .lifecycle, level: .debug)
                Logger.diag.log("about to open DIM with \(config.arguments, privacy: .private(mask: .hash))")
                NSWorkspace.shared.openApplication(at: appURl, configuration: config)
            } else {
                Logger.log("failed handleEvent: \(bDIM.bID) running" ,category: .lifecycle, level: .debug)
            }
        }
    }
    
    private func timer(interval: Double) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {_ in
            NotificationCenter.default.post(name: .doHelperTimer, object: nil)
        }
    }

    deinit {
        for (c,obs) in observers {
            c.removeObserver(obs)
        }
    }
}

