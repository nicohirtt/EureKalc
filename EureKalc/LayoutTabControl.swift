//
//  LayoutTabControl.swift
//  EureKalc
//
//  Created by Nico on 13/01/2020.
//  Copyright © 2020 Nico Hirtt. All rights reserved.
//

import Cocoa


// *******************************************************************************
// ***   PANNEAU DE CONTROLE DE PRESENTATION (blocs, couleur, mise en page..)   **
// *******************************************************************************

class LayoutTabController: NSViewController, NSColorChanging {
    
    @IBOutlet var textPanel: NSBox!
    @IBOutlet var fontNamePopup: NSPopUpButton!
    @IBOutlet var boldCheckBox: NSButton!
    @IBOutlet var italicCheckBox: NSButton!
    @IBOutlet var fontSizeField: NSTextField!
    @IBOutlet var fontSizeStepper: NSStepper!
    @IBOutlet var fontColorBtn: NSButton!
    @IBOutlet var autoFontBtn: NSButton!
    
    @IBOutlet var framePanel: NSBox!
    @IBOutlet var frameBtn: NSButton!
    @IBOutlet var frameLineColorBtn: NSButton!
    @IBOutlet var frameFillBtn: NSButton!
    @IBOutlet var framFillColorBtn: NSButton!
    @IBOutlet var connectorLeftParPopup: NSPopUpButton!
    @IBOutlet var connectorRightParPopup: NSPopUpButton!
    @IBOutlet var frameLineStepper: NSStepper!
    @IBOutlet var marginStepper: NSStepper!
    
    @IBOutlet var numberPanel: NSBox!
    @IBOutlet var numberAutoFormatBtn: NSButton!
    @IBOutlet var numberFloatFormatBtn: NSButton!
    @IBOutlet var numberSciFormatBtn: NSButton!
    @IBOutlet var numberUnitPopup: NSPopUpButton!
    @IBOutlet var numberDigitsBtn: NSButton!
    @IBOutlet var numberDecBtn: NSButton!
    @IBOutlet var numberPrecisionField: NSTextField!
    @IBOutlet var numberPrecisionStepper: NSStepper!
    @IBOutlet var vectorLengthBtn: NSStepper!
    
    @IBOutlet var gridPanel: NSBox!
    @IBOutlet var columnsField: NSTextField!
    @IBOutlet var rowsField: NSTextField!
    @IBOutlet var columnsStepper: NSStepper!
    @IBOutlet var rowsStepper: NSStepper!
    @IBOutlet var gridAlignLeftBtn: NSButton!
    @IBOutlet var gridAlignCenterBtn: NSButton!
    @IBOutlet var gridAlignRightBtn: NSButton!
    @IBOutlet var gridAlignEquation: NSButton!
    @IBOutlet var gridAlignTopBtn: NSButton!
    @IBOutlet var gridAlignBaseBtn: NSButton!
    @IBOutlet var gridALignBottomBtn: NSButton!
    @IBOutlet var gridFitWidthBtn: NSButton!
    @IBOutlet var gridEqualWidthBtn: NSButton!
    @IBOutlet var gridFitHeightBtn: NSButton!
    @IBOutlet var gridEqualHeightBtn: NSButton!
    @IBOutlet var showGridBtn: NSButton!
    @IBOutlet var gridVmarginStepper: NSStepper!
    @IBOutlet var gridHmarginStepper: NSStepper!
    
    @IBOutlet var namePanel: NSBox!
    @IBOutlet var expName: NSTextField!
    
    @IBOutlet var viewSizePanel: NSBox!
    @IBOutlet var viewWidthField: NSTextField!
    @IBOutlet var viewHeightField: NSTextField!
    @IBOutlet var viewWidthStepper: NSStepper!
    @IBOutlet var viewHeightStepper: NSStepper!
        
    @IBOutlet var tablePanel: NSBox!
    @IBOutlet var showTableLabels: NSButton!
    @IBOutlet var tableColLeft: NSButton!
    @IBOutlet var tableColCenter: NSButton!
    @IBOutlet var tableColRight: NSButton!
    
    
    var theMainControl : MainController?
    
