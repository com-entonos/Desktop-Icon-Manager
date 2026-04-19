
//  Logger.swift
//  DIM
//
//  Created by G.J. Parker on 4/17/26.
//  Copyright © 2026 G.J. Parker. All rights reserved.
//

enum bDIM {
    static let bID = "com.parker9.DIM-4"
    static let hID = "com.parker9.DIMHelper"
    static let gUD = "group." + bID
    static let hHI = "com.entonos.HideIcons"
}

import OSLog

@available(macOS 11.0, *)
extension Logger {
    private static var subsystem = bDIM.bID
    static let scriptExecution = Logger(subsystem: subsystem, category: "ScriptExecution")
    static let ui = Logger(subsystem: subsystem, category: "UserInterface")
    static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")

    /// All logs related to tracking and analytics.
    static let diag = Logger(subsystem: subsystem, category: "info")
    static let err = Logger(subsystem: subsystem, category: "error")
    
    static func log(_ message: String, category: Logger = .lifecycle, level: OSLogType = .info) {
        // 1. Send to System Console
        switch level {
        case .debug: category.debug("\(message, privacy: .public)")
        case .error: category.error("\(message, privacy: .public)")
        case .fault: category.fault("\(message, privacy: .public)")
        default: category.info("\(message, privacy: .public)")
        }
        
        // 2. Print to Xcode Console
        let emoji = level == .error || level == .fault ? "❌" : "ℹ️"
        print("\(emoji) [\(level)] \(message)")
    }
}

/*

 extension Logger {
     //private static var subsystem = Bundle.main.bundleIdentifier!
     static let subsystem = "com.parker9.DIM-4"
     static let scriptExecution = Logger(subsystem: subsystem, category: "ScriptExecution")
     static let ui = Logger(subsystem: subsystem, category: "UserInterface")
     static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")
     
     static func log(_ message: String, category: Logger = .lifecycle, level: OSLogType = .info) {
         // 1. Send to System Console
         switch level {
         case .debug: category.debug("\(message, privacy: .public)")
         case .error: category.error("\(message, privacy: .public)")
         case .fault: category.fault("\(message, privacy: .public)")
         default: category.info("\(message, privacy: .public)")
         }
         
         // 2. Print to Xcode Console
         let emoji = level == .error || level == .fault ? "❌" : "ℹ️"
         print("\(emoji) [\(level)] \(message)")
     }
 }

 

 */
