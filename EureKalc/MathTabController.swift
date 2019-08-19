//
//  MathTabController.swift
//  EureKalc
//
//  Created by Nico on 19/03/2020.
//  Copyright © 2020 Nico Hirtt. All rights reserved.
//

import Cocoa


// *******************************************************************************
// ***   PANNEAU DE CONTROLE MATH (grilles, couleur, mise en page..)              **
// *******************************************************************************


class MathTabController: NSViewController {
    
    @IBOutlet var equationPanel: NSBox!
    @IBOutlet var recalcBtn: NSButton!
    @IBOutlet var hideResultBtn: NSButton!
    
    @IBOutlet var dupRightBtn: NSButton!
    @IBOutlet var dupDownBtn: NSButton!
    
    @IBOutlet var noConnectorBtn: NSButton!
    @IBOutlet var connector1Btn: NSButton!
    @IBOutlet var connector2Btn: NSButton!
    @IBOutlet var connector3Btn: NSButton!
    @IBOutlet var connector4Btn: NSButton!
    
    @IBOutlet var moveFirstBtn: NSButton!
    @IBOutlet var moveBeforeBtn: NSButton!
    @IBOutlet var moveAfterBtn: NSButton!
    @IBOutlet var moveLastBtn: NSButton!
    @IBOutlet var moveToUpperLine: NSButton!
    
    @IBOutlet var memoriseFormulaBtn: NSButton!
    
    @IBOutlet var transformPanel: NSBox!
    @IBOutlet var simplifyBtn: NSButton!
    @IBOutlet var solveBtn: NSButton!
    @IBOutlet var panelEquationView: EquationView!
    
    
    var theMainControl : MainController?
    var theEquation : HierarchicExp = HierarchicExp()
        
