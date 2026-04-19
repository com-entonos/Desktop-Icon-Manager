//
//  ViewController.swift
//  DIM
//
//  Created by G.J. Parker on 19/1/17.
//  Copyright © 2026 G.J. Parker. All rights reserved.
//

import Cocoa
import OSLog

import ServiceManagement

enum ActionItems : Int, CaseIterable { case  open = 0, hide, quit }

class ViewController: NSViewController {
    
    // variables to deal w/ different Arrangements and what the code should do (these are default values which will be overwritten soon)
    var restoreAtStart = false  // Restore icon positions at start?
    var actionAfterStart = ActionItems.open
    var automaticSave = false
    var currentName = "Default" // some name for an icon Arrangment
    var arrangements = [String: Any]()  // dictionary keyed to name w/ corresponding iconSet (AppleScript data object)
    var orderedArrangements = [String]()  // an ordered list of Arrangement names to populate drop down menu and Edit sheet
    var timerSeconds = -1
    var thisVer = "0.0" // change to string so we can fetch it from bundle...
    
    // these are disposable run variables
    var start = true     // did we just start?
    var overrideSetting = false  // is user holding command (⌘) during start?
    var saveTimer: Timer?
    var dataVer = "0.0"
    var quitTimer: Timer?
    var quitCount = 20
    var didChangeScreen = false
    
    // this is for updating
    var updateAvailable = [String]()
    var updateDownloaded = false
    
    // our outlets to various labels, buttons, etc on the main storyboard
    @IBOutlet weak var doingTF: NSTextField!
    @IBOutlet weak var doingPI: NSProgressIndicator!
    @IBOutlet weak var warningTF: NSTextField!
    @IBOutlet weak var warningButton: NSButton!
    @IBOutlet weak var actionMenu: NSPopUpButton!
    @IBOutlet weak var automaticSaveButton: NSButton!
    @IBOutlet weak var timeMenu: NSPopUpButton!
    @IBOutlet weak var currentTF: NSTextField!
    @IBOutlet weak var currentNumDesktop: NSTextField!
    @IBOutlet weak var currentNumArrangement: NSTextField!
    @IBOutlet weak var arrangementButton: NSPopUpButton!
    @IBOutlet weak var restoreButton: NSButton!
    @IBOutlet weak var memorizeButton: NSButton!
    
    var dim: DIM?
    
    var hiding = false
    var hider : Hider? //= Hider(false)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideSetting = NSEvent.modifierFlags == .command  // check to see if user is holding command key during launch
        
        migrateToAppGroupIfNeeded()
        
