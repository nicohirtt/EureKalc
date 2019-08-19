//
//  ekTableScrollView.swift
//  EureKalc
//
//  Created by Nico on 31/12/2020.
//  Copyright © 2020 Nico Hirtt. All rights reserved.
//

import Foundation
import Cocoa

// Une classe particulière (NSScrollview + NStableview) pour l'affichage de tables
class ekTableScrollView: NSScrollView, NSTableViewDelegate, NSTableViewDataSource {
    
    var theTable : NSTableView = NSTableView() // la view qui affiche la table
    var selDidChange = false // a-t-on changé la sélection de ligne ou colonne
    var colExps : [HierarchicExp] = [] // les expressions hiérarchiques qui représentent les colonnes
    var thePhVals : [PhysValue] = [] // les physVals des colonnes (pour les types 'dataframe' et 'colexp')
    var rowNames : [String] = []
    var colNames : [String] = []
    var dataType : String = "colexp" // "matrix" ou "colexp" ou "dataframe"
    var drawSettings : [[String:Any]] = [] // réglages de chaque colonne
    var nRows = 0
    var nCols = 0
    
    var selectedColNbr : Int {
        theTable.selectedColumn
    }
    
    var selectedValue : PhysValue? {
        if theTable.selectedColumn == -1 { return nil}
        if dataType == "colexp" {
            return colExps[theTable.selectedColumn].executeHierarchicScript()
        } else if dataType == "matrix" {
            return colExps[0].executeHierarchicScript()
        } else if dataType == "dataframe" && theTable.selectedColumn > 0 {
            let dataframe = colExps[0].executeHierarchicScript()
            return dataframe.values[theTable.selectedColumn - 1] as? PhysValue
        }
        return nil
    }
    
    func resize(_ size: NSSize) {
        self.frame.size = size
        theTable.frame = self.bounds
    }
    
    func reset(theExp: HierarchicExp) {
       _ = initialise(cExps: colExps, theExp: theExp, new: true)
    }
        
