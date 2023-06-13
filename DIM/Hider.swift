//
//  Hider.swift
//
//  Created by G.J. Parker on 23/01/27.
//  Copyright © 2023 G.J. Parker. All rights reserved.
//

import Cocoa

extension Notification.Name {
    static let doHide = NSNotification.Name("doHide")                       //toggle hide/show Desktop icons
}

extension NSWindow.Level {
    static let hiddenLayer = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow))-2)
    static let floatLayer  = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow))+1)
    static let staticLayer = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow))+5)
}

class Hider {  // class that covers Desktop w/ pictures of Desktop- invoked by notifications and/or internal timers
    
    class MyWindow : NSWindow { // just add some data and methods for NSWindow- this will hold a window w/ a Desktop pic
        var color: NSColor? = nil   // display solid color instead of actual Desktop? nil means actual, otherwise that color
        var beingUsed = false
        
        init(contentRect: NSRect, hidden: Bool) {
            super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false) // create NSWindow
            reset(contentRect: contentRect, hidden: hidden)
        }
        
        func reset(contentRect: NSRect, hidden: Bool) {
            self.setFrame(contentRect, display: true, animate: false)   // force the correct frame for window
            //if #available(macOS 13.0, *) { self.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenNone, .ignoresCycle] } else { self.collectionBehavior = [.canJoinAllSpaces, .fullScreenNone, .ignoresCycle] }
            self.collectionBehavior = [.canJoinAllSpaces, .fullScreenNone, .ignoresCycle]
            self.level = hidden ? .floatLayer : .hiddenLayer
            //self.orderFrontRegardless() //place on top of this level
            self.beingUsed = true
            // rest is to make the window dumb
            self.canHide = false; self.isExcludedFromWindowsMenu = true; self.isOpaque = true
            self.hasShadow = false; self.hidesOnDeactivate = false; self.discardCursorRects()
            self.discardEvents(matching: .any, before: nil); self.ignoresMouseEvents = true; self.isRestorable = false
            self.animationBehavior = .none
        }
        
