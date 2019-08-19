//
//  ScriptWindowController.swift
//  EureKalc
//
//  Created by Nico on 27/03/2020.
//  Copyright © 2020 Nico Hirtt. All rights reserved.
//

import Cocoa

class ScriptEditView: NSTextView {
    
    var myController : ScriptViewController?
    var consoleMode = false
    
    override var acceptsFirstResponder: Bool {
         return true
     }
    
    // gestion automatique des indentations
     override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        let theKey = Int(event.keyCode)
        if theKey == 48 || theKey == 36 || theKey == 76 {
            if consoleMode {
                let thePos = NSMaxRange(self.selectedRange)
                let text = self.string.prefix(thePos-1)
                let splitted = text.split(separator: "\n",omittingEmptySubsequences: false)
                let line = String(splitted.last!)
                let hScript = codeScriptHierarchic(script: line)
                let result = hScript.executeHierarchicScript()
                let resultText = result.stringExp(units: true)
                if resultText != "" {
                    self.string = self.string.dropLast() + "  -->  " + resultText + "\n"
                }
            } else {
                autoIndent()
            }
        }
        if consoleMode { return }
        _ = myController!.saveScript()
    }
    
    func autoIndent() {
        if consoleMode { return }
        let text = self.string
        let loc = self.selectedRange().location
        let part1 = String(text.prefix(loc)) + "*"
        let newpart1 = myController!.autoIndent(part1)
        let newLoc = newpart1.count - 1
        let newText = myController!.autoIndent(text)
        self.string = newText
        self.setSelectedRange(NSMakeRange(newLoc, 0))
        _ = myController!.saveScript()
    }
    
    func setSettings() {
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        
        let font = NSFont(name: "Monaco", size: 12)
        var attributes = typingAttributes
        attributes[NSAttributedString.Key.font] = font as Any
        typingAttributes = attributes

    }
    
}



class ScriptViewController: NSViewController {

    @IBOutlet var scriptEditView: ScriptEditView!
    
    var scriptName: String = "" // Le nom du script
    var scriptLibrary : ekLibraryItem? = nil // la librairie pour les scripts en librairie
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scriptEditView.myController = self
        scriptEditView.setSettings()
        
    }
    
    @IBAction func runButton(_ sender: Any) {
        let hierExp = saveScript()
        _ = hierExp.executeHierarchicScript()
    }
    
    // Crée une version indentée du script
    func autoIndent(_ text: String) -> String {
        let myCharacterSet = CharacterSet(charactersIn: " \t") // espace et tab
        var newText = ""
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var indent = 0
        for aLine in lines {
            let line = String(aLine).trimmingCharacters(in: myCharacterSet) // suppression des blancs avant traitement
            if lineWithKeyword(line: line, prefixes: ["If(","While(","For(","Function("]) {
                newText = newText + String(repeating: "\t", count: indent) + line + "\n"
                indent = indent + 1
            } else if lineWithKeyword(line: line, prefixes: ["Else"], exact: true) {
                newText = newText + String(repeating: "\t", count: max(0,indent-1)) + line + "\n"
            } else if lineWithKeyword(line: line, prefixes: ["Endif","Loop","Next","End"], exact: true) {
                indent = max(indent - 1,0) // en cas d'erreur, évite le bogue !!
                newText = newText + String(repeating: "\t", count: indent) + line + "\n"
            } else {
                newText = newText + String(repeating: "\t", count: indent) + line + "\n"
            }
        }
        newText.removeLast()
        return(newText)
    }
    
    //pour tester si la ligne commence par un mot-clé type IF, END, etc... en différentes casses
    func lineWithKeyword(line: String, prefixes: [String], exact: Bool = false) -> Bool {
        if exact { // la ligne est exactement égale
            for p in prefixes {
                if line == p { return true }
                if line == p.lowercased() { return true }
                if line == p.uppercased() {return true }
            }
        } else { // la ligne commence par...
            for p in prefixes {
                if line.hasPrefix(p) { return true }
                if line.hasPrefix(p.lowercased()) { return true }
                if line.hasPrefix(p.uppercased()) {return true }
            }
        }
        return false
    }
    
    
    func saveScript() -> HierarchicExp {
        if scriptEditView.consoleMode { return HierarchicExp() }
        let hierExp = codeScriptHierarchic(script: scriptEditView.string)
        if scriptLibrary == nil {
            if scriptName.contains(".") {
                let splitted = scriptName.split(separator: ".")
                let popName = String(splitted[0])
                let scriptName = String(splitted[1])
                if popName == "World" {
                    theSim.scripts[scriptName] = hierExp
                } else {
                    theSim.pops[popName]!.scripts[scriptName] = hierExp
                }
            } else {
                theScripts[scriptName] = hierExp
            }
        } else {
            scriptLibrary!.script = scriptEditView.string
        }
        return hierExp
    }
    
    func showScript(_ inputText : String?) {
        scriptEditView.string = ""
        var script: HierarchicExp?
        if scriptLibrary == nil {
            if scriptName.contains(".") {
                let splitted = scriptName.split(separator: ".")
                let popName = String(splitted[0])
                let name = String(splitted[1])
                if popName == "World" {
                    script = theSim.scripts[name]
                } else {
                    script = theSim.pops[popName]!.scripts[name]
                }
            } else {
                script = theScripts[scriptName]
            }
            //if script == nil { return }
            let text = script?.toText() ?? ""
            scriptEditView.string = autoIndent(text)
            scriptEditView.isEditable = true
        } else {
            scriptEditView.string = self.autoIndent(scriptLibrary!.script)
        }
    }
    
}
