//
//  varsTabController.swift
//  EureKalc
//
//  Created by Nico on 26/09/2020.
//  Copyright © 2020 Nico Hirtt. All rights reserved.
//

import Cocoa
import Foundation

class VarsTabController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    @IBOutlet var varsScrollView: NSScrollView!
    @IBOutlet var theOutlineView: NSOutlineView!
    @IBOutlet var nameColumn: NSTableColumn!
    @IBOutlet var deleteBtn: NSButton!
    @IBOutlet var editBtn: NSButton!
    @IBOutlet var newItemBtn: NSButton!
    @IBOutlet var runScriptBtn: NSButton!
    @IBOutlet var useLibBtn: NSButton!
    @IBOutlet var descriptionLbl: NSTextField!
    @IBOutlet var copyBtn: NSButton!
    
    var selectedItem : varsOutlineItem?
    var editType = ""

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        theOutlineView.delegate = self
        theOutlineView.dataSource = self
        mainDoc.varsTabCtrl = self
        
    }
    
    func reloadItems() {
        theOutlineView.reloadItem(nil, reloadChildren: true)
    }
    
    // Le datasource de la fenêtre de visualisation des scripts
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            switch index {
            case 0: return varsOutlineItem(itemType: "document", name: "Document", father: nil)
            case 2: return varsOutlineItem(library: dataLibrary, father: nil)
            case 1: return varsOutlineItem(itemType: "sim", name: "Model", father: nil)
            default: return ""
            }
        }
        return (item as! varsOutlineItem).childs[index]
    }
    
    // is expandable ?
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable: Any) -> Bool {
        let item = isItemExpandable as! varsOutlineItem
        if item.itemType == "var" || item.itemType == "func" || item.itemType == "script" { return false }
        return true
    }
    
    // number of children
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem: Any?) -> Int {
        if numberOfChildrenOfItem == nil { return 3 }
        var n = (numberOfChildrenOfItem as! varsOutlineItem).childs.count
        if editType == (numberOfChildrenOfItem as! varsOutlineItem).itemType {
            n = n + 1
        }
        return (numberOfChildrenOfItem as! varsOutlineItem).childs.count
    }
    
    // Contenu à afficher pour chaque item
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if item == nil { return ""}
        let outlineItem = item as! varsOutlineItem
        let itemType = outlineItem.itemType
        let itemName = outlineItem.name
        var theString = ""
        switch itemType {
        case "document" :
            theString = "Document"
        case "variables" :
            theString = "Variables"
        case "functions" :
            theString = "Functions"
        case "scripts" :
            theString = "Scripts"
        case "sim" :
            theString = "Model & populations"
        case "world" :
            theString = "World"
        case "pop" :
            theString = "Population : " + itemName
        case "simvars" :
            theString = "Variables"
        case "simscripts" :
            theString = "Scripts"
        case "simpopvars" :
            theString = "Variables"
        case "simpopscripts" :
            theString = "Scripts"
        case "library" :
            theString = itemName
        case "var" :
            theString = itemName
            let fatherType = outlineItem.father!.itemType
            var phVal : PhysValue?
            if fatherType == "library" {
                theString = outlineItem.libraryItem!.name + " = " + outlineItem.libraryItem!.desc
            } else {
                if fatherType == "variables" {
                    phVal = theVariables[itemName] ?? PhysValue()
                }
                else if fatherType == "simvars" { phVal = theSim.vars[itemName]}
                else if fatherType == "simpopvars" {
                    let pop = outlineItem.father!.father!.name
                    phVal = theSim.pops[pop]!.vars[itemName]
                }
                if phVal == nil { theString = "" }
                else { theString =  phVal!.stringExp(units: true) }
                theString = itemName + " = " + theString
                if theString.hasPrefix("") { theString = "" }
            }
        case "func" :
            let fatherType = outlineItem.father!.itemType
            if fatherType == "library" {
                theString = outlineItem.libraryItem!.desc
            } else {
                theString = theFunctions[itemName]!.stringExp()
                if theString.hasPrefix("") { theString = "" }
            }
        case "script" :
            theString = itemName
        default :
            theString = ""
        }
        return theString
    }
    
    // le view d'une cellule du outline
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let theView = NSTextField()
        theView.isBezeled = false
        let itemType = (item as! varsOutlineItem).itemType
        let fatherType = (item as! varsOutlineItem).father?.itemType
        theView.isEditable = false
        if itemType == "var" || itemType == "func" || itemType == "script" {
            if fatherType != "library" {
                theView.isEditable = true
            }
        }
        theView.drawsBackground = false
        theView.target = self
        theView.action = #selector(changedTextCell)
        return theView
    }
    
    // gestion de l'interface
    
    // Sélection d'un item
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let theRow = theOutlineView.selectedRow
        selectedItem = theOutlineView.item(atRow: theRow) as? varsOutlineItem
        editBtn.isEnabled = false
        runScriptBtn.isEnabled = false
        useLibBtn.isEnabled = false
        newItemBtn.isEnabled = false
        deleteBtn.isEnabled = false
        
        if selectedItem === nil { return }
        
        let itemType = selectedItem!.itemType
        if itemType == "simvars" || itemType == "simpopvars" || itemType == "simscripts" || itemType == "simpopscripts" || itemType == "world" || itemType == "pop" {
            return
        }
        
        if itemType == "library" {
            useLibBtn.isEnabled = true
            return
        }
        
        if itemType != "var" && itemType != "func" && itemType != "script" {
            newItemBtn.isEnabled = true
            return
        }
        
        let fatherType = selectedItem!.father?.itemType
        if fatherType == "library" {
            editBtn.isEnabled = false
            runScriptBtn.isEnabled = false
            useLibBtn.isEnabled = true
            copyBtn.isEnabled = true
            newItemBtn.isEnabled = false
            deleteBtn.isEnabled = false
            let libItem = selectedItem!.libraryItem!
            descriptionLbl.stringValue = libItem.name + " : " + libItem.desc + "\r" + libItem.script
        } else {
            descriptionLbl.stringValue = ""
            useLibBtn.isEnabled = false
            copyBtn.isEnabled = false
            if itemType == "script" {
                runScriptBtn.isEnabled = true
                editBtn.isEnabled = true
            } else {
                editBtn.isEnabled = false
                runScriptBtn.isEnabled = false
            }
            if fatherType == "simvars" || fatherType == "simpopvars" || fatherType == "simscripts" || fatherType == "simpopscripts" {
                newItemBtn.isEnabled = false
                deleteBtn.isEnabled = false
            } else {
                newItemBtn.isEnabled = true
                deleteBtn.isEnabled = true
            }
            if itemType == "var" {
                let itemName = selectedItem!.name
                if theVarExps[itemName] != nil {
                    descriptionLbl.stringValue = "Last definition : " + itemName + "=" + theVarExps[itemName]!.stringExp()
                }
            }
        }
        
        if mainCtrl.scriptVisible && itemType == "script" {
            var theName = ""
            switch fatherType {
            case "scripts" :
                theName = selectedItem!.name
            case "simscripts" :
                theName = "World." + selectedItem!.name
            case "simpopscripts" :
                theName = selectedItem!.father!.father!.name + "." + selectedItem!.name
            default :
                mainCtrl.scriptTextView.string = "ATTENTION : go to 'preferences' to edit library items or import them in your document with the 'Use' button below"
                theName = selectedItem!.name + "( in lib " + selectedItem!.libraryItem!.father.libName + ")"
                return // pour ne pas éditer les scripts de librairie ici !
            }
            mainCtrl.showScript(scriptName: theName)
        }
    }
    
    // édition du contenu du outlineview
    @objc func changedTextCell(sender: NSTextField) {
        let fatherType = selectedItem!.father?.itemType
        if fatherType == "variables" || fatherType == "functions" {
            let tScript = sender.stringValue
            let hScript = codeScriptHierarchic(script: tScript)
            let result = hScript.executeHierarchicScript()
            if result.isError { return }
            theVariables[""] = nil
            theFunctions[""] = nil
        }
        else if fatherType == "scripts" {
            let oldName = selectedItem!.name
            let hScript = theScripts[oldName]
            let newName = sender.stringValue
            if newName != "" && theScripts[newName] == nil {
                theScripts[oldName] = nil
                theScripts[newName] = hScript
                mainCtrl.scriptsPopupReset()
                mainCtrl.showScript(scriptName: newName)
            }
        }
        else { return }
        theOutlineView.reloadItem(nil, reloadChildren: true)

    }
    
    @IBAction func addItem(_ sender: Any) {
        if selectedItem == nil { return }
        let theType = selectedItem!.itemType
        var fatherType = selectedItem!.father?.itemType
        var theFather = selectedItem!.father
        if theType == "variables" || theType == "functions" || theType == "scripts" {
            fatherType = theType
            theFather = selectedItem!
        }
        if fatherType == "variables" {
            theVariables[""]=PhysValue(intVal: 0) // une variable bidon temporaire
            theOutlineView.expandItem(theFather)
            theOutlineView.reloadItem(theFather, reloadChildren: true)
            let n = theOutlineView.row(forItem: theFather) + theFather!.childs.count
            theOutlineView.selectRowIndexes(IndexSet(integer: n), byExtendingSelection: false)
        }
        if fatherType == "functions" {
            theFunctions[""]=HierarchicExp()
            theOutlineView.expandItem(theFather)
            theOutlineView.reloadItem(theFather, reloadChildren: true)
            let n = theOutlineView.row(forItem: theFather) + theFather!.childs.count
            theOutlineView.selectRowIndexes(IndexSet(integer: n), byExtendingSelection: false)
        }
        if fatherType == "scripts" {
            var k = 1
            var theName = "script 1"
            while theScripts[theName] != nil {
                k = k + 1
                theName = "script \(k)"
            }
            theScripts[theName] = HierarchicExp()
            theOutlineView.expandItem(theFather)
            theOutlineView.reloadItem(theFather, reloadChildren: true)
            let n = theOutlineView.row(forItem: theFather) + theScripts.keys.sorted().firstIndex(of: theName)! + 1
            theOutlineView.selectRowIndexes(IndexSet(integer: n), byExtendingSelection: false)
            mainCtrl.scriptsPopupReset()
        }
        theOutlineView.reloadItem(nil, reloadChildren: true)
    }
    
    @IBAction func editItem(_ sender: Any) {
        if selectedItem == nil { return }
        let itemType = selectedItem!.itemType
        if itemType != "var" && itemType != "func" && itemType != "script" { return }
        let fatherType = selectedItem!.father?.itemType
        var theName = ""
        switch fatherType {
        case "scripts" :
            theName = selectedItem!.name
        case "simscripts" :
            theName = "World." + selectedItem!.name
        case "simpopscripts" :
            theName = selectedItem!.father!.father!.name + "." + selectedItem!.name
        default :
            //theName = selectedItem!.name + "( in lib " + selectedItem!.libraryItem!.father.libName + ")"
            return
        }
        let scriptWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "ScriptWindowController") as! NSWindowController
           scriptWindowController.showWindow(self)
        let scriptWindow = scriptWindowController.window
        let scriptViewController = scriptWindow!.contentViewController as! ScriptViewController
        scriptWindow?.title = theName
        scriptViewController.scriptName = theName
        scriptViewController.showScript(nil)
        theOutlineView.reloadItem(nil, reloadChildren: true)
    }
    
    @IBAction func deleteItem(_ sender: Any) {
        if selectedItem == nil { return }
        let fatherType = selectedItem!.father?.itemType
        if fatherType == "variables" {
            theVariables[selectedItem!.name] = nil
        }
        if fatherType == "functions" {
            theFunctions[selectedItem!.name] = nil
        }
        if fatherType == "scripts" {
            theScripts[selectedItem!.name] = nil
            mainCtrl.scriptsPopupReset()
        }
        theOutlineView.reloadItem(nil, reloadChildren: true)
    }
    
    @IBAction func runScript(_ sender: Any) {
        if selectedItem == nil { return }
        let itemType = selectedItem!.itemType
        if itemType  != "script" { return }
        let fatherType = selectedItem!.father?.itemType
        var hScript : HierarchicExp
        switch fatherType {
        case "simscripts":
            hScript = theSim.scripts[selectedItem!.name]!
        case "simpopscripts" :
            let popName = selectedItem!.father!.name
            hScript = theSim.pops[popName]!.scripts[selectedItem!.name]!
        default:
            hScript = theScripts[selectedItem!.name]!
        }
        let result = hScript.executeHierarchicScript()
        if result.type == "error" { mainCtrl.printToConsole(result.asString!)}
        theOutlineView.reloadItem(nil, reloadChildren: true)
    }
    
    @IBAction func useLibraryItem(_ sender: Any) {
        if selectedItem == nil { return }
        let itemType = selectedItem!.itemType
        if itemType == "library" {
            let r = selectedItem!.library!.useLibrary()
            if r.isError { mainCtrl.printToConsole(r.asString!) }
        } else {
            let r = selectedItem!.libraryItem!.use()
            if r.isError { mainCtrl.printToConsole(r.asString!) }
        }
        theOutlineView.reloadItem(nil, reloadChildren: true)
    }
    
    @IBAction func copyHierexp(_ sender: Any) {
        if selectedItem == nil { return }
        let itemType = selectedItem!.itemType
        if itemType == "library" {
            return
        } else {
            selectedItem!.libraryItem!.copy()
        }
        theOutlineView.reloadItem(selectedItem?.father, reloadChildren: true)
    }
}

