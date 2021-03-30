//
//  EditSheet.swift
//  DIM 3.0
//
//  Created by G.J. Parker on 19/1/19.
//  Copyright © 2019 G.J. Parker. All rights reserved.
//

import Cocoa

class EditSheet: NSViewController {
    
    var myContainerViewDelegate: ViewController?  // this will be set by the parent viewcontroller
    
    @IBOutlet weak var editTableView: NSTableView!  //IB outlets
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var doingTF: NSTextField!
    @IBOutlet weak var doingPI: NSProgressIndicator!
    @IBOutlet weak var doneButton: NSButton!
    
    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "private.table-row") //for reordering of list
    var startRow = 0       // starting row when entiries are drag/drop for reordering so we can reorder our data list
    var startingName = ""  // starting currentName
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startingName = myContainerViewDelegate!.currentName                       // save starting currentName in case we need it, just make what user expects to happen
        removeButton.isEnabled = myContainerViewDelegate!.arrangements.count > 1  // we always need at least one arrangment
        
        // set up tableView including support for drag/drop for reordering
        editTableView.delegate = self
        editTableView.dataSource = self
        editTableView.registerForDraggedTypes([dragDropType])
        editTableView.reloadData()
        setRowSelection(name: startingName)  // select the currentName as the selection
    }
    
    override var representedObject: Any? {
        didSet {
            editTableView.reloadData()
            setRowSelection(name: myContainerViewDelegate!.currentName)
        }
    }
    
    // want to edit an arrangement name, perhaps
    @IBAction func doubleClick(_ sender: NSTableView) {
        performSegue(withIdentifier: "toChange", sender: nil)
    }
   
    //user wants to add or rename an arrangement
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        if sender == nil {  // rename an arrangement
            guard let addVC = segue.destinationController as? ChangeArrangement else {return}
            addVC.newName = myContainerViewDelegate!.orderedArrangements[editTableView.selectedRow]
        } else {            // want to add an arrangement
            if segue.identifier == "toAdd" {  // not needed since we hav only on segue, but...
                guard let addVC = segue.destinationController as? AddArrangement else {return}
                var name = myContainerViewDelegate!.orderedArrangements[editTableView.selectedRow]  // find a default unique arrangement name
                for i in 1... {
                    if myContainerViewDelegate!.arrangements[name+" "+String(i)] == nil {
                        name = name + " " + String(i)
                        break
                    }
                }
                addVC.dim = myContainerViewDelegate!.dim
                addVC.newName = name
                addVC.orderedArrangements = myContainerViewDelegate!.orderedArrangements
            }
        }
    }
    
    // this is sent back from addArrangement/changeArrangment sheet, we either renamed or added an arrangment
    func addArrangment(_ newName: String, oldName: String, what: String) {
        if what == "Change" && newName != oldName && myContainerViewDelegate!.arrangements[newName] == nil {  // rename is only valid if name changed AND there isn't one already w/ that name, otherwise silently fail
            myContainerViewDelegate!.currentName = newName
            myContainerViewDelegate!.orderedArrangements[myContainerViewDelegate!.orderedArrangements.index(of: oldName)!] = newName
            myContainerViewDelegate!.arrangements[newName] = myContainerViewDelegate!.arrangements[oldName]
            myContainerViewDelegate!.arrangements[oldName] = nil
            myContainerViewDelegate!.savePrefs()
            myContainerViewDelegate!.loadMenu()
            editTableView.reloadData()
            setRowSelection(name: newName)
        } else if what == "Add" && newName != "" && myContainerViewDelegate!.arrangements[newName] == nil {    // we're going add, but only if we have a new name that isn't used (and is something), otherwise silently fail
            memorize(newName)
            myContainerViewDelegate!.currentName = newName
            myContainerViewDelegate!.orderedArrangements.append(newName)
            removeButton.isEnabled = myContainerViewDelegate!.orderedArrangements.count > 1
            editTableView.reloadData()
            setRowSelection(name: newName)
        } else { NSSound.beep() }
    }
    
    // user wants to delete an arrangement
    @IBAction func removeButtonPressed(_ sender: NSButton) {
        let index = editTableView.selectedRow
        if index < 0 || index+1 > myContainerViewDelegate!.orderedArrangements.count { return }  // this should *never* happen
        let thisName = myContainerViewDelegate!.orderedArrangements[index]
        myContainerViewDelegate!.orderedArrangements.remove(at: index) // delete this arrangement
        myContainerViewDelegate!.arrangements[thisName] = nil          // also delete the actual data for this arrangement
        if thisName == myContainerViewDelegate!.currentName {          // user deleted currentName, need to find a new one...
            if myContainerViewDelegate!.arrangements[startingName] != nil {  // do we still have the starting name?
                myContainerViewDelegate!.currentName = startingName    // yes, then use it!
            } else {
                myContainerViewDelegate!.currentName = myContainerViewDelegate!.orderedArrangements[0] //no, starting name is also gone, just grab the first one in the ordered list, we require something...
            }
        }
        removeButton.isEnabled = myContainerViewDelegate!.arrangements.count > 1 // update delete button (need at least two to be enabled)
        myContainerViewDelegate!.savePrefs()   // and save state
        myContainerViewDelegate!.loadMenu()
        editTableView.reloadData()
        setRowSelection(name: myContainerViewDelegate!.currentName)
    }
    
    // only way out of this view, so make sure all the data structures are consistent including iconSet and numSet (else bad things will happen) and save for return
    @IBAction func donePressed(_ sender: NSButton) {
        let thisName = myContainerViewDelegate!.orderedArrangements[editTableView.selectedRow]
        myContainerViewDelegate!.currentName = thisName
        myContainerViewDelegate!.dim!.iconSet = myContainerViewDelegate!.arrangements[thisName]!
        myContainerViewDelegate!.dim!.numInSet = 0
        myContainerViewDelegate!.dim!.numOnDesktop = 0
        myContainerViewDelegate!.savePrefs()
        myContainerViewDelegate!.loadMenu()
        self.dismiss(self)
    }
    
    
    // memorize the new arrangment- somewhat redundant code, but the view changed, so...
    func memorize(_ name: String) {
        updateUI("Memorizing Icon Positions...")
        DispatchQueue.global(qos: .utility).async { [unowned self] in
            self.myContainerViewDelegate!.arrangements[name] = self.myContainerViewDelegate!.fetchSet()
            DispatchQueue.main.async {
                self.myContainerViewDelegate!.savePrefs()
                self.myContainerViewDelegate!.loadMenu()
                self.updateUI()
            }
        }
    }
    func updateUI(_ message: String) {  // turn off controls while memorizing
        doingTF.stringValue = message
        doneButton.isEnabled = false
        addButton.isEnabled = false
        removeButton.isEnabled = false
        doingTF.isHidden = false
        editTableView.isEnabled = false
        doingPI.startAnimation(nil)
    }
    func updateUI() {  // turn controls back on after memorizing
        doneButton.isEnabled = true
        addButton.isEnabled = true
        removeButton.isEnabled = myContainerViewDelegate!.arrangements.count > 1
        doingTF.isHidden = true
        editTableView.isEnabled = true
        doingPI.stopAnimation(nil)
    }
    
    // helper function to set the selection to the arrangement w/ specified name
    func setRowSelection(name: String) {
        editTableView.selectRowIndexes(IndexSet(integer: myContainerViewDelegate!.orderedArrangements.index(of: name)!), byExtendingSelection: false)
    }
}


