//
//  AddArrangement.swift
//  DIM 3.0
//
//  Created by G.J. Parker on 19/1/19.
//  Copyright © 2019 G.J. Parker. All rights reserved.
//

import Cocoa

class AddArrangement: NSViewController {
    
    var newName = ""  // default new arrangement name, will be set by the parent viewcontroller
    var dim : DIM?
    var orderedArrangements = [String]()
    //var toDo = ""  // we are either making a new arrangement or we are renaming an existing arrangement, will be set by parent viewcontroller
    
    @IBOutlet weak var newArrangement: NSTextField!
    
    @IBOutlet weak var okButton: NSButton!
    @IBOutlet weak var windowPosition: NSButton!
    @IBOutlet weak var windowSize: NSButton!
    @IBOutlet weak var whichWindow: NSPopUpButton!
    
    var getWindows = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        newArrangement.stringValue = newName
        loadMenu()
        dim?.saveWindowPosition = false
        dim?.saveWindowBounds = false
        whichWindow.selectItem(at: 0)  // default to doing Desktop
        windowPosition.isEnabled = false
        windowSize.isEnabled = false
        newArrangement.stringValue = newName  // grab default
        okButton.title = "Add"
    }
    
    func loadMenu() {
        updateUI("Searching for Finder windows...")
        whichWindow.removeAllItems()
        getWindows = dim!.getWindows()
        for i in 0..<getWindows.count {
            getWindows[i] += " window"
        }
        getWindows.insert("Desktop", at: 0)
        whichWindow.addItems(withTitles: getWindows)
        whichWindow.menu?.addItem(NSMenuItem.separator()) // simple seperator
        whichWindow.addItem(withTitle: "Update this list...")
        updateUI()
    }
    
    @IBAction func containerButton(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem //{ //selectedItem?.title {
        if idx >= getWindows.count { //} == "Update this list..." {
            print("loadMenu()...")
            loadMenu()
        } else if idx == 0 {
            windowPosition.isEnabled = false
            windowSize.isEnabled = false
            newArrangement.stringValue = newName.replacingOccurrences(of: " window", with: "")
        } else {
            windowPosition.isEnabled = true
            windowSize.isEnabled = true
            let name = sender.titleOfSelectedItem!
            var possible = name
            var j = 1
            while orderedArrangements.contains(possible) {
                possible = name + " " + String(j)
                j += 1
            }
            newArrangement.stringValue = possible
        }
    }
    
    @IBAction func savePositionCheck(_ sender: NSButton) {
        let save = (sender.state.rawValue == 1)             // "1" is checked, return true in that case
        dim?.saveWindowPosition = save
    }
    
    @IBAction func saveBoundsCheck(_ sender: NSButton) {
        let save = (sender.state.rawValue == 1)             // "1" is checked, return true in that case
        dim?.saveWindowBounds = save
    }
    @IBOutlet weak var containerLabel: NSTextField!
        
    // AppleScript can take a while, turn off all controlls until it's done and do an animation so user doesn't get too confused
    func updateUI(_ message: String) {
        containerLabel.stringValue = message
        newArrangement.isEnabled = false
        okButton.isEnabled = false
        windowPosition.isEnabled = false
        windowSize.isEnabled = false
        whichWindow.isEnabled = false
    }
    
    // apparently AppleScript call is done, turn on the contollers again so the user can do something...
    func updateUI() {  //turn on controllers once AppleScript is done
        containerLabel.stringValue = "Container to memorize:"
        newArrangement.isEnabled = true
        okButton.isEnabled = true
        windowPosition.isEnabled = true
        windowSize.isEnabled = true
        whichWindow.isEnabled = true
    }
    
    // user press Add/Change so pass back the new name, old name and if Change or Add (if pressed Cancel it simply destroys the view and returns)
    @IBAction func okPressed(_ sender: NSButton) {
        let editVC = presentingViewController as! EditSheet
        let idx = whichWindow.indexOfSelectedItem
        print("idx: \(idx)")
        dim?.targetWindow = idx  // bug fix for 4.0.1
        if idx > 0 { // doing a window?
            let win = dim!.targetWindow
            if win < 1 {  // no such window exists, punt!
                editVC.addArrangment("", oldName: "", what: "missing") // trick to not do anything other than beep
                self.dismiss(self)
                return
            }
        }
        print("idx: \(idx)")
        editVC.addArrangment(newArrangement.stringValue, oldName: newName, what: okButton.title) // either Desktop or existing window
        self.dismiss(self)
    }
}
