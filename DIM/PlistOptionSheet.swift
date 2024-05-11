//
//  PlistOptionSheet.swift
//  DIM
//
//  Created by G.J. Parker on 7/23/23.
//  Copyright © 2023 G.J. Parker. All rights reserved.
//

import Cocoa

enum PlistOptions: Int {    // different options for importing UserDefaults
    case cancel = 0, replace, mergeIntoCurrent, mergeIntoImported
}

class PlistOption: NSViewController {
    var myContainerViewDelegate: ViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBOutlet weak var replaceButton: NSButton!
    @IBOutlet weak var mergeIntoImportedButton: NSButton!
    @IBOutlet weak var mergeIntoCurrentButton: NSButton!
    
    @IBOutlet weak var includeMissing: NSButton!
    
    @IBAction func radioButtonSelected(_ sender: NSButton) {
        includeMissing.isEnabled = sender.title != "Replace current Settings"
    }
    
    @IBAction func buttonPressed(_ sender: NSButton) {
        var plistOption : PlistOptions = .cancel
        if sender.title != "Cancel" {
            if replaceButton.state == .on { plistOption = .replace }
            else if mergeIntoCurrentButton.state == .on { plistOption = .mergeIntoCurrent }
            else { plistOption = .mergeIntoImported}
            //print(replaceButton.state,mergeIntoCurrentButton.state,mergeIntoImportedButton.state)
        }
        self.dismiss(self)
        myContainerViewDelegate?.doPlistOption(plistOption, includeMissing : includeMissing.state == .on)
    }
    
}
