//
//  myWindow.swift
//  EureKalc
//
//  Created by Nico on 09/12/2022.
//  Copyright © 2022 Nico Hirtt. All rights reserved.
//

import Cocoa

class myWindow: NSWindow {

    var equationView : EquationView?
    
    override func keyDown(with event: NSEvent) {
        makeFirstResponder(equationView!)
        super.keyDown(with: event)
    }
    
}
