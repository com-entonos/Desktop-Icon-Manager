//
//  Hider.swift
//  DIM
//
//  Created by G.J. Parker on 19/11/4.
//  Copyright © 2021 G.J. Parker. All rights reserved.
//

import Cocoa

class Hider {
    init() {  // get notified when user wants to toggle
        NotificationCenter.default.addObserver(self, selector: #selector(self.doHide), name: NSNotification.Name("doHide"), object: nil)
    }
    
    var transWindow = [NSWindow]()  // our current Desktop pictures (empty means we're in the Show state)
    
    @objc func doHide() {
        if transWindow.count == 0 {  // appears the user want to hide icons
            for screen in NSScreen.screens {  // create the corresponding windows
                transWindow.append(createWin(screen))
            }
            spaceChange() // and go display them
            // get notified when Spaces or Screens change
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.spaceChange), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        } else {
            // stop notifications for Screen and Space chages
            NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
            // teardown
            for (index, win) in transWindow.enumerated() {
                win.orderOut(self)
                transWindow[index].windowController?.window = nil
            }
            // we use the fact that transWindow.count = 0 keep track if the icons are hidden or not.
            transWindow.removeAll()
        }
    }
    
    @objc func screenChanged() {  // call back for when the user reconfigured the Screen
        let screens = NSScreen.screens
        if screens.count > transWindow.count {  // number of screens increase, so create some new windows
            for i in (transWindow.count)..<screens.count {
                transWindow.append(createWin(screens[i]))
            }
        }
        spaceChange()  // regardless of what happened, update the overlays just in case
    }
    
    func createWin(_ screen: NSScreen) -> NSWindow {
        // create a window w/ the same size as the screen we're given
        return resetWin(NSWindow(contentRect: NSMakeRect(0, 0, NSWidth(screen.frame), NSHeight(screen.frame)), styleMask: .borderless, backing: .buffered, defer: true, screen: screen))
    }
    
    func resetWin(_ win: NSWindow) -> NSWindow {
        win.collectionBehavior = NSWindow.CollectionBehavior.canJoinAllSpaces          // we want the window to follow Spaces around
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.backstopMenu)))  //hack? this makes mission control and expose ignore the window
        // rest is to make the window dumb
        win.canHide = false
        win.isExcludedFromWindowsMenu = true
        win.hidesOnDeactivate = false
        win.discardCursorRects()
        win.discardEvents(matching: NSEvent.EventTypeMask.any, before: nil)
        win.ignoresMouseEvents = true
        win.orderBack(nil)
        win.isRestorable = false
        win.animationBehavior = .none
        return win
    }
    
    @objc func spaceChange() {
        var desktopPics = NSImage.desktopPictures()  // grab pictures of the Desktop(s)
        for (index, screen) in NSScreen.screens.enumerated() {  // cycle through the physical Screens
            for (numPic, desktopPic) in desktopPics.enumerated() {  // find the first desktop picture that has the same size as this screen
                if desktopPic.size.height == screen.frame.height && desktopPic.size.width == screen.frame.width {
                    // get an imageView w/ the correct size and picture
                    let imageView = NSImageView(frame: screen.frame)
                    imageView.image = desktopPic
                    // make sure the window has the same size as the screen
                    if screen.frame != transWindow[index].frame {transWindow[index].setFrame(screen.frame, display: false, animate: false)}
                    // ok, replace the view
                    transWindow[index].contentView = imageView
                    // hopefully to avoid problems on which screen and which desktop, get rid of the ones we've done
                    desktopPics.remove(at: numPic)
                    break
                }
            }
        }
    }
}
extension NSImage { //don't need to do an extension, but it appears fun, so let's do it.
    
    static func desktopPictures() -> [NSImage] {  // for each desktop we find, take a picture add it onto an array and return it
        var images = [NSImage]()
        for window in CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[ String : Any]] {

            // we need windows owned by Dock
            guard let owner = window["kCGWindowOwnerName"] as? String else {continue}
            if owner != "Dock" {
                continue
            }
            // we need windows named like "Desktop Picture %"
            guard let name = window["kCGWindowName"] as? String else {continue}
            if !name.hasPrefix("Desktop Picture") {
                continue
            }
            // ok, this belongs to a screen. grab a picture of it and append to the return array
            guard let index = window["kCGWindowNumber"] as? CGWindowID else {continue}  //pendantic
            let cgImage = CGWindowListCreateImage(CGRect.null, CGWindowListOption(arrayLiteral: CGWindowListOption.optionIncludingWindow), index, CGWindowImageOption.nominalResolution)
            images.append(NSImage(cgImage: cgImage!, size: NSMakeSize(CGFloat(cgImage!.width), CGFloat(cgImage!.height))))
        }
        // return the array of Desktop pictures
        return images
    }
}
