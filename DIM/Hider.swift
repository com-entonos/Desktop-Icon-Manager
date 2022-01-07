//
//  Hider.swift
//  DIM
//
//  Created by G.J. Parker on 1/7/22.
//  Copyright © 2022 G.J. Parker. All rights reserved.
//
import Cocoa

extension Notification.Name {
    static let doHide = NSNotification.Name("doHide")                       //toggle hide/show Desktop icons
    static let createDesktops = NSNotification.Name("createDesktops")       //recreate windows for all Desktops
    static let updateDesktop = NSNotification.Name("updateDesktop")         //update only windows that are on screen (i.e. current Desktop(s))
    static let updateAllDesktops = NSNotification.Name("updateAllDesktops") //update all windows to reflect current Desktops
}

class Hider {  // class that covers Desktop w/ pictures of Desktop- invoked by notifications and/or internal timers
    
    class MyWindow : NSWindow { // just add some data and methods for NSWindow- this will hold a window w/ a Desktop pic
        var cgID: CGWindowID        // CGWindowID of a Desktop
        var color: NSColor? = nil   // display solid color instead of actual Desktop? nil means actual, otherwise that color
        
        init(contentRect: NSRect, cgID: CGWindowID) {
            self.cgID = cgID
            super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false) // create NSWindow
            
