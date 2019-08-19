//
//  LibraryPrefsController.swift
//  EureKalc
//
//  Created by Nico on 02/02/2021.
//  Copyright © 2021 Nico Hirtt. All rights reserved.
//

import Cocoa


// Gestion des librairies de constantes, fonctions et scripts
class libraryPrefsController : NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, NSPasteboardItemDataProvider {
    

    
    
    @IBOutlet var libraryOutline: NSOutlineView!
    @IBOutlet var nameColumn: NSTableColumn!
    @IBOutlet var descColumn: NSTableColumn!
    @IBOutlet var typeColumn: NSTableColumn!
    @IBOutlet var autoColumn: NSTableColumn!
    @IBOutlet var defColumn: NSTableColumn!
    
    var selectedItem : Any?
    var draggedItem : Any?
    var draggedNode:AnyObject? = nil

    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "private.table-row")

    override func viewDidLoad() {
        super.viewDidLoad()
        prefsController!.dataLibController = self
        libraryOutline.delegate = self
        libraryOutline.dataSource = self
        nameColumn.isEditable = true
        libraryOutline.registerForDraggedTypes([dragDropType])
        //libraryOutline.registerForDraggedTypes([NSPasteboard.PasteboardType.string])
        
        // Disable dragging items from our view to other applications.
        libraryOutline.setDraggingSourceOperationMask(NSDragOperation(), forLocal: false)
        
        // Enable dragging items within and into our view.
        libraryOutline.setDraggingSourceOperationMask(NSDragOperation.every, forLocal: true)
    }
    
    
    // drag and drop
    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
    }
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        let pbItem:NSPasteboardItem = NSPasteboardItem()
        pbItem.setDataProvider(self, forTypes: [dragDropType])
        return pbItem
    }
    
    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItems draggedItems: [Any]) {
        draggedNode = draggedItems[0] as AnyObject?
        session.draggingPasteboard.setData(Data(), forType: dragDropType)
    }
    
    // dépôt de l'élément sélectionné à la position index de l'élément item
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        if selectedItem == nil { return false }
        var newFather = dataLibrary
        if item == nil { return false }
        if item! is ekLibrary {
            newFather = item as! ekLibrary
        } else {
            if index == -1 { return false }
            newFather = (item as! ekLibraryItem).father
        }
        var oldIndex = libraryOutline.childIndex(forItem: selectedItem as Any)
        if selectedItem! is ekLibrary {
            let movedLib = (selectedItem as! ekLibrary)
            if movedLib.father == nil { return false }
            let oldFather = movedLib.father!
            oldIndex = oldIndex - oldFather.definitions.count
            var newIndex = index - oldFather.definitions.count
            if newIndex < 0 { newIndex = 0 }
            if newFather.libs.count <= newIndex {
                newFather.libs.append(movedLib)
            } else {
                newFather.libs.insert(movedLib, at: newIndex)
            }
            movedLib.father = newFather
            if newFather.isEqual(to: oldFather) && newIndex < oldIndex {
                oldFather.libs.remove(at: oldIndex + 1)
            } else {
                oldFather.libs.remove(at: oldIndex)
            }
        } else {
            let movedItem = (selectedItem as! ekLibraryItem)
            let oldFather = movedItem.father
            var newIndex = index
            if newIndex < 0 { newIndex = 0 }
            if newFather.definitions.count <= newIndex {
                newFather.definitions.append(movedItem)
            } else {
                newFather.definitions.insert(movedItem, at: newIndex)
            }
            movedItem.father = newFather
            if newFather.isEqual(to: oldFather) && newIndex < oldIndex {
                oldFather.definitions.remove(at: oldIndex + 1)
            } else {
                oldFather.definitions.remove(at: oldIndex)
            }
        }
        libraryOutline.reloadData()
        saveLib()
        return true
    }
    
    // début d'une session de drag&drop
    func outlineView(_ outlineView: NSOutlineView, validateDrop: NSDraggingInfo, proposedItem: Any?, proposedChildIndex: Int) -> NSDragOperation {
        draggedItem = selectedItem
        return NSDragOperation.every
    }
    
    
    
    // Le datasource de la fenêtre de visualisation des scripts
    
    // child of item
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            let nDefs = dataLibrary.definitions.count
            if index < nDefs {
                return dataLibrary.definitions[index]
            } else {
                return dataLibrary.libs[index - nDefs]
            }
        } else {
            let theLib = item as! ekLibrary
            let nDefs = theLib.definitions.count
            if index < nDefs {
                return theLib.definitions[index]
            } else {
                return theLib.libs[index - nDefs]
            }
        }
    }
    
    // expandable ??
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable: Any) -> Bool {
        if isItemExpandable is ekLibrary { return true }
        return false
    }
    
    // number of children ??
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem: Any?) -> Int {
        if numberOfChildrenOfItem == nil {
             return dataLibrary.definitions.count + dataLibrary.libs.count
        }
        if numberOfChildrenOfItem! is ekLibrary {
            let theLib = numberOfChildrenOfItem as! ekLibrary
            let n = theLib.definitions.count + theLib.libs.count
            return n
        } else {
            return 0
        }
    }
    
    // Le delegate
    
    // objectvalue for item and column
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if item == nil { return "" }
        if item! is ekLibrary {
            if tableColumn == nameColumn { return (item! as! ekLibrary).libName }
            else { return ""}
        }
        switch tableColumn {
        case nameColumn :
            return (item! as! ekLibraryItem).name
        case descColumn :
            return (item! as! ekLibraryItem).desc
        case typeColumn :
            return String((item! as! ekLibraryItem).type)
        case autoColumn :
            return (item! as! ekLibraryItem).auto ? NSControl.StateValue.on : NSControl.StateValue.off
        default :
            return (item! as! ekLibraryItem).script
        }
    }
    
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        
        if tableColumn == nameColumn || tableColumn == descColumn || tableColumn == defColumn || item is ekLibrary {
            let theView = NSTextField()
            theView.isBezeled = false
            theView.isEditable = true
            theView.drawsBackground = false
            theView.target = self
            theView.action = #selector(changedTextCell)
            let theString = self.outlineView(outlineView, objectValueFor: tableColumn, byItem: item)! as! String
            theView.stringValue = theString
            theView.controlSize = NSControl.ControlSize.small
            return theView
        } else if tableColumn == typeColumn {
            let theView = NSPopUpButton()
            let theType = self.outlineView(outlineView, objectValueFor: tableColumn, byItem: item)! as! String
            var theTitles = ["var","func","script"]
            theTitles.remove(at: theTitles.firstIndex(of: theType)!)
            theTitles.insert(theType, at: 0)
            theView.addItems(withTitles: theTitles)
            theView.controlSize = NSControl.ControlSize.small
            (theView.cell as! NSPopUpButtonCell).arrowPosition = NSPopUpButton.ArrowPosition.noArrow
            theView.bezelStyle = NSButton.BezelStyle.recessed
            theView.target = self
            theView.action = #selector(changedButton)
            return theView
        } else {
            let theView = NSButton()
            theView.setButtonType(NSButton.ButtonType.switch)
            theView.title = ""
            theView.state = self.outlineView(outlineView, objectValueFor: tableColumn, byItem: item)! as! NSControl.StateValue
            theView.controlSize = NSControl.ControlSize.small
            theView.target = self
            theView.action = #selector(changedButton)
            return theView
        }
    }
    
   //  Changement d'un texte
    @objc func changedTextCell(sender: NSTextField) {
        let colNbr = libraryOutline.column(for: sender)
        let rowNbr = libraryOutline.row(for: sender)
        let value = sender.stringValue
        let theItem = libraryOutline.item(atRow: rowNbr)
        if (theItem is ekLibrary) {
            if colNbr == 0 {
                (theItem as! ekLibrary).libName = value
            }
        } else {
            let item = theItem as! ekLibraryItem
            switch colNbr {
                case 0: item.name = value
                case 1 : item.desc = value
                default : item.script = value
            }
        }
        libraryOutline.reloadData()
        libraryOutline.selectRowIndexes([libraryOutline.row(forItem: theItem)], byExtendingSelection: false)
        saveLib()
    }
    
    // Changement d'un popup ou d'une checkbox
    @objc func changedButton(sender: NSButton) {
        let colNbr = libraryOutline.column(for: sender)
        let rowNbr = libraryOutline.row(for: sender)
        let item = libraryOutline.item(atRow: rowNbr) as! ekLibraryItem
        if colNbr == 2 { item.type = (sender as! NSPopUpButton).titleOfSelectedItem! }
        if colNbr == 3 { item.auto = (sender.state == NSControl.StateValue.on) }
        saveLib()
    }
    
    // Sélection d'un script ou d'un groupe
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let theRow = libraryOutline.selectedRow
        selectedItem = libraryOutline.item(atRow: theRow)
    }
    
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
    // Drag and drop support
    let data = Data()
    pboard.declareTypes([dragDropType], owner: self)
    pboard.setData(data, forType: dragDropType)
    saveLib()
    return true
    }
    
  

    
    
    @IBAction func addFolder(_ sender: Any) {
        var theLib = dataLibrary
        var theItem : ekLibraryItem? = nil
        if selectedItem != nil {
            if selectedItem! is ekLibrary {
                theLib = selectedItem! as! ekLibrary
            } else {
                theItem = selectedItem as? ekLibraryItem
                theLib = theItem!.father
            }
        }
        let newLib = ekLibrary(name: "Name?")
        newLib.father = theLib
        theLib.libs.append(newLib)
        libraryOutline.expandItem(theLib)
        libraryOutline.reloadData()
        saveLib()
    }
    
    @IBAction func addItem(_ sender: Any) {
        var theLib = dataLibrary
        var itemIndex = -1
        if selectedItem != nil {
            if selectedItem! is ekLibrary {
                theLib = selectedItem! as! ekLibrary
            } else {
                let theItem = selectedItem as? ekLibraryItem
                itemIndex = libraryOutline.childIndex(forItem: theItem!)
            }
        }
        let newItem = ekLibraryItem()
        newItem.name = "Name?"
        newItem.type = "var"
        newItem.auto = false
        newItem.script = ""
        newItem.father = theLib
        if itemIndex + 1 >= theLib.definitions.count {
            theLib.definitions.append(newItem)
        } else {
            theLib.definitions.insert(newItem, at: itemIndex + 1)
        }
        libraryOutline.expandItem(theLib)
        libraryOutline.reloadData()
        saveLib()
    }
    
    @IBAction func editItem(_ sender: Any) {
        if selectedItem == nil {return}
        if selectedItem! is ekLibrary { return }
        let item = selectedItem as! ekLibraryItem
        
        let scriptWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "ScriptWindowController") as! NSWindowController
           scriptWindowController.showWindow(self)
        let scriptWindow = scriptWindowController.window
        let scriptViewController = scriptWindow!.contentViewController as! ScriptViewController
        
        scriptWindow?.title = item.name + "(in lib " + item.father.libName + ")"
        scriptViewController.scriptName = ""
        scriptViewController.scriptLibrary = item
        scriptViewController.showScript(item.script)
        saveLib()
    }
    
    func editedScript(script: String) {
        if selectedItem == nil {return}
        if selectedItem! is ekLibrary { return }
        let item = selectedItem as! ekLibraryItem
        item.script = script
        libraryOutline.reloadData()
        saveLib()
    }
    
    @IBAction func deleteItem(_ sender: Any) {
        if selectedItem != nil {
            if selectedItem! is ekLibrary {
                let theLib = selectedItem! as! ekLibrary
                if theLib.father != nil {
                    let n = libraryOutline.childIndex(forItem: theLib)
                    let father = theLib.father!
                    father.libs.remove(at: n - father.definitions.count)
                }
            } else {
                let theItem = selectedItem as? ekLibraryItem
                let n = libraryOutline.childIndex(forItem: theItem!)
                let father = theItem!.father
                father.definitions.remove(at: n)
            }
        }
        libraryOutline.reloadData()
        saveLib()
    }
    
    @IBAction func moveItemDown(_ sender: Any) {
        if selectedItem != nil {
            if selectedItem! is ekLibrary {
                let theLib = selectedItem! as! ekLibrary
                if theLib.father != nil {
                    let father = theLib.father!
                    let n = libraryOutline.childIndex(forItem: theLib) - father.definitions.count
                    if n < father.libs.count - 1 {
                        father.libs[n] = father.libs[n+1]
                        father.libs[n+1] = theLib
                    }
                }
            } else {
                let theItem = selectedItem as? ekLibraryItem
                let n = libraryOutline.childIndex(forItem: theItem!)
                let father = theItem!.father
                if n < father.definitions.count - 1 {
                    father.definitions[n] = father.definitions[n+1]
                    father.definitions[n+1] = theItem!
                }
            }
            libraryOutline.reloadData()
            libraryOutline.selectRowIndexes([libraryOutline.row(forItem: selectedItem!)], byExtendingSelection: false)
        }
        saveLib()
    }
    
    @IBAction func moveItemUp(_ sender: Any) {
        if selectedItem != nil {
            if selectedItem! is ekLibrary {
                let theLib = selectedItem! as! ekLibrary
                if theLib.father != nil {
                    let father = theLib.father!
                    let n = libraryOutline.childIndex(forItem: theLib) - father.definitions.count
                    if n > 0 {
                        father.libs[n] = father.libs[n-1]
                        father.libs[n-1] = theLib
                    }
                }
            } else {
                let theItem = selectedItem as? ekLibraryItem
                let n = libraryOutline.childIndex(forItem: theItem!)
                let father = theItem!.father
                if n > 0 {
                    father.definitions[n] = father.definitions[n-1]
                    father.definitions[n-1] = theItem!
                }
            }
            libraryOutline.reloadData()
            libraryOutline.selectRowIndexes([libraryOutline.row(forItem: selectedItem!)], byExtendingSelection: false)
        }
        saveLib()
    }
    
    @IBAction func importLib(_ sender: Any) {
        let myFileDialog = NSOpenPanel()
        myFileDialog.runModal()
        let filename = myFileDialog.url
        if filename != nil {
            do {
                let str = try String(contentsOfFile: filename!.path, encoding: String.Encoding.utf8)
                dataLibrary = ekLibrary(fromString: str)
            } catch {
                print("error ??")
            }
        }
        libraryOutline.reloadData()
        saveLib()
    }
    
    @IBAction func exportLib(_ sender: Any) {
        let myFileDialog = NSSavePanel()
        myFileDialog.runModal()
        let filename = myFileDialog.url
        if filename != nil {
        let str = dataLibrary.toString()
            do {
                try str.write(to: filename!, atomically: true, encoding: String.Encoding.utf8)
            } catch {
                print("error ??")
                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            }
        }
    }
    
    func saveLib() {
        let myDefaults = UserDefaults.standard
        let libString = dataLibrary.toString()
        myDefaults.set(libString, forKey: "library")
    }
    
    
    @IBAction func reloadLibraries(_ sender: Any) {
        let test =
            dialogOKCancel(question: "Are you sure ?", text: "This will delete all changes made to the library and restore the factory settings")
        if test == true {
            loadLibraries(reset: true)
        }
        saveLib()
    }
    
    
    
}

