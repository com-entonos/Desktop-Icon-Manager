//
//  DIMDockTilePlugin.swift
//  DIMDockTilePlugin
//
//  Created by G.J. Parker on 5/15/25.
//  Copyright © 2025 G.J. Parker. All rights reserved.
//

import AppKit
import OSLog

@objc(DIMDockTilePlugin)
class DIMDockTilePlugin: NSObject, NSDockTilePlugIn {
    
    private var allArrangements: [String] = []
    
    var dockTile: NSDockTile?
    
    private var menu = NSMenu()  // we need the strong reference otherwise selector doesn't work
    
    private var isMainAppRunning: Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: bDIM.bID
        ).isEmpty
    }
    
    func setDockTile(_ dockTile: NSDockTile?) {
        Logger.log("DIMDockPlugin.setDockTile: dockTile !nil? \(dockTile != nil)" ,category: .lifecycle, level: .debug)
        self.dockTile = dockTile
    }
    
    func dockMenu() -> NSMenu? {
        menu = NSMenu()
        allArrangements.removeAll()
        let a = UserDefaults(suiteName: bDIM.bID)!.array(forKey: "orderedArrangements") as? [String] ?? [] // only works if not sandbox main app?
        allArrangements = a
        for index in -1..<allArrangements.count {
            let it = NSMenuItem(title: "Restore\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(self.selectMenu(_:)), keyEquivalent: ""); it.target = self; it.tag = index
            menu.addItem(it)
        }
        menu.addItem(NSMenuItem.separator())
        for index in -1..<allArrangements.count {
            let it = NSMenuItem(title: "Memorize\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(self.selectMenu(_:)), keyEquivalent: ""); it.target = self; it.tag = index
            let itA = NSMenuItem(title: "Purge\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(self.selectMenu(_:)), keyEquivalent: "");itA.target = self; itA.tag = index; itA.isAlternate = true; itA.keyEquivalentModifierMask = .option
            menu.addItem(it)
            menu.addItem(itA)
        }
        menu.addItem(NSMenuItem.separator())
        let itA = NSMenuItem(title: "Toggle icons", action: #selector(self.selectMenu(_:)), keyEquivalent: ""); itA.target = self; itA.tag = -2; menu.addItem(itA)
        menu.addItem(NSMenuItem.separator())
        let it = NSMenuItem(title: "Select missing icons", action: #selector(self.selectMenu(_:)), keyEquivalent: ""); it.target = self; it.tag = -2; menu.addItem(it)
        //Logger.log("DIMDockPlugin.dockMenu: # arrangements=\(allArrangements.count)" ,category: .lifecycle, level: .debug)
        return menu
    }
    
    @objc func selectMenu(_ sender: NSMenuItem) {
        guard let appURl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bDIM.bID) else {
            Logger.log("DIMDockPlugin.select: url for \(bDIM.gUD) failed" ,category: .lifecycle, level: .debug)
            return
        }
        
        var args: [String] = []
        let name = sender.tag < 0 ? [] : [allArrangements[sender.tag]]
        if sender.tag > -2 {
            args.append(sender.title.hasPrefix("Purge") ? "--purge" : (sender.title.hasPrefix("Memorize") ? "--update" : "--restore"))
        } else {
            args.append(sender.title.hasPrefix("Toggle") ? "--hide-icons" : "--select-missing-icons")
        }
        //Logger.diag.log("DIMDockPlugin.select going to \(args[0], privacy: .public), tag:\(sender.tag, privacy: .public) >\(name[0], privacy: .private(mask: .hash))<")

        if !self.isMainAppRunning {
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = args + name + ["--quit"]  // since we are not sandboxed, we should be able to pass arguments
            config.activates = false
            Logger.log("DIMDockPlugin.select about to open DIM with \(config.arguments)",category: .lifecycle, level: .debug)
            //Logger.diag.log("DIMDockPlugin.select about to open DIM with \(config.arguments, privacy: .private(mask: .hash))")
            NSWorkspace.shared.openApplication(at: appURl, configuration: config)
        } else {
            Logger.log("DIMDockPlugin.select failed: \(bDIM.bID) running" ,category: .lifecycle, level: .debug)
        }
    }
    
}
