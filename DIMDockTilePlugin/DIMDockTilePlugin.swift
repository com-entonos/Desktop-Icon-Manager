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
    override init() {
        if #available(macOS 11.0, *) { Logger(subsystem: "DIMDTP", category: "info").log("init DIMDockTilePlugin Bundle=\(Bundle(for: DIMDockTilePlugin.self).bundleIdentifier ?? "no bundle",privacy: .public)") }
    }
  //  private let dockHelper = DockHelper()
    
    func setDockTile(_ dockTile: NSDockTile?) {
        if #available(macOS 11.0, *) { Logger(subsystem: "DIMDTP", category: "info").log("in DIMDockTilePlugin.setDockTile \(dockTile?.className ?? "", privacy: .public)") }
   //     DockHelper().setDockTile(dockTile)
    }
    func dockMenu() -> NSMenu? {
        if #available(macOS 11.0, *) { Logger(subsystem: "DIMDTP", category: "info").log("in DIMDockTilePlugin.dockMenu") }
    //    return dockHelper.setMenu()
        return nil
    }
}
