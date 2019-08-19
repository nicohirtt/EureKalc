//
//  EditionField.swift
//  EureKalc
//
//  Created by Nico on 06/12/2022.
//  Copyright © 2022 Nico Hirtt. All rights reserved.
//

import Cocoa

class EditionField: NSTextField, NSTextFieldDelegate {

    var mainController : MainController?
    var mainview : EquationView?
    var mouseLocation: NSPoint? { self.window?.mouseLocationOutsideOfEventStream }
    
    override var isEnabled: Bool {
        willSet {
            textColor = newValue ? NSColor.darkGray : NSColor.systemBlue
        }
    }

    override func mouseDown(with event: NSEvent) {
        self.continueEdit()
        mainController?.selectedEquation?.editing = true
        let location = event.locationInWindow
        let viewLocation = self.currentEditor()!.convert(location, from: nil)
        let position = (self.currentEditor()! as! NSTextView).characterIndexForInsertion(at: viewLocation)
        self.currentEditor()!.selectedRange = NSMakeRange(position, 0)
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let event = NSApplication.shared.currentEvent
        // 36=RETURN, 76=ENTER, 48=TAB, ESC=53, RAR=124, LAR=123, UAR=126, DAR=125
        // 115=TOP, 119=BOTTOM, DELR=117, BACK=51
        if event==nil {
            return false
        }
        let key=event!.keyCode
        let theRange = self.currentEditor()!.selectedRange
        let L = theRange.length
        let P = theRange.location

        if [36,76,48,53,126,125,115,119].contains(key) {
            mainController!.manageKeyEvent(event: event!)
            return true
        } else if [123,124,51,117].contains(key)  {
               
            if self.stringValue == "" {
                mainController!.manageKeyEvent(event: event!)
                return true
            }
            
            if L == self.stringValue.count {
                mainController!.manageKeyEvent(event: event!)
                return true
            }
            
            if key == 123 && P==0 && L==0 {
                mainController!.manageKeyEvent(event: event!)
                return true
            }
            
            if key == 124 && P == self.stringValue.count && L == 0 {
                mainController!.manageKeyEvent(event: event!)
                return true
            }
                
        }
        // sinon, on laisse le TextField gérer l'événement
        return false
    }
    
    func emptyDisabled() {
        self.isEditable = false
        self.isEnabled = false
        self.stringValue = ""
        self.window!.makeFirstResponder(mainController!.theEquationView)
    }

    func continueEdit() {
        self.isEditable = true
        self.isEnabled = true
        self.window!.makeFirstResponder(self)
        self.currentEditor()!.moveToEndOfLine(self)
    }
    
    func startAndSelectEdit(string: String) {
        self.isEditable = true
        self.isEnabled = true
        self.stringValue = string
        self.selectText(self)
        self.window!.makeFirstResponder(self)
    }
    
    func showDisabled(string: String) {
        self.isEditable = false
        self.isEnabled = false
        self.stringValue = string
        self.window!.makeFirstResponder(mainController!.theEquationView)
    }
}