    var colorSender : NSButton?
    
    var oldGridStepperVal : Int = 4
    var theEquation : HierarchicExp = HierarchicExp()
    var theGrid : HierGrid?
    var row : Int = 0
    var col : Int = 0
    
    var tabCol = 0
    var tableSettingsChanged = false
    var tableView : ekTableScrollView?
    var isRowNames : Bool = false
    var showRowNames : Bool = false
    var tabColSettings : [String:Any] = [:]
    var correctedTabCol : Int = 0
    var tableType : String = ""

       
    override var representedObject: Any? {
        didSet {
            //Update the view, if already loaded.
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mainDoc.layoutTabCtrl = self
        fontNamePopup.removeAllItems()
        fontNamePopup.addItems(withTitles: theFontNames)
    }
    
    
    // Choix et initialisation des panneaux
    func updatePanel() {
        textPanel.isHidden = true
        framePanel.isHidden = true
        mathTabCtrl.equationPanel.isHidden = true
        gridPanel.isHidden = true
        numberPanel.isHidden = true
        namePanel.isHidden = true
        viewSizePanel.isHidden = true
        tablePanel.isHidden = true

        if selectedEquation != nil { theEquation = selectedEquation! }
        else { theEquation = thePage }
        var y = self.view.frame.height - 3
        
        theGrid = (theEquation.op == "_grid") ? theEquation as? HierGrid : nil
        
        if theEquation.op == "table"  && theEquation.view != nil {
            tableView = theEquation.view! as? ekTableScrollView
            tableType = tableView!.dataType
            if tableType != "matrix" {
                tabCol = tableView!.theTable.selectedColumn
                tabColSettings = tabCol > -1 ? (tableView?.drawSettings[tabCol] ?? [:]) : [:]
                showRowNames = theEquation.drawSettingForKey(key: "showLabels") as! Bool
                correctedTabCol = showRowNames ? tabCol-1 : tabCol
                isRowNames = (showRowNames && tabCol == 0)
            } else {
                tabCol = -1
                tabColSettings = [:]
                showRowNames = false
                isRowNames = false
            }
        } else {
            tableView = nil
            tableType = ""
            showRowNames = false
        }
        
        // Panneau Nom
        let fatherOp = theEquation.father == nil ? "" : theEquation.father!.op
        if theEquation.op == "_grid" || theEquation.op == "_page" || fatherOp == "_grid" {
            y = placePanel(panel: namePanel, at: y)
            expName.stringValue = theEquation.name ?? ""
        } else {
            expName.stringValue = ""
        }
        
        // Réglage initial du panneau "text font" autoFontCheckBox.isEnabled = true
        if !theEquation.isGraph {
            y = placePanel(panel: textPanel, at: y)
            var theFont = theEquation.theFont
            if tableView != nil && tableType != "marix" {
                if tabColSettings["font"] == nil {
                    autoFontBtn.state = NSControl.StateValue.on
                } else {
                    autoFontBtn.state = NSControl.StateValue.off
                    theFont = tabColSettings["font"] as! NSFont
                }
            } else {
                if theEquation.drawSettings == nil {
                    autoFontBtn.state = NSControl.StateValue.on
                } else {
                    autoFontBtn.state = NSControl.StateValue.off
                }
            }
            enableFontControls(enable: true)
            let familyName = theFont.familyName
            fontNamePopup.selectItem(withTitle: familyName!)
            if theFont.fontDescriptor.symbolicTraits.contains(.bold) {
                boldCheckBox.state = NSControl.StateValue.on
            } else {
                boldCheckBox.state = NSControl.StateValue.off
            }
            if theFont.fontDescriptor.symbolicTraits.contains(.italic) {
                italicCheckBox.state = NSControl.StateValue.on
            } else {
                italicCheckBox.state = NSControl.StateValue.off
            }
            let theSize = theFont.pointSize
            fontSizeField.stringValue = String(Int(theSize))
            fontSizeStepper.intValue = Int32(theSize)
        }

        // régalge du panneau grid
        if theGrid != nil {
            y = placePanel(panel: gridPanel, at: y)
            let nCols = theGrid!.cols
            let nRows = theGrid!.rows
            columnsField.integerValue = nCols
            rowsField.integerValue = nRows
            columnsStepper.integerValue = nCols
            rowsStepper.integerValue = nRows
            if theGrid!.isBaseGrid || theGrid!.islineGrid {
                columnsStepper.isEnabled = false
                rowsStepper.isEnabled = false
            } else {
                columnsStepper.isEnabled = true
                rowsStepper.isEnabled = true
            }
            if theGrid!.showGrid {
                showGridBtn.state = NSControl.StateValue.on
                frameLineStepper.integerValue = theEquation.drawSettingForKey(key: "framewidth") as! Int
                frameLineColorBtn.isEnabled = true
                frameLineStepper.isEnabled = true
            } else {
                showGridBtn.state = NSControl.StateValue.off
                frameLineColorBtn.isEnabled = false
                frameLineStepper.isEnabled = false
            }
            if theGrid!.gridWidth == "fit" {gridFitWidthBtn.state = NSControl.StateValue.on}
            else {gridEqualWidthBtn.state = NSControl.StateValue.on}
            if theGrid!.gridHeight == "fit" {gridFitHeightBtn.state = NSControl.StateValue.on}
            else {gridEqualHeightBtn.state = NSControl.StateValue.on}
            gridHmarginStepper.integerValue = Int(theGrid!.hMargin)
            gridVmarginStepper.integerValue = Int(theGrid!.vMargin)
        }
        
        
        // réglage initial du panneau "frame"
        if theEquation.op.contains("block") || theEquation.isAncestor || theEquation.op == "_grid" {

            y = placePanel(panel: framePanel, at: y)
            frameBtn.isEnabled = true
            if theEquation.op == "_grid" {
                frameBtn.isEnabled = false
                marginStepper.isEnabled = false
            } else {
                frameBtn.isEnabled = true
                marginStepper.isEnabled = true
            }
            if theEquation.drawSettingForKey(key: "framewidth") != nil {
                frameLineStepper.integerValue = theEquation.drawSettingForKey(key: "framewidth") as! Int
                frameBtn.state = NSControl.StateValue.on
                frameLineColorBtn.isEnabled = true
                frameLineStepper.isEnabled = true
            } else {
                frameLineStepper.integerValue = 0
                frameBtn.state = NSControl.StateValue.off
                frameLineColorBtn.isEnabled = false
                frameLineStepper.isEnabled = false
            }
            if theEquation.drawSettingForKey(key: "framefillcolor") != nil {
                frameFillBtn.state = NSControl.StateValue.on
                framFillColorBtn.isEnabled = true
            } else {
                frameFillBtn.state = NSControl.StateValue.off
                framFillColorBtn.isEnabled = false
            }
    
            if theEquation.drawSettingForKey(key: "leftpar") != nil {
                let par = theEquation.drawSettingForKey(key: "leftpar") as! String
                connectorLeftParPopup.selectItem(withTitle: par)
            } else {
                connectorLeftParPopup.selectItem(at: 0)
            }
            if theEquation.drawSettingForKey(key: "rightpar") != nil {
                let par = theEquation.drawSettingForKey(key: "rightpar") as! String
                connectorRightParPopup.selectItem(withTitle: par)
            } else {
                connectorRightParPopup.selectItem(at: 0)
            }
            
            self.view.addSubview(mathTabCtrl.equationPanel)
            mathTabCtrl.initEquationPanel()
            y = placePanel(panel: mathTabCtrl.equationPanel, at: y)
        }
        
        // Panneau de réglage de la taille d'un view
        if ["button","slider","popup","hslider","cslider","stepper",
            "vslider","image","checkbox","table","text"].contains(theEquation.op) && theEquation.view != nil {
            y = placePanel(panel: viewSizePanel, at: y)
            let theSize = theEquation.view!.frame.size
            viewWidthStepper.integerValue = Int(theSize.width)
            viewHeightStepper.integerValue = Int(theSize.height)
            viewWidthField.integerValue = Int(theSize.width)
            viewHeightField.integerValue = Int(theSize.height)
        }
        
        // réglage du panneau "valeur numérique"
        if (theEquation.op == "_val" && theEquation.value != nil) || (tableType == "matrix") {
            let value = tableType == "matrix" ? tableView!.thePhVals[0] : theEquation.value!
            if value.type == "double" || value.type == "int" {
                self.view.addSubview(numberPanel)
                y = placePanel(panel: numberPanel, at: y)
                let unitName = value.unit.name
                let format = theEquation.drawSettingForKey(key: "format") as? String ?? "auto"
                let digits = theEquation.drawSettingForKey(key: "digits") as? Bool ?? true
                let precision = theEquation.drawSettingForKey(key: "precision") as? Int ?? defaultNumberPrecision
                initNumPanel(unitName: unitName, format: format, digits: digits, precision: precision)
            }
            if value.dim.count == 1 {
                let vecLength = theEquation.drawSettingForKey(key: "vecLength") as? Int ?? maxNumberValuesShown
                vectorLengthBtn.integerValue = vecLength/2
            }
        } else if (theEquation.result != nil) {
            if theEquation.result!.op == "_val" {
                let value = theEquation.result!.value!
                if value.type == "double" {
                    self.view.addSubview(numberPanel)
                    y = placePanel(panel: numberPanel, at: y)
                    let unitName = value.unit.name
                    let format = theEquation.drawSettingForKey(key: "format") as? String ?? "auto"
                    let digits = theEquation.drawSettingForKey(key: "digits") as? Bool ?? true
                    let precision = theEquation.drawSettingForKey(key: "precision") as? Int ?? defaultNumberPrecision
                    initNumPanel(unitName: unitName, format: format, digits: digits, precision: precision)
                }
                if value.dim.count == 1 {
                    let vecLength = theEquation.drawSettingForKey(key: "vecLength") as? Int ?? maxNumberValuesShown
                    vectorLengthBtn.integerValue = vecLength/2
                }
            }
        } else if tableView != nil && tableType != "matrix" {
            y = placePanel(panel: tablePanel, at: y)
            showTableLabels.state = showRowNames ? NSControl.StateValue.on : NSControl.StateValue.off
            if correctedTabCol > -1 {
                self.view.addSubview(numberPanel)
                y = placePanel(panel: numberPanel, at: y)
                tabColSettings = tableView!.drawSettings[correctedTabCol]
                let unitName = tabColSettings["unit"] != nil ? (tabColSettings["unit"]! as! Unit).name : ""
                let format = tabColSettings["format"] != nil ? tabColSettings["format"]! as! String : "auto"
                let digits = tabColSettings["digits"] != nil ? tabColSettings["digits"]! as! Bool : true
                let precision = tabColSettings["precision"] != nil ? tabColSettings["precision"]! as! Int : defaultNumberPrecision
                initNumPanel(unitName: unitName, format: format, digits: digits, precision: precision)
            }
        }
    }
    
    func initNumPanel(unitName: String, format: String, digits: Bool, precision: Int) {
        numberUnitPopup.removeAllItems()
        let unit = Unit(unitExp: unitName)
        numberUnitPopup.addItems(withTitles: unit.similarUnitNames)
        numberUnitPopup.selectItem(withTitle: unitName)
        
        
        if format == "auto" { setBtnState(numberAutoFormatBtn)}
        if format == "float" { setBtnState(numberFloatFormatBtn)}
        if format == "sci" { setBtnState(numberSciFormatBtn)}
        
        if digits { setBtnState(numberDigitsBtn)
        } else { setBtnState(numberDecBtn) }

        numberPrecisionField.integerValue = precision
        numberPrecisionStepper.integerValue = precision
    }
    
    @IBAction func autoFontBtn(_ sender: Any) {
        if selectedEquation != nil {
            theEquation = selectedEquation! }
        else { theEquation = thePage }
        if autoFontBtn.state == NSControl.StateValue.on {
            theEquation.setSetting(key: "font",value : nil)
            theEquation.setSetting(key: "textcolor",value: nil)
        }
        updatePanel()
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    @IBAction func fontChanged(_ sender: Any) {
        let fontFamily = fontNamePopup.titleOfSelectedItem!
        let fontSize = CGFloat(fontSizeField.intValue)
        var theFontMask : NSFontTraitMask
        if boldCheckBox.state == NSControl.StateValue.on {
            theFontMask = NSFontTraitMask.boldFontMask
        } else {
            theFontMask = NSFontTraitMask.unboldFontMask
        }
        if italicCheckBox.state == NSControl.StateValue.on {
            theFontMask = NSFontTraitMask(rawValue: theFontMask.rawValue | NSFontTraitMask.italicFontMask.rawValue)
        } else {
            theFontMask = NSFontTraitMask(rawValue: theFontMask.rawValue | NSFontTraitMask.unitalicFontMask.rawValue)
        }
        let theFont = NSFontManager.shared.font(withFamily: fontFamily, traits: theFontMask, weight: 5, size: fontSize)
        if theFont == nil { return }
        if selectedEquation == nil {
            thePage.setSetting(key: "font", value: theFont!)
        } else if theEquation.op == "table"  && tabCol > -1 && !isRowNames && tableType != "matrix" {
            tabColSettings["font"] = theFont
            tableView!.drawSettings[tabCol] = tabColSettings
        } else {
            selectedEquation!.setSetting(key: "font", value: theFont!)
        }
        autoFontBtn.state = NSControl.StateValue.off
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    
    @IBAction func fontSizeStepperChanged(_ sender: Any) {
        fontSizeField.stringValue = String(fontSizeStepper.intValue)
        fontChanged(self)
        autoFontBtn.state = NSControl.StateValue.off
        mainDoc.tryAutoSave()
    }
    
    func enableFontControls(enable: Bool) {
        fontNamePopup.isEnabled = enable
        boldCheckBox.isEnabled = enable
        italicCheckBox.isEnabled = enable
        fontSizeField.isEnabled = enable
        fontSizeStepper.isEnabled = enable
        fontColorBtn.isEnabled = enable
    }
    
    @IBAction func changedFrameSettings(_ sender: Any) {
        if frameBtn.state == NSControl.StateValue.on || theEquation.op == "_grid"  {
            theEquation.setSetting(key: "framewidth", value: frameLineStepper.integerValue)
            frameLineColorBtn.isEnabled = true
            frameLineStepper.isEnabled = true
        } else {
            theEquation.removeSetting(key: "framewidth")
            frameLineColorBtn.isEnabled = false
            frameLineStepper.isEnabled = false
            theEquation.setSetting(key: "framemargin", value: defaultFrameMargin)
            marginStepper.integerValue = Int(defaultFrameMargin)
            theEquation.setSetting(key: "innergrid", value: false)
        }
        if frameFillBtn.state == NSControl.StateValue.on {
            theEquation.setSetting(key: "framefillcolor", value: NSColor.gray)
            framFillColorBtn.isEnabled = true
        } else {
            theEquation.removeSetting(key: "framefillcolor")
            framFillColorBtn.isEnabled = false
        }

        if connectorLeftParPopup.indexOfSelectedItem < 1 {
            theEquation.removeSetting(key: "leftpar")
        } else {
            theEquation.setSetting(key: "leftpar", value: connectorLeftParPopup.titleOfSelectedItem!)
        }
        if connectorRightParPopup.indexOfSelectedItem < 1 {
            theEquation.removeSetting(key: "rightpar")
        } else {
            theEquation.setSetting(key: "rightpar", value: connectorRightParPopup.titleOfSelectedItem!)
        }
        theEquation.setSetting(key: "framemargin", value: CGFloat(marginStepper.integerValue))
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    
    @IBAction func clickedColorButton(_ sender: Any) {
        colorSender = sender as? NSButton
        self.view.window!.makeFirstResponder(self)
        NSApplication.shared.orderFrontColorPanel(self)
        mainDoc.tryAutoSave()
    }
    
    func changeColor(_ sender: NSColorPanel?) {
        let theColor = sender?.color
        if theColor == nil { return }
        // Changement de la couleur du texte
        if colorSender == fontColorBtn {
            if selectedEquation == nil {
                thePage.setSetting(key: "textcolor", value: theColor!)
            } else {
                selectedEquation!.setSetting(key: "textcolor", value: theColor!)
            }
        } else if colorSender == framFillColorBtn {
            frameFillBtn.state = NSControl.StateValue.on
            if selectedEquation == nil {
                thePage.setSetting(key: "framefillcolor", value: theColor!)
            } else {
                selectedEquation!.setSetting(key: "framefillcolor", value: theColor!)
            }
        } else if colorSender == frameLineColorBtn {
            if selectedEquation == nil {
                thePage.setSetting(key: "framecolor", value: theColor!)
            } else {
                selectedEquation!.setSetting(key: "framecolor", value: theColor!)
            }
        }
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    @IBAction func changedNumberPanel(_ sender: Any) {
        
        var selectedAxis = -1
        if theEquation.isGraph {
            let element = theEquation.graph!.lastClickedElement
            if element == "x" || element == "titlex" || element == "labx" {
                selectedAxis = 0
            } else {
                selectedAxis = 1
            }
        }
        
        // format auto, float ou sci
        var format = "auto"
        if btnState(numberFloatFormatBtn) { format = "float" }
        if btnState(numberSciFormatBtn) { format = "sci"}
        if theEquation.isGraph {
            theEquation.graph!.axesLabsFormat[selectedAxis] = format
        } else if theEquation.op == "table" && tabCol > -1 && tableType != "matrix" {
            tabColSettings["format"] = format
        } else {
            theEquation.setSetting(key: "format", value: format)
        }
        
        // unité
        
        var unit = Unit(num: true).baseUnit()
        if theEquation.isGraph {
            unit = theEquation.graph!.axesUnit?[selectedAxis] ?? Unit()
        } else if tableType == "matrix" {
            unit = tableView!.thePhVals[0].unit
        } else if theEquation.op == "table" && tabCol > -1 && !isRowNames {
            if tabColSettings["unit"] != nil { unit = tabColSettings["unit"]! as! Unit }
            unit = tableView!.thePhVals[showRowNames ? tabCol - 1 : tabCol].unit
        } else if theEquation.op == "_val" {
            unit = theEquation.value!.unit
        } else if theEquation.result != nil {
            unit = theEquation.result!.value!.unit
        }
 
        
        if numberUnitPopup.selectedItem != nil {
            unit = unitsByName[numberUnitPopup.titleOfSelectedItem!] ?? Unit()
        }
        if theEquation.isGraph {
            if theEquation.graph!.axesUnit == nil { theEquation.graph!.axesUnit = [Unit(),Unit()] }
            theEquation.graph!.axesUnit![selectedAxis] = unit
        } else if tableType == "matrix" {
            tableView!.thePhVals[0].unit = unit
        } else if theEquation.op == "table" && tabCol > -1 && !isRowNames {
            tabColSettings["unit"] = unit
            tableView!.thePhVals[showRowNames ? tabCol - 1 : tabCol].unit = unit
            tableSettingsChanged = true
        } else if theEquation.op == "_val" || tableType == "matrix" {
            theEquation.value!.unit = unit
        } else if theEquation.result != nil {
            theEquation.result!.value!.unit = unit
        }
        
        // digits true ou false
        var digits = true
        if btnState(numberDecBtn) { digits = false }
        if theEquation.isGraph {
             theEquation.graph!.axesLabsDigits[selectedAxis] = digits
        } else if tableType == "matrix" {
            theEquation.setSetting(key: "digits", value: digits)
            tableView!.colExps[0].setSetting(key: "digits", value: digits)
         } else if theEquation.op == "table"  && tabCol > -1 && !isRowNames {
             tabColSettings["digits"] = digits
             tableSettingsChanged = true
        } else if theEquation.op == "_val" {
            theEquation.setSetting(key: "digits", value: digits)
        } else if theEquation.result != nil {
            theEquation.result!.setSetting(key: "digits", value: digits)
        }
        
        // précision
        var precision : Int
        if (sender as! NSControl) == numberPrecisionStepper {
            precision = numberPrecisionStepper.integerValue
            if precision == 0 && digits {
                precision = 1
                numberPrecisionStepper.integerValue = 1
            }
            numberPrecisionField.integerValue = precision
        } else {
            precision = numberPrecisionField.integerValue
            numberPrecisionStepper.integerValue = precision
        }
        if theEquation.isGraph {
             theEquation.graph!.axesLabsPrecision[selectedAxis] = precision
        } else if tableType == "matrix" {
            theEquation.setSetting(key: "precision", value: precision)
            tableView!.colExps[0].setSetting(key: "precision", value: precision)
        } else if theEquation.op == "table"  && tabCol > -1 && !isRowNames && tableType != "matrix" {
            tabColSettings["precision"] = precision
            tableSettingsChanged = true
        } else if theEquation.op == "_val" {
            theEquation.setSetting(key: "precision", value: precision)
        } else if theEquation.result != nil {
            theEquation.result!.setSetting(key: "precision", value: precision)
        }
        
        // longueur des vecteurs
        let vecLength = 2*vectorLengthBtn.integerValue
        if theEquation.op == "_val" {
            theEquation.setSetting(key: "vecLength", value: vecLength)
        } else if theEquation.result != nil {
            theEquation.result!.setSetting(key: "vecLength", value: vecLength)
        }
        
        // On redessine les graphes
        if theEquation.isGraph {
            _ = theEquation.executeHierarchicScript()
            theEquation.graph!.autoLimits(j: selectedAxis)
        }
        
        // Finalisation pour le cas d'un tableau
        if theEquation.op == "table" && tabCol > -1 && tableType != "matrix" {
            if tableSettingsChanged && !isRowNames {
                let oldName = tableView!.colNames[showRowNames ? tabCol - 1 : tabCol]
                let prefix = oldName.split(separator: "[")[0]
                let newName = (String(prefix) + " [" + unit.name + "]").replacingOccurrences(of: "  ", with: " ")
                tableView!.theTable.tableColumns[tabCol].title = newName
                tabColSettings["tabcolname"]=newName
            }
            tableView!.drawSettings[tabCol] = tabColSettings
        }
        if theEquation.isGraph {
            graphTabCtrl.updatePanel()
        }
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    @IBAction func changeGridSize(_ sender: Any) {
        let nCols = theGrid!.cols
        let nRows = theGrid!.rows
        if columnsStepper.integerValue > nCols {
            theGrid!.addColumn(col: nCols)
        } else if columnsStepper.integerValue < nCols {
            theGrid!.deleteColumn(col: nCols-1)
        } else if rowsStepper.integerValue > nRows {
            theGrid!.addRow(row: nRows)
        } else if rowsStepper.integerValue < nRows {
            theGrid!.deleteRow(row: nRows-1)
        }
        columnsField.integerValue = columnsStepper.integerValue
        rowsField.integerValue = rowsStepper.integerValue
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    @IBAction func changeGridSettings(_ sender: Any) {
        let nCols = theGrid!.cols
        let nRows = theGrid!.rows
        switch sender as! NSButton {
        case gridAlignLeftBtn :
            if theEquation.op == "_grid" { theGrid!.hAligns = Array(repeating: "left", count: nCols)}
            else { theGrid!.hAligns[col] = "left"}
        case gridAlignCenterBtn:
            if theEquation.op == "_grid" { theGrid!.hAligns = Array(repeating: "center", count: nCols)}
            else { theGrid!.hAligns[col] = "center"}
        case gridAlignRightBtn :
            if theEquation.op == "_grid" { theGrid!.hAligns = Array(repeating: "right", count: nCols)}
            else { theGrid!.hAligns[col] = "right"}
        case gridAlignEquation :
            if theEquation.op == "_grid" { theGrid!.hAligns = Array(repeating: "equation", count: nCols)}
            else { theGrid!.hAligns[col] = "equation"}
        case gridAlignTopBtn :
            if theEquation.op == "_grid" { theGrid!.vAligns = Array(repeating: "top", count: nRows)}
            else { theGrid!.vAligns[row] = "top"}
        case gridAlignBaseBtn :
            if theEquation.op == "_grid" { theGrid!.vAligns = Array(repeating: "baseline", count: nRows)}
            else { theGrid!.vAligns[row] = "baseline"}
        case gridALignBottomBtn :
            if theEquation.op == "_grid" { theGrid!.vAligns = Array(repeating: "bottom", count: nRows)}
            else { theGrid!.vAligns[row] = "bottom"}
        case gridFitWidthBtn :
            theGrid!.gridWidth = "fit"
        case gridEqualWidthBtn :
            theGrid!.gridWidth = "equal"
        case gridFitHeightBtn :
            theGrid!.gridHeight = "fit"
        case gridEqualHeightBtn :
            theGrid!.gridHeight = "equal"
        case showGridBtn :
            theGrid!.showGrid = (showGridBtn.state == NSControl.StateValue.on)
            if theGrid!.showGrid {
                theEquation.setSetting(key: "framewidth", value: frameLineStepper.integerValue)
                frameLineColorBtn.isEnabled = true
                frameLineStepper.isEnabled = true
            } else {
                //frameBtn.state = NSControl.StateValue.off
                if frameBtn.state == NSControl.StateValue.off {
                    theEquation.removeSetting(key: "frameWidth")
                    frameLineColorBtn.isEnabled = false
                    frameLineStepper.isEnabled = false
                }
            }
        default : return
        }
        updatePanel()
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    
    @IBAction func gridMarginsChanged(_ sender: NSStepper) {
        theGrid!.vMargin = CGFloat(gridVmarginStepper.integerValue)
        theGrid!.hMargin = CGFloat(gridHmarginStepper.integerValue)
        mainCtrl.theEquationView.needsDisplay = true
    }
    
    @IBAction func changeExpName(_ sender: Any) {
        if theEquation.name != nil {
            mainDoc.namedExps[theEquation.name!] = nil
        }
        let newName = expName.stringValue
        if newName == "" {
            theEquation.name = nil
        } else {
            theEquation.name = newName
            mainDoc.namedExps[newName] = theEquation
        }
        if theEquation.op == "_page" {
            mainCtrl.resetPageButtons(mainDoc.currentPage)
        }
        mainDoc.tryAutoSave()
    }
    
    @IBAction func changedViewSize(_ sender: Any) {
        if sender as? NSControl == viewWidthStepper || sender as? NSControl == viewHeightStepper {
            viewWidthField.floatValue = viewWidthStepper.floatValue
            viewHeightField.floatValue = viewHeightStepper.floatValue
        } else {
            viewWidthStepper.floatValue = viewWidthField.floatValue
            viewHeightStepper.floatValue = viewHeightField.floatValue
        }
        var theWidth = CGFloat(viewWidthField.floatValue)
        var theHeight = CGFloat(viewHeightField.floatValue)
        if theWidth < 20 {
            theWidth = 20
        }
        if theWidth < 20 {
            theHeight = 20
        }
        if theEquation.graph != nil {
            let frameRect = theEquation.graph!.frameRect
            theEquation.graph!.frameRect = NSRect(x: frameRect.origin.x, y: frameRect.origin.y, width: theWidth, height: theHeight)
        } else if theEquation.view != nil {
            theEquation.view!.setFrameSize(NSSize(width: theWidth, height: theHeight))
        }
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    @IBAction func changeTableLabes(_ sender: Any) {
        let theTableView = theEquation.view! as! ekTableScrollView
        let choice = (sender as! NSButton).state == NSControl.StateValue.on
        theEquation.setSetting(key: "showLabels", value: choice)
        theTableView.removeFromSuperview()
        theEquation.view = nil
        _ = theEquation.executeHierarchicScript()
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    @IBAction func changeTableColAlignment(_ sender: NSButton) {
        if theEquation.op == "table" && tabCol > -1 {
            // ***** NEFO NCTIONNE PAS ******
            (tableView?.theTable.tableColumns[0].dataCell as! NSTextFieldCell).alignment = NSTextAlignment.center
        }
    }
    
}

