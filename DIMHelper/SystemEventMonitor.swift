//
//  SystemEventMonitor.swift
//  DIMHelper
//
//  Created by G.J. Parker on 4/14/26.
//  Copyright © 2026 G.J. Parker. All rights reserved.
//

// wait: 10.0, data: [(10.0, ["--restore", "--quit"]), (0.5, ["--restore", "--quit"]), (0.0, [])]

import Cocoa
import OSLog


extension Notification.Name {
    static let doTest = Notification.Name("doTest")
}

final class SystemEventMonitor {
    
    private var observers: [NSObjectProtocol] = []
    
    private var isMainAppRunning: Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: bDIM.bID
        ).isEmpty
    }
    
    func start() {

        let ws = NSWorkspace.shared.notificationCenter
        let nc = NotificationCenter.default
        let cn:[ String: (NotificationCenter, NSNotification.Name)] = [
                   "wake": (ws, NSWorkspace.didWakeNotification),
             "screenWake": (ws, NSWorkspace.screensDidWakeNotification),
                 "change": (nc, NSApplication.didChangeScreenParametersNotification),
                  "sleep": (ws, NSWorkspace.willSleepNotification),
            "screenSleep": (ws, NSWorkspace.screensDidSleepNotification),
                   "test": (nc, .doTest)
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
        // otherwise default
        if data.isEmpty { data = [  "wake": (3.0, ["--restore", "--quit"]),
                                  "change": (0.5,  ["--restore", "--quit"])]
            Logger.log("WARNING: DIMHelper using default data",category: .lifecycle, level: .debug)
        }
        //  saving with UserDefaults...
        //let plistCompatibleDict = data.reduce(into: [String: [Any]]()) { (result, element) in
        //    let (key, (delay, args)) = element
        //    result[key] = [delay, args] // Store as a simple array
        //}
        //UserDefaults(suiteName: bDIM.gUD)!.set(plistCompatibleDict, forKey: "helperData")
        //UserDefaults(suiteName: bDIM.gUD)!.synchronize()
        //UserDefaults(suiteName: bDIM.gUD)!.removeObject(forKey: "helperData")
        
        //data["test"] = (1.0, ["--restore", "--quit"]); test(); Logger.log("added delay:\(data["test"]!.0) args:\(data["test"]!.1) )",category: .lifecycle, level: .debug)
        
        var events: [(NotificationCenter, NSNotification.Name, Double, [String])] = []
        for (key, (delay, args)) in data {
            if key != "startup" {
                events.append((cn[key]!.0, cn[key]!.1, delay, args))
                //Logger.log("events: nc:\(cn[key]!.0) name:\(cn[key]!.1) delay:\(delay) args:\(args)", category: .lifecycle, level: .debug)
            }
        }
        //Logger.log("events: \(events)", category: .lifecycle, level: .debug)
        if events.isEmpty {
            Logger.log("no events to observe!", category: .lifecycle, level: .debug)
            return
        }
    
        for (center, name, time, args) in events {
            //Logger.log("name:\(name) delay:\(time) args:\(args) )",category: .lifecycle, level: .debug)
            Logger.diag.log("observing for name:\(name.rawValue , privacy: .public) delay:\(time,privacy: .public) args:\(args, privacy: .private(mask: .hash))")
            let obs = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.handleEvent(time: time, args: args)
            }
            observers.append(obs)
        }
        if let (delay, args) = data["startup"] {
            handleEvent(time: delay, args: args)
            defaults.removeObject(forKey: "newData")
            defaults.synchronize()
        }
    }

    private func handleEvent(time: Double, args: [String]) {
        guard let appURl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bDIM.bID) else {
            Logger.log("failed handleEvent: url for \(bDIM.gUD) failed" ,category: .lifecycle, level: .debug)
            return
        }
        
        Logger.log("going to start in \(time) seconds...",category: .lifecycle, level: .debug)
        let GDefaults = UserDefaults(suiteName: bDIM.gUD)!
        Timer.scheduledTimer(withTimeInterval: time, repeats: false) { _ in
            if !self.isMainAppRunning {
                GDefaults.set(args, forKey: "helperArgs")
                GDefaults.synchronize()
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = args
                config.activates = false
                //Logger.log("about to open DIM with \(config.arguments)",category: .lifecycle, level: .debug)
                Logger.diag.log("about to open DIM with \(config.arguments, privacy: .private(mask: .hash))")
                NSWorkspace.shared.openApplication(at: appURl, configuration: config)
            } else {
                Logger.log("failed handleEvent: \(bDIM.bID) running" ,category: .lifecycle, level: .debug)
            }
        }
    }
    
    private func test() {
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) {_ in
            NotificationCenter.default.post(name: .doTest, object: nil)
        }
    }

    deinit {
        let ws = NSWorkspace.shared.notificationCenter
        let nc = NotificationCenter.default
        for obs in observers {
            ws.removeObserver(obs)
            nc.removeObserver(obs)
        }
    }
}

