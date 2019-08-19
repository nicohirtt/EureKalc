//
//  UnitsPrefsController.swift
//  EureKalc
//
//  Created by Nico on 02/02/2021.
//  Copyright © 2021 Nico Hirtt. All rights reserved.
//

import Cocoa

class unitsPrefsController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    
    @IBOutlet var unitsTable: NSTableView!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        prefsController!.unitsController = self
        unitsTable.delegate = self
        unitsTable.dataSource = self
    }
    
    
    // nombre de lignes du tableau
    func numberOfRows(in tableView: NSTableView) -> Int {
        return unitsDefs.count
    }
    
    // remplit le tableau en utilisant le unitsDefs
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let theUnitDef = unitsDefs[row]
        let colNumber = tableView.column(withIdentifier: tableColumn!.identifier)
        if colNumber == 0 { return theUnitDef[0] }
        if theUnitDef[0].hasPrefix("#") || theUnitDef.count != 5 { return "" }
        return theUnitDef[colNumber]
    }
    
    // crée le NSView du tableau
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableColumn == nil { return nil }
        let theView = NSTextField()
        theView.isBezeled = false
        theView.isEditable = true
        theView.drawsBackground = false
        theView.delegate = self
        return theView
    }
    
    // Edition d'une cellule du tableau
    func controlTextDidEndEditing(_ obj: Notification) {
        let sender = obj.object as! NSTextField
        let colNbr = unitsTable.column(for: sender)
        let rowNbr = unitsTable.row(for: sender)
        let value = sender.stringValue
        if colNbr == 0 && value.hasPrefix("#") {
            unitsDefs[rowNbr] = [value,"","","",""]
        } else {
            unitsDefs[rowNbr][colNbr] = value
        }
        resetUnitsFormDefinitions()
        saveChanges()
    }
    
    // ajout d'une ligne
    @IBAction func addUnit(_ sender: Any) {
        let row = unitsTable.selectedRow
        if row < 0 { return }
        if row == unitsDefs.count - 1 {
            let oneDef = unitsDefs[row]
            unitsDefs.append(["new_unit",oneDef[1],"","",""])
        } else if unitsDefs[row][0].hasPrefix("#") {
            let oneDef = unitsDefs[row+1]
            unitsDefs.insert(["new_unit",oneDef[1],"","",""], at: row+1)
        } else {
            let oneDef = unitsDefs[row]
            unitsDefs.insert(["new_unit",oneDef[1],"","",""], at: row+1)
        }
        resetUnitsFormDefinitions()
        unitsTable.reloadData()
        unitsTable.selectRowIndexes(IndexSet(integer: row+1), byExtendingSelection: false)
        saveChanges()
    }
    
    @IBAction func moveUnitUp(_ sender: Any) {
        let row = unitsTable.selectedRow
        if row < 0 { return }
        if row == 0 { return }
        let oneDef = unitsDefs[row]
        unitsDefs[row] = unitsDefs[row-1]
        unitsDefs[row-1] = oneDef
        unitsTable.reloadData()
        unitsTable.selectRowIndexes(IndexSet(integer: row-1), byExtendingSelection: false)
        saveChanges()
    }
    
    @IBAction func moveUnitDown(_ sender: Any) {
        let row = unitsTable.selectedRow
        if row < 0 { return }
        if row == unitsDefs.count - 1 { return }
        let oneDef = unitsDefs[row]
        unitsDefs[row] = unitsDefs[row+1]
        unitsDefs[row+1] = oneDef
        unitsTable.reloadData()
        unitsTable.selectRowIndexes(IndexSet(integer: row+1), byExtendingSelection: false)
        saveChanges()
    }
    
    
    @IBAction func deleteUnit(_ sender: Any) {
        let row = unitsTable.selectedRow
        if row < 0 { return }
        unitsDefs.remove(at: row)
        resetUnitsFormDefinitions()
        unitsTable.reloadData()
        unitsTable.selectRowIndexes(IndexSet(integer: max(row-1,0)), byExtendingSelection: false)
        saveChanges()
    }
    
    

    
    @IBAction func resetDefaults(_ sender: Any) {
        let test =
            dialogOKCancel(question: "Are you sure ?", text: "This will delete all changes made to the units and restore the factory settings")
        if test == true {
            loadUnits(reset: true)
            unitsTable.reloadData()
            saveChanges()        }
    }
    
    
    // exportation des règles et des langues utilisateur sous forme de fichiers texte
    @IBAction func exportUnits(_ sender: Any) {
        let theOutput = unitsToString()
        let savePanel = NSSavePanel()
        savePanel.begin { (result) in
             if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                let filename = savePanel.url!
                do {
                    try theOutput.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
                } catch {
                    print("error")
                    // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                }
             }
         }
    }
    
    @IBAction func importUnits(_ sender: Any) {
        let openPanel = NSOpenPanel()
        var theString = ""
        openPanel.begin { (result) in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
               let filename = openPanel.url!
                do {
                    theString = try String.init(contentsOf: filename)

                } catch {
                    print("error")
                   // failed to read file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                    return()
               }
                getUnitsFromString(theString)
                resetUnitsFormDefinitions()
                self.unitsTable.reloadData()
                self.saveChanges()
            }
        }

    }
    
    func saveChanges() {
         let myDefaults = UserDefaults.standard
         let theOutput = unitsToString()
         myDefaults.set(theOutput, forKey: "units")
     }
    
}


func getUnitsFromString(_ theString : String) {
    unitsDefs = []
    let splittedLines = theString.split(separator: "\n")
    for aLine in splittedLines {
        let splittedItems = aLine.split(separator: "\t", omittingEmptySubsequences: false)
        let name = String(splittedItems[0])
        var oneDef : [String] = []
        if name.hasPrefix("#") || splittedItems.count != 5 {
            oneDef = [name, "", "", "", ""]
        } else {
            for oneItem in splittedItems {
                oneDef.append(String(oneItem))
            }
            let powersString = oneDef[1]
            let mult = Double(oneDef[2]) ?? 1
            let offset = Double(oneDef[3]) ?? 0
            let splittedMults = oneDef[4].split(separator: ",")
            let multiples = splittedMults.compactMap( {unitsMultiples(rawValue: String($0)) } )
            _ = createUnits(name: name, powStr: powersString, mult: mult, offset: offset, multiples: multiples)
        }
        unitsDefs.append(oneDef)
     }
}

func resetUnitsFormDefinitions() {
    unitsByName = [:]
    unitsByType = [:]
    for oneDef in unitsDefs {
        let name = oneDef[0]
        if !name.hasPrefix("#") {
            let powersString = oneDef[1]
            let mult = Double(oneDef[2]) ?? 1
            let offset = Double(oneDef[3]) ?? 0
            let splittedMults = oneDef[4].split(separator: ",")
            let multiples = splittedMults.compactMap( {unitsMultiples(rawValue: String($0)) } )
            _ = createUnits(name: name, powStr: powersString, mult: mult, offset: offset, multiples: multiples)
        }
     }
}

func unitsToString() -> String {
    var r = ""
    for oneUnit in unitsDefs {
        r = r + oneUnit[0] + "\t" + oneUnit[1] + "\t" + oneUnit[2] + "\t" + oneUnit[3] + "\t" + oneUnit[4] + "\n"
    }
    r.removeLast()
    return r
}