// la classe qui gère les librairies de données
class ekLibrary {
    var libName : String = "Library"
    var definitions : [ekLibraryItem] = []
    var libs : [ekLibrary] = []
    var father : ekLibrary?
    
    init(name : String) {
        libName = name
    }
    
    init(fromString: String) {
        let splitted = fromString.split(separator: "\n")
        if String(splitted[0]) != "#LIB Library" { return }
        var currentLibrary = self
        var librariesPath : [ekLibrary] = []
        var currentItem = ekLibraryItem()
        var currentScript = ""
        var mode = "LIB" // peut être "LIB", "SCRIPT", ...
        for aLine in splitted.dropFirst() {
            var line = String(aLine)
            if line.hasPrefix("#ITEM ") {
                currentItem = ekLibraryItem()
                line.removeFirst(6)
                if line.hasPrefix("AUTO ") {
                    line.removeFirst(5)
                    currentItem.auto = true
                }
                let splittedLine = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
                currentItem.type = String(splittedLine[0])
                currentItem.name = String(splittedLine[1])
                currentItem.desc = String(splittedLine[2])
                currentItem.father = currentLibrary
                currentLibrary.definitions.append(currentItem)
                currentScript = ""
                mode = "SCRIPT"
            } else if mode == "SCRIPT" {
                if line.hasPrefix("#ENDSCRIPT") {
                    currentItem.script = currentScript
                    mode = "LIB"
                } else {
                    currentScript = currentScript + line + "\n"
                }
            } else if line.hasPrefix("#ENDLIB") {
                // fin du dossier
                if librariesPath.count == 0 { return }
                currentLibrary.father = librariesPath.last!
                currentLibrary = librariesPath.last!
                librariesPath.removeLast()
            } else if line.hasPrefix("#LIB ") {
                // nouveau dossier
                line.removeFirst(5)
                let newLibrary = ekLibrary(name: String(line))
                librariesPath.append(currentLibrary)
                currentLibrary.libs.append(newLibrary)
                currentLibrary = newLibrary
            }
            
        }
    }
    