            self.setFrame(contentRect, display: true, animate: false)  // is this necessary?
            self.collectionBehavior = .canJoinAllSpaces  // we want the window to follow Spaces around (until we find the correct space then we'll pin it on top)
            self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.backstopMenu)))  //hack? this makes mission control and expose ignore the window
            self.orderBack(nil)  // critical we place on back
            // rest is to make the window dumb
            self.canHide = false; self.isExcludedFromWindowsMenu = true; self.isOpaque = true
            self.hasShadow = false; self.hidesOnDeactivate = false; self.discardCursorRects()
            self.discardEvents(matching: .any, before: nil); self.ignoresMouseEvents = true; self.isRestorable = false
            self.animationBehavior = .none
            //self.animationBehavior = .default
        }
        
        func setWin(imageView: NSImageView?, showing: Bool, hidden: Bool) { // update picture and pin if we found the correct Space
            if self.color == nil { self.contentView = imageView! }
            if showing { // if this is currently showing, bring to front and pin it to this Space
                self.orderFront(nil); self.collectionBehavior = .stationary; self.animationBehavior = .none
            }
            if !hidden { self.orderOut(nil) }  // showing desktop, don't show this window at all
        }
    }
    
    var myScreen: [NSScreen : [MyWindow]] = [:] // for each screen, a list of Desktop windows corresponding to number of Spaces for that screen
    var hidden_ = false                         // are icons hidden?
    var deskCFArray : CFArray?                  // array that holds the CGWindowID of Desktops as a CFArray used in CG routines
    var cgIDCFArray: [ CGWindowID : CFArray ] = [:] // dictionary that holds CGWindowID in a CFArray used in CG routines
    var observation: NSKeyValueObservation?     // Apple doc
    
    var hidden: Bool {                          // are icons currently hidden?
        get { return hidden_ }
        set (value) { hidden_ = value }
    }
    // hide or show Desktop icons
    @objc func doHide(_ notifier : Notification) { //print("in doHide \(!hidden) \(myScreen.isEmpty) \(notifier)")
        hidden = !hidden        // toggle hide/show icons
        if hidden {             // appears the user want to hide icons
            for (_, wins) in myScreen {
                for win in wins { //print("  windows: \(win.frame) \(win.cgID) \(win.collectionBehavior)")
                    if win.collectionBehavior == .stationary { win.orderFront(nil) }    // this window as previously pinned, so we know which Space, bring it to front
                    else { win.orderBack(nil) }                                         // this window was not previously pinned, place in back
                }
            }
            updateDesktops(Notification(name: .updateAllDesktops, object: nil, userInfo: nil)) // force all Desktops to be updated
        } else {
            for (_, wins) in myScreen { for win in wins { win.orderOut(nil) } }   // don't show any of the Desktop windows
        }
    }

    @objc func updateDesktops(_ notifier : Notification) {  // update pictures of Desktop(s)
        if notifier.name == NSWorkspace.activeSpaceDidChangeNotification { usleep(100_000) }  //ugh! FIXME apple
        //print("updateDesktops \(notifier.name == .updateAllDesktops) \(notifier.name)")
        
        for screen in NSScreen.screens {                    // for each screen
            for window in myScreen[screen]! {               //   loop through windows (i.e. Spaces)
                if let winCG = (CGWindowListCreateDescriptionFromArray(cgIDCFArray[window.cgID]) as! [[ String : AnyObject]]).last { // get CG window
                    let showing = winCG[kCGWindowIsOnscreen as String] as? Bool ?? false        // is it on screen?
                    if showing || notifier.name == .updateAllDesktops { // only update image if we're showing or if we were requested to do all
                        //print("  U>\(screen.frame) \(window.cgID) \(showing) \(window.collectionBehavior == .stationary) \(notifier.name == .updateAllDesktops) \(window.color)")
                        if window.color != nil {            // do we want the actual Desktop wallpaper?
                            window.setWin(imageView: nil, showing: showing, hidden: hidden)         // leave the solid color alone
                        } else {
                            guard let cgImage = CGWindowListCreateImage(.null, [.optionIncludingWindow], window.cgID, [.nominalResolution]) else { continue }  // grab the picture
                            let image = NSImage(cgImage: cgImage, size: NSZeroSize)
                            //let imageView = NSImageView(image: image)
                            let imageView = NSImageView(frame: screen.frame)
                            imageView.image = image
                            window.setWin(imageView: imageView, showing: showing, hidden: hidden)   // update the picture
                        }
                    }
                }
            }
        }
    }
    
    @objc func createDesktops(_ notifier : Any?) {          // make window for each desktop
        let h0 = NSHeight((NSScreen.screens.filter({$0.frame.origin == CGPoint.zero}).first?.frame)!) // height of Screen that has menu bar
        
        // need to find Desktop windows... (let's use apple's approved way so we don't trip up security guards)
        let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)! as! [[String: AnyObject]]  // get all the windows everywhere
        let desktopWindowLevel = CGWindowLevelForKey(.desktopWindow) - 1                                    // level of Desktop background image
        let desktopWindows = windows.filter {
            let windowLevel = $0[kCGWindowLayer as String] as! CGWindowLevel
            return windowLevel == desktopWindowLevel
        }
        let desktopCGID = desktopWindows.map { $0[kCGWindowNumber as String] as! CGWindowID}                // array of Desktop background image CGWindowID
        
        // now create a CFArray with all the CGWindowID that are Desktop pictures
        let pointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: desktopCGID.count)
        for (index, win) in desktopCGID.reversed().enumerated() {       // we reverse simply so when we create the windows, they stack up in a way that makes more sense
            pointer[index] = UnsafeRawPointer(bitPattern: UInt(win))
        }
        deskCFArray = CFArrayCreate(kCFAllocatorDefault, pointer, desktopCGID.count, nil)  // there it is. used in CGWindowListCreateDescriptionFromArray call
        
        // now create CFArray w/ one element for each of the CGWindowID that are Desktop picturess
        for cgID in desktopCGID {
            let pointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 1)
            pointer[0] = UnsafeRawPointer(bitPattern: UInt(cgID))
            cgIDCFArray[cgID] = CFArrayCreate(kCFAllocatorDefault, pointer, 1, nil)       // there it is, store it as value in dictionary. used in CGWindowListCreateDescriptionFromArray call
        }
        
        for (_, wins) in myScreen { for win in wins { win.orderOut(nil)} } // if there any windows, don't show them anymore
        myScreen = [:]
        
        for screen in NSScreen.screens { // need to create a list of windows for this screen to accomodate the number of Spaces it has
            let rectNS = screen.frame   // get frame of Screen in screen coordinates
            let origin = CGPoint(x: rectNS.origin.x, y: h0 - rectNS.origin.y - rectNS.height)   // translate from Screen to CG origin: y_CG = h0 - y_Screen - height
            let rect = CGRect(origin: origin, size: rectNS.size)                                // this CGRect is in CG coordinates for the Screen
            for window in CGWindowListCreateDescriptionFromArray(deskCFArray) as! [[ String : AnyObject]] {  // get all of the Desktop windows
                let rectCG = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!  // get CGRect in CG coordinates (not Screen coordinates)
                if rectCG == rect {  // this Desktop window has the same frame as the screen, it must be one of the Spaces
                    let cgID = window[kCGWindowNumber as String] as! CGWindowID     // get the CGWindowID
                    let win = MyWindow(contentRect: screen.frame, cgID: cgID)       // create a window for this Desktop picture w/ exact size of the Screen
                    guard let cgImage = CGWindowListCreateImage(.null, [.optionIncludingWindow], cgID, [.nominalResolution]) else { continue }  //grab a picture of Desktop
                    
                    let image = NSImage(cgImage: cgImage, size: NSZeroSize)
                    //let imageView = NSImageView(image: image)
                    let imageView = NSImageView(frame: screen.frame)
                    imageView.image = image
                    win.setWin(imageView: imageView, showing: false, hidden: hidden)    // add the picture to the window
                    
                    if myScreen[screen] == nil { myScreen[screen] = [win] } else { myScreen[screen]!.append(win) }  // and store the window into the dictionary
                }
            }
        }
        updateDesktops(Notification(name: .updateDesktop, object: nil, userInfo: nil))  // now go set the currently displayed Desktops
    }
    // set up initial window lists for each screen and observers
    init() {
        hidden = true
        createDesktops(nil) // go grab all the Desktops
        NotificationCenter.default.addObserver(self, selector: #selector(self.doHide(_:)), name: .doHide, object: nil) // catch toggle
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.updateDesktops(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil) // Space changes
        NotificationCenter.default.addObserver(self, selector: #selector(self.createDesktops(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil) // Screens change
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateDesktops(_:)), name: .updateDesktop, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateDesktops(_:)), name: .updateAllDesktops, object: nil)
        // this should capture in/out of Dark Mode
        if #available(OSX 10.14, *) {
            observation = NSApp.observe(\.effectiveAppearance) { (app, _) in
                if self.hidden { // give 3 second delay to make sure the Desktop did in fact update
                    Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false, block: { _ in
                        NotificationCenter.default.post(name: .updateAllDesktops, object: nil) })
                }
            }
        }
    }
    // tear down observers (is this really necessary?)
    deinit {
        NotificationCenter.default.removeObserver(self, name: .doHide, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateDesktop, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateAllDesktops, object: nil)
        for (_, wins) in myScreen { for win in wins { win.orderOut(nil)} } // if there any windows, don't show them anymore
        myScreen = [:] // and free up screen/window dictionary
    }
}