// stuff to deal w/ tableView
extension EditSheet: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in editTableView: NSTableView) -> Int {
        return myContainerViewDelegate!.orderedArrangements.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return myContainerViewDelegate!.orderedArrangements[row]
    }
    func tableView(_ editTableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?{
        var result:NSTableCellView
        result  = editTableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as! NSTableCellView
        result.textField?.stringValue = myContainerViewDelegate!.orderedArrangements[row]
        return result
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        
    }
    
    // for drag and drop reordering
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: self.dragDropType)
        startRow = row
        return item
    }
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            if let str = (dragItem.item as! NSPasteboardItem).string(forType: self.dragDropType), let index = Int(str) {
                oldIndexes.append(index)
            }
        }
        
        var oldIndexOffset = 0
        var newIndexOffset = 0
        
        // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
        // You may want to move rows in your content array and then call `tableView.reloadData()` instead.  ! but do NOT call reloadData here, so just do it manually
        tableView.beginUpdates()
        for oldIndex in oldIndexes {
            if oldIndex < row {
                tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
                oldIndexOffset -= 1
            } else {
                tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
                newIndexOffset += 1
            }
        }
        tableView.endUpdates()
        
        // update the data, just need to do orderedArrangements
        let name = myContainerViewDelegate!.orderedArrangements[startRow]
        if startRow > row {
            myContainerViewDelegate!.orderedArrangements.remove(at: startRow)
            myContainerViewDelegate!.orderedArrangements.insert(name, at: row)
        } else {
            myContainerViewDelegate!.orderedArrangements.insert(name, at: row)
            myContainerViewDelegate!.orderedArrangements.remove(at: startRow)
        }
        
        return true
    }
    
}