        /* capture option key press/release - FIXME: doesn't trigger if menu is open */
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in self.setMemorizeButtonTitle(!event.modifierFlags.contains(.option)); return event})
            //self.flagsChanged(with: event); return event })
            
        // quiting: invalidate any timers and should we do a save?
        NotificationCenter.default.addObserver(forName: .atEnd, object: nil, queue: .main, using: { notice in
            if self.automaticSave && self.timerSeconds < 0 && !(self.restoreAtStart && self.actionAfterStart == .quit) {
                //self.arrangements[self.currentName] = self.refetchSet()  // w/o gui
                self.arrangements[self.currentName] = self.mergeArrangements(addArrangement: self.arrangements[self.currentName]!, baseArrangement: self.refetchSet())
                self.savePrefs()
            }
            if self.saveTimer != nil { self.saveTimer?.invalidate(); self.saveTimer = nil }    // get rid of any timers
        })
        
        /* if screens wake up or change parameters, do a restore.  NSWorkspace.screensDidWakeNotification*/
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main, using: { notice in self.doWaitRestore(notice) })
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: { notice in self.doWaitRestore(notice) })
        
        /* deal with notification from Dock menu items... */
        NotificationCenter.default.addObserver(forName: .doRestore, object: nil, queue: .main, using: { notice in
            //if #available(macOS 11.0, *) { Logger.diag.log("notice->\(notice.name.rawValue, privacy: .public)<>\(notice.object as? String ?? "restoreButton", privacy: .private(mask: .hash))") }
            if let name = notice.object as? String { self.currentTF.stringValue = "Using Icon Arrangement: " + name; self.restore(name) } else { self.do_restore(self.restoreButton as Any)} })
        NotificationCenter.default.addObserver(forName: .doMemorize, object: nil, queue: .main, using: { notice in //this is Purge
            //if #available(macOS 11.0, *) { Logger.diag.log("notice->\(notice.name.rawValue, privacy: .public)<>\(notice.object as? String ?? "memorizeButton", privacy: .private(mask: .hash))") }
            let name = notice.object as? String ?? self.currentName
            self.currentTF.stringValue = "Using Icon Arrangement: " + name; self.memorize(name) })
        NotificationCenter.default.addObserver(forName: .doAdd, object: nil, queue: .main, using: { notice in
            //if #available(macOS 11.0, *) { Logger.diag.log("notice->\(notice.name.rawValue, privacy: .public)<>\(notice.object as? String ?? self.currentName, privacy: .private(mask: .hash))") }
            let name = notice.object as? String ?? self.currentName
            self.currentTF.stringValue = "Using Icon Arrangement: " + name; self.memorize(name, addTo: true) })
        
        /* redraw Memorize/Purge Icon Positions button */
        NotificationCenter.default.addObserver(forName: .doMemorizeButton, object: nil, queue: .main, using: { _ in self.setMemorizeButtonTitle() })
        
        if #available(macOS 13.0, *) {
            // incase we updated, stop old if running...
            let serv = SMAppService.loginItem(identifier: bDIM.hID)
            try? serv.unregister()
            if UserDefaults(suiteName: bDIM.gUD)!.bool(forKey: "doHelper") {
                _ = toggleHelper(to: true)
            }
        }
        arrangementButton.cell?.menu?.delegate = self  // so loadMenu constructs itself when button is pressed
    }
    func doWaitRestore(_ notice : Notification) {
        if !self.didChangeScreen {
            self.didChangeScreen = true; Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: { _ in self.didChangeScreen = false}) // ignore future calls until we reset
            let waitRestore = UserDefaults(suiteName: bDIM.gUD)!.object(forKey: "waitRestore") != nil ? UserDefaults(suiteName: bDIM.gUD)!.double(forKey: "waitRestore") : 10.0
            if #available(macOS 11.0, *) { Logger.diag.log("notice->\(notice.name.rawValue, privacy: .public) \(waitRestore, privacy: .public)")}
            self.do_restore(self.restoreButton as Any)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if start {
            thisVer = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
            if #available(macOS 11.0, *) { Logger.diag.info("starting DIM \(self.thisVer, privacy: .public)") }
            doingPI.startAnimation(nil)
            DispatchQueue.main.async {
                self.dim = DIM()
                if self.dim == nil || self.dim!.testBridge == "no" || self.dim!.testBridge == nil {
                    if #available(macOS 11.0, *) { Logger.err.error("DIM failed to connect to Finder") }
                    self.errorwithAS()
                } else {
                    self.loadPrefs()
                    self.start = false
                    self.updateUI()
                    if !self.noCommandLineArgs(CommandLine.arguments) {self.doCommandLineArgs(CommandLine.arguments) }
                    NotificationCenter.default.post(name: .newArrangement, object: self.orderedArrangements)//; if #available(macOS 11.0, *) { Logger.diag.log("viewDidAppear post NotificationCenter .newArrangement >\(self.orderedArrangements,privacy: .private(mask: .hash))<") }
                }
            }
            //DispatchQueue.global(qos: .userInteractive).async {
            //    if self.dim == nil { self.dim = DIM() }
            //    DispatchQueue.main.async {
            //    }
            //}
        }
    }
    /* this doesn't seem to catch anything.... /**/
    override var acceptsFirstResponder: Bool { return true }
    override func flagsChanged(with event: NSEvent) {
        print("flagsChanged: \(event.modifierFlags)")
        setMemorizeButtonTitle(!event.modifierFlags.contains(.option))
        super.flagsChanged(with: event)
    } */
    func setMemorizeButtonTitle(_ doAddI : Bool? = nil) {
        let doAdd = doAddI ?? !NSEvent.modifierFlags.contains(.option)
        memorizeButton.title = doAdd ? "Memorize Icon Positions" : "Purge Icon Positions"
      //print("setMemorizeButtonTitle: \(doAdd) \(memorizeButton.title)")
    }
    
    @objc func terminate() {
        quitCount -= 1
        if NSEvent.modifierFlags == .command {
            warningTF.stringValue = "(Hold ⌘ while starting DIM to reach this window)"
            quitTimer?.invalidate()
        } else if quitCount > 0 {
            warningTF.stringValue = "Hold ⌘ to abort Quit (\(Int(0.9 + Double(quitCount)/5.0)))" // triggers every 0.2 seconds
        } else {
            quitTimer?.invalidate()
            NSApp.terminate(self)
        }
    }
     
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
    // Button pressed to Memorize...
    @IBAction func do_memorize(_ sender: Any) {
        setMemorizeButtonTitle()
        quitTimer?.invalidate()
        memorize(currentName,addTo: !NSEvent.modifierFlags.contains(.option))
        refreshTimer()
    }
    
    // Button pressedd to Restore...
    @IBAction func do_restore(_ sender: Any) {
        setMemorizeButtonTitle()
        quitTimer?.invalidate()
        restore(currentName)
        refreshTimer()
    }

    
    // memorize an arrangement given by name
    func memorize(_ name: String, addTo: Bool = false) {
        //if #available(macOS 11.0, *) { Logger.diag.log("memorize, addTo? \(addTo, privacy: .public) name:\(name, privacy: .private(mask: .hash))<") }
        updateUI(addTo ? "Memorizing Icon Positions..." : "Purging Icon Positions...")
        DispatchQueue.global(qos: .utility).async { [unowned self] in  // apparently we need to do this otherwise UI isn't updated during AppleScript call
            let currentArrangement = (name == currentName) ? self.refetchSet() : self.fetchSet()
            if addTo {
                self.arrangements[name] = self.mergeArrangements(addArrangement: self.arrangements[name]!, baseArrangement: currentArrangement)
                self.dim!.iconSet = self.arrangements[name] // tell AppleScript about the new set
            } else {
                self.arrangements[name] = currentArrangement
            }
            if name != self.currentName {
                self.dim!.iconSet = self.arrangements[self.currentName]
            }
            DispatchQueue.main.async {
                self.savePrefs()
                self.updateUI()
            }
        }
    }
    
    // restore from arrangement given by name
    func restore(_ name: String) {
        updateUI("Restoring Icon Positions...")
        DispatchQueue.global(qos: .utility).async { [unowned self] in
            self.setSet(set: self.arrangements[name]!)
            self.dim!.numOnDesktop = 0
            if name != self.currentName { self.dim!.iconSet = self.arrangements[self.currentName]}
            DispatchQueue.main.async {
                self.updateUI()
            }
        }
    }
    
    // AppleScript can take a while, turn off all controlls until it's done and do an animation so user doesn't get too confused
    func updateUI(_ message: String) {
        doingTF.stringValue = message
        memorizeButton.isEnabled = false
        restoreButton.isEnabled = false
        doingTF.isHidden = false
        doingPI.startAnimation(nil)
        warningButton.isEnabled = false
        actionMenu.isEnabled = false
        warningButton.isHidden = true
        actionMenu.isHidden = true
        warningTF.isHidden = true
        automaticSaveButton.isEnabled = false
        timeMenu.isEnabled = false
        automaticSaveButton.isHidden = true
        timeMenu.isHidden = true
        arrangementButton.isEnabled = false
    }
    
    // apparently AppleScript call is done, turn on the contollers again so the user can do something...
    func updateUI() {  //turn on controllers once AppleScript is done
        memorizeButton.isEnabled = true
        restoreButton.isEnabled = true
        doingTF.isHidden = true
        doingPI.stopAnimation(nil)
        warningButton.isEnabled = true
        actionMenu.isEnabled = restoreAtStart
        warningButton.isHidden = false
        actionMenu.isHidden = false
        warningTF.isHidden = !(restoreAtStart && actionAfterStart == .quit)
        automaticSaveButton.isHidden = (restoreAtStart && actionAfterStart == .quit)
        automaticSaveButton.isEnabled = !automaticSaveButton.isHidden
        timeMenu.isHidden = automaticSaveButton.isHidden
        timeMenu.isEnabled = !timeMenu.isHidden && automaticSaveButton.state == .on
        arrangementButton.isEnabled = true
        updateInfo()
    }
    
    //set AppleScript data and restore icon positions
    func setSet(set: Any) {
        dim!.iconSet = set
        dim!.restore()
    }
    
    // memorize icon positions and return AppleScript data
    func fetchSet() -> Any {
        dim!.memorize()
        return dim!.iconSet as Any
    }
    func refetchSet() -> Any {
        dim!.rememorize()
        return dim!.iconSet as Any
    }
    
    // Check for Restore at start was toggled
    @IBAction func restoreQuitCheck(_ sender: NSButton) { // Restore at Start?
        restoreAtStart = (sender.state.rawValue == 1)             // "1" is checked, return true in that case
        sanitize()
    }
    
    // Check action menu after Restore was toggled
    @IBAction func selectActionMen(_ sender: NSPopUpButton) {
        if let item = sender.selectedItem?.tag {
            if actionAfterStart.rawValue != item {
                actionAfterStart = ActionItems(rawValue: item)!
                savePrefs()
                sanitize()
            }
        }
    }

    func sanitize() {
        quitTimer?.invalidate()                // enable Quit after Restore if latter is checked
        actionMenu.isEnabled = restoreAtStart
        warningTF.isHidden = !(restoreAtStart && actionAfterStart == .quit)  // if this is checked (we know Restore is), warn the user
        automaticSaveButton.isHidden = (restoreAtStart && actionAfterStart == .quit)
        automaticSaveButton.isEnabled = !automaticSaveButton.isHidden
        timeMenu.isHidden = automaticSaveButton.isHidden
        timeMenu.isEnabled = !timeMenu.isHidden && automaticSaveButton.state == .on
        savePrefs()
        refreshTimer()
        //let x = FSEventStreamCreate(nil, <#T##callback: FSEventStreamCallback##FSEventStreamCallback##(ConstFSEventStreamRef, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer, UnsafePointer<FSEventStreamEventFlags>, UnsafePointer<FSEventStreamEventId>) -> Void#>, <#T##context: UnsafeMutablePointer<FSEventStreamContext>?##UnsafeMutablePointer<FSEventStreamContext>?#>, <#T##pathsToWatch: CFArray##CFArray#>, <#T##sinceWhen: FSEventStreamEventId##FSEventStreamEventId#>, <#T##latency: CFTimeInterval##CFTimeInterval#>, <#T##flags: FSEventStreamCreateFlags##FSEventStreamCreateFlags#>)
    }
    
    func refreshTimer() {
        if saveTimer != nil { saveTimer?.invalidate(); saveTimer = nil }
        if automaticSave && timerSeconds > 0 && !(restoreAtStart && actionAfterStart == .quit) {
            saveTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timerSeconds), repeats: true, block: { timer in
                if self.saveTimer != nil {
                    //self.arrangements[self.currentName] = self.refetchSet()
                    self.arrangements[self.currentName] = self.mergeArrangements(addArrangement: self.arrangements[self.currentName]!, baseArrangement: self.refetchSet())
                    self.savePrefs()
                }
            })
        }
    }
    
    @IBAction func automaticSaveCheck(_ sender: NSButton) {
        quitTimer?.invalidate()
        automaticSave = (sender.state.rawValue == 1)            // 1 if checked
        savePrefs()
        refreshTimer()
        timeMenu.isEnabled = automaticSave
    }
    
    func setTimerMenu() {
        timeMenu.removeAllItems()
        timeMenu.addItems(withTitles: ["at Quit", "every 30 minutes", "every hour", "every 2 hours", "every 6 hours", "every 12 hours", "every day"])
        var selectItem = -1
        switch timerSeconds {
        case -1:
            selectItem = 0
        case 60*30:
            selectItem = 1
        case 60*60:
            selectItem = 2
        case 60*60*2:
            selectItem = 3
        case 60*60*6:
            selectItem = 4
        case 60*60*12:
            selectItem = 5
        default:
            selectItem = 6
        }
        timeMenu.selectItem(at: selectItem)
    }
    
    @IBAction func timerInterval(_ sender: NSPopUpButton) {
        quitTimer?.invalidate()
        if let name = sender.selectedItem?.title {
            var newTimerSeconds = 0
            switch name {
            case "at Quit":
                newTimerSeconds = -1
            case "every 30 minutes":
                newTimerSeconds = 60 * 30
            case "every hour":
                newTimerSeconds = 60 * 60
            case "every 2 hours":
                newTimerSeconds = 60 * 60 * 2
            case "every 6 hours":
                newTimerSeconds = 60 * 60 * 6
            case "every 12 hours":
                newTimerSeconds = 60 * 60 * 12
            default:
                newTimerSeconds = 60 * 60 * 24
            }
            if timerSeconds != newTimerSeconds {
                timerSeconds = newTimerSeconds
                savePrefs()
                refreshTimer()
            }
        }
    }
    
    // let's read user's preferences
    func loadPrefs() {  // go read user's perferences
        if goodLoadPrefs() {  // try to be robust in reading them back in, if there is an unrecoverable problem (or data doesn't exist), start afresh
            if restoreAtStart && !overrideSetting && noCommandLineArgs(CommandLine.arguments) {  // did they want us to restore automatically at start?
                if actionAfterStart == .hide { NSApp.hide(self) }
//              restore(currentName) //doesn't seem to work, so just brute force a restore  (instead of the next line)
                setSet(set: arrangements[currentName]!)
                dim!.numOnDesktop = 0  // we have to make sure numArrangement, numDesktop and iconSet is set, if we got here, we only have to update numDesktop so tell Finder to do so
                if actionAfterStart == .quit && dataVer == thisVer {  // should we quit in 5 seconds?
                    quitCount = UserDefaults(suiteName: bDIM.gUD)!.object(forKey: "quitCount") != nil ? UserDefaults(suiteName: bDIM.gUD)!.integer(forKey: "quitCount") : 20
                    warningTF.stringValue = "Hold ⌘ to abort Quit (\(Int(0.9 + Double(quitCount)/5.0)))"
                    quitTimer = Timer.scheduledTimer(timeInterval: TimeInterval(0.2), target: self, selector: #selector(self.terminate), userInfo: nil, repeats: true)
                }
            } else {
                dim!.iconSet = arrangements[currentName]!  // no automatic restore, so just load AppleScript data (iconSet, numDesktop and numSet) for current arrangment
                dim!.numInSet = 0     // tell Finder to compute
                dim!.numOnDesktop = 0 // tell Finder to compute
            }
        } else {   // first run or no user data or fatal problem reading user data
            restoreAtStart = false  // these are the defaults
            actionAfterStart = .quit // let's force user to select this, perhaps it will reduce confusion
            automaticSave = false
            currentName = "Default"
            timerSeconds = -1
            orderedArrangements.append(currentName)
            arrangements[currentName] = fetchSet()  // this will cause numArrangment, numDesktop and iconSet to be defined so we are all good, it also stores the initial arrangement- we always need at least one!
            savePrefs()
            doingTF.isHidden = true
        }
        // set up timer options
        setTimerMenu()
        
        warningButton.state = (restoreAtStart ? .on : .off) // set default state of check for Restore at start
        actionMenu.isEnabled = restoreAtStart                   // if Restore at startup, allow the user to pick action for after
        warningTF.isHidden = !(restoreAtStart && actionAfterStart == .quit) // if Restore and Quit at startup, warn the user how to get back to our screen
        automaticSaveButton.isHidden = (restoreAtStart && actionAfterStart == .quit)
        automaticSaveButton.state = (automaticSave ? .on : .off)
        timeMenu.isHidden = automaticSaveButton.isHidden
        timeMenu.isEnabled = !timeMenu.isHidden && automaticSaveButton.state == .on
        updateInfo() // loadMenu()  // finally, construct the arrangement drop down menu
        refreshTimer()
    }
    
    //let's assume something bad happened to the stored user data...
    func goodLoadPrefs() -> Bool {
        let defaults = UserDefaults(suiteName: bDIM.gUD)!
        guard let name = defaults.string(forKey: "currentName")  else { return false }  // is there a plist?
        guard (defaults.array(forKey: "orderedArrangements") != nil) else { return false }
        currentName = name
        if defaults.object(forKey: "actionAfterStart") != nil {
            let item = defaults.integer(forKey: "actionAfterStart")
            actionMenu.selectItem(at: item)
            actionAfterStart = ActionItems(rawValue: item) ?? actionAfterStart
        } else if defaults.object(forKey: "quitAfterStart") != nil {
            actionAfterStart = ActionItems(rawValue: defaults.bool(forKey: "quitAfterStart") ? 2 : 0)!
        }
        restoreAtStart = defaults.bool(forKey: "restoreAtStart")
        orderedArrangements = defaults.array(forKey: "orderedArrangements") as! [String]
        arrangements = defaults.dictionary(forKey: "arrangements")!
        if defaults.object(forKey: "timerSeconds") != nil {timerSeconds = defaults.integer(forKey: "timerSeconds")}
        if defaults.object(forKey: "automaticSave") != nil {automaticSave = defaults.bool(forKey: "automaticSave")}
        
        if defaults.object(forKey: "dataVerString") != nil { dataVer = defaults.string(forKey: "dataVerString")!}
        defaults.set(thisVer, forKey: "dataVerString") // since we ran, update dataVer
        if dataVer != thisVer { defaults.removeObject(forKey: "donate") }
        if defaults.string(forKey: "donate") != nil {donateLabel.textColor = NSColor.labelColor}
        
        // in a perfect world we would be done. but let's not assume perfect and instead assume non-perfect
        // first, let's construct a new array using the data we (supposedly) have in arrangements dictionary
        var valid = [String]()  // valid will be a copy of arrangements but must be 'valid' (i.e. dictionary can be cast to NSArray with 5 or more elements)
        for (arr, data) in arrangements {
            if let dictEntry = data as? NSArray {
                if dictEntry.count > 4 {valid.append(arr)} else { arrangements[arr] = nil}
            }
        }
        var corrected = [String]() // now try to preserve the order, valid has all 'valid' arrangements
        for arr in orderedArrangements {
            if valid.contains(arr) {corrected.append(arr)} // add only if we have a dictionary key in 'valid'
        }
        if corrected.count < valid.count {  // and assume orderedArrangement was corrupt, just add what's missing
            for arr in valid {
                if !corrected.contains(arr) {corrected.append(arr)} // add only if 'corrected' doesn't have the 'valid' key
            }
        }
        if corrected.count > 0 {  // we have something, if not all
            if arrangements[currentName] == nil {  // and confirm we have a valid currentName
                currentName = corrected[0]  // oh no, we don't- grab the first one and reset flag for restoring at start
                restoreAtStart = false
            }
            orderedArrangements = corrected  // either everything was perfect or we corrected what wasn't.
            return true  // and tell them to use this data
        }
        // ah, we have unrecoverable errors
        arrangements.removeAll()
        orderedArrangements.removeAll()
        return false // we don't have sets recoverable, punt and redo
    }
    
    // save user's preferences
    func savePrefs() {
        let defaults = UserDefaults(suiteName: bDIM.gUD)!
        defaults.set(currentName, forKey: "currentName")
        defaults.set(restoreAtStart, forKey: "restoreAtStart")
        defaults.set(actionAfterStart.rawValue, forKey: "actionAfterStart")
        defaults.set(orderedArrangements, forKey: "orderedArrangements")
        defaults.set(arrangements, forKey: "arrangements")
        defaults.set(automaticSave, forKey: "automaticSave")
        defaults.set(timerSeconds, forKey: "timerSeconds")
     // DistributedNotificationCenter.default().postNotificationName(.newArrangement, object: nil, userInfo: ["orderedArrangements" : self.orderedArrangements], deliverImmediately: true); if #available(macOS 11.0, *) { Logger.diag.log("SavePrefs DistributedNotice .newArrangement posted") }
        NotificationCenter.default.post(name: .newArrangement, object: orderedArrangements)//; if #available(macOS 11.0, *) { Logger.diag.log("SavePrefs post NotificationCenter .newArrangement >\(self.orderedArrangements,privacy: .private(mask: .hash))<") }
    }
    
    // construct the Arrangement popdown menu
    func loadMenu() {
        actionMenu.selectItem(at: actionAfterStart.rawValue)
        updateInfo()
        if let nn = arrangementButton.menu?.numberOfItems {  // destroy the existing menus
            for num in 1 ..< nn {
                arrangementButton.menu?.removeItem(at: nn-num)
            }
            for name in orderedArrangements {               // create a new menu, first w/ all the arrangement names...
                let menuItem = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                menuItem.state = (name == currentName ? .on : .off)
                arrangementButton.menu?.addItem(menuItem)
            }
            arrangementButton.menu?.addItem(NSMenuItem.separator())     // simple seperator
            let editMenu = NSMenuItem(title: "Edit...", action: #selector(editArrangement), keyEquivalent: "") // the "Edit..." option
            arrangementButton.menu?.addItem(editMenu)
            arrangementButton.menu?.addItem(NSMenuItem.separator())     // simple seperator
            let showMenu = NSMenuItem(title: "Select unmemorized Icons", action: #selector(showNewIcons), keyEquivalent: "")    // "Select unmemorized icons" option
            arrangementButton.menu?.addItem(showMenu)
            arrangementButton.menu?.addItem(NSMenuItem.separator())
            if #available(macOS 13.0, *) {
                let runningHelper = SMAppService.loginItem(identifier: bDIM.hHI).status == .enabled
                let hiderMenu = NSMenuItem(title: !runningHelper ? "Start Hide Icons" : "Stop Hide Icons", action: #selector(doHider), keyEquivalent: "")    // "Hide/Show Desktop icons" option
                arrangementButton.menu?.addItem(hiderMenu)
            } else {
                let hiderMenu = NSMenuItem(title: hiding ? "Show Desktop icons" : "Hide Desktop icons", action: #selector(doHider), keyEquivalent: "")    // "Hide/Show Desktop icons" option
                arrangementButton.menu?.addItem(hiderMenu)
            }
            
            
            if #available(macOS 13.0, *) {
                arrangementButton.menu?.addItem(NSMenuItem.separator())

                let serv = SMAppService.loginItem(identifier: bDIM.hID)
                let runningHelper = serv.status == .enabled
                let want = UserDefaults(suiteName: bDIM.gUD)!.bool(forKey: "doHelper")
                let userDenied = (runningHelper != want) ? !toggleHelper(to: want) : false
                let menuTitle = "DIM helper is " + (userDenied ? "denied!" : (serv.status == .enabled ? "running" : "stopped"))
                let submenuItem = NSMenuItem(title: menuTitle, action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: menuTitle)
                if userDenied {
                    submenu.addItem(NSMenuItem(title: "Perhaps allow DIM in App Background Activity...", action: #selector(doHelperUD), keyEquivalent: ""))
                } else {
                    submenu.addItem(NSMenuItem(title: serv.status == .enabled ? "Stop DIM helper" : "Start DIM helper", action: #selector(doHelper), keyEquivalent: ""))
                }
                submenuItem.submenu = submenu
                arrangementButton.menu?.addItem(submenuItem)
            }
        }
    }
    
    func updateInfo() {
        currentTF.stringValue = "Use Icon Arrangement: " + currentName  // some useful(?) info for user
        if let num = dim!.numInSet {
            if let dictEntry = arrangements[currentName] as? NSArray {
                if dictEntry.count > 5 { currentNumArrangement.stringValue = "Number of memorized window Icons: " + String(num) }
                else { currentNumArrangement.stringValue = "Number of memorized Desktop Icons: " + String(num) }
            }
        } //AppleScript data should be insync
        if let num = dim!.numOnDesktop {
            if let dictEntry = arrangements[currentName] as? NSArray {
                if dictEntry.count > 5 { currentNumDesktop.stringValue = "Number of current window Icons: " + String(num) }
                else { currentNumDesktop.stringValue = "Number of current Desktop Icons: " + String(num) }
            }
        }
    }
    
    // user selected a different(?) arrangement
    @IBAction func arrangeButton(_ sender: NSPopUpButton) {
        quitTimer?.invalidate()
        if let name = sender.selectedItem?.title {
            if name != currentName && arrangements[name] != nil {
                _arrangeButton(name)
                refreshTimer() // refresh timer if it exists
            }
        }
    }
    
    func _arrangeButton(_ name: String) {
        currentName = name
        dim!.iconSet = arrangements[currentName]!  // sync AppleScript data
        dim!.numInSet = 0
        dim!.numOnDesktop = 0
        savePrefs()
        updateInfo() //loadMenu()
    }
    @objc func doHelperUD(_ sender: NSMenuItem) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func doHelper(_ sender: NSMenuItem) {
        let start = sender.title.contains("Start")
        if #available(macOS 13.0, *) {
            _ = toggleHelper(to: start)
        }
    }
    
    // toggle hiding/unhiding Desktop icons
    @objc func doHider(_ sender: NSMenuItem) {
        _doHider()
    }
    func _doHider() {
        quitTimer?.invalidate()
        
        if #available(macOS 13.0, *) {
            let serv = SMAppService.loginItem(identifier: bDIM.hHI)
            if serv.status == .enabled {
                try? serv.unregister()
            } else {
                try? serv.register()
            }
        } else {
            if hider != nil {
                NotificationCenter.default.post(name: .doHide, object: nil)
            } else {
                hider = Hider()
            }
        }
        hiding = !hiding // toggle state
        //updateInfo() //loadMenu()
    }
    
    // user wants to highlight new icons...
    @objc func showNewIcons(_ sender: NSMenuItem) {
        quitTimer?.invalidate()
        dim!.showNewIcons()
    }
    
    // user wants to edit arrangements...
    @objc func editArrangement(_ sender: NSMenuItem) {
        quitTimer?.invalidate()
        performSegue(withIdentifier: "toEditSheet", sender: self)
    }
    
    // give EditSheet access to the global data (could use notifications, but...)
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "toEditSheet" {
            if let dvc = segue.destinationController as? EditSheet {
                dvc.myContainerViewDelegate = self
            }
        } else if segue.identifier == "toPlistOption" {
            if let dvc = segue.destinationController as? PlistOption {
                dvc.myContainerViewDelegate = self
            }
        } else if segue.identifier == "toUpdate" {
            if let dvc = segue.destinationController as? UpdateSheet {
                dvc.myContainerViewDelegate = self
            }
        }
    }
    
    @IBOutlet weak var donateLabel: NSTextField!
    // hardcoded URL for donations (oh please!)
    @IBAction func donateClicked(_ sender: NSButton) {
        quitTimer?.invalidate()
        let url = URL(string: "http://www.parker9.com/d")
        NSWorkspace.shared.open(url!)
        donateLabel.textColor = NSColor.systemGray  //labelColor.withAlphaComponent(0.2)
        UserDefaults(suiteName: bDIM.gUD)!.set("done", forKey: "donate")
    }
    
    // hardcoded URL for home
    @IBAction func homeClicked(_ sender: NSButton) {
        quitTimer?.invalidate()
        let url = URL(string: "http://www.parker9.com/desktopIconManager4.html#d")
        NSWorkspace.shared.open(url!)
    }
    
    func errorwithAS() {
        if  ProcessInfo.processInfo.operatingSystemVersion.majorVersion > 12 {
            performSegue(withIdentifier: "toErrorVentura", sender: self)
        } else {
            performSegue(withIdentifier: "toError", sender: self)
        }
    }
    
    func updateError(_ title : String) {
        //print("in updateError: \(title)")
        DispatchQueue.main.async {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            appDelegate.checkUpdateMenuItem.title = title
            appDelegate.checkUpdateMenuItem.isEnabled = false
            Timer.scheduledTimer(withTimeInterval: 60*5, repeats: false) { (timer) in
                appDelegate.checkUpdateMenuItem.title = "Check for update..."
                appDelegate.checkUpdateMenuItem.isEnabled = true}
        }
    }
    @IBAction func checkForUpdate(_ sender: NSMenuItem) {
        let prog = Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as! String
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let url = URL(string: "https://www.parker9.com/com.parker9.versions.plist")!
        URLCache.shared.removeAllCachedResponses()
        if !updateDownloaded {
            let getDB = URLSession.shared.dataTask(with: url) { data, response, error in
                if error != nil || data == nil { self.updateError("Error connecting to update server"); return }
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { self.updateError("Error from update server"); return }
                do {
                    let database = try PropertyListSerialization.propertyList(from: data!, format: nil) as! [String : [String]]
                    if let progData = database[prog] {
                        if version != progData[0] { self.updateAvailable = progData; DispatchQueue.main.async { self.performSegue(withIdentifier: "toUpdate", sender: nil) }
                        } else { self.updateError("No update available")}
                    }
                } catch { self.updateError("Error understanding server response"); return }
            }
            getDB.resume()
        } else {
            if updateAvailable.count > 0 {
                let downloadFile = URL(string: updateAvailable[1])!
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                let downloadFolder = String(downloadFile.lastPathComponent.dropLast(4))
                let target = downloads.appendingPathComponent(downloadFolder)
                let prog = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
                let app = target.appendingPathComponent(prog + ".app")
                NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: downloads.path)
            }
        }
    }
    
    func noCommandLineArgs(_ args : [String]) -> Bool {
        let commands : Set = ["--memorize", "--add", "--restore", "--arrangement", "--hide-icons", "--select-missing-icons", "--delete", "--quit", "--update", "--purge"]
        return Set(args).intersection(commands).isEmpty &&
                UserDefaults(suiteName: bDIM.gUD)!.object(forKey: "helperArgs") == nil
        // N=0   UD!=nil  ==nil
        //  T       T       F       F
        //  F       T       F       F
        //  T       F       T       T
        //  F       F       T       F
    }
    func doCommandLineArgs(_ args : [String]) {
        let groupDefaults = UserDefaults(suiteName: bDIM.gUD)!
        var newArgs = args + (groupDefaults.stringArray(forKey: "helperArgs") ?? [])
        groupDefaults.removeObject(forKey: "helperArgs")
        groupDefaults.synchronize()
        while (!newArgs.isEmpty) {
            let isName = (newArgs.count > 1) ? newArgs[1].prefix(2) != "--"  : false
            let arrangementName = isName ? newArgs[1] : currentName
            let arg = newArgs[0]
            newArgs = Array(newArgs.dropFirst(isName ? 2 : 1))
            if #available(macOS 11.0, *) {
                if isName {  Logger.diag.info("parsing DIM argument = \(arg, privacy: .public) \(arrangementName, privacy: .private(mask: .hash))")
                } else { Logger.diag.info("parsing DIM argument = \(arg, privacy: .public)") }
            } //.private(mask: .hash)
            switch arg {
            case "--delete" :
                if orderedArrangements.count > 1 && orderedArrangements.contains(arrangementName) && arrangements[arrangementName] != nil {
                    orderedArrangements.remove(at: orderedArrangements.firstIndex(of: arrangementName)!)
                    arrangements.removeValue(forKey: arrangementName)
                    if currentName == arrangementName {
                        currentName = orderedArrangements[0]
                        _arrangeButton(currentName)
                    }
                }
            case "--memorize", "--purge" :
                updateUI("Purging Icon Positions...")
                DispatchQueue.global(qos: .utility).sync { [unowned self] in
                    let currentArrangement = (arrangementName == currentName) ? refetchSet() : fetchSet()
                    arrangements[arrangementName] = currentArrangement
                    if arrangementName != currentName { dim!.iconSet = arrangements[currentName] }
                    savePrefs()
                    if !orderedArrangements.contains(arrangementName) {
                        orderedArrangements.append(arrangementName)
                        _arrangeButton(currentName)
                    }
                }
                updateUI()
                refreshTimer()
            case "--add", "--update" :
                if arrangements[arrangementName] != nil {
                    updateUI("Memorizing Icon Positions...")
                    DispatchQueue.global(qos: .utility).sync { [unowned self] in
                        let currentArrangement = (arrangementName == currentName) ? refetchSet() : fetchSet()
                        arrangements[arrangementName] = mergeArrangements(addArrangement: arrangements[arrangementName]!, baseArrangement: currentArrangement)
                        dim!.iconSet = arrangements[arrangementName]
                        if arrangementName != currentName {
                            dim!.iconSet = arrangements[currentName]
                            _arrangeButton(currentName)
                        } else { savePrefs()}
                    }
                    updateUI()
                    refreshTimer()
                }
            case "--restore" :
                if arrangements[arrangementName] != nil {
                    updateUI("Restoring Icon Positions...")
                    DispatchQueue.global(qos: .utility).sync { [unowned self] in
                        setSet(set: arrangements[arrangementName]!)
                        dim!.numOnDesktop = 0
                        if arrangementName != currentName {
                            dim!.iconSet = arrangements[currentName]
                            _arrangeButton(currentName)
                        }
                    }
                    updateUI()
                    refreshTimer()
                }
            case "--arrangement" :
                if orderedArrangements.contains(arrangementName) && arrangements[arrangementName] != nil && arrangementName != currentName {
                    _arrangeButton(arrangementName)
                    refreshTimer()
                }
            case "--hide-icons" :
                _doHider()
            case "--select-missing-icons" :
                dim!.showNewIcons()
            case "--quit" :
                NSApp.terminate(self)
            default:
                if #available(macOS 11.0, *) {
                    Logger.diag.info("WARNING: unknown DIM argument = \(arg, privacy: .public)")
                }
            }
        }
    }

// add Import and Export of UserDefaults
    @IBAction func writePlist(_ sender: NSMenuItem) {  // this will (hopefully) copy the current UserDefaults data to user specified place
        // export any optional UserDefaults
        let defaults = UserDefaults(suiteName: bDIM.gUD)!
        let waitRestore = defaults.object(forKey: "waitRestore") != nil ? defaults.double(forKey: "waitRestore") : 10.0
        let quitCount = defaults.object(forKey: "quitCount") != nil ? defaults.integer(forKey: "quitCount") : 20
        let startHidden = defaults.object(forKey: "startHidden") != nil ? defaults.bool(forKey: "startHidden") : false
        let doHelper = defaults.bool(forKey: "doHelper")
        // old
        //let url2 = FileManager.default.homeDirectoryForCurrentUser.path+"/Library/Preferences/" + bDIM.bID + ".plist"
        // should have been?
        //let url2 = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/\(bDIM.bID)/Data/Library/Preferences/\(bDIM.bID).plist")
        
        // to read Group App UserDefaults...
        //defaults read ~/Library/Group\ Containers/group.com.parker9.DIM-4/Library/Preferences/group.com.parker9.DIM-4.plist
        let url2 = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: bDIM.gUD)!
            .appendingPathComponent("Library/Preferences/\(bDIM.gUD).plist").path
        if FileManager.default.fileExists(atPath: url2) {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.message = "Select location to export DIM Settings:"
            panel.nameFieldStringValue = bDIM.gUD + ".plist"
            panel.prompt = "Export"
            panel.allowedFileTypes = ["plist"]
            panel.nameFieldLabel = "Export As:"
            panel.beginSheetModal(for: self.view.window! ) {(reply) in
                if reply == .OK, let exportURL = panel.url {
                    let data = NSDictionary(dictionary: [
                        "currentName" : self.currentName,
                        "restoreAtStart" : self.restoreAtStart,
                        "actionAfterStart" : self.actionAfterStart.rawValue,
                        "orderedArrangements" : self.orderedArrangements,
                        "arrangements" : self.arrangements,
                        "automaticSave" : self.automaticSave,
                        "timerSeconds" : self.timerSeconds,
                        "waitRestore" : waitRestore,
                        "quitCount" : quitCount,
                        "startHidden" : startHidden,
                        "doHelper" : doHelper] )
                    if !data.write(toFile: exportURL.path, atomically: true) {if #available(macOS 11.0, *) { Logger.err.error("could not create exported Settings to \(exportURL.path, privacy: .private(mask: .hash))")}}
                }
            }
        }
    }
    var newData : NSDictionary?
    @IBAction func readPlist(_ sender: Any) {   // import new UserDefaults
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select DIM Settings to import:"
        panel.prompt = "Import"
        panel.allowedFileTypes = ["plist"]
        panel.nameFieldLabel = "Import As:"
        panel.beginSheetModal(for: self.view.window!) { (reply) in
            if reply == .OK, let importURL = panel.url {
                var segueID = "toBadFile"
                do {
                    let newData = try NSDictionary(contentsOf: importURL, error: ())   // try to coerce to NSDictionary
                    if let _ = newData["currentName"] as? String,
                        (newData["arrangements"] as? [String: Any])?.count ?? -1 == (newData["orderedArrangements"] as? [String])?.count ?? -2 { // is valid dictionary for DIM?
                        segueID = "toPlistOption"
                        self.newData = newData
                    }
                } catch { if #available(macOS 11.0, *) { Logger.err.error("cast to NSDictionary failed in readPlist")} }
                self.performSegue(withIdentifier: segueID, sender: self)
            }
        }
    }
    func doPlistOption(_ plistOption : PlistOptions = .cancel, includeMissing : Bool = false) {    // replace, merge input to current, merge current into import or cancel
        //print("includeMissing? \(includeMissing), plistOption: \(plistOption)")
        if plistOption != .cancel && newData?["arrangements"] != nil {
            switch plistOption {
            case .mergeIntoCurrent:
                
                // if optional UserDefaults do not exist and newData does, save optionals to UserDefaults
                let defaults = UserDefaults(suiteName: bDIM.gUD)!
                if defaults.object(forKey: "waitRestore") == nil, let waitRestore = newData!["waitRestore"] as? Double { defaults.set(waitRestore, forKey: "waitRestore") }
                if defaults.object(forKey: "quitCount") == nil, let quitCount = newData!["quitCount"] as? Bool { defaults.set(quitCount, forKey: "quitCount") }
                if defaults.object(forKey: "startHidden") == nil, let startHidden = newData!["startHidden"] as? Bool { defaults.set(startHidden, forKey: "startHidden") }
                
                if let newArrangements = newData!["arrangements"] as? [String: Any] {
                    if #available(macOS 11.0, *) { Logger.diag.info(".mergIntoCurrent \(newArrangements.count, privacy: .public) \(self.arrangements.count, privacy: .public)") }
                    for (name, arrangement) in newArrangements {
                        if arrangements[name] == nil {
                            arrangements[name] = arrangement
                        } else if includeMissing {
                            arrangements[name] = mergeArrangements(addArrangement: arrangement, baseArrangement: arrangements[name]!)
                        }
                        if !orderedArrangements.contains(name) { orderedArrangements.append(name) }
                    }
                }
            case .replace, .mergeIntoImported:
                currentName = newData?["currentName"] as? String ?? currentName
                restoreAtStart = newData?["restoreAtStart"] as? Bool ?? restoreAtStart
                actionAfterStart = ActionItems(rawValue: newData?["actionAfterStart"] as? Int ?? actionAfterStart.rawValue) ?? actionAfterStart
                orderedArrangements = newData?["orderedArrangements"] as? [String] ?? orderedArrangements
                automaticSave = newData?["automaticSave"] as? Bool ?? automaticSave
                timerSeconds = newData?["timerSeconds"] as? Int ?? timerSeconds
        
                // if newData has any optional UserDefaults replace them
                let defaults = UserDefaults(suiteName: bDIM.gUD)!
                if let waitRestore = newData?["waitRestore"] as? Double {defaults.set(waitRestore, forKey: "waitRestore")}
                if let quitCount = newData?["quitCount"] as? Int {defaults.set(quitCount, forKey: "quitCount")}
                if let startHidden =  newData?["startHidden"] as? Bool {defaults.set(startHidden, forKey: "startHidden")}
                if let doHelper = newData?["doHelper"] as? Bool {defaults.set(doHelper, forKey: "doHelper")}
                
                if plistOption == .replace {
                    arrangements = newData!["arrangements"] as? [String: Any] ?? arrangements
                    if #available(macOS 11.0, *) { Logger.diag.info(".replace \(self.arrangements.count, privacy: .public)") }
                } else {
                    if let newArrangements = newData!["arrangements"] as? [String: Any] {
                        for (name, arrangement) in newArrangements {
                            if arrangements[name] == nil || !includeMissing {
                                arrangements[name] = arrangement
                            } else if includeMissing {
                                arrangements[name] = mergeArrangements(addArrangement: arrangements[name]!, baseArrangement: arrangement)
                            }
                            if !orderedArrangements.contains(name) { orderedArrangements.append(name) }
                        }
                        /*
                        for (name, arrangment) in newArrangements {
                            arrangements[name] = arrangment
                            if !orderedArrangements.contains(name) { orderedArrangements.append(name) }
                        }
                        */
                        if #available(macOS 11.0, *) { Logger.diag.info(".mergeIntoImported \(self.arrangements.count, privacy: .public) \(newArrangements.count, privacy: .public)") }
                    }
                }
            case .cancel: // should never reach, but compiler complains
                return
            }
            savePrefs()
            overrideSetting = true
            loadPrefs()
            overrideSetting = false
        }
        newData = nil
    }
    
    /*
    for desktop:
     set iconSet to {iconNames, iconPositions, screenSize, iconSize, textSize}
    for windows:
     set iconSet to {iconNames, iconPositions, screenSize, iconSize, textSize, aliasWindow}
     if saveWindowPosition then set end of iconSet to windowPosition
     if saveWindowBounds then set end of iconSet to windowBounds
     */
    func mergeArrangements(addArrangement: Any, baseArrangement: Any) -> Any {
        // add any addArrangement icons missing in baseArrangement to baseArrangement
        if let oldData = addArrangement as? [Any], let newData = baseArrangement as? [Any] {
            let oldNames = oldData[0] as! [String]
            let oldPos = oldData[1] as! [[Int]]
            
            //let newData = baseArrangement as! [Any]
            var newNames = newData[0] as! [String]
            var newPos = newData[1] as! [[Int]]
            
            // add any old items to current ones
            for (index,name) in oldNames.enumerated() {
                if !newNames.contains(name) {
                    newNames.append(name)
                    newPos.append(oldPos[index])
                }
            }
            let mergedArrangement = NSMutableArray.init() // now construct NSMutableArray to hold new iconSet
            mergedArrangement.add(NSMutableArray(array: newNames))  //first names
            mergedArrangement.add(NSMutableArray(array: newPos))    //then positions
            for i in 2..<newData.count { mergedArrangement.add(newData[i])} // and all the other stuff (screenSize, iconSize...)
            let final : Any = mergedArrangement                     // and wrap it up as an Any
           /* if #available(macOS 11.0, *) {
                print("addArrangement: \(addArrangement)")
                print("baseArrangement: \(baseArrangement)")
                print("final: \(final)")
            } */
            return final // return final merged
        } else {
            return baseArrangement  // some problem, just return base (i.e. no merge)
        }
    }
    
    func migrateToAppGroupIfNeeded() {
        let appGroup = UserDefaults(suiteName: bDIM.gUD)!
      
        guard !appGroup.bool(forKey: "migratedFromStandard") else { return }
        
        // sandboxed: UserDefaults.standard is already scoped to container
        // unsandboxed: UserDefaults.standard is ~/Library/Preferences — may be empty
        
        var dict: [String: Any] = [:]
        
        if dict.isEmpty {
            // sandboxed app can not read sandbox container this way, but unsandbox can...
            let sandboxPlist = ("~/Library/Containers/" + bDIM.bID +
                                "/Data/Library/Preferences/" + bDIM.bID + ".plist") as NSString
            let url = URL(fileURLWithPath: sandboxPlist.expandingTildeInPath)
            if FileManager.default.fileExists(atPath: url.path),
               let containerDict = NSDictionary(contentsOf: url) as? [String: Any] {
                dict = containerDict
            }
        }
        
        if dict.isEmpty {  // we are sandboxed OR nothing was in the container to start with
            dict = UserDefaults.standard.dictionaryRepresentation()
        }
        // filter out junk...
        let systemPrefixes = ["com.apple.", "Apple", "NS", "AK", "ATS", "PL", "KB_", "ACD", "_HI", "shouldShowRSVP", "Countr", "MultipleSess", "NavPanel", "Web", "_AKB", "PKS"]
        dict.forEach { key, value in
            guard !systemPrefixes.contains(where: { key.hasPrefix($0) }) else { return }
            appGroup.set(value, forKey: key) }
    
        appGroup.set(true, forKey: "migratedFromStandard")
        
        /*
        // only migrate once
        guard appGroup.bool(forKey: "migratedFromStandard") == false else { return }
        
        // copy all keys from standard to app group
        UserDefaults.standard.dictionaryRepresentation().forEach { key, value in
            appGroup.set(value, forKey: key)
        }
        
        appGroup.set(true, forKey: "migratedFromStandard")
        appGroup.synchronize()
        */
    }
    
    // helper app
    @available(macOS 13.0, *)
    func toggleHelper(to start: Bool,_ helperBundleID: String = bDIM.hID) -> Bool {
        
        let groupDefaults = UserDefaults(suiteName: bDIM.gUD)!
        groupDefaults.set(start, forKey: "doHelper")
        
        let helperService = SMAppService.loginItem(identifier: helperBundleID)
        let isEnabled = helperService.status == .enabled
        if start && !isEnabled {
            do {
                try helperService.register()
                Logger.diag.info("DIMHelper enabled successfully")
            } catch {
                Logger.diag.info("DIMHelper registration failed: \(error.localizedDescription, privacy: .public)")
                //userDenied = error.localizedDescription.contains("Operation not permitted")
                return false
            }
        } else if !start && isEnabled {
            helperService.unregister { error in
                if let error = error {
                    Logger.diag.info("Failed to unregister DIMHelper: \(error.localizedDescription, privacy: .public)")
                } else {
                    Logger.diag.info("Unregistered DIMHelper")
                    groupDefaults.removeObject(forKey: "helperArgs") //remove debris...
                }
            }
        }
        groupDefaults.synchronize()
        return true
    }
}

extension ViewController: NSMenuDelegate {  // so loadMenu constructs itself when button is pressed
    func menuNeedsUpdate(_ menu: NSMenu) {
        //print("NSMenuDelegate fired! \(menu)")
        loadMenu()
    }
}
