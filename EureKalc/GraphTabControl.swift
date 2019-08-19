//
//  MathTabControl.swift
//  EureKalc
//
//  Created by Nico on 13/01/2020.
//  Copyright © 2020 Nico Hirtt. All rights reserved.
//

import Cocoa



// *******************************************************************************
// ***   PANNEAU DE CONTROLE DES GRAPHES                                        **
// *******************************************************************************


class GraphTabController: NSViewController, NSColorChanging {
    
    @IBOutlet var graphMainPanel: NSBox!
    @IBOutlet var graphTitleField: NSTextField!
    @IBOutlet var graphAxesFrameBtn: NSButton!
    @IBOutlet var graphAxesWidthStepper: NSStepper!
    @IBOutlet var graphAxesColorBtn: NSButton!
    @IBOutlet var graphAxesFillBtn: NSButton!
    @IBOutlet var graphAxesFillColorBtn: NSButton!
    @IBOutlet var legendPositionPopup: NSPopUpButton!
    @IBOutlet var graphShowLegendBtn: NSButton!
    
    @IBOutlet var graphAxisPanel: NSBox!
    @IBOutlet var minAxisField: NSTextField!
    @IBOutlet var maxAxisField: NSTextField!
    @IBOutlet var axisDivsStepper: NSStepper!
    @IBOutlet var axisSubDivsStepper: NSStepper!
    @IBOutlet var graphShowArrowBtn: NSButton!
    @IBOutlet var axisPositionPopup: NSPopUpButton!
    @IBOutlet var graphAxisNameField: NSTextField!
    @IBOutlet var graphTickLabelsBtn: NSButton!
    @IBOutlet var graphMainTicksBtn: NSButton!
    @IBOutlet var axisDivsLabel: NSTextField!
    @IBOutlet var axisSubDivsLabel: NSTextField!
    @IBOutlet var graphGridColorBtn: NSButton!
    @IBOutlet var graphSubGridColorBtn: NSButton!
    @IBOutlet var graphMainGridWidthStepper: NSStepper!
    @IBOutlet var graphSubGridWidthStepper: NSStepper!
    @IBOutlet var autoMinMaxBtn: NSButton!
    
    @IBOutlet var graphTracePanel: NSBox!
    @IBOutlet var graphLinePopup: NSPopUpButton!
    @IBOutlet var graphLineSizeStepper: NSStepper!
    @IBOutlet var graphLineColorBtn: NSButton!
    @IBOutlet var graphDotsPopup: NSPopUpButton!
    @IBOutlet var graphDotSizeStepper: NSStepper!
    @IBOutlet var graphDotColorbtn: NSButton!
    @IBOutlet var graphDotSpacingField: NSTextField!
    @IBOutlet var graphDotSpacingStepper: NSStepper!
    @IBOutlet var graphTraceNameField: NSTextField!
    
    @IBOutlet var graphFontPanel: NSBox!
    @IBOutlet var graphFontPopup: NSPopUpButton!
    @IBOutlet var graphFontSizeCombo: NSComboBox!
    @IBOutlet var graphBoldBtn: NSButton!
    @IBOutlet var graphItalicBtn: NSButton!
    @IBOutlet var graphTextColorBtn: NSButton!
    
    @IBOutlet var graphHistoPanel: NSBox!
    @IBOutlet var barSpace2Field: NSTextField!
    @IBOutlet var barSpace1Field: NSTextField!
    @IBOutlet var barSpace2Stepper: NSStepper!
    @IBOutlet var barSpace1Stepper: NSStepper!
    @IBOutlet var barHorizontalBtn: NSButton!
    @IBOutlet var barStackedBtn: NSButton!
    
    @IBOutlet var graphHistoBarPanel: NSBox!
    @IBOutlet var graphBarColorBtn: NSButton!
    @IBOutlet var graphBarNameField: NSTextField!
    
