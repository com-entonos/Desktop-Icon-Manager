//
//  DIMDockTilePlugin.swift
//  DIMDockTilePlugin
//
//  Created by G.J. Parker on 5/15/25.
//  Copyright © 2025 G.J. Parker. All rights reserved.
//

import AppKit
import OSLog

class DIMDockTilePlugin: NSObject, NSDockTilePlugIn {
    let SUBSYSTEM = "DIMDTP" //"com.parker9.DIMDockTilePlugin" //"DIMDockTilePlugin.docktileplugin"
    let BundleID = "com.parker9.DIM-4"
    let dockHelper = DockHelper()
    
    var orderedArrangements = [String]()
   // var allArrangements = [String]()
    
   // let noticeNewArrangement = NSWorkspace.shared.notificationCenter.addObserver(forName: NSNotification.Name("newArrangement"), object: nil, queue: .main, using: { notice in
   //     if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("DIMDockTilePlugin.notification newArrangement recieved:\(notice.object as? [String] ?? ["nil"], privacy: .public)<")}
   //     if let list = notice.object as? [String] { UserDefaults.standard.set(list, forKey: "orderedArrangements")} })

    override init() {
        super.init()
        if #available(macOS 11.0, *) { Logger.diag.log("DIMDockTilePlugin.init Bundle=\(Bundle(for: DIMDockTilePlugin.self).bundleIdentifier ?? "no bundle",privacy: .public)<>\(Bundle.main.bundleIdentifier ?? "no main bundle",privacy: .public)< \(NSWorkspace.shared.runningApplications.map {$0.bundleIdentifier},privacy: .public)") }
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.saveUserDefaults(_:)), name: Notification.Name("newArrangement"), object: nil)
        /*DistributedNotificationCenter.default().addObserver(forName: .newArrangement, object: nil , queue: .main, using: { notice in
            if #available(macOS 11.0, *) { Logger.diag.log("DIMDockTilePlugin.distributedNot newArrangement recieved=\(notice.name.rawValue ,privacy: .public)<>\(notice.userInfo?["orderedArrangements"] as? [String] ?? [""],privacy: .public)<") }
            if let list = notice.userInfo?["orderedArrangements"] as? [String] {
                UserDefaults.standard.set(list, forKey: "orderedArrangements")
                self.orderedArrangements = list
            }
        })*/
    }
    @objc func saveUserDefaults(_ notice: Notification) {
         if #available(macOS 11.0, *) { Logger.diag.log("DIMDockTilePlugin distributedNot newArrangement recieved=\(notice.name.rawValue ,privacy: .public)<>\(notice.userInfo?["orderedArrangements"] as? [String] ?? [""],privacy: .public)<") }
         //if let list = notice.userInfo?["orderedArrangements"] as? [String] { UserDefaults.standard.set(list, forKey: "orderedArrangements") }
         if let list = notice.userInfo?["orderedArrangements"] as? [String] { orderedArrangements = list}
     }/**/
    
    func setDockTile(_ dockTile: NSDockTile?) {
        if #available(macOS 11.0, *) { Logger.diag.log("DIMDockTilePlugin.setDockTile \(dockTile?.className ?? "", privacy: .public)") }
        if let _ = dockTile {
      /*      NSWorkspace.shared.notificationCenter.addObserver(forName: NSNotification.Name("newArrangement"), object: nil, queue: .main, using: { notice in
                if #available(macOS 11.0, *) { Logger.diag.log("DIMDockTilePlugin.WSnotification newArrangement recieved:\(notice.object as? [String] ?? ["nil"], privacy: .public)<")}
                if let list = notice.object as? [String] { UserDefaults.standard.set(list, forKey: "orderedArrangements")} })
            NotificationCenter.default.addObserver(forName: NSNotification.Name("newArrangement"), object: nil, queue: .main, using: { notice in
                if #available(macOS 11.0, *) { Logger.diag.log("DIMDockTilePlugin.notification newArrangement recieved:\(notice.object as? [String] ?? ["nil"], privacy: .public)<")}
                if let list = notice.object as? [String] { UserDefaults.standard.set(list, forKey: "orderedArrangements")} }) */
        } else {
            //NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSNotification.Name("newArrangement"), object: nil)
            //NotificationCenter.default.removeObserver(self, name: NSNotification.Name("newArrangement"), object: nil)
            DistributedNotificationCenter.default().removeObserver(self, name: .newArrangement, object: nil)
            if #available(macOS 11.0, *) { Logger.diag.log("DIMDockTilePlugin.notification stopped")}
        }
        dockHelper.setDockTile(dockTile)
    }
    func dockMenu() -> NSMenu? {
        if #available(macOS 11.0, *) { Logger.diag.log("DIMDockTilePlugin.dockMenu") }
        return dockHelper.setMenu(orderedArrangements)
/*
        allArrangements.removeAll()
        if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  'orderedArrangements' exist?\(UserDefaults.standard.array(forKey: "orderedArrangements") != nil ,privacy: .public) [String]? \(UserDefaults.standard.array(forKey: "orderedArrangements") as? [String] ?? [" "],privacy: .public) Bunldle.main.ID=\(Bundle.main.bundleIdentifier ?? "nothing", privacy: .public)<") }
        if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  CFPreferencesCopyAppValue exist? \(CFPreferencesCopyAppValue("orderedArrangements" as CFString, self.BundleID as CFString) != nil,privacy: .public) [String]? \(CFPreferencesCopyAppValue("orderedArrangements" as CFString, self.BundleID as CFString) as? [String] ?? [" "], privacy: .public)<>\(self.BundleID, privacy: .public)<") }
        
        if let a = UserDefaults.standard.array(forKey: "orderedArrangements") as? [String] {
            allArrangements = a
            if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  from user defaults: \(self.allArrangements.count,privacy: .public) orderedArrangements=\(self.allArrangements, privacy: .public)<>\(self.BundleID, privacy: .public)<") }
        } else if let a = CFPreferencesCopyAppValue("orderedArrangements" as CFString, BundleID as CFString) as? [String] {
            allArrangements = a
            if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  CFP \(self.BundleID,privacy: .public) defaults: \(self.allArrangements.count,privacy: .public) orderedArrangements=\(self.allArrangements, privacy: .public)<>\(self.BundleID, privacy: .public)<") }
        } else if let a = CFPreferencesCopyAppValue("orderedArrangements" as CFString, Bundle(for: DIMDockTilePlugin.self).bundleIdentifier! as CFString) as? [String] {
            allArrangements = a
            if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  CFP \(Bundle(for: DIMDockTilePlugin.self).bundleIdentifier!,privacy: .public) defaults: \(self.allArrangements.count,privacy: .public) orderedArrangements=\(self.allArrangements, privacy: .public)<>\(self.BundleID, privacy: .public)<") }
        } else {
            if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  no orderedArrangements in \(self.BundleID, privacy: .public)") }
            allArrangements = ["Default"] //allArrangements = ["Default", "Default 1"]
            //return nil
        }
    
        
        let menu = NSMenu()
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: "Restore \(index < 0 ? "<current>" : allArrangements[index])", action: #selector(selectDMIP(_:)), keyEquivalent: ""); it.target = self; it.tag = index; it.isEnabled = true
            menu.addItem(it)
        }
        menu.addItem(NSMenuItem.separator())
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: "Memorize \(index < 0 ? "<current>" : allArrangements[index])", action: #selector(selectDMIP(_:)), keyEquivalent: "");it.target = self; it.tag = index; it.isEnabled = true
            menu.addItem(it)
        }
        if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  return menu: \(menu.numberOfItems, privacy: .public)") }
        return menu
    }
    @objc func selectDMIP(_ sender: NSMenuItem) {
        let name = sender.tag < 0 ? "<current>" : allArrangements[sender.tag]
        if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("DIMDockTilePlugin.selectDMI: name=\(name, privacy: .public)<\(sender.tag, privacy: .public)>\(sender.title, privacy: .public)<") }
        if NSWorkspace.shared.runningApplications.first(where: { app in app.bundleIdentifier == BundleID}) != nil {
            let cmd0 = sender.title.hasPrefix("Memorize") ? "doMemorize" : "doRestore"
            if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  sending notification \(sender.title, privacy: .public) ->\(cmd0, privacy: .public), obj=\(sender.tag < 0 ? "nil" : name, privacy: .public)<-") }
            NSWorkspace.shared.notificationCenter.post(name: NSNotification.Name(cmd0), object: sender.tag < 0 ? nil : name)
        } else {
            let cmd0 = "open -b \(BundleID) --args " + (sender.title.hasPrefix("Memorize") ? "--memorize" : "--restore") + (sender.tag < 0 ? "" : (#" ""# + name + #"""#)) + " --quit"
            if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  send zsh command ->\(cmd0, privacy: .public)<-") }
            try? saveShell(cmd0)
        }
        let cmd0 = "open -b \(BundleID) --args " + (sender.title.hasPrefix("Memorize") ? "--memorize" : "--restore") + (sender.tag < 0 ? "" : (#" ""# + name + #"""#)) + " --quit"
        if #available(macOS 11.0, *) { Logger(subsystem: SUBSYSTEM, category: "info").log("  would be send zsh command ->\(cmd0, privacy: .public)<-") }
    }
    func saveShell(_ command: String) throws {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe; task.standardError = pipe; task.standardInput = nil
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        try task.run()
        
        return
   */
    }
}




