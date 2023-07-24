//
//  ErrorSheet.swift
//  DIM
//
//  Created by G.J. Parker on 19/1/24.
//  Copyright © 2021 G.J. Parker. All rights reserved.
//

import Cocoa

class ErrorSheet: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func quitButton(_ sender: NSButton) {
        exit(0)
    }
    
    @IBAction func okButton(_ sender: NSButton) {
        self.dismiss(self)
        return
    }
}