    @IBOutlet var fieldPanel: NSBox!
    @IBOutlet var fieldMin: NSTextField!
    @IBOutlet var fieldMax: NSTextField!
    @IBOutlet var fieldMed: NSTextField!
    @IBOutlet var fieldColor1: NSButton!
    @IBOutlet var fieldColor3: NSButton!
    @IBOutlet var fieldColor2: NSButton!
    @IBOutlet var fieldUnitPopup: NSPopUpButton!
    @IBOutlet var vecSizeStepper0: NSSlider!
    @IBOutlet var vecSizeStepper1: NSSlider!
    @IBOutlet var fieldName: NSTextField!
    @IBOutlet var fieldNumberStepper: NSStepper!
    @IBOutlet var fieldNumber: NSTextField!
    
    
    var theMainControl : MainController?
    var colorSender : NSButton?
    
    var oldGridStepperVal : Int = 4
    
    override var representedObject: Any? {
        didSet {
            //Update the view, if already loaded.
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mainDoc.graphTabCtrl = self
        graphFontPopup.removeAllItems()
        let theFontNames = ["Arial", "ArialNarrow", "Athelas", "Avenir", "AvenirNext","Baskerville", "CenturyGothic", "Courier", "Euclid", "EuclidSymbol", "Garamond","GillSans", "Helvetica", "HelveticaNeue", "HoeflerText","Optima", "Palatino", "Times", "TimesNewRomanPS", "Trebuchet", "Verdana", ".AppleSystemUIFont"]
        graphFontPopup.addItems(withTitles: theFontNames)
    }
    
    
    // Choix et initialisation des panneaux
    func updatePanel() {
        var theEquation = selectedEquation
        if theEquation == nil { theEquation = thePage }
        var y = self.view.frame.height - 6
        
        graphAxisPanel.isHidden = true
        graphMainPanel.isHidden = true
        graphTracePanel.isHidden = true
        graphFontPanel.isHidden = true
        graphHistoPanel.isHidden = true
        graphHistoBarPanel.isHidden = true
        layoutTabCtrl.numberPanel.isHidden = true
        fieldPanel.isHidden = true
        layoutTabCtrl.viewSizePanel.isHidden = true

        if theEquation!.isGraph && theEquation!.graph != nil {
            
            let theGraph = theEquation!.graph!
            let element = theGraph.lastClickedElement
            
            // Panneau général
            y = placePanel(panel: graphMainPanel, at: y)
            graphTitleField.stringValue = theGraph.mainTitle
            graphAxesFrameBtn.state = stateValue(theGraph.axesFrame)
            graphAxesWidthStepper.integerValue = Int(theGraph.axesWidth * 2)
            graphAxesFillBtn.state = stateValue(theGraph.axesFill)
            graphShowLegendBtn.state = stateValue(theGraph.legend)
            switch theGraph.legendPos {
            case "RB" : legendPositionPopup.selectItem(at: 1)
            case "B" : legendPositionPopup.selectItem(at: 2)
            default: legendPositionPopup.selectItem(at: 0)
            }
            
            // Taille du graphique
            layoutTabCtrl.theEquation = theEquation!
            self.view.addSubview(layoutTabCtrl.viewSizePanel)
            y = placePanel(panel: layoutTabCtrl.viewSizePanel, at: y)
            let theSize = theGraph.frameRect.size
            layoutTabCtrl.viewWidthStepper.integerValue = Int(theSize.width)
            layoutTabCtrl.viewHeightStepper.integerValue = Int(theSize.height)
            layoutTabCtrl.viewWidthField.integerValue = Int(theSize.width)
            layoutTabCtrl.viewHeightField.integerValue = Int(theSize.height)
            
            // histogramme
            if theGraph.barData != nil {
                y = placePanel(panel: graphHistoPanel, at: y)
                barSpace2Field.doubleValue = Double(theGraph.histoS2 * 100)
                barSpace2Stepper.doubleValue = Double(theGraph.histoS2 * 100)
                if theGraph.barData!.count > 1 && theGraph.histoStacked == false {
                    barSpace1Field.isEnabled = true
                    barSpace1Field.doubleValue = Double(theGraph.histoS1 * 100)
                    barSpace1Stepper.isEnabled = true
                    barSpace1Stepper.doubleValue = Double(theGraph.histoS1 * 100)
                } else {
                    barSpace1Field.isEnabled = false
                    barSpace1Field.stringValue = ""
                    barSpace1Stepper.isEnabled = false
                }
                barHorizontalBtn.state = (theGraph.histoOrientation == "V") ? NSControl.StateValue.off : NSControl.StateValue.on
                barStackedBtn.state = theGraph.histoStacked ? NSControl.StateValue.on : NSControl.StateValue.off
            }
            
            // champ
            if theGraph.fields != nil {
                y = placePanel(panel: fieldPanel, at: y)
                var n : Int = 0
                if theGraph.fields!.count == 1 {
                    fieldNumberStepper.isEnabled = false
                    fieldNumber.isEnabled = false
                } else {
                    fieldNumberStepper.isEnabled = true
                    fieldNumber.isEnabled = true
                }
                if fieldNumberStepper.intValue > theGraph.fields!.count {
                    fieldNumber.integerValue = 1
                    fieldNumberStepper.integerValue = 1
                } else {
                    fieldNumber.integerValue = fieldNumberStepper.integerValue
                    n = fieldNumberStepper.integerValue - 1
                }
                fieldPanel.isHidden = false
                let unit = theGraph.fields![n].unit
                if theGraph.fields![n].isVec {
                    vecSizeStepper0.isEnabled = true
                    vecSizeStepper1.isEnabled = true
                    fieldColor2.isEnabled = false
                    fieldMed.isEnabled = false
                    fieldColor3.isEnabled = false
                } else {
                    vecSizeStepper0.isEnabled = false
                    vecSizeStepper1.isEnabled = false
                    fieldColor2.isEnabled = true
                    fieldMed.isEnabled = true
                    fieldColor3.isEnabled = true
                }
                fieldUnitPopup.removeAllItems()
                if !unit.isNilUnit() {
                    fieldUnitPopup.addItems(withTitles: unit.similarUnitNames)
                    fieldUnitPopup.selectItem(withTitle: unit.name)
                }
                let valsInUnit = theGraph.fieldLimits![n].valuesInUnit
                fieldMin.formatValue(valsInUnit.count > 0 ? valsInUnit[0] : nil)
                fieldMax.formatValue(valsInUnit.count > 1 ? valsInUnit[1] : nil)
                fieldMed.formatValue(valsInUnit.count > 2 ? valsInUnit[2] : nil)

                fieldName.stringValue = theGraph.fieldNames![n]
                
            }
            
            // Axes des graphes de type plot
            if element == "x" || element == "y" || element == "titlex" || element == "titley" || element == "labx" || element == "laby" {
                y = placePanel(panel: graphAxisPanel, at: y)
                
                var j : Int
                if element == "x" || element == "titlex" || element == "labx" {
                    j = 0
                    graphAxisPanel.title = graphAxisPanel.title.replacingOccurrences(of: "Y", with: "X")
                    
                } else {
                    j = 1
                    graphAxisPanel.title = graphAxisPanel.title.replacingOccurrences(of: "X", with: "Y")
                }
                let unitMult = theGraph.axesUnit![j].mult
                minAxisField.formatValue(theGraph.axesLim(j).min / unitMult)
                maxAxisField.formatValue(theGraph.axesLim(j).max / unitMult)
                oldGridStepperVal = Int((theGraph.axesLim(j).max - theGraph.axesLim(j).min) / theGraph.axesDivs[j])
                axisDivsStepper.integerValue = oldGridStepperVal
                axisDivsLabel.integerValue = oldGridStepperVal
                axisSubDivsStepper.integerValue = theGraph.axesSubDivs[j]
                axisSubDivsLabel.integerValue = theGraph.axesSubDivs[j]
                
                graphShowArrowBtn.state = stateValue(theGraph.axesArrows[j])
                var pos = "None"
                if theGraph.axesPos[j] == "min" { pos = "Min"}
                if theGraph.axesPos[j] == "max" { pos = "Max"}
                if theGraph.axesPos[j] == "0" { pos = "Zero"}
                axisPositionPopup.selectItem(withTitle: pos)
                
                if j == 0 {
                    graphAxisNameField.stringValue = theGraph.axesTitles[0]
                } else {
                    graphAxisNameField.stringValue = theGraph.axesTitles[1]
                }
                graphMainTicksBtn.state = stateValue(theGraph.ticks[j].main)
                graphTickLabelsBtn.state = stateValue(theGraph.tickLabels[j])
                if theGraph.grids[j].main {
                    graphMainGridWidthStepper.integerValue = Int(2 * theGraph.gridsWidths[j].main)
                } else {
                    graphMainGridWidthStepper.integerValue = 0
                }
                if theGraph.grids[j].sub {
                    graphSubGridWidthStepper.integerValue = Int(2 * theGraph.gridsWidths[j].sub)
                } else {
                    graphSubGridWidthStepper.integerValue = 0
                }
                
                if theGraph.axesAuto[j] {
                    autoMinMaxBtn.state = NSControl.StateValue.on
                } else {
                    autoMinMaxBtn.state = NSControl.StateValue.off
                }
                
                // panneau réglage des nombres et unités
                self.view.addSubview(layoutTabCtrl.numberPanel)
                y = placePanel(panel: layoutTabCtrl.numberPanel, at: y)
        
                let selectedAxis = (element == "x" || element == "titlex" || element == "labx") ? 0 : 1
                let unit = theGraph.axesUnit![selectedAxis]
                let unitName = unit.name
                let digits = theGraph.axesLabsDigits[selectedAxis]
                let format = theGraph.axesLabsFormat[selectedAxis]
                let precision = theGraph.axesLabsPrecision[selectedAxis]
                layoutTabCtrl.initNumPanel(unitName: unitName, format: format, digits: digits, precision: precision)
                layoutTabCtrl.theEquation = theEquation!
            }
            
            if element == "title" || element == "titlex" || element == "titley"  {
                y = placePanel(panel: graphFontPanel, at: y)
                
                var theFont = theGraph.graphFonts["maintitle"]!
                if element == "labx" ||  element == "laby" {
                    theFont = theGraph.graphFonts["ticklabels"]!
                } else if element == "titlex" ||  element == "titley" {
                    theFont = theGraph.graphFonts["axeslabels"]!
                }
                let familyName = theFont.familyName
                graphFontPopup.selectItem(withTitle: familyName!)
                if theFont.fontDescriptor.symbolicTraits.contains(.bold) {
                    graphBoldBtn.state = NSControl.StateValue.on
                }
                if theFont.fontDescriptor.symbolicTraits.contains(.italic) {
                    graphItalicBtn.state = NSControl.StateValue.on
                }
                let theSize = theFont.pointSize
                graphFontSizeCombo.stringValue = String(Int(theSize))
            }
            
            if ["0","1","2","3","4","5","6","7","8","9"].contains(element) && theGraph.xyData != nil {
                y = placePanel(panel: graphTracePanel, at: y)
                
                let n = Int(element)!
                let dotType = theGraph.dotType[n]
                if dotType == "" {
                    graphDotsPopup.selectItem(at: 0)
                } else {
                    graphDotsPopup.selectItem(withTitle: dotType)
                }
                graphDotSizeStepper.integerValue = Int(theGraph.dotSize[n])
                let lineWidth = Int(theGraph.lineWidth[n])
                graphLineSizeStepper.integerValue = lineWidth
                let lineType = theGraph.lineType[n]
                if lineWidth == 0 {
                    graphLinePopup.selectItem(at: 0)
                } else {
                    graphLinePopup.selectItem(at: lineType + 1)
                }
                let interval = theGraph.dotInterval[n]
                graphDotSpacingField.integerValue = interval
                graphDotSpacingStepper.integerValue = interval
                graphTraceNameField.stringValue = theGraph.graphLegend[n]
            }
            
            if ["0","1","2","3","4","5","6","7","8","9"].contains(element) && theGraph.barData != nil {
                y = placePanel(panel: graphHistoBarPanel, at: y)
                let n = Int(element)!
                if theGraph.graphLegend.count < n+1 {
                    graphBarNameField.stringValue = ""
                } else {
                    graphBarNameField.stringValue = theGraph.graphLegend[n]
                }
            }
        }
    }
    
    @IBAction func clickedColorButton(_ sender: Any) {
        colorSender = sender as? NSButton
        self.view.window!.makeFirstResponder(self)
        NSApplication.shared.orderFrontColorPanel(self)
    }
    
    func changeColor(_ sender: NSColorPanel?) {
        if selectedEquation == nil {return}
        if selectedEquation!.graph == nil {return}
        let theGraph = selectedEquation!.graph!
        let element = theGraph.lastClickedElement
        let theColor = sender?.color
        if theColor == nil { return }
        if ["0","1","2","3","4","5","6","7","8","9"].contains(element) {
            let n = Int(element)!
            if colorSender == graphLineColorBtn {
                theGraph.lineColor[n] = theColor!
            } else if colorSender == graphDotColorbtn {
                theGraph.dotColor[n] = theColor!
            } else if colorSender == graphBarColorBtn {
                theGraph.lineColor[n] = theColor!
            }
        } else if colorSender == graphTextColorBtn {
            if element == "title" {
                theGraph.graphColors["maintitle"] = theColor!
            } else if element == "titlex" || element == "titley" {
                theGraph.graphColors["axeslabels"] = theColor!
            } else if element == "labx" || element == "laby" {
                theGraph.graphColors["ticklabels"] = theColor!
            }
        } else if colorSender == graphGridColorBtn {
            theGraph.graphColors["maingrid"] = theColor!
            theGraph.graphColors["subgrid"] = theColor!
        } else if colorSender == graphAxesColorBtn {
            theGraph.graphColors["axes"] = theColor!
        } else if colorSender == graphAxesFillColorBtn {
            theGraph.graphColors["axesfill"] = theColor!
        } else if colorSender == fieldColor1 {
            let n = fieldNumber.integerValue - 1
            theGraph.fieldColors![n].values[0] = theColor!
        } else if colorSender == fieldColor2 {
            let n = fieldNumber.integerValue - 1
            theGraph.fieldColors![n].values[1] = theColor!
        } else if colorSender == fieldColor3 {
            let n = fieldNumber.integerValue - 1
            if theGraph.fieldColors![n].values.count<3 {
                theGraph.fieldColors![n].values.append(theColor!)
            } else {
                theGraph.fieldColors![n].values[2] = theColor!
            }
            if fieldMed.stringValue == "" {
                fieldMed.formatValue( (fieldMax.doubleValue + fieldMin.doubleValue)/2)
                let unitMult = theGraph.fields![n].unit.mult
                theGraph.fieldLimits![n].values = [fieldMin.doubleValue * unitMult,fieldMax.doubleValue * unitMult, fieldMed.doubleValue * unitMult]
            }
        }
        mainCtrl.theEquationView.needsDisplay = true
    }
    
    @IBAction func graphMainChanged(_ sender: Any) {
        if selectedEquation == nil {return}
        if selectedEquation!.graph == nil {return}
        let theGraph = selectedEquation!.graph!
        theGraph.mainTitle = graphTitleField.stringValue
        theGraph.axesFrame = (graphAxesFrameBtn.state == NSControl.StateValue.on)
        theGraph.axesFill = (graphAxesFillBtn.state == NSControl.StateValue.on)
        theGraph.legend = (graphShowLegendBtn.state == NSControl.StateValue.on)
        theGraph.axesWidth = CGFloat(graphAxesWidthStepper.integerValue) / 2
        mainCtrl.theEquationView.needsDisplay = true
        let legPos = legendPositionPopup.indexOfSelectedItem
        theGraph.legendPos = ["RT","RB","B"][legPos]
    }
    
    @IBAction func setAutoTitle(_ sender: Any) {
        if selectedEquation == nil {return}
        if selectedEquation!.graph == nil {return}
        let theGraph = selectedEquation!.graph!
        theGraph.mainTitle = selectedEquation!.stringExp()
        mainCtrl.theEquationView.needsDisplay = true
    }
    
    @IBAction func changedAxisSettings(_ sender: Any) {
        if selectedEquation == nil {return}
        if selectedEquation!.graph == nil {return}
        let theGraph = selectedEquation!.graph!
        var j = 0
        if ["y","laby","titley"].contains(theGraph.lastClickedElement) {j = 1}
        let minS = minAxisField.stringValue
        let maxS = maxAxisField.stringValue
        let mind = Double(minS.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")) ?? Double.nan
        let maxd = Double(maxS.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")) ?? Double.nan

         var k = axisDivsStepper.integerValue
        let unitMult = theGraph.axesUnit![j].mult
        if minS == "" || maxS == "" || mind.isNaN || maxd.isNaN || maxd <= mind {
            // valeur vide dans un champ de limite d'axe => on recalcule des valeurs par défaut
            theGraph.autoLimits(j: j, k: k)
            minAxisField.formatValue(theGraph.axesLim(j).min / unitMult)
            maxAxisField.formatValue(theGraph.axesLim(j).max / unitMult)
        } else if mind != theGraph.axesLim(j).min / unitMult || maxd != theGraph.axesLim(j).max / unitMult {
            // l'utilisateur a introduit de nouvelles valeurs min ou max
            theGraph.setDoubleLims(j, min: mind * unitMult, max: maxd * unitMult)
        } else  {
            // l'utilisateur a changé le stepper principal
            var auto = autoLimAndDivs(x1: mind, x2: maxd, k: k)
            // les boucles servent à trouver la valeur k suivante
            while k > oldGridStepperVal && auto.dx * unitMult == theGraph.axesDivs[j] && k < Int(axisDivsStepper.maxValue) {
                k = k + 1
                auto = autoLimAndDivs(x1: mind, x2: maxd, k: k)
            }
            while k < oldGridStepperVal && auto.dx * unitMult == theGraph.axesDivs[j] && k > Int(axisDivsStepper.minValue) {
                k = k - 1
                auto = autoLimAndDivs(x1: mind, x2: maxd, k: k)
            }
            theGraph.axesDivs[j] = auto.dx * unitMult
            axisDivsStepper.integerValue = k
            axisDivsLabel.integerValue = k
        }
        theGraph.axesSubDivs[j] = axisSubDivsStepper.integerValue
        axisSubDivsLabel.integerValue = axisSubDivsStepper.integerValue
        let pos = axisPositionPopup.indexOfSelectedItem
        if pos == 0 {
            theGraph.axes[j] = false
        } else {
            theGraph.axes[j] = true
            theGraph.axesPos[j] = ["min","max","0"][pos-1]
        }
        theGraph.axesArrows[j] = (graphShowArrowBtn.state == NSControl.StateValue.on)
        
        theGraph.axesTitles[j] = graphAxisNameField.stringValue
        
        theGraph.ticks[j].main = (graphMainTicksBtn.state == NSControl.StateValue.on )
        theGraph.tickLabels[j] = (graphTickLabelsBtn.state == NSControl.StateValue.on)
        
        oldGridStepperVal = axisDivsStepper.integerValue
        if graphMainGridWidthStepper.integerValue == 0 {
            theGraph.grids[j].main = false
        } else {
            theGraph.grids[j].main = true
        }
        if graphSubGridWidthStepper.integerValue == 0 {
            theGraph.grids[j].sub = false
        } else {
            theGraph.grids[j].sub = true
        }
        theGraph.gridsWidths[j].main = CGFloat(graphMainGridWidthStepper.integerValue) / 2
        theGraph.gridsWidths[j].sub = CGFloat(graphSubGridWidthStepper.integerValue) / 2
        
        if autoMinMaxBtn.state == NSControl.StateValue.on {
            theGraph.axesAuto[j] = true
            theGraph.autoLimits(j: j, k: k)
            minAxisField.doubleValue = theGraph.axesLim(j).min
            maxAxisField.doubleValue = theGraph.axesLim(j).max
        } else {
            theGraph.axesAuto[j] = false
        }
        updatePanel()
        mainCtrl.theEquationView.needsDisplay = true
    }
    
    
    
    @IBAction func changeLineAndDot(_ sender: Any) {
        if selectedEquation == nil {return}
        if selectedEquation!.graph == nil {return}
        let theGraph = selectedEquation!.graph!
        let element = theGraph.lastClickedElement
        if !["0","1","2","3","4","5","6","7","8","9"].contains(element) {return}
        let n = Int(element)!
        if graphDotsPopup.indexOfSelectedItem == 0 {
            theGraph.dotType[n] = ""
        } else {
            theGraph.dotType[n] = graphDotsPopup.titleOfSelectedItem!
        }
        theGraph.dotSize[n] = CGFloat(graphDotSizeStepper.integerValue)
        let lineTypeNbr = graphLinePopup.indexOfSelectedItem
        if lineTypeNbr == 0 {
            theGraph.lineWidth[n] = 0
            graphLineSizeStepper.integerValue = 0
        } else {
            theGraph.lineType[n] = lineTypeNbr-1
            if graphLineSizeStepper.integerValue == 0 {
                graphLineSizeStepper.integerValue = 1
            }
        }
        theGraph.lineWidth[n] = CGFloat(graphLineSizeStepper.integerValue) / 2
        if theGraph.lineWidth[n] == 0 {
            theGraph.lineType[n] = 0
            theGraph.lineWidth[n] = 0
            graphLineSizeStepper.integerValue = 0
        }
        var interval = graphDotSpacingField.integerValue
        if interval < 0 { interval = 0}
        theGraph.dotInterval[n] = interval
        graphDotSpacingStepper.integerValue = interval
        
        theGraph.lineColor[n] = theGraph.lineColor[n]
        theGraph.dotColor[n] = theGraph.dotColor[n]

        
        theGraph.graphLegend[n] = graphTraceNameField.stringValue
        mainCtrl.theEquationView.needsDisplay = true
    }
    
    @IBAction func changeDotIntervalStepper(_ sender: Any) {
        let interval = graphDotSpacingStepper.integerValue
        graphDotSpacingField.integerValue = interval
        changeLineAndDot(self)
    }
    
    @IBAction func changedGraphFont(_ sender: Any) {
        if selectedEquation == nil {return}
        if selectedEquation!.graph == nil {return}
        let theGraph = selectedEquation!.graph!
        let element = theGraph.lastClickedElement
        
        let fontFamily = graphFontPopup.titleOfSelectedItem!
        let fontSize = CGFloat(graphFontSizeCombo.integerValue)
        var theFontMask : NSFontTraitMask
        if graphBoldBtn.state == NSControl.StateValue.on {
            theFontMask = NSFontTraitMask.boldFontMask
        } else {
            theFontMask = NSFontTraitMask.unboldFontMask
        }
        if graphItalicBtn.state == NSControl.StateValue.on {
            theFontMask = NSFontTraitMask(rawValue: theFontMask.rawValue | NSFontTraitMask.italicFontMask.rawValue)
        } else {
            theFontMask = NSFontTraitMask(rawValue: theFontMask.rawValue | NSFontTraitMask.unitalicFontMask.rawValue)
        }
        let theFont = NSFontManager.shared.font(withFamily: fontFamily, traits: theFontMask, weight: 5, size: fontSize)
        if theFont == nil { return }
        
        switch element {
        case "x", "y" : theGraph.graphFonts["ticklabels"] = theFont!
        case "title" : theGraph.graphFonts["maintitle"] = theFont!
        default : theGraph.graphFonts["axeslabels"] = theFont!
        }
        mainCtrl.theEquationView.needsDisplay = true
    }
    
    @IBAction func changeBarSpaceStepper(_ sender: NSStepper) {
        let theGraph = selectedEquation!.graph!
        if sender == barSpace2Stepper {
            barSpace2Field.doubleValue = barSpace2Stepper.doubleValue
            theGraph.histoS2 = CGFloat(barSpace2Stepper.doubleValue)/100
        } else {
            barSpace1Field.doubleValue = barSpace1Stepper.doubleValue
            theGraph.histoS1 = CGFloat(barSpace1Stepper.doubleValue)/100
        }
        mainCtrl.theEquationView.needsDisplay = true
    }
    
    
    @IBAction func changedHistoSpaces(_ sender: Any) {
        let theGraph = selectedEquation!.graph!
        theGraph.histoS2 = CGFloat(barSpace2Field.doubleValue)/100
        barSpace2Stepper.doubleValue = barSpace2Field.doubleValue
        if barSpace1Field.isEnabled {
            theGraph.histoS1 = CGFloat(barSpace1Field.doubleValue)/100
            barSpace1Stepper.doubleValue = barSpace1Field.doubleValue
        }
        mainCtrl.theEquationView.needsDisplay = true
    }
    
    @IBAction func changedHistoType(_ sender: Any) {
        let theGraph = selectedEquation!.graph!
        theGraph.histoOrientation = (barHorizontalBtn.state == NSControl.StateValue.on) ? "H" : "V"
        theGraph.histoStacked = (barStackedBtn.state == NSControl.StateValue.on)
        if theGraph.histoOrientation == "V" {
            theGraph.tickLabels = [false,true]
            theGraph.autoLimits(j: 1)
            theGraph.grids = [(false,false),(true,true)]
            theGraph.ticks = [(false,false),(true,true)]
        } else {
            theGraph.tickLabels = [true,false]
            theGraph.autoLimits(j: 0)
            theGraph.grids = [(true,true),(false,false)]
            theGraph.ticks = [(true,true),(false,false)]
        }
        mainCtrl.theEquationView.needsDisplay = true
        updatePanel()
     }
    
    @IBAction func changeHistoName(_ sender: Any) {
        let theGraph = selectedEquation!.graph!
        let element = theGraph.lastClickedElement
        if ["0","1","2","3","4","5","6","7","8","9"].contains(element) {
            let n = Int(element)!
            while theGraph.graphLegend.count <= n+1 {
                theGraph.graphLegend.append("")
            }
            theGraph.graphLegend[n] = graphBarNameField.stringValue
        }
        mainCtrl.theEquationView.needsDisplay = true
    }
    
    @IBAction func changeScalFieldLimits(_ sender: Any) {
        if selectedEquation?.graph == nil { return }
        let theGraph = selectedEquation!.graph!
        let n = (fieldNumber.integerValue > theGraph.fields!.count) ? 0 : fieldNumber.integerValue - 1
        let unitMult = theGraph.fields![n].unit.mult
        if fieldMed.stringValue != "" {
            theGraph.fieldLimits![n].values = [fieldMin.doubleValue * unitMult,fieldMax.doubleValue * unitMult, fieldMed.doubleValue * unitMult]
        } else {
            theGraph.fieldLimits![n].values = [fieldMin.doubleValue * unitMult,fieldMax.doubleValue * unitMult]
        }
        theGraph.fieldNames![n] = fieldName.stringValue
        theGraph.fields![n].unit =  unitsByName[fieldUnitPopup.titleOfSelectedItem ?? ""] ?? Unit()
        theGraph.fieldLimits![n].unit =  unitsByName[fieldUnitPopup.titleOfSelectedItem ?? ""] ?? Unit()
        theGraph.fieldVecSizes![n] = PhysValue(unit: Unit(), type: "double", values: [vecSizeStepper0.doubleValue,vecSizeStepper1.doubleValue])
        mainCtrl.theEquationView.needsDisplay = true
        let c0 = theGraph.fieldColors![n].values[0] as! NSColor
        theGraph.fieldColors![n].values[0] = c0
        let c1 = theGraph.fieldColors![n].values[1] as! NSColor
        theGraph.fieldColors![n].values[1] = c1
        updatePanel()
   }
    
    
}