        func setWin(imageView: NSImageView, onScreen: Bool, hidden: Bool) { // update picture and pin if we found the correct Space
            self.contentView = imageView
            if onScreen && !self.collectionBehavior.contains(.stationary) {
                //if #available(macOS 13.0, *) { self.collectionBehavior = [.stationary, .canJoinAllApplications, .fullScreenNone, .ignoresCycle] } else { self.collectionBehavior = [.stationary, .fullScreenNone, .ignoresCycle] }   // pin this window to this Space
                self.collectionBehavior = [.stationary, .fullScreenNone, .ignoresCycle]
                self.level = hidden ? .staticLayer : .hiddenLayer //; print("set")    // move to top of this level
            }
            //print("in setWin, beingUsed=\(self.beingUsed), onScreen=\(onScreen) \(self.isOnActiveSpace), hidden=\(hidden), stationary?=\(self.collectionBehavior.contains(.stationary)), screen.frame==frame?\(self.screen?.frame == self.frame), frame=\(self.frame)")
        }
    }
    
    private var myDesktops : [ CGWindowID : MyWindow] = [:] //
    private var backupDesktops : [ MyWindow] = []
    private var hidden_ = false                         // are icons hidden?
    private var observation: NSKeyValueObservation?     // Apple doc- to detect dark/light mode switch
    
    var hidden: Bool {                          // are icons currently hidden?
        get { return hidden_ }
        set (value) { hidden_ = value }
    }
    // hide or show Desktop icons
    func doHide() { //print("in doHide, hidden=\(!hidden), empty myDesktops?\(myDesktops.isEmpty)")
        hidden = !hidden        // toggle hide/show icons
        if hidden {             // appears the user want to hide icons
            updateDesktops(true) // force all Desktops to be updated
            backupDesktops.filter({return $0.beingUsed}).forEach({win in win.level = .floatLayer})
            myDesktops.forEach({_, win in win.level = win.collectionBehavior.contains(.stationary) ? .staticLayer : .floatLayer})
        } else {
            myDesktops.forEach({ _, win in win.level = .hiddenLayer})    // don't show any of the Desktop windows
            backupDesktops.forEach({win in win.level = .hiddenLayer})
        }
    }

    func updateDesktops(_ doAll : Bool = false) {  // update pictures of Desktop(s)
        //print("updateDesktops, doAll=\(doAll) number of myDesktops:\(myDesktops.count), screens:\(Set(myDesktops.map({$0.value.screen})).count)")
        
        let dict = getDesktopArray(doAll ? .optionAll: .optionOnScreenOnly)
        for (cgWin, onScreen) in dict.map({ ($0[kCGWindowNumber as String] as! CGWindowID, $0[kCGWindowIsOnscreen as String] as? Bool ?? false)}) {
            if let win = myDesktops[cgWin] { //print("cgWin=\(cgWin), onScreen=\(onScreen), stationary?\(myDesktops[cgWin]?.collectionBehavior == .stationary)")
                setImageView(cgWin: cgWin, win: win, onScreen: onScreen)    //;print(cgWin,myDesktops[cgWin]!.frame,onScreen,myDesktops[cgWin]!.collectionBehavior.contains(.stationary),hidden)
            }  //else { print("    OOPS- \(cgWin) is not in MyDesktops!") }
        } //;print(" ")
        //print("number of myDesktops:\(myDesktops.count), screens:\(Set(myDesktops.map({$0.value.screen})).count), NSScreen:\(NSScreen.screens.count)")
    }
    
    func setImageView(cgWin: CGWindowID, win : MyWindow, onScreen : Bool) {
        if let color = win.color {
            let image = NSImage.swatchWithColor(color: color, size: win.frame.size)
            let imageView = NSImageView(image: image)
            win.setWin(imageView: imageView, onScreen: onScreen, hidden: hidden)
        } else {
            guard let cgImage = CGWindowListCreateImage(CGRectNull, [.optionIncludingWindow], cgWin, [.nominalResolution]) else { return }
            let image = NSImage(cgImage: cgImage, size: NSZeroSize)
            let imageView = NSImageView(image: image)
            win.setWin(imageView: imageView, onScreen: onScreen, hidden: hidden)
        }
        //print(cgWin, onScreen, win.isOnActiveSpace, hidden, win == nil, win.level == hiddenLayer, win.level == floatLayer, win.level == staticLayer)
    }
    
    func getDesktopArray(_ option: CGWindowListOption = .optionAll) -> [[String: AnyObject]] {
        var nTry = 0
        repeat {
            // need to find Desktop windows... (let's use apple's approved way so we don't trip up security guards)
            let windows = CGWindowListCopyWindowInfo([option], kCGNullWindowID)! as! [[String: AnyObject]]  // get (all or onscreen) windows
            let desktopWindowLevel = CGWindowLevelForKey(.desktopWindow) - 1                                // level of Desktop background image
            let desktopWindows = windows.filter {                                                           // get array of dictionaries for Desktop CGWindows
                let windowLevel = $0[kCGWindowLayer as String] as! CGWindowLevel
                return windowLevel == desktopWindowLevel
            }

            var screenRect: [CGRect] = []
            let numOnScreen = desktopWindows.reduce(0) { numOnScreen, window in             // find the number of desktops onScreen and also construct array of unique screen CGRects
                let rect = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!
                if !screenRect.contains(rect) { screenRect.append(rect)}
                let onScreen = window[kCGWindowIsOnscreen as String] as? Bool ?? false
                return numOnScreen + (onScreen ? 1 : 0)
            }
            let n = screenRect.count
            let good = n == NSScreen.screens.count || n == backupDesktops.count || n == backupDesktops.filter({return $0.beingUsed}).count
            //print("numOnScreen=\(numOnScreen), screenRect.count=\(screenRect.count), backup.count=\(backupDesktops.filter({return $0.beingUsed}).count), screens.count=\(NSScreen.screens.count), good=\(good), nTry=\(nTry)")
            if (numOnScreen == screenRect.count && good) || nTry > 20 { return desktopWindows }
            usleep(150_000)
            nTry += 1   // FIX ME?
        } while true
    }
    
    func createDesktops() { //print("createDesktops, myDesktop.count=\(myDesktops.count)")     // make window for each desktop
        
        //print("number of backupDesktops:\(backupDesktops.count), \(backupDesktops.filter({return $0.beingUsed}).count), \(NSScreen.screens.count)")
        createBackups() //;print("number of backupDesktops:\(backupDesktops.count), \(backupDesktops.filter({return $0.beingUsed}).count), \(NSScreen.screens.count)")
        
        let screens = NSScreen.screens; let h0 = NSHeight(screens[0].frame) // height of Screen that has menu bar
        myDesktops.forEach({ _, win in win.beingUsed = false; win.level = .hiddenLayer; win.orderOut(nil) })  // assume window is not going to be used
        for desktopWindows in getDesktopArray() {   // loop over CGWindows that are Desktops...
            let rectCG = CGRect(dictionaryRepresentation: desktopWindows[kCGWindowBounds as String] as! CFDictionary)!
            let origin = CGPoint(x: rectCG.origin.x, y: h0 - rectCG.origin.y - rectCG.height)
            let rect = CGRect(origin: origin, size: rectCG.size)            // CGrect is in Screen coordinates
            let cgID = desktopWindows[kCGWindowNumber as String] as! CGWindowID
            //print("is cgID not in myDesktops? \(myDesktops[cgID]==nil)")
            if let win = myDesktops[cgID] {
                win.reset(contentRect: rect, hidden: hidden)
            } else {
                myDesktops[cgID] = MyWindow(contentRect: rect, hidden: hidden)
            }
            let onScreen = desktopWindows[kCGWindowIsOnscreen as String] as? Bool ?? false
            setImageView(cgWin: cgID, win: myDesktops[cgID]!, onScreen: onScreen)   //;print(cgID,myDesktops[cgID]!.frame)
        }
        //print("number of myDesktops:\(myDesktops.count), \(NSScreen.screens.count)")
        for cgID in myDesktops.filter({ return !$0.value.beingUsed}).keys { //print(cgID,myDesktops[cgID]!.frame,myDesktops[cgID]!.beingUsed)   // remove any myDesktops that are not being used
            myDesktops[cgID]?.orderOut(nil); myDesktops.removeValue(forKey: cgID)    //?.close()
        }   //;print("number of myDesktops:\(myDesktops.count), \(NSScreen.screens.count)")
        myDesktops.forEach({_, win in win.orderFrontRegardless()})
        //print("number of myDesktops:\(myDesktops.count), screens:\(Set(myDesktops.map({$0.value.screen})).count)")
    }
    func createBackups() {
        backupDesktops.forEach({ win in win.beingUsed = false; win.orderOut(nil); win.level = .hiddenLayer })
        while NSScreen.screens.count < 1 { usleep(150_000) }
        let screens = NSScreen.screens
        for (idx, screen) in screens.enumerated() {
            if idx >= backupDesktops.count {
                backupDesktops.append(MyWindow(contentRect: screen.frame, hidden: hidden))
            } else {
                backupDesktops[idx].reset(contentRect: screen.frame, hidden: hidden)
            }
            backupDesktops[idx].color = .black
            setImageView(cgWin: 0, win: backupDesktops[idx], onScreen: false)
        }
        backupDesktops.forEach({win in if win.beingUsed {win.orderFrontRegardless()}})  //; backupDesktops.forEach({win in print(win.frame,win.beingUsed)})
    }
    // set up initial window lists for each screen and observers
    init(_ hidden : Bool = true) {
        self.hidden = hidden
        createDesktops() // go grab all the Desktops
        
        let NCdefault = NotificationCenter.default
        NCdefault.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: {_ in
            usleep(500_000); self.createDesktops()})    //;print("didChangeScreenParameters done")})
        NCdefault.addObserver(forName: .doHide, object: nil, queue: .main, using: {_ in self.doHide() })
        let WSsharedNC = NSWorkspace.shared.notificationCenter
        WSsharedNC.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main, using: {_ in //print("didWake")
            self.updateDesktops(true)}) //; print("didWake done") })
        WSsharedNC.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: { _ in
            usleep(150_000);  self.updateDesktops(true)})   //;print("activeSpaceDidChange done")}) //ugh! FIXME apple
        
        // this should capture in/out of Dark Mode
        if #available(OSX 10.14, *) {
            observation = NSApp.observe(\.effectiveAppearance) { (app, _) in
                if self.hidden { // give 3 second delay to make sure the Desktop did in fact update
                    Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false, block: { _ in self.updateDesktops(true)})   //; print("mode change!") })
                }
            }
        }
    }
    // tear down observers (is this really necessary?)
    deinit {
        observation?.invalidate() // invalidate any background timers
        let WSsharedNC = NSWorkspace.shared.notificationCenter
        WSsharedNC.removeObserver(self, name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        WSsharedNC.removeObserver(self, name: NSWorkspace.screensDidWakeNotification, object: nil)
        let NCdefault = NotificationCenter.default
        NCdefault.removeObserver(self, name: .doHide, object: nil)
        NCdefault.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        myDesktops.removeAll(); backupDesktops.removeAll() // and free up screen/window dictionary
    }
}

extension NSImage { // return an solid color image
  class func swatchWithColor(color: NSColor, size: NSSize) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    color.drawSwatch(in: NSRect(origin: .zero, size: size))
    image.unlockFocus()
    return image
  }
}
