import Cocoa
import AppleScriptObjC

@objc(NSObject) protocol DIMBridge {  // protocol to bridge to AppleScriptObjC- thanks to https://github.com/hhas/Swift-AppleScriptObjC
    
    var iconSet: Any { get set }             // array of applescript arrays [ [iconNames], [iconPositions], [screenSize] ], used both for getting and setting
    var numArrangement: NSNumber { get set } // returns stored number of icons on desktop (does not compute)- only use get, but seems set is required (but not used)
    var numDesktop: NSNumber { get set }     // returns stored number of icons in the current iconSet- only use get, but seems set is required (but not used)
    var getWindows: [NSString] {get set}    // get an array of Finder window names that are in icon view
    var saveWindowPosition: NSNumber {get set}  // should we save Finder window position?
    var saveWindowBounds: NSNumber {get set}    // should we save Finder window size?
    var targetWindow: NSNumber { get set }      // for creating iconSet for Finder windows

    func numOnDesktop() // set number of icons on desktop by asking Finder, this is an AppleScript function
    func numInSet()     // sets number of icons in iconSet by asking Finder to count items in iconSet, this is an AppleScript function
    func memorize()     // This grabs required data from Finder through AppleScript, sets iconSet, numArrangement and numDesktop, this is a function (no return value)
    func rememorize()   // same as memorize, but replaces iconSet but first uses iconSet to determine if Desktop or Finder window
    func restore()      // This tells the Finder to restore icons through AppleScript positions according to current iconSet and updates numArrangment, this is a function (no return value)
    func showNewIcons() // This tells the Finder to select unmemorized icons on the desktop
    func listWindows()  // function to construct getWindows

    var testBridge: NSString { get }  // test function to see if AppleScriptObjC bridge is working
}


class DIM {  // this class deals directly
    
    var  _DIM: DIMBridge?
    
    init() {
        Bundle.main.loadAppleScriptObjectiveCScripts()
        let DIMBridgeClass: AnyClass = NSClassFromString("ApplescriptBridge")!
        self._DIM = DIMBridgeClass.alloc() as? DIMBridge
    }

    var DIM: DIMBridge? {
        get { return _DIM }
    }
    func getWindows() -> [String] { // array of Finder windows currently in icon view
        if _DIM != nil {
            _DIM!.listWindows()
            let names = _DIM!.getWindows
            return names as [String]
        }
        return [String]() // nothing found!
    }
    func restore() {  // restore icons according to iconSet
        if _DIM != nil { _DIM!.restore() }
    }
    func memorize() {  // new iconSet
        if _DIM != nil { _DIM!.memorize() }
    }
    func rememorize() { // replace iconSet w/ new values
        if _DIM != nil { _DIM!.rememorize() }
    }
    func showNewIcons() {  // show unmemorize icons
        if _DIM != nil { _DIM!.showNewIcons() }
    }
    var testBridge : String? { // test AppleScriptObjC bridge
        get { return _DIM?.testBridge as String? }
    }
    var targetWindow : Int {  // used only from AddArrangement.swift to deal w/ Finder windows
        get { return _DIM!.targetWindow as! Int }
        set (value) {
            _DIM!.targetWindow = value as NSNumber
        }
    }
    var iconSet : Any? {
        get { return _DIM?.iconSet as Any? }    // get whatever is in iconSet
        set (value) {
            if value != nil {
                _DIM!.iconSet = value as Any    // set iconSet
                _DIM!.numInSet()                // and update the number of icons in iconSet
            }
        }
    }
    var numInSet : Int? {
        get { return _DIM?.numArrangement as? Int } // get number of icons in iconSet
        set (value) {
            if _DIM != nil {_DIM!.numInSet()}       // update the number of icons in iconSet
        }
    }
    var numOnDesktop : Int? {
        get { return _DIM?.numDesktop as? Int }     // get number of icons on Desktop or Finder window
        set (value) {
            if _DIM != nil {_DIM!.numOnDesktop()}   // update number of icons on Desktop or Finder window
        }
    }
    var saveWindowPosition : Bool {                 // should we save Finder window position?
        get { return _DIM?.saveWindowPosition as! Int == 1}
        set (value) { _DIM?.saveWindowPosition = value ? 1 : 0}
    }
    var saveWindowBounds : Bool {                   // should we save Finder window size?
        get {return _DIM?.saveWindowBounds as! Int == 1}
        set (value) {_DIM?.saveWindowBounds = value ? 1 : 0}
    }

}