//
//  DockerHelper.swift
//  DIM
//
//  Created by G.J. Parker on 5/17/25.
//  Copyright © 2025 G.J. Parker. All rights reserved.
//


import AppKit
import OSLog

extension Notification.Name {
    static let doRestore = Notification.Name("doRestore")
    static let doMemorize = Notification.Name("doMemorize")
    static let newArrangement = Notification.Name("newArrangement")
}
@available(macOS 11.0, *)
extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static let subsystem = "com.parker9.DIM-4" //Bundle.main.bundleIdentifier!

    /// All logs related to tracking and analytics.
    static let diag = Logger(subsystem: subsystem, category: "info")
    static let err = Logger(subsystem: subsystem, category: "error")
}


//class DockHelper: NSResponder {
class DockHelper {
    let BundleID = "com.parker9.DIM-4"
    var allArrangements = [String]()
    var isMain = false
    
    let SUBSYTEM = "DIMDTP" //"com.parker9.DIMDockTilePlugin" //"DIMDockTilePlugin.docktileplugin"
    
    init() {
  //  override init() {
 //       super.init()
        isMain = (BundleID == Bundle(for: DockHelper.self).bundleIdentifier ?? "com.parker9.DIM-4")
        if #available(macOS 11.0, *) { Logger.diag.log("DockHelper.init: isMain? \(self.isMain, privacy: .public) >bundleID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)<") }
    }
 /*   init(_ bundle : String = "com.parker9.DIM-4") {
        super.init()
        isMain = (BundleID == Bundle(for: DockHelper.self).bundleIdentifier ?? bundle)
        if #available(macOS 11.0, *) { Logger(subsystem: subsystem, category: "info").log("DockHelper.init: isMain? \(self.isMain, privacy: .public) >bundleID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)<") }
    } */
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setDockTile(_ dockTile: NSDockTile?) {
        if #available(macOS 11.0, *) { Logger.diag.log("DockHelper.setDockTile: bundleID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)<- \(dockTile == nil ? "no dockTile":dockTile!.className, privacy: .public)< isMain? \(self.isMain, privacy: .public)") }
    }
    
