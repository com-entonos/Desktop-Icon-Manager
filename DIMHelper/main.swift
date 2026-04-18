//
//  main.swift
//  DIMHelper
//
//  Created by G.J. Parker on 4/17/26.
//  Copyright © 2026 G.J. Parker. All rights reserved.
//

import AppKit

MainActor.assumeIsolated {  // this wrapper is for Swift 6 to shut up
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    
    app.run()
}