    override var representedObject: Any? {
        didSet {
            //Update the view, if already loaded.
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mainDoc.mathTabCtrl = self
        panelEquationView.isMainView = false
    }
    
    
    func updatePanel() {
        
        layoutTabCtrl.numberPanel.isHidden = true
        equationPanel.isHidden = true
        transformPanel.isHidden = true

        if selectedEquation == nil {
            mainCtrl.currentRules = []
            let panelPage = HierarchicExp(op: "_page", [HierGrid(cols: 1, rows: 0)])
            panelEquationView.thePage = panelPage
            panelEquationView.needsDisplay = true
            return
        }
        theEquation = selectedEquation!
        if theEquation.father == nil { return }
        if theEquation.op == "_edit" { return }

        var y = self.view.frame.height - 6
        if theEquation.isAncestor || theEquation.isBlockOrPage {
            self.view.addSubview(mathTabCtrl.equationPanel)
            y = placePanel(panel: equationPanel, at: y)
            initEquationPanel()
        }
        
        
        if !theEquation.isBlockOrPage && !theEquation.isGraph {
            
            if theEquation.op == "_val" && theEquation.value != nil {
                let value = theEquation.value!
                if value.type == "double" {
                    self.view.addSubview(layoutTabCtrl.numberPanel)
                    y = placePanel(panel: layoutTabCtrl.numberPanel, at: y)
                    layoutTabCtrl.theEquation = theEquation
                    let unitName = value.unit.name
                    let format = theEquation.drawSettingForKey(key: "format") as? String ?? "auto"
                    let digits = theEquation.drawSettingForKey(key: "digits") as? Bool ?? true
                    let precision = theEquation.drawSettingForKey(key: "precision") as? Int ?? defaultNumberPrecision
                    layoutTabCtrl.initNumPanel(unitName: unitName, format: format, digits: digits, precision: precision)
                }
            }
            
            // placement du panneau de transformation d'équation
            let theWidth = transformPanel.frame.width
            transformPanel.setFrameSize(NSSize(width: theWidth, height: y + 6))
            y = placePanel(panel: transformPanel, at: y)

            panelEquationView.isMainView = false
            mainCtrl.currentRules = theEquation.getRulesForExp()
            let theRulesExps = mainCtrl.currentRules.map({ $0.newExp })
            let panelGrid = HierGrid(cols: 1,
                                     rows: mainCtrl.currentRules.count,
                                     arguments: theRulesExps)
            panelEquationView.thePage = HierarchicExp(op: "_page", [panelGrid])
            panelEquationView.needsDisplay = true
                        
            solveBtn.isEnabled = false
            if theEquation.ancestor?.op == "=" {
                solveBtn.isEnabled = true
            }
        }

    }
    
    func initEquationPanel() {
        theEquation = selectedEquation!
        equationPanel.isHidden = false
        moveToUpperLine.isHidden = true

        if !theEquation.isBlockOrPage || !theEquation.isGraph {
            hideResultBtn.isEnabled = true
            var hideResult = false
            if theEquation.drawSettingForKey(key: "hideresult") != nil {
                hideResult = theEquation.drawSettingForKey(key: "hideresult") as! Bool
            }
            setBtnState(hideResultBtn, set: hideResult)
        } else {
            hideResultBtn.isEnabled = false
        }
        
        let connector = theEquation.drawSettingForKey(key: "connector")
        if connector == nil {
            noConnectorBtn.state = NSControl.StateValue.on
        } else {
            for btn in [connector1Btn, connector2Btn, connector3Btn, connector4Btn] {
                if connector as! String == btn!.title {
                    btn!.state = NSControl.StateValue.on
                }
            }
        }
        
        let theFather = theEquation.father!
        if theFather.op == "_grid" {
            let theGrid = theFather as! HierGrid
            moveBeforeBtn.isEnabled = true
            moveFirstBtn.isEnabled = true
            moveLastBtn.isEnabled = true
            moveAfterBtn.isEnabled = true
            if theGrid.rows == 1 {
                moveFirstBtn.title = "⬅︎"
                moveBeforeBtn.title = "←"
                moveAfterBtn.title = "→"
                moveLastBtn.title = "➡︎"
            } else if theGrid.cols == 1 {
                moveFirstBtn.title = "⬆︎"
                moveBeforeBtn.title = "↑"
                moveAfterBtn.title = "↓"
                moveLastBtn.title = "⬇︎"
            } else {
                moveFirstBtn.title = "↑"
                moveBeforeBtn.title = "↓"
                moveAfterBtn.title = "←"
                moveLastBtn.title = "→"
            }
            
            let k = theEquation.argInFather
            if (theGrid.isBaseGrid && k > 0) || (theGrid.islineGrid && k == 0 && theGrid.argInFather > 0) {
                moveToUpperLine.isHidden = false
            }
            
        } else {
            moveBeforeBtn.isEnabled = false
            moveFirstBtn.isEnabled = false
            moveLastBtn.isEnabled = false
            moveAfterBtn.isEnabled = false
        }
        
        memoriseFormulaBtn.isEnabled = false
        if theEquation.op == "=" {
            if theEquation.args[0].op == "_var" {
                memoriseFormulaBtn.isEnabled = true
            }
        }
    }
    
    
    @IBAction func calculateBtn(_ sender: Any) {
        theEquation.calcResult()
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    @IBAction func memoriseFormula(_ sender: Any) {
        theEquation.getVarExp(force: true)
    }
    
    @IBAction func hideResultBtn(_ sender: Any) {
        theEquation.setSetting(key: "hideresult", value: btnState(hideResultBtn))
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    @IBAction func setConnector(_ sender: NSButton) {
        if sender == noConnectorBtn {
            theEquation.removeSetting(key: "connector")
        } else {
            theEquation.setSetting(key: "connector", value: sender.title)
        }
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()

    }
        
    @IBAction func duplicateBtn(_ sender: NSButton) {
        if !theEquation.isAncestor { return }
        let copy = theEquation.copyExp(removeView: false)
        let dir = (sender == dupRightBtn) ? "right" : "down"
        let n = theEquation.argInFather
        if theEquation.father!.op == "_grid" {
            let theGrid = theEquation.father as! HierGrid
            if theGrid.islineGrid {
                if dir == "right" {
                    // on ajoute la copie dans la grille ligne existante derrière l'original
                    theGrid.insertArgs(col: n+1, args: [copy])
                } else {
                    // on insère une grille verticale
                    let newGrid = HierGrid(cols: 1, rows: 2, arguments: [theEquation,copy])
                    theGrid.replaceArg(n: n, newExp: newGrid)
                }
            } else if theGrid.isBaseGrid {
                if dir == "down" {
                    // on ajoute la copie dans la grille colonne existante derrière l'original
                    theGrid.insertArgs(row: n+1, args: [copy])
                } else {
                    // on insère une grille horizontale
                    let newGrid = HierGrid(cols: 2, rows: 1, arguments: [theEquation,copy])
                    theGrid.replaceArg(n: n, newExp: newGrid)
                }
            } else {
                let cr = theGrid.colAndRow(ofArg: n)
                if dir == "right" {
                    // on ajoute une colonne en recopiant cet élément
                    if theGrid.cols <= cr.col+1 {
                        theGrid.addColumn(col: cr.col + 1)
                    }
                    else if !theGrid.argAt(col: cr.col+1, row: cr.row).isEdit {
                        theGrid.addColumn(col: cr.col + 1)
                    }
                    theGrid.replaceArg(n: theGrid.argNumber(col: cr.col + 1, row: cr.row),
                                       newExp: copy)
                } else {
                    // on ajoute un rang en recopiant cet élément
                    if theGrid.rows <= cr.row+1 {
                        theGrid.addRow(row: cr.row + 1)
                    }
                    else if !theGrid.argAt(col: cr.col, row: cr.row+1).isEdit {
                        theGrid.addRow(row: cr.row + 1)
                    }
                    theGrid.replaceArg(n: theGrid.argNumber(col: cr.col, row: cr.row + 1),
                                       newExp: copy)
                }
            }
        }
        mainCtrl.selectEquation(equation: copy)
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()

    }
    
    @IBAction func moveElementBtn(_ sender: Any) {
        let theFather = theEquation.father!
        let k = theEquation.argInFather
        if theFather.op != "_grid" { return }
        let theGrid = theFather as! HierGrid
        
        if (sender as! NSButton) == moveToUpperLine {
            let baseGrid = theGrid.isBaseGrid ? theGrid : (theGrid.father! as! HierGrid)
            let line = theGrid.isBaseGrid ? theEquation.argInFather : theGrid.argInFather
            if baseGrid.args[line-1].op != "_grid" {
                let exp0 = baseGrid.args[line-1].copyExp(removeView: false)
                let newLineGrid = HierGrid(gridLineArgs: [exp0])
                baseGrid.replaceArg(n: line-1, newExp: newLineGrid)
            }
            let upperRow = baseGrid.args[line-1] as! HierGrid

            if theGrid.isBaseGrid && theEquation.op == "_grid" {
                // la sélection est une grille-ligne que l'on déplace entièrement à la fin de la ligne précédente
                for anExp in theEquation.args {
                    upperRow.insertArgs(col: upperRow.nArgs, args: [anExp])
                }
                baseGrid.deleteRow(row: k)
                mainCtrl.selectEquation(equation: upperRow)
            } else {
                // c'est le premier élément d'une grille ligne ou un élémebnt seul : on le déplace vers la ligne précédente
                upperRow.insertArgs(col: upperRow.nArgs, args: [theEquation.copyExp(removeView: false)])
                if theGrid.isBaseGrid {
                    theGrid.deleteRow(row: k)
                } else {
                    theGrid.deleteColumn(col: 0)
                    if theGrid.nArgs == 0 {
                        baseGrid.deleteRow(row: line)
                    }
                }
                mainCtrl.selectEquation(equation: upperRow.args.last!)
            }
        }
        else if theGrid.rows == 1 || theGrid.cols == 1 {
            if (sender as! NSButton) == moveFirstBtn {
                theEquation.moveExp(at: 0, newFather: theFather)
            } else if (sender as! NSButton) == moveLastBtn {
                theEquation.moveExp(at: theFather.nArgs - 1, newFather: theFather)
            } else if (sender as! NSButton) == moveBeforeBtn {
                if k > 0 {
                    theEquation.moveExp(at: k - 1, newFather: theFather)
                }
            } else if (sender as! NSButton) == moveAfterBtn {
                if k < theFather.nArgs - 1 {
                    theEquation.moveExp(at: k + 1, newFather: theFather)
                }
            }
        } else {
            let n = theGrid.cols
            if (sender as! NSButton) == moveFirstBtn {
                if k >= n  {
                    theFather.exchangeMyArgs(n1: k, n2: k-n)
                }
            } else if (sender as! NSButton) == moveBeforeBtn {
                if k + n < theFather.nArgs {
                    theFather.exchangeMyArgs(n1: k, n2: k+n)
                }
            } else if (sender as! NSButton) == moveAfterBtn {
                if k > 0 {
                    theEquation.moveExp(at: k - 1, newFather: theFather)
                }
            } else if (sender as! NSButton) == moveLastBtn {
                if k < theFather.nArgs - 1 {
                    theEquation.moveExp(at: k + 1, newFather: theFather)
                }
            }
        }
        
        mainCtrl.theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()

    }
    
    
    // sélection d'une équation dans la liste des règles appliquables
    func manageMouseDown(event: NSEvent) {
        let vPoint = panelEquationView.getViewPoint(winPoint: event.locationInWindow)
        let theExp = getEquation(atPoint: vPoint, inExp: panelEquationView.thePage)
        if theExp != nil && theExp?.ancestor != nil {
            let clickedExp = theExp!.ancestor!
            let tag = clickedExp.argInFather
            mainCtrl.executeCurrentRuleNumber(tag: tag)
        }
        mainDoc.tryAutoSave()
    }
    
    @IBAction func solveBtnClicked(_ sender: Any) {
        mainCtrl.solveEquation()
        mainDoc.tryAutoSave()
    }
    
    @IBAction func numericCalc(_ sender: Any) {
        mainCtrl.calculateNum()
        mainDoc.tryAutoSave()
    }
    
    @IBAction func applyFormula(_ sender: Any) {
        var theString = (sender as! NSTextField).stringValue
        (sender as! NSTextField).stringValue = ""
        if theString == "" { return }
        if theString == "-" { theString = "-(♘)"}
        else if theString == "/" { theString = "1/(♘)"}
        else if ["+","-","*","/","^"].contains(String(theString.first!)) {
            theString = "(♘)" + theString
        }
        if ["+","-","*","/","^"].contains(String(theString.last!)) {
            theString = theString + "(♘)"
        }
        theString = theString.replacingOccurrences(of: "()", with: "(♘)")
        mainCtrl.applyFormula(theString)
        mainDoc.tryAutoSave()
    }
    
}