    func initialise(cExps: [HierarchicExp], theExp: HierarchicExp, new: Bool) -> PhysValue {
        var showLabels = theExp.drawSettingForKey(key: "showLabels") as? Bool ?? false
        let result = PhysValue()
        colExps = cExps
       
        var reset = new
        if reset {
            theTable.tableColumns.forEach({theTable.removeTableColumn($0)})
        }
        
        let firstPhysVal = colExps[0].executeHierarchicScript()
        if firstPhysVal.type == "error" { return firstPhysVal }
        if firstPhysVal.dims()[0] == 0 || firstPhysVal.values.count == 0 {
            return errVal("No data for this table")
        }
        let dims = firstPhysVal.dims()
        
        if theExp.draw != nil {
            if theExp.draw!.settings?["tablesettings"] != nil {
                drawSettings = theExp.draw!.settings!["tablesettings"] as! [[String : Any]]
                theExp.setSetting(key: "tablesettings", value: nil)
            }
        }
        let nSettings = drawSettings.count
        if nSettings < nCols {
            drawSettings.append(contentsOf: Array(repeating: [:], count: nCols + 1 - nSettings))
        }
        
        //theTable = NSTableView()
        if showLabels {
            let aColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "_titlecolumn"))
            aColumn.isEditable = false
            aColumn.width = 60
            if drawSettings.count == 0 {
                drawSettings = [["colwidth":0]]
            }
            drawSettings[0]["colwidth"] = aColumn.width
            aColumn.title = firstPhysVal.type == "dataframe"  ? colExps[0].stringExp() : ""
            theTable.addTableColumn(aColumn)
        }
        
        // cas d'un dataframe
        if firstPhysVal.type == "dataframe" {
            thePhVals = firstPhysVal.values.map( {$0 as! PhysValue })
            dataType = "dataframe"
            nCols = showLabels ? thePhVals.count + 1 : thePhVals.count
            if nSettings < nCols {
                drawSettings.append(contentsOf: Array(repeating: [:], count: nCols + 1 - nSettings))
            }
            nRows = (firstPhysVal.values[0] as! PhysValue).dim[0]
            colNames = firstPhysVal.names![0]
            if firstPhysVal.names![1].count == 0 {
                rowNames = Array(1...nRows).map({ String($0 - 1) })
            } else {
                rowNames = firstPhysVal.names![1]
            }
            
            for (k,oneExp) in firstPhysVal.values.enumerated() {
                var aColumn : NSTableColumn
                if reset {
                    aColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: String(k)))
                    aColumn.isEditable = true   // ******** à modifier ultérieurement **********
                    if drawSettings[k]["colwidth"] != nil {
                        aColumn.width = drawSettings[k]["colwidth"] as! CGFloat
                    } else {
                        aColumn.width = 60
                        drawSettings[k]["colwidth"] = aColumn.width
                    }
                    theTable.addTableColumn(aColumn)
                } else {
                    aColumn = theTable.tableColumns[k]
                    aColumn.width = drawSettings[k]["colwidth"] as? CGFloat ?? 60
                }
                var unit = (oneExp as! PhysValue).unit
                if drawSettings[k]["unit"] != nil {
                    let oldUnit = drawSettings[k]["unit"]! as! Unit
                    if unit.isIdentical(unit: oldUnit) { unit = oldUnit }
                }
                drawSettings[k]["unit"] = unit
                if !unit.isNilUnit() {
                    colNames[k] = colNames[k] + " [" + unit.name + "]"
                }
                if drawSettings[k]["tabcolname"] != nil && !reset {
                    colNames[k] = drawSettings[k]["tabcolname"] as! String
                } else {
                    drawSettings[k]["tabcolname"] = colNames[k]
                }
                
                aColumn.title = colNames[k]
            }
        
        // cas d'une matrice
        } else if dims.count == 2 {
            showLabels = false
            theTable.allowsColumnSelection = false
            thePhVals = [firstPhysVal]
            dataType = "matrix"
            nCols = dims[0]
            if nSettings < nCols {
                drawSettings.append(contentsOf: Array(repeating: [:], count: nCols + 1 - nSettings))
            }
    
            nRows = dims[1]
            drawSettings = [[:]]
            rowNames = (1...nRows).map( {String($0)} ) // 1, 2, 3,...

            if nRows < 26 {
                colNames = (1...dims[0]).map( { String(UnicodeScalar(UInt8(64 + $0))) }) // A, B, C,...
            } else {
                colNames = (1...nCols).map( {String($0)} )
            }

            var unit = firstPhysVal.unit
            if theExp.drawSettingForKey(key: "unit") == nil {
                theExp.setSetting(key: "unit", value: unit)
            } else {
                unit = theExp.drawSettingForKey(key: "unit")! as! Unit
            }
            drawSettings[0]["unit"] = unit
            var title = colExps[0].stringExp()
            if !unit.isNilUnit() {
                title = title + " [" + unit.name + "]"
            }
            if !showLabels {
                theTable.headerView = nil
            }
            
            
            for k in 0..<dims[0] {
                let colTitle = colNames[k]
                let aColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: colTitle))
                aColumn.isEditable = true // ******** à modifier ultérieurement **********
                aColumn.width = 60
                drawSettings[k]["colwidth"] = aColumn.width
                aColumn.title = colTitle
                theTable.addTableColumn(aColumn)
            }
        
        // Cas de n colonnes distinctes
        } else if dims.count == 1 {
            dataType = "colexp"
            thePhVals = []
            nRows = dims[0]
            if reset == true || colExps.count != nCols || drawSettings.count != nCols {
                reset = true
                nCols = showLabels ? colExps.count + 1 : colExps.count
                drawSettings = Array(repeating: [:], count: nCols)
            }
            rowNames = (1...nRows).map( {String($0 - 1)} ) // 1, 2, 3,...
            colNames = Array(repeating: "", count: colExps.count)
            
            for (k,oneExp) in colExps.enumerated() {
                colNames[k] = oneExp.stringExp()
                var aColumn : NSTableColumn
                if reset {
                    aColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: String(k)))
                    aColumn.isEditable = true   // ******** à modifier ultérieurement **********
                    aColumn.width = 60
                    theTable.addTableColumn(aColumn)
                } else {
                    aColumn = theTable.tableColumns[k]
                }
                drawSettings[k]["colwidth"] = aColumn.width
                let thePhysVal = oneExp.executeHierarchicScript()
                if thePhysVal.type == "error" { return thePhysVal }
                else if thePhysVal.values.count != nRows {
                    return PhysValue(error: "all columns must have same length")
                }
                thePhVals.append(thePhysVal)
                var title = oneExp.stringExp()
                var unit = thePhysVal.unit
                if drawSettings[k]["unit"] != nil {
                    let oldUnit = drawSettings[k]["unit"]! as! Unit
                    if oldUnit.isIdentical(unit: unit) { unit = oldUnit}
                }
                drawSettings[k]["unit"] = unit
                if !unit.isNilUnit() {
                    title = title + " [" + unit.name + "]"
                }
                aColumn.title = title
            }
        } else {
            return PhysValue(error: "Unable to process arguments")
        }
        if reset {
            theTable.delegate = self
            theTable.dataSource = self
            theTable.action = #selector(onItemClicked)
            theTable.allowsColumnSelection = true
            theTable.gridColor = selectionColor
            theTable.gridStyleMask = NSTableView.GridLineStyle.solidVerticalGridLineMask
            theTable.allowsColumnReordering = false
            self.documentView = theTable
            self.hasVerticalScroller = true
            self.hasHorizontalScroller = true
            //theTable.font = NSFont(name: "Times", size: 8)!
        }
        return result
    }
    
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if theTable.numberOfColumns < 1 { return 0 }
        if dataType == "dataframe" { nRows = (thePhVals[0]).dim[0]}
        if dataType == "matrix" { nRows = thePhVals[0].dim[1] }
        if dataType == "colexp" { nRows = thePhVals[0].dim[0] }
        return nRows
    }
    
    
    // retourne le contenu d'une cellule du tableau
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {

        let identifier = tableColumn!.identifier
        if mainDoc.mySubViews[self] == nil { return nil }
        let theExp = mainDoc.mySubViews[self]!
        let showLabels = dataType == "matrix" ? false : (theExp.drawSettingForKey(key: "showLabels") as? Bool ?? false)
        if mainDoc.mySubViews[self] == nil { return nil}
        let colNumber = tableView.column(withIdentifier: identifier)
        let c = showLabels ? colNumber - 1 : colNumber

        var strVal = ""
        
        if drawSettings.count < thePhVals.count {
            drawSettings = Array(repeating: [:], count: thePhVals.count + 1)
        }
        if dataType == "dataframe" {
            if thePhVals.count <= c { return "" }
            if colNumber == 0 && showLabels {
                strVal = rowNames[row]
            } else {
                return oneValToString(
                    thePhVals[c],
                    n: row,
                    hierExp: colExps[0],
                    settings: mergeDics(["font":defaultFont, "textcolor": defaultTextColor],drawSettings[colNumber]),
                    noQuotes: true)
             }
            
        } else if dataType == "matrix" {
            if thePhVals[0].indexFromCoords(coord: [c,row]) == nil { return "" }
            return oneValToString(
                thePhVals[0],
                n: thePhVals[0].indexFromCoords(coord: [c,row])!,
                hierExp: colExps[0],
                settings: mergeDics(["font":defaultFont, "textcolor": defaultTextColor],theExp.drawSettings!),
                noQuotes: true
            )
            
        } else if dataType == "colexp" {
            if colNumber == 0 && showLabels {
                strVal = rowNames[row]
            } else {
                if thePhVals[c].values.count < row + 1 { return "" }
                colExps[c].draw = colExps[c].draw ?? HierDraw()
                colExps[c].draw!.settings = mergeDics(drawSettings[colNumber],["font":defaultFont, "textcolor": defaultTextColor])
                colExps[c].draw!.settings = drawSettings[colNumber]
                return oneValToString(
                    thePhVals[c],
                    n: row,
                    hierExp: colExps[c],
                    settings: mergeDics(["font":defaultFont, "textcolor": defaultTextColor],drawSettings[colNumber]),
                    noQuotes: true
                )
            }
            
        } else {
            strVal = ""
        }
        
        return NSAttributedString(string: strVal, attributes: [
            NSAttributedString.Key.font:defaultFont,
            NSAttributedString.Key.foregroundColor:defaultTextColor
        ])

    }
    
    
    
    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        let theEquation = mainDoc.mySubViews[self]!
        mainCtrl.selectEquation(equation: theEquation)
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
    
    func tableViewSelectionDidChange(_ notification : Notification) {
        selDidChange = true
    }
    
    func tableViewColumnDidResize(_ notification: Notification) {
        let col = notification.userInfo!["NSTableColumn"] as! NSTableColumn
        let colNumber = col.tableView!.column(withIdentifier: col.identifier)
        self.drawSettings[colNumber]["colwidth"] = col.width
    }
    
    
    @objc func onItemClicked() {
        if NSEvent.modifierFlags.contains(.control) {
            let mouseLoc = theTable.window!.mouseLocationOutsideOfEventStream
            let newMouseDownEvent = NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: mouseLoc,
                modifierFlags: NSEvent.ModifierFlags.control,
                timestamp: 1.0,
                windowNumber: theTable.window!.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 0)
            if newMouseDownEvent == nil { return }
            mainCtrl.contextMenu.removeAllItems()
            mainCtrl.contextMenu.addItem(withTitle: "Copy Table", action: #selector(copyTable), keyEquivalent: "")
            mainCtrl.contextMenu.addItem(withTitle: "Copy to PDF", action: #selector(copyToPDF), keyEquivalent: "")
            NSMenu.popUpContextMenu(mainCtrl.contextMenu, with: newMouseDownEvent!, for: self)
        }
        if !selDidChange {
            theTable.deselectAll(self)
        }
        selDidChange = false
        let theEquation = mainDoc.mySubViews[self]!
        mainCtrl.selectEquation(equation: theEquation)
     }
   
    @objc func cellWasEdited(sender : NSTextField) {
        let newValue = sender.stringValue
        print (newValue)
    }
    
    @objc func copyTable() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        var copiedText = ""
        let n = self.numberOfRows(in: self.theTable)
        for aCol in self.theTable.tableColumns {
            copiedText = copiedText + aCol.title + "\t"
        }
        copiedText = copiedText + "\n"
        for r in 0..<n {
            var c = 0
            for aCol in self.theTable.tableColumns {
                var str = (self.tableView(self.theTable, objectValueFor: aCol, row: r) as! NSAttributedString).string
                if c>0 {
                    str = str.replacingOccurrences(of: ".", with: ",")
                }
                copiedText = copiedText + str + "\t"
                c=c+1
            }
            copiedText = copiedText + "\n"
        }
        pasteboard.setString(copiedText, forType: NSPasteboard.PasteboardType.string)
    }
    
    @objc func copyToPDF() {
        mainCtrl.copyToPDF()
    }
    
}
