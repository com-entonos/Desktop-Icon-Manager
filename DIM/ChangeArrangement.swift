//
//  ChangeArrangement.swift
//  DIM
//
//  Created by G.J. Parker on 19/10/26.
//  Copyright © 2019 G.J. Parker. All rights reserved.
//

import Cocoa

class ChangeArrangement: NSViewController {
    
    var newName = ""  // default new arrangement name, will be set by the parent viewcontroller
    //var toDo = ""  // we are either making a new arrangement or we are renaming an existing arrangement, will be set by parent viewcontroller
    
    @IBOutlet weak var newArrangement: NSTextField!
    @IBOutlet weak var whatToDoLabel: NSTextField!
    @IBOutlet weak var okButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        newArrangement.stringValue = newName  // grab default
        whatToDoLabel.stringValue = "Enter new Icon Arrangement name:"
        
        // set up the correct title for the Add/Change button
        okButton.title = "Change"
    }
    
    // user press Add/Change so pass back the new name, old name and if Change or Add (if pressed Cancel it simply destroys the view and returns)
    @IBAction func okPressed(_ sender: NSButton) {
        let editVC = presentingViewController as! EditSheet
        editVC.addArrangment(newArrangement.stringValue, oldName: newName, what: okButton.title)
        self.dismiss(self)
    }
}