    func setMenu(_ arrangements : [String]? = nil) -> NSMenu? {
        if #available(macOS 11.0, *) { Logger.diag.log("DockHelper.setMenu: isMain? \(self.isMain, privacy: .public), bundlID=\(self.BundleID, privacy: .public)< this bundleID=\(Bundle(for: DockHelper.self).bundleIdentifier ?? "nothing", privacy: .public)< ") }
        allArrangements.removeAll()
        if #available(macOS 11.0, *) { Logger.diag.log("  arrangements exist?\(arrangements != nil ,privacy: .public) \(arrangements != nil ? arrangements!.count : -1,privacy: .public) [String]? \(arrangements ?? [" "],privacy: .public)<") }
        if arrangements != nil && !(arrangements?.isEmpty ?? true) { allArrangements = arrangements! } else {
            CFPreferencesAppSynchronize(BundleID as CFString)
            
            if #available(macOS 11.0, *) { Logger.diag.log("  'orderedArrangements' exist?\(UserDefaults.standard.array(forKey: "orderedArrangements") != nil ,privacy: .public) [String]? \(UserDefaults.standard.array(forKey: "orderedArrangements") as? [String] ?? [" "],privacy: .public) Bunldle.main.ID=\(Bundle.main.bundleIdentifier ?? "nothing", privacy: .public)<") }
            if #available(macOS 11.0, *) { Logger.diag.log("  suiteName exist? \(UserDefaults(suiteName: self.BundleID)?.array(forKey: "orderedArrangements") != nil,privacy: .public)<=\(UserDefaults(suiteName: self.BundleID)?.array(forKey: "orderedArrangements") as? [String] != nil, privacy: .public)<>\(self.BundleID, privacy: .public)<") }
            if #available(macOS 11.0, *) { Logger.diag.log("  CFPreferencesCopyAppValue exist? \(CFPreferencesCopyAppValue("orderedArrangements" as CFString, self.BundleID as CFString) != nil,privacy: .public) [String]? \(CFPreferencesCopyAppValue("orderedArrangements" as CFString, self.BundleID as CFString) as? [String] ?? [" "], privacy: .public)<>\(self.BundleID, privacy: .public)<") }
            
            let aa = CFPreferencesCopyAppValue("orderedArrangements" as CFString, BundleID as CFString) as Any?
            if #available(macOS 11.0, *) { Logger.diag.log("  casting Any? \(aa != nil,privacy: .public) aa as [String]=\(aa as? [String] ?? ["nil"], privacy: .public)<>\(self.BundleID, privacy: .public)<") }
            
            if let a = UserDefaults.standard.array(forKey: "orderedArrangements") as? [String] {
                allArrangements = a
                if #available(macOS 11.0, *) { Logger.diag.log("  from UserDefaults: \(self.allArrangements.count,privacy: .public) orderedArrangements=\(self.allArrangements, privacy: .public)<>\(self.BundleID, privacy: .public)<") }
            } else if let a = CFPreferencesCopyAppValue("orderedArrangements" as CFString, BundleID as CFString) as? [String] {
                //if let a = CFPreferencesCopyValue("orderedArrangements" as CFString, BundleID as CFString, kCFPreferencesCurrentUser,kCFPreferencesCurrentHost) as? [String] {
                    allArrangements = a
                if #available(macOS 11.0, *) { Logger.diag.log("  from CFPrefs: \(self.allArrangements.count,privacy: .public) orderedArrangements=\(self.allArrangements, privacy: .public)<>\(self.BundleID, privacy: .public)<") }
            } else {
                if #available(macOS 11.0, *) { Logger.diag.log("  no orderedArrangements in \(self.BundleID, privacy: .public)") }
                //allArrangements = ["Default", "Default 1"]
                allArrangements = ["must be one"]
                //return nil
            }
        }
        
        let menu = NSMenu()
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: "Restore\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(self.selectDMIP(_:)), keyEquivalent: ""); it.target = self; it.tag = index
            menu.addItem(it)
        }
        menu.addItem(NSMenuItem.separator())
        for index in -1..<(allArrangements.count > 1 ? allArrangements.count : 0) {
            let it = NSMenuItem(title: "Memorize\(index < 0 ? "" : (" " + allArrangements[index]))", action: #selector(self.selectDMIP(_:)), keyEquivalent: "");it.target = self; it.tag = index
            menu.addItem(it)
        }
        if #available(macOS 11.0, *) { Logger.diag.log("  return menu: \(menu.numberOfItems, privacy: .public)") }
        return menu
    }
    @objc func selectDMIP(_ sender: NSMenuItem) {
        let name = sender.tag < 0 ? "<current>" : allArrangements[sender.tag]
        if #available(macOS 11.0, *) { Logger.diag.log("DockHelper.selectDMI: name=\(name, privacy: .public)<\(sender.tag, privacy: .public)>\(sender.title, privacy: .public)<") }
        if NSWorkspace.shared.runningApplications.first(where: { app in app.bundleIdentifier == BundleID}) != nil {
            let cmd0 = sender.title.hasPrefix("Memorize") ? "doMemorize" : "doRestore"
            if #available(macOS 11.0, *) { Logger.diag.log("  sending notification \(sender.title, privacy: .public) ->\(cmd0, privacy: .public), obj=\(sender.tag < 0 ? "nil" : name, privacy: .public)<-") }
            NSWorkspace.shared.notificationCenter.post(name: NSNotification.Name(cmd0), object: sender.tag < 0 ? nil : name)
        } else {
            let cmd0 = "open -b \(BundleID) --args " + (sender.title.hasPrefix("Memorize") ? "--add" : "--restore") + (sender.tag < 0 ? "" : (#" ""# + name + #"""#)) + " --quit"
            if #available(macOS 11.0, *) { Logger.diag.log("  send zsh command ->\(cmd0, privacy: .public)<-") }
            try? saveShell(cmd0)
        }
        let cmd0 = "open -b \(BundleID) --args " + (sender.title.hasPrefix("Memorize") ? "--add" : "--restore") + (sender.tag < 0 ? "" : (#" ""# + name + #"""#)) + " --quit"
        if #available(macOS 11.0, *) { Logger.diag.log("  would be send zsh command ->\(cmd0, privacy: .public)<-") }
    }
    func saveShell(_ command: String) throws {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe; task.standardError = pipe; task.standardInput = nil
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        try task.run()
        
        return
    }
}