    // transforme une librairie complète en chaîne pour la sauvegarde
    func toString() -> String {
        var theString = "#LIB " + libName + "\n" + "\n"
        for aDef in definitions {
            theString = theString + "#ITEM "
            if aDef.auto {theString = theString + "AUTO "}
            theString = theString + aDef.type + " " + aDef.name + " " + aDef.desc + "\n"
            theString = theString + aDef.script + "\n"
            theString = theString + "#ENDSCRIPT " + aDef.name + "\n" + "\n"
        }
        for aFolder in libs {
            theString = theString + aFolder.toString() + "\n"
        }
        theString = theString + "#ENDLIB " + libName + "\n" + "\n"
        return theString
    }
    
    // retourne l'index d'un élément dans sa catégorie (ainsi que cette catégorie)
    func indexInCategory(index: Int) -> (lib: Bool, index:Int) {
        if index >= definitions.count {
            return(true,index-definitions.count)
        }
        return(false,index)
    }
    
    func useLibrary(ifAuto: Bool = false) -> PhysValue {
        // chargement des variables auto
        for aDef in self.definitions {
            if aDef.auto || ifAuto == false {
                let r = aDef.use()
                if r.isError { return r}
            }
        }
        for aLib in self.libs {
            let r = aLib.useLibrary(ifAuto: ifAuto)
            if r.isError {return r}
        }
        return PhysValue()
    }
    