class varsOutlineItem {
    var itemType : String = "node" // var, func, script, functions, sim, world, pop...
    var name : String = "" // nom de var, nom de fonction, nom de population, World, Simulation, Global, Functions
    var father : varsOutlineItem?
    var library : ekLibrary?
    var libraryItem : ekLibraryItem?
    
    var childs : [varsOutlineItem] {
        var result : [varsOutlineItem] = []
        switch itemType {
        case "variables" :
            var listOfVars = Array(theVariables.keys)
            listOfVars.append(contentsOf: Array(theVarExps.keys))
            listOfVars = Array(Set(listOfVars))
            for aVar in listOfVars {
                result.append(varsOutlineItem(itemType: "var", name: aVar, father: self))
            }
        case "functions" :
            for aFunc in theFunctions.keys.sorted() {
                result.append(varsOutlineItem(itemType: "func", name: aFunc, father: self))
            }
        case "scripts" :
            for aScript in theScripts.keys.sorted() {
                result.append(varsOutlineItem(itemType: "script", name: aScript, father: self))
            }
        case "sim" :
            result.append(varsOutlineItem(itemType: "world", name: "world", father: self))
            for aPop in theSim.pops.keys.sorted() {
                result.append(varsOutlineItem(itemType: "pop", name: aPop, father: self))
            }
        case "world" :
            result.append(varsOutlineItem(itemType: "simvars", name: "simvars", father: self))
            result.append(varsOutlineItem(itemType: "simscripts", name: "simscripts", father: self))
        case "pop" :
            result.append(varsOutlineItem(itemType: "simpopvars", name: "simpopvars", father: self))
            result.append(varsOutlineItem(itemType: "simpopscripts", name: "simpopscripts", father: self))
        case "simvars" :
            for aVar in theSim.vars.keys.sorted() {
                result.append(varsOutlineItem(itemType: "var", name: aVar, father: self))
            }
        case "simscripts" :
            for aScript in theSim.scripts.keys.sorted() {
                result.append(varsOutlineItem(itemType: "script", name: aScript, father: self))
            }
        case "simpopvars" :
            let popName = father!.name
            for aVar in theSim.pops[popName]!.vars.keys.sorted() {
                result.append(varsOutlineItem(itemType: "var", name: aVar, father: self))
            }
        case "simpopscripts" :
            let popName = father!.name
            for aScript in theSim.pops[popName]!.scripts.keys.sorted() {
                result.append(varsOutlineItem(itemType: "script", name: aScript, father: self))
            }
        case "library" :
            let theLib = self.library!
            for aDef in theLib.definitions {
                result.append(varsOutlineItem(libraryItem: aDef, father: self))
            }
            for aLib in theLib.libs {
                result.append(varsOutlineItem(library: aLib, father: self))
            }
        case "document" :
            result.append(varsOutlineItem(itemType: "variables", name: "Variables", father: self))
            result.append(varsOutlineItem(itemType: "functions", name: "Functions", father: self))
            result.append(varsOutlineItem(itemType: "scripts", name: "Scripts", father: self))

        default :
            return result
        }
        return result
    }
    
    init(itemType: String, name: String, father: varsOutlineItem? = nil) {
        self.itemType = itemType
        self.name = name
        self.father = father
    }
    
    init(library : ekLibrary, father: varsOutlineItem?) {
        self.itemType = "library"
        self.name = library.libName
        self.father = father
        self.library = library
    }
    
    init(libraryItem: ekLibraryItem, father: varsOutlineItem) {
        self.itemType = libraryItem.type
        self.name = libraryItem.name
        self.father = father
        self.libraryItem = libraryItem
    }
}