    func isEqual(to: ekLibrary) -> Bool {
        if libName != to.libName { return false}
        if father == nil || to.father == nil {
            if father != nil { return false}
            if to.father != nil { return false }
            return true
        }
        if father!.isEqual(to: to.father!) { return true }
        return false
    }
    
    // Cherche un item de la librairie nommé "named" et du type "var" ou "func" ou "any"
    func getItem(named: String, type: String = "any") -> ekLibraryItem? {
        for aDef in self.definitions {
            if aDef.name == named && (aDef.type == type || type == "any") { return aDef }
        }
        for aLib in self.libs {
            let r = aLib.getItem(named: named, type: type)
            if r != nil { return r }
        }
        return nil
    }
}

class ekLibraryItem {
    var name : String = "name?"
    var desc : String = ""
    var type : String = "var" // « var », « func », « script »
    var auto : Bool = false // chargement automatique
    var script : String = ""
    var father : ekLibrary = dataLibrary
    
    // charge l'item dans la mémoire et retourne éventuellement un message d'erreur
    func use() -> PhysValue {
        let hScript = codeScriptHierarchic(script: script)
        if type == "var" || type == "func" {
            if hScript.op == "SCRIPT_BLOC" {
                if hScript.nArgs == 1 {
                    hScript.args[0].getVarExp(force: true)
                }
            }
            return hScript.executeHierarchicScript()
        } else if type == "script" {
            theScripts[name] = hScript
            return PhysValue()
        } else {
            return errVal("Unknown error in library item " + name)
        }
    }
    
    func copy() {
        let hScript = codeScriptHierarchic(script: script)
        if type == "var" || type == "func" {
            if hScript.op == "SCRIPT_BLOC" {
                if hScript.nArgs == 1 {
                    mainCtrl.copiedEquation = hScript.args[0]
                    let pasteBoard = NSPasteboard.general
                    pasteBoard.clearContents()
                    pasteBoard.setString(hScript.args[0].stringExp(), forType: .string)
                }
            }
        }
    }
}




