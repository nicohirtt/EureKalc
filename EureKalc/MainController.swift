//
//  ViewController.swift
//  EureKalc
//
//  Created by Nico on 19/08/2019.
//  Copyright © 2019 Nico Hirtt. All rights reserved.
//

import Cocoa

class MainController: NSViewController, NSTextFieldDelegate {
    
    var selectedEquation : HierarchicExp?
    var partialEquation: Bool = false // l'exp sélectionnée est une partie d'exp... TEST
    var multiSelection : [HierarchicExp] = []
    var mouseEquation : HierarchicExp?
    var copiedEquation : HierarchicExp?
    var specialKeys : [Int:String] = [48:"TAB",36:"RET",76:"ENT",124:"RAR",123:"LAR",126:"UAR",125:"DAR",53:"ESC",51:"DEL"]
    //var inputText : String = ""
    
    var myTabsCtrl: TabButtonsController?
    var theTabs: [NSView] = []
    
    var dragStart : NSPoint?
    var currentRules : [(rule: mathRule, newExp: HierarchicExp, pathLevel: Int)] = []
    var page : HierarchicExp?
    var scriptVisible = false
    var consoleVisible = false
    var lastScript : String?
    
    var mouseTimer = Timer()
    var mouseHighlite = true
    var selectionHighlite = true
    var showGrids = false
    
    let pageEditField = NSTextField()
    var timerBoxOpen : Bool = false
    var timerUnit : Unit?
    
    var editionMode = true // faux si on est en train de recalculer une page, un grid, une exp
        
    @IBOutlet var viewIntervalField: NSTextField!
    
    @IBOutlet var windowView: NSView!
    @IBOutlet var editionField: EditionField!
    
    @IBOutlet var mouseHighliteBtn: NSButton!
    @IBOutlet var showGridBtn: NSButton!
    @IBOutlet var zoomResetBtn: NSButton!
    
    @IBOutlet var pagesButtonsView: multipleButtons!
    @IBOutlet var pageCommands: NSBox!
    
    @IBOutlet var theEquationView: EquationView!
    @IBOutlet var contextMenu: NSMenu!
    @IBOutlet var consoleDivider: NSSplitView!
    @IBOutlet var consoleTextView: ScriptEditView!
    @IBOutlet var scriptDivider: NSSplitView!
    @IBOutlet var leftView: NSView!
    @IBOutlet var scriptTextView: ScriptEditView!
    @IBOutlet var scriptsCombo: NSComboBox!
    @IBOutlet var showScriptEditView: NSButton!
    @IBOutlet var hideScriptEditView: NSButton!
    @IBOutlet var runScriptBtn: NSButton!
    
    @IBOutlet var tabButtonsView: NSView!
    @IBOutlet var layoutTab: NSView!
    @IBOutlet var mathTab: NSView!
    @IBOutlet var graphTab: NSView!
    @IBOutlet var simTab: NSView!
    @IBOutlet var varsTab: NSView!
    @IBOutlet var simSpeedFld: NSTextField!
    @IBOutlet var simIterationsLbl: NSTextField!
    @IBOutlet var pauseRunBtn: NSButton!
    @IBOutlet var simSpeedSlider: NSSlider!
    @IBOutlet var timerSettingsBox: NSBox!
    @IBOutlet var deltaTField: NSTextField!
    @IBOutlet var timerUnitPopup: NSPopUpButton!
    @IBOutlet var SimPauseField: NSTextField!
    @IBOutlet var scriptsPanel: NSView!
    @IBOutlet var mainPanel: NSView!
    
    @IBOutlet var consoleView: NSView!
    @IBOutlet var scriptPanelWidthConstraint: NSLayoutConstraint!
    @IBOutlet var clearConsoleBtn: NSButton!
    @IBOutlet var showConsoleBtn: NSButton!
    @IBOutlet var helpCombo: NSComboBox!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        theEquationView.isMainView = true
        mainDoc.mainCtrl = self
        theEquationView.needsDisplay = true
        scriptTextView.setSettings()
        scriptsCombo.removeAllItems()

        editionField.isEditable=true
        editionField.isEnabled=true
        editionField.mainController = self
        editionField.delegate = editionField
        editionField.mainview = theEquationView
      }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
        
    override func viewDidAppear() {
        super.viewDidAppear()
        setViewScale()
        hideScriptEditor()
        let mainWindow = NSApplication.shared.mainWindow
        if mainWindow != nil {
            mainWindow!.makeFirstResponder(theEquationView)
            if mainDoc.wFrame != nil {
                mainWindow?.setFrame(mainDoc.wFrame!, display: true)
            }
        }
        pagesButtonsView.target = self
        pagesButtonsView.action = #selector(self.pageButtonClicked)
        resetPageButtons( mainDoc.currentPage )
        showPage(n: mainDoc.currentPage)
        lastScript = mainDoc.lastScript
        
        if #available(macOS 11.0, *) {
            pauseRunBtn.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
        } else {
            // Fallback on earlier versions
        }
        
        consoleVisible = true
        showHideConsole(self)
        consoleTextView.consoleMode = true
        scriptTextView.isEditable = false
        

        mouseHighlite = mainDoc.mouseHighlite ?? true
        mouseHighliteBtn.state = mouseHighlite ? NSControl.StateValue.on : NSControl.StateValue.off
        
        timerUnitPopup.removeAllItems()
        timerUnitPopup.addItem(withTitle: "Iter.")
        timerUnitPopup.addItems(withTitles: unitsByName["s"]!.similarUnitNames)
        timerUnitPopup.selectItem(at: 0)
        timerUnit=nil

        timerSettingsBox.setFrameSize(NSSize(width: 216, height: 27))
        timerSettingsBox.setFrameOrigin(NSPoint(x: timerSettingsBox.superview!.bounds.width - 216, y: timerSettingsBox.frame.origin.y))
        simIterationsLbl.integerValue = theSim.loop
        pauseRunBtn.state = NSControl.StateValue.off
        if theSim.vars["dt"]!.asDouble! == 0 {
            deltaTField.stringValue = "(real)"
        } else {
            deltaTField.stringValue = theSim.vars["dt"]!.stringExp(units: true)
        }
        SimPauseField.doubleValue = theSim.pause
        if theSim.simSpeed == 0 { theSim.simSpeed = 1 }
        simSpeedFld.doubleValue = theSim.simSpeed
        timerBoxOpen = false
        viewIntervalField.integerValue = theSim.viewInterval

        
        mainDoc.tryAutoSave()
        mainDoc.isSaved = true
        
        if mainDoc.scriptVisible ?? false {
            showScriptEditor()
        } else {
            hideScriptEditor()
        }
        (theEquationView.window! as! myWindow).equationView = theEquationView

        helpCombo.removeAllItems()
        helpCombo.addItem(withObjectValue: "Help")
        for cat in functionsHelp {
            helpCombo.addItem(withObjectValue: cat.catName)
        }
        
    }
    
    
    @IBAction func testPrintInfo(_ sender: Any) {
        Swift.print(NSPrintInfo.shared.leftMargin, NSPrintInfo.shared.topMargin )
    }
    
    @objc func pageButtonClicked(_ sender: Any) {
        let theButton = sender as! NSButton
        let selectedPage = theButton.title
        pagesButtonsView.selectButton(selectedPage)
        showPage(n: thePageNames.firstIndex(of: selectedPage)!)
        mainDoc.tryAutoSave()
       }
    
    
    func resetPageButtons(_ page : Int) {
        pagesButtonsView.resetButtons(titles: thePageNames,
                                      select: page,
                                      maxWidth: theEquationView.frame.width - 300)
        let theWidth = pagesButtonsView.frame.size.width
        pageCommands.frame.origin.x = theWidth - 10
    }
    
    
    // *****************
    // Gestion des menus
    // *****************
    
    @IBAction func copy(_ sender: Any) {
        copySelection()
        mainDoc.tryAutoSave()
    }
    
    @IBAction func cut(_ sender: Any) {
        copySelection()
        deleteSelection()
        mainDoc.tryAutoSave()
    }
    
    @IBAction func paste(_ sender: Any) {
        if selectedEquation == nil {return}
        if copiedEquation == nil { return }
        let ancestor = selectedEquation!.ancestor!
        let currentGrid = ancestor.father! as! HierGrid
        let currentExpInGrid = ancestor.argInFather
        copiedEquation!.replaceExp(selectedEquation!)
        //let newExp = ancestor.simplify()
        let newExp = copiedEquation!.ancestor!.simplify()
        currentGrid.replaceArg(n: currentExpInGrid, newExp: newExp)
        deselectAll()
        theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    @IBAction func delete(_ sender: Any) {
        deleteSelection()
        mainDoc.tryAutoSave()
    }
    
    // insère une grille à la position de la sélection en plaçant le contenu de la sélection dans la première case de la grille
    @objc func insertGrid() {
        if multiSelection.count > 1 {
            let exp1 = multiSelection[0]
            if !exp1.father!.isGrid { return }
            let fatherGrid = exp1.father! as! HierGrid
            if fatherGrid.rows != 1 { return }
            let n = exp1.argInFather
            let theGrid = HierGrid(cols: multiSelection.count, rows: 1)
            for (i,anExp) in multiSelection.enumerated() {
                theGrid.replaceArg(n: i, newExp: anExp.copyExp(removeView: false))
                if i > 0 { anExp.removeFromFather() }
            }
            fatherGrid.replaceArg(n: n, newExp: theGrid)
            fatherGrid.colWidths = Array(fatherGrid.colWidths.prefix(upTo: fatherGrid.nArgs))
            fatherGrid.cols = fatherGrid.nArgs
            theGrid.addRow(row: 1)
            multiSelection = []
            selectedEquation = nil
            
        } else {
            if !selectedEquation!.isAncestor && !selectedEquation!.isCustomGrid {return}
            if selectedEquation == nil {return}
            let n = selectedEquation!.argInFather
            let theGrid = HierGrid(cols: 2, rows: 2)
            theGrid.replaceArg(n: 0, newExp: selectedEquation!.copyExp(removeView: false))
            selectedEquation!.father!.replaceArg(n: n, newExp: theGrid)
            selectEquation(equation: theGrid)
        }
        theEquationView.needsDisplay = true
    }
    
    @objc func insertColumn() {
        if selectedEquation?.father == nil { return }
        if !selectedEquation!.father!.isCustomGrid { return }
        let grid = selectedEquation!.father! as! HierGrid
        let n = selectedEquation!.argInFather
        let col = grid.colAndRow(ofArg: n).col
        grid.addColumn(col: col)
    }

    @objc func insertRow() {
        if selectedEquation?.father == nil { return }
        if !selectedEquation!.father!.isCustomGrid { return }
        let grid = selectedEquation!.father! as! HierGrid
        let n = selectedEquation!.argInFather
        let row = grid.colAndRow(ofArg: n).row
        grid.addRow(row: row)
    }
    
    func copySelection() {
        if selectedEquation == nil {return}
        copiedEquation = selectedEquation!.copyExp(removeView: false)
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(selectedEquation!.stringExp(), forType: .string)
        theEquationView.needsDisplay = true
    }
    
    func duplicateSelection() {
        if selectedEquation == nil {return}
        if !selectedEquation!.isAncestor {return}
        let theGrid = selectedEquation!.father! as! HierGrid
        let n = selectedEquation!.argInFather
        let theCopy = selectedEquation!.copyExp(removeView: false)
        if theGrid.isBaseGrid {
            let lineGrid = HierGrid.init(gridLineArgs: [selectedEquation!,theCopy])
            theGrid.replaceArg(n: n, newExp: lineGrid)
        } else if theGrid.islineGrid {
            theGrid.insertArgs(col: n+1, args: [theCopy])
        } else {
            return
        }
        selectEquation(equation: theCopy)
        reRunExp(self)
        theEquationView.needsDisplay = true
    }
        
    func deleteSelection() {
        // Suppression d'une équation (et des blocs vides où elle se trouve)
        // on réduit aussi les blocs d'un seul argument à cet élément
        if selectedEquation == nil {return}
        if selectedEquation!.father == nil { return }
        if selectedEquation!.father!.op == "_page" {
            // on ne peut pas supprimer la grille de base !
            clearPage()
            return
        }
        if !selectedEquation!.isDeletable { return }
        if selectedEquation!.father!.op != "_grid" { return } // inutile car déjà testé dans isDeletable

        selectedEquation!.deleteSubviews()
        let n = selectedEquation!.argInFather
        let theGrid = selectedEquation!.father as! HierGrid
        let cr = theGrid.colAndRow(ofArg: n)
        
        // Si la grille-père ne contient qu'un unique élément
        if theGrid.rows == 1 && theGrid.cols == 1 {
            if theGrid.isBaseGrid {
                // un unique élément de la grille de base ?
                theGrid.resetToEmpty()
                editNewExp(thePage.args[0].args[0])
            } else if theGrid.islineGrid {
                // l'unique élement d'une grille-ligne ?
                if theGrid.father!.nArgs == 1 {
                    clearPage()
                } else {
                    let lineNumber = theGrid.argInFather
                    theGrid.removeFromFather()
                    if (page!.args.count > lineNumber) { selectEquation(equation: page!.args[lineNumber])}
                }
            } else {
                // une grille ordinaire ne contenant qu'un élément ?
                selectedEquation = theGrid
                deleteSelection()
            }
            
        // si c'est l'unique élément non vide d'une ligne ou colonne on supprime cette ligne/colonne
        // sinon on supprime l'élement et on le remplace par une expression vide
        } else {
            var testrow = true
            (0..<theGrid.cols).forEach({ col in
                if col != cr.col {
                    let arg = theGrid.args[theGrid.argNumber(col: col, row: cr.row)]
                    if arg.op != "_edit" { testrow = false }
                }
            })
            var testcol = true
            (0..<theGrid.rows).forEach({ row in
                if row != cr.row {
                    let arg = theGrid.args[theGrid.argNumber(col: cr.col, row: row)]
                    if arg.op != "_edit" { testcol = false }
                }
            })
            
            if testrow {
                if theGrid.rows > 1 {
                    theGrid.deleteRow(row: cr.row)
                    if n > 0 && theGrid.cols == 1 { selectEquation(equation: theGrid.args[n-1])}
                    else { deselectAll() }
                } else {
                    theGrid.resetToEmpty()
                    selectEquation(equation: theGrid.args[0])
                }
            } else if testcol {
                if theGrid.cols > 1 {
                    theGrid.deleteColumn(col: cr.col)
                    if n > 0 && theGrid.rows == 1 { selectEquation(equation: theGrid.args[n-1])}
                    else { deselectAll() }
                } else {
                    theGrid.resetToEmpty()
                    selectEquation(equation: theGrid.args[0])
                }
            } else {
                theGrid.replaceArg(n: theGrid.argNumber(col: cr.col, row: cr.row), newExp: HierarchicExp(withText: " "))
                selectEquation(equation: theGrid.args[n])
            }
            if theGrid.cols == 1 && theGrid.rows == 1 && theGrid.father!.op != "_page" {
                // Une grille ordinaire réduite à un seul élément ? Pas question !
                let gridFather = theGrid.father!
                let uniqueArg = theGrid.args[0]
                let n = theGrid.argInFather
                uniqueArg.father = gridFather
                gridFather.args[n] = uniqueArg
                selectEquation(equation: uniqueArg)
            }
            
        }
    }
    
    
    
    // ********************
    // Gestion de la souris
    // ********************
    
    // redimensionnement des contrôles
    func manageMouseDragged(event: NSEvent) {
        let vPoint = theEquationView.getViewPoint(winPoint: event.locationInWindow)
        if dragStart == nil { return }
        let origin = selectedEquation!.origin
        let originalSize = selectedEquation!.theRect!.size
        let theSize = NSSize(width: vPoint.x - origin.x, height: origin.y - vPoint.y)
        let dW = theSize.width - originalSize.width
        let dH = theSize.height - originalSize.height
        if selectedEquation!.isGraph {
            let theGraph = selectedEquation?.graph
            if theGraph == nil { return }
            theGraph!.frameRect = NSRect(origin: origin, size: theSize)
        } else if selectedEquation!.view != nil {
            var viewSize = selectedEquation!.view!.frame.size
            switch selectedEquation!.op {
            case "table" :
                viewSize.width = max(viewSize.width + dW,50)
                viewSize.height =  max(viewSize.height + dH,50)
                (selectedEquation!.view! as! ekTableScrollView).resize(viewSize)
            case "slider", "hslider", "checkbox", "button", "popup" :
                viewSize.width = max(viewSize.width + dW,30)
                selectedEquation!.view!.frame.size = viewSize
            case "vslider" :
                viewSize.height =  max(viewSize.height + dH,30)
                selectedEquation!.view!.frame.size = viewSize
            case "cslider" :
                let cSize = max(viewSize.width + dW, viewSize.height + dH, 30)
                selectedEquation!.view!.frame.size = NSSize(width: cSize, height: cSize)
            default :
                viewSize.width = max(viewSize.width + dW,50)
                viewSize.height =  max(viewSize.height + dH,50)
                selectedEquation!.view!.frame.size = viewSize
            }
        }
        theEquationView.needsDisplay = true
    }
    
    func manageMouseMoved(event: NSEvent) {
        let vPoint = theEquationView.getViewPoint(winPoint: event.locationInWindow)
        var theExp = getEquation(atPoint: vPoint, inExp: thePages[mainDoc.currentPage])
        // si on survole le carré de redimensionnement...
        if selectedEquation != nil {
            if selectedEquation!.isScalable {
                if selectedEquation!.resizingDotRect!.contains(vPoint) {
                    theExp = selectedEquation!
                }
            }
        }
        if theExp != nil {
            if mouseEquation != theExp! || !mouseTimer.isValid {
                mouseEquation = theExp!
                mouseTimer.invalidate()
                mouseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { _ in self.stopTimer() })

                theEquationView.needsDisplay = true
            }
        } else {
            if mouseEquation != nil {
                mouseEquation = nil
                theEquationView.needsDisplay = true
            }
        }
    }
    
    
    @IBAction func changeMousHighlite(_ sender: Any) {
        mouseHighlite = ((sender as! NSButton).state == NSControl.StateValue.on)
        mainDoc.tryAutoSave()
    }
    
     @IBAction func changeShowGrid(_ sender: Any) {
        showGrids = !showGrids
         theEquationView.needsDisplay = true
    }

    
    @IBAction func zoomIn(_ sender: Any) {
        theMainDoc!.viewScale = theMainDoc!.viewScale * 0.9
        setViewScale()
    }
    
    @IBAction func resetZoom(_ sender: Any) {
        theMainDoc!.viewScale = 1.0
        setViewScale()    }
    
    @IBAction func zoomOut(_ sender: Any) {
        theMainDoc!.viewScale = theMainDoc!.viewScale / 0.9
        setViewScale()
    }
    
    func setViewScale() {
        let theScale = theMainDoc!.viewScale
        let frameSize = theEquationView.frame
        let boundSize = NSSize(width: frameSize.width*theScale, height: frameSize.height*theScale)
        theEquationView.bounds.size = boundSize
        zoomResetBtn.title = "\(Int(100.5/(theScale))) %"
        theEquationView.needsDisplay = true
    }
    
    func stopTimer() {
        mouseTimer.invalidate()
        theEquationView.needsDisplay = true
    }
    

    // traitement du clic
    func manageMouseDown(event: NSEvent) {
        let nClick = event.clickCount
        let vPoint = theEquationView.getViewPoint(winPoint: event.locationInWindow)
        var clickedEquation : HierarchicExp
        dragStart = nil
        
        // Si on était en train d'éditer une NSTextView, on enregistre l'attrib.string
        if selectedEquation != nil {
            if selectedEquation!.editing {
                selectedEquation!.editing = false
            }
            if selectedEquation!.op == "text" {
                //selectedEquation!.atString = (selectedEquation!.view as! NSTextView).attributedString()
            }
        }

        
        // 1 ou 2 clicks en dehors de toute équation => désélectionner (1) ou insérer (2)
        if mouseEquation == nil {
            if nClick == 2  {
                clickedEquation = thePages[mainDoc.currentPage]
            } else {
                deselectAll()
                return
            }
        } else {
            clickedEquation = mouseEquation!
        }
        
        // extension de la sélection au père avec la touche "option"
        // idem avec plusieurs clics rapides sur une équation (pas un bloc !)

        if event.modifierFlags.contains(.option) && selectedEquation != nil {
            if selectedEquation!.contains(clickedEquation) && selectedEquation!.father != nil {
                clickedEquation = selectedEquation!.father!
            }
        } else if !clickedEquation.isBlockOrPage && nClick > 1 {
            for _ in 2...nClick {
                if clickedEquation.father != nil {
                    clickedEquation = clickedEquation.father!
                }
            }
        }
        
        // Affichage d'un MENU CONTEXTUEL pour la sélection avec la touche control...
        if event.modifierFlags.contains(.control) && selectedEquation != nil {
            if clickedEquation.father == nil { return }
            if selectedEquation!.contains(clickedEquation) && selectedEquation!.father != nil  {
                contextMenu.removeAllItems()
                contextMenu.addItem(withTitle: "Simplify", action: #selector(simplifyExp), keyEquivalent: "")
                // Menu "isoler"
                if clickedEquation.ancestor?.op == "=" {
                    contextMenu.addItem(withTitle: "Isolate", action: #selector(solveEquation), keyEquivalent: "")
                }
                // menu : ajouter une grille
                if clickedEquation.isAncestor {
                    contextMenu.addItem(withTitle: "Insert in a new grid", action: #selector(insertGrid), keyEquivalent: "")
                }
                // menu :
                if clickedEquation.father!.isCustomGrid {
                    contextMenu.addItem(withTitle: "Insert column before this", action: #selector(insertColumn), keyEquivalent: "")
                    contextMenu.addItem(withTitle: "Insert row before this", action: #selector(insertRow), keyEquivalent: "")
                }
                // menu des règles appliquables
                if currentRules.count > 0 {
                    let rulesItem = NSMenuItem(title: "Apply rule", action: nil, keyEquivalent: "")
                    contextMenu.addItem(rulesItem)
                    let rulesSubMenu = NSMenu()
                    var tag = 0
                    for aRule in currentRules {
                        let newItem = NSMenuItem(title: aRule.rule.labelForLanguage(lang: userLanguage, def: true),
                                                 action: #selector(executeRule), keyEquivalent: "")
                        newItem.tag = tag
                        tag = tag + 1
                        rulesSubMenu.addItem(newItem)
                    }
                    contextMenu.setSubmenu(rulesSubMenu, for: rulesItem)
                }
                // Menu remplacement d'une variable par son expression mémorisée
                if clickedEquation.op == "_var" {
                    let varName = clickedEquation.string!
                    if theVarExps[varName] != nil {
                        let varExpItem = NSMenuItem(title: "Replace with : " + theVarExps[varName]!.stringExp(), action: #selector(replaceExpression), keyEquivalent: "")
                        contextMenu.addItem(varExpItem)
                    }
                }
                // Menu des unités, format, précision...
                if clickedEquation.op == "_val" {
                    let unitsItem = NSMenuItem(title: "Unit", action: nil, keyEquivalent: "")
                    contextMenu.addItem(unitsItem)
                    let unitsSubMenu = NSMenu()
                    var tag = 0
                    let unitsList = (clickedEquation.value!.unit).similarUnitNames
                    for aUnit in unitsList {
                        let newItem = NSMenuItem(title: aUnit, action: #selector(changeUnit), keyEquivalent: "")
                        newItem.tag = tag
                        tag = tag + 1
                        unitsSubMenu.addItem(newItem)
                    }
                    contextMenu.setSubmenu(unitsSubMenu, for: unitsItem)
                }
  
                contextMenu.addItem(withTitle: "Copy to PDF", action: #selector(copyToPDF), keyEquivalent: "")
                contextMenu.addItem(withTitle: "Copy to PNG", action: #selector(copyToPng), keyEquivalent: "")
                contextMenu.addItem(withTitle: "Copy to LaTex", action: #selector(copyToLatex), keyEquivalent: "")

                NSMenu.popUpContextMenu(contextMenu, with: event, for: theEquationView)

                return
            }
   
        }
        
        // clic simple sur l'équation qui était sélectionnée => On désélectionne ou on édite (text, graphe...)
        if selectedEquation != nil && nClick == 1 {
            
            if selectedEquation!.isScalable {
                if selectedEquation!.resizingDotRect!.contains(vPoint) {
                    dragStart = vPoint
                    return
                }
            }
            if selectedEquation == clickedEquation && (clickedEquation.op == "text") {
                let view = selectedEquation!.view!
                view.isHidden = false
                let expOrigin = clickedEquation.draw!.origin
                let size = clickedEquation.draw!.size
                let viewOrigin = NSPoint(x: expOrigin.x, y: expOrigin.y - size.height)
                view.frame = NSRect(origin: viewOrigin , size: size)
                NSApplication.shared.mainWindow!.makeFirstResponder(view)
                selectedEquation!.editing = true
                return
            }
            if selectedEquation == clickedEquation && !selectedEquation!.isGraph  {
                deselectAll()
                return
            }
        }
        
        // double clic sur un emplacement vide => on place le inputExp
        if clickedEquation.isBlockOrPage && nClick == 2 {
            var theGrid : HierGrid
            if clickedEquation.op == "_page" { theGrid = clickedEquation.args[0] as! HierGrid }
            else { theGrid = clickedEquation as! HierGrid}
            var position = 0

            if theGrid.islineGrid {
                theGrid.args.forEach({ arg in
                    if arg.origin.x < vPoint.x { position = position + 1 }
                })
                if position == theGrid.args.count && position > 0 {
                    let previousExp = theGrid.args[position - 1]
                    if previousExp.isEdit {
                        selectEquation(equation: previousExp)
                        theEquationView.needsDisplay = true
                        return
                    }
                }
                setInputExp(theGrid: theGrid, position: position)
            } else if theGrid.isBaseGrid {
                for arg in theGrid.args {
                    if arg.origin.y - arg.size.height < vPoint.y {
                        if arg.op == "_grid" {
                            if arg.origin.x + arg.size.width < vPoint.x {
                                // on insère à la fin de la ligne
                                position = arg.nArgs
                                if position > 0 {
                                    let previousExp = arg.args[position - 1]
                                    if previousExp.isEdit {
                                        selectEquation(equation: previousExp)
                                        theEquationView.needsDisplay = true
                                        return
                                    }
                                }
                            } else {
                                // on insère au début
                                position = 0
                            }
                            setInputExp(theGrid: arg as! HierGrid, position: position)
                        } else if arg.op == "_edit" {
                            selectEquation(equation: arg)
                        } else {
                            // on crée un hBlock et on insère...
                            let n = arg.argInFather
                            let lineGrid = HierGrid(gridLineArgs: [arg,HierarchicExp(withText: " ")])
                            theGrid.replaceArg(n: n, newExp: lineGrid)
                            selectEquation(equation: lineGrid.args[1])
                            //setInputExp(theGrid: hGrid, position: position)
                        }
                        theEquationView.needsDisplay = true
                        return
                    }
                }
                // on n'a pas trouvé -> donc on insère en-dessous
                position = theGrid.nArgs
                setInputExp(theGrid: theGrid, position: position)
            }
            theEquationView.needsDisplay = true
            return
            
        }
            
        // Affichage des réglages d'un graphe
        if clickedEquation.isGraph && clickedEquation.graph != nil {
            let graph = clickedEquation.graph!
            let element = graph.clickedElement(mouse: vPoint)
            graph.lastClickedElement = element
        }
        
        // extension de la sélection si au sein du même grid
        if event.modifierFlags.contains(.shift) && selectedEquation != nil && multiSelection.count == 0 {
            if selectedEquation!.isAncestor && clickedEquation.isAncestor {
                if selectedEquation!.father == clickedEquation.father {
                    let theGrid = selectedEquation!.father!
                    var n1 = selectedEquation!.argInFather
                    var n2 = clickedEquation.argInFather
                    if n2 < n1 { (n1,n2) = (n2,n1) }
                    for n in n1...n2 {
                        multiSelection.append(theGrid.args[n])
                    }
                    selectedEquation = nil
                    return
                }
            }
        }
        
        // clic sur une équation complète ou partielle => on sélectionne !
        multiSelection = []
        selectEquation(equation: clickedEquation)
        theEquationView.needsDisplay = true
        if clickedEquation.father?.result == clickedEquation {
            editionField!.isEditable = false
            editionField!.isEnabled = false
            theEquationView.window!.makeFirstResponder(theEquationView)
        }
    }
    
    
    // sélectionne une équation complète ou partielle
    func selectEquation(equation: HierarchicExp) {
        // Si on était en train d'éditer et qu'on n'a pas confirmé, on supprime l'expression éditée
        selectedEquation = equation
        theEquationView.window!.makeFirstResponder(theEquationView)
        // préparation des menus
        let delegate = (NSApplication.shared.delegate) as! AppDelegate
        delegate.insertGridItem.isEnabled = false
        delegate.addColumn.isEnabled = false
        delegate.addRow.isEnabled = false
        //
        if selectedEquation!.father == nil {
            deselectAll()
            return
        }
        var inputText : String = ""
        if equation.op == "_edit" {
            editNewExp(equation)
            activeTab = "layout"
            tabsCtrl.updateActivetab()
            return
        } else {
            inputText = equation.stringExp()
        }
        if selectedEquation!.isGraph {
            tabsCtrl.activateGraphTab(self)
        } else {
            if activeTab == "graph" { activeTab = "layout" }
            tabsCtrl.updateActivetab()
        }
        // Gestion des menus
        if selectedEquation!.isAncestor {
            partialEquation = false
            delegate.insertGridItem.isEnabled = true
            if selectedEquation!.father!.isCustomGrid {
                delegate.addColumn.isEnabled = true
                delegate.addRow.isEnabled = true
            }
        } else {
            partialEquation = true
        }
        if equation.isBlockOrPage {
            partialEquation = false
            editionField.showDisabled(string: inputText)
        } else {
            editionField.showDisabled(string: inputText)
            currentRules = selectedEquation!.getRulesForExp()
        }
 
        theEquationView.needsDisplay = true
    }
    
    // sélection vide et suppression de l'expression d'édition si nécessaire
    func deselectAll() {
        multiSelection = []
        selectedEquation = nil
        theEquationView.needsDisplay = true
        editionField.emptyDisabled()
        tabsCtrl.updateActivetab()
    }

    /*
    func editedTextDidChange() {
        if selectedEquation != nil {
            if selectedEquation!.isAncestor {
                selectedEquation!.string = editionField.stringValue
                theEquationView.needsDisplay = true
            }
        }
    }
     */

    func decsepToDot(_ t: String) -> String {
        if decimalSep == "." { return t}
        let r = t.replacingOccurrences(of: ",", with: ".")
        return r.replacingOccurrences(of: ";", with: ",")
    }
    
    func dotToDecsep(_ t: String) -> String {
        if decimalSep == "." { return t}
        let r = t.replacingOccurrences(of: ",", with: ";")
        return r.replacingOccurrences(of: ".", with: decimalSep)
    }
    
    func manageKeyEventInWindow(event: NSEvent) {
        print (event.keyCode)
    }
    
    // réponse générale à une touche enfoncée via le editionField
    func manageKeyEvent(event: NSEvent) {
        if selectedEquation == nil { return }
        let modFlags = event.modifierFlags
        let theKey = Int(event.keyCode)
        let sKey = (specialKeys.keys.contains(theKey)) ? specialKeys[theKey]! : ""
        if sKey == "" {
            // on tape quelque chose à la place de la sélection
            editionField.stringValue = event.characters ?? ""
            editionField.continueEdit()
            return
        } else if sKey == "RET" || sKey == "ENT" || sKey == "TAB" {
            // on a tapé une touche spéciale
            confirmEntry(withKey: sKey, modFlags: modFlags)
        } else if sKey == "ESC" {
            // escape désélectionne
            deselectAll()
        } else if sKey == "DEL" {
            deleteSelection()
            mainDoc.tryAutoSave()
        } else if sKey == "RAR" || sKey == "LAR" || sKey == "UAR" || sKey == "DAR" {
            // flèches
            // Si c'est une hypermatrice 3dim -> On change de slice
            if selectedEquation!.op == "_val" {
                let matrix = selectedEquation!.value!
                if matrix.dim.count == 3 {
                    var hypermatsetting = selectedEquation!.draw!.settings!["hypermatview"] as! [Int]
                    var dim = hypermatsetting[0]
                    var index = hypermatsetting[1]
                    if sKey == "UAR" { index = (index == matrix.dim[dim] - 1) ? 0 : index + 1 }
                    if sKey == "DAR" { index = (index == 0) ? matrix.dim[dim] - 1 : index - 1 }
                    if sKey == "LAR" {
                        dim = (dim == 0) ? matrix.dim.count - 1 : dim - 1
                        index = 0
                    }
                    if sKey == "RAR" {
                        dim = (dim == matrix.dim.count - 1) ? 0 : dim + 1
                        index = 0
                    }
                    hypermatsetting = [dim,index]
                    selectedEquation!.setSetting(key: "hypermatview", value: hypermatsetting)
                    theEquationView.needsDisplay = true
                    return
                }
            }
            confirmEntry(withKey: sKey, modFlags: modFlags)
            if selectedEquation?.father == nil { return }
            let f = selectedEquation!.father!
            let n = selectedEquation!.argInFather
            // entrée dans un grid avec la touche option (alt)
            if sKey == "DAR" && selectedEquation!.op == "_grid" && modFlags.contains(.shift)  {
                selectEquation(equation: selectedEquation!.args[0])
            } else if sKey == "UAR" && selectedEquation!.op == "_grid" && modFlags.contains(.shift)  {
                selectEquation(equation: f)
            }
            else if selectedEquation!.isAncestor || selectedEquation!.isBlock {
                if f.op == "_page" {
                    if sKey == "UAR" || sKey == "LAR" { deselectAll() }
                    else if selectedEquation!.nArgs > 0 && (sKey == "DAR" || sKey == "RAR") {
                        selectEquation(equation: selectedEquation!.args[0])
                    }
                } else if f.op == "_grid" {
                    let theGrid = f as! HierGrid
                    let cr = theGrid.colAndRow(ofArg: n)
                    if sKey == "RAR" && cr.col < theGrid.cols - 1 { selectEquation(equation: f.args[n+1]) }
                    else if sKey == "LAR" && cr.col > 0 { selectEquation(equation: f.args[n-1]) }
                    else if sKey == "UAR" && cr.row > 0 { selectEquation(equation: f.args[n - theGrid.cols])}
                    else if sKey == "DAR" && cr.row < theGrid.rows - 1 { selectEquation(equation: f.args[n + theGrid.cols])}
                    else { selectEquation(equation: f) }
                }
            } else {
                if sKey == "RAR" && n < f.nArgs - 1 { selectEquation(equation: f.args[n+1]) }
                else if sKey == "LAR" && n > 0 { selectEquation(equation: f.args[n-1]) }
                else if sKey == "UAR" { selectEquation(equation: f) }
                else if sKey == "DAR" && selectedEquation!.nArgs > 0 {selectEquation(equation: selectedEquation!.args[0]) }
            }
                        
            theEquationView.needsDisplay = true
        }
    }
    
    
    // On a confirmé une entrée de chaine avec la touche "withKey"
    func confirmEntry(withKey: String, modFlags : NSEvent.ModifierFlags = NSEvent.ModifierFlags()) {
        
        let stringExp = decsepToDot(editionField.stringValue)
        if selectedEquation == nil { return }
        let theGraph = selectedEquation?.graph
        let theViewSize = selectedEquation?.viewSize
        let theView = selectedEquation?.view
        var hierExp = selectedEquation!.isGrid ? selectedEquation! : algebToHierarchic(stringExp) // l'expression tapée codée
        
        if selectedEquation!.father == nil { return } // On ne peut pas modifier un résultat (exp qui n'est pas un argument)
        
        if selectedEquation!.isAncestor || selectedEquation!.isBlock {
            // on a confirmé une équation complète avec Tab, Ent ou Ret
            if hierExp.isEmptyString || hierExp.op == "" {
                hierExp = HierarchicExp(withText: " ")
            } else if !selectedEquation!.isGrid {
                // on ajoute le résultat si nécessaire
                selectedEquation!.deleteSubviews()
                let theSettings = selectedEquation!.result?.drawSettings
                let theUnit = selectedEquation!.result?.value?.unit
                if hierExp.op == selectedEquation!.op {  hierExp.graph = theGraph }
                if theView != nil && theViewSize != nil && hierExp.op == selectedEquation!.op {
                    hierExp.view = theView
                    hierExp.viewSize = theViewSize
                }
                hierExp.editing = true
                let result = hierExp.executeHierarchicScript()
                if !result.isError {
                    if hierExp.op != "_grid" && hierExp.op != "_page" {
                        hierExp = hierExp.simplify()
                        hierExp.view = theView
                        hierExp.viewSize = theViewSize
                    }
                }
                // Mémorisation de l'expression si du type var =
                hierExp.getVarExp()
                
                if result.values.count > 0 {
                    // On crée une expression contenant le calcul et son résultat, en récupérant éventuellement les formats
                    if theUnit != nil {
                        if result.unit.isIdentical(unit: theUnit!) {
                            result.unit = theUnit!
                        }
                    }
                    hierExp.setResult(HierarchicExp(withPhysVal: result))
                    hierExp.result!.draw = HierDraw()
                    hierExp.result!.draw!.settings = theSettings
                    if (hierExp.op == "=" || hierExp.op == "_val") {
                        hierExp.setSetting(key: "hideresult", value: true)
                    }
                    if result.isError {
                        hierExp.setSetting(key: "hideresult", value: false)
                    }
                }
            }
            
            let currentBlock = selectedEquation!.father!
            let currentExpInBlock = selectedEquation!.argInFather
            
            // En fonction de la situation, on ajoute des éléments de bloc ou de nouveaux blocs
            if currentBlock.op != "_grid" {
                return
            }
            
            let theGrid = currentBlock as! HierGrid
            let cr = theGrid.colAndRow(ofArg: currentExpInBlock)
            if !selectedEquation!.isGrid {
                theGrid.replaceArg(n: currentExpInBlock, newExp: hierExp)
            }
            if withKey == "TAB" {
                if theGrid.isBaseGrid {
                    // tab dans le grid principal crée un grid-ligne et nouvel emplacement derrière
                    let newGrid = HierGrid(gridLineArgs: [hierExp,HierarchicExp(withText: " ")])
                    theGrid.replaceArg(n: currentExpInBlock, newExp: newGrid)
                    editNewExp(newGrid.args[1])
                    //editState = 1
                } else if modFlags.contains(.shift) {
                    // Tab majuscule ajoute une colonne à gauche
                    theGrid.addColumn(col: cr.col)
                    editNewExp(theGrid.argAt(col:cr.col,row:cr.row))
                } else {
                    // tab (autres cas) ajoute une colonne au grid à droite ou à gauche (maj-tab)
                    theGrid.addColumn(col: cr.col + 1)
                    editNewExp(theGrid.argAt(col:cr.col + 1,row:cr.row))
                }
                
            } else if withKey == "RET" {
                if theGrid.islineGrid {
                    if modFlags.contains(.shift) {
                        // ret-majuscule dans une grid-ligne crée une grid-colonne
                        let n = hierExp.argInFather
                        hierExp.removeFromFather()
                        let newexp = HierarchicExp(withText: " ")
                        let colGrid = HierGrid(cols: 1, rows: 2,arguments: [hierExp,newexp])
                        colGrid.moveExp(at: n, newFather: theGrid)
                        editNewExp(newexp)
                    } else {
                        // ret dans une grid-ligne crée une nouvelle grid-ligne en dessous (et coupure éventuelle)
                        let newExps = theGrid.splitLineGrid(at: currentExpInBlock)
                        let baseGrid = theGrid.father!
                        let gridPlace = theGrid.argInFather
                        baseGrid.replaceArg(n: gridPlace, newExp: newExps[0]!)
                        (baseGrid as! HierGrid).insertArgs(row: gridPlace+1, args: [newExps[1]!])
                        if newExps[1]!.isEdit { editNewExp(newExps[1]!) }
                        else { deselectAll() }
                    }
                   
                    
                } else {
                    // autres retours (ou alt-retour) ajoute une ligne dans la même grid
                    if modFlags.contains(.shift) {
                        theGrid.addRow(row: cr.row)
                        editNewExp(theGrid.args[theGrid.argNumber(col:cr.col,row:cr.row)])
                    } else {
                        theGrid.addRow(row: cr.row + 1)
                        editNewExp(theGrid.args[theGrid.argNumber(col:cr.col,row:cr.row + 1)])
                    }
                }
                
            } else {
                // on a fait un "ENTER"
                selectEquation(equation: hierExp)
                //deselectAll()
            }
                            
            
        } else {
            // on a modifié un morceau d'équation
            if selectedEquation?.ancestor == nil { return }
            let ancestor = selectedEquation!.ancestor!
            hierExp.replaceExp(selectedEquation!)
            let result = ancestor.executeHierarchicScript()
            //if !result.isError {
            let simplified = ancestor.simplify()
            simplified.replaceExp(ancestor)
            simplified.getVarExp()
            if result.values.count > 0 {
                let theSettings = simplified.result?.drawSettings
                simplified.setResult(HierarchicExp(withPhysVal: result))
                simplified.result!.draw = HierDraw()
                simplified.result!.draw!.settings = theSettings
            } else {
                ancestor.result = nil
            }
            deselectAll()
        }
        theEquationView.needsDisplay = true
        mainDoc.tryAutoSave()
    }
    
    // Place l'hierexp de type "_edit" qui représente l'entrée en cours
    func setInputExp(theGrid: HierGrid, position: Int) {
        var input = HierarchicExp(withText: " ")
        if theGrid.isBaseGrid {
            if position >= theGrid.nArgs && theGrid.args[theGrid.nArgs-1].isEdit {
                input = theGrid.args[theGrid.nArgs-1]
            } else {
                theGrid.insertArgs(row: position, args: [input])
            }
        } else  if theGrid.islineGrid {
            theGrid.insertArgs(col: position, args: [input])
        } else {
            return
        }
        editNewExp(input)
    }
    
    
    func editNewExp(_ theExp: HierarchicExp) {
        selectedEquation = theExp
        partialEquation = false
        editionField.showDisabled(string: "")
        theEquationView.needsDisplay = true
    }
      
    // Appelé par le tab d'édition quand l'utilisateur change le réglage de fonte ???
    func fontChanged(auto: Bool, font: NSFont?, textColor: NSColor?) {
        
    }
    
    // Divers
    
    @objc func copyToPDF() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([NSPasteboard.PasteboardType.pdf], owner: nil)
        var theRect = theEquationView.frame
        if selectedEquation != nil { theRect = selectedEquation!.draw!.rect }
        selectionHighlite = false
        let memoriseMouseHighlite = mouseHighlite
        mouseHighlite = false
        theEquationView.needsDisplay = true
        theEquationView.writePDF(inside: theRect, to: pasteboard)
        selectionHighlite = true
        mouseHighlite = memoriseMouseHighlite
    }
    
    @objc func copyToPng() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([NSPasteboard.PasteboardType.pdf], owner: nil)
        var theRect = theEquationView.frame
        if selectedEquation != nil { theRect = selectedEquation!.draw!.rect }
        selectionHighlite = false
        let memoriseMouseHighlite = mouseHighlite
        mouseHighlite = false
        theEquationView.needsDisplay = true
        let imgData = theEquationView.bitmapImageRepForCachingDisplay(in: theRect)
        if imgData != nil {
            imgData!.size = theRect.size
            theEquationView.cacheDisplay(in: theRect, to: imgData!)
            let pngData = imgData!.representation(using: .png, properties: [:])
            pasteboard.setData(pngData!, forType: NSPasteboard.PasteboardType.png)
        }
        selectionHighlite = true
        mouseHighlite = memoriseMouseHighlite
    }
    
    @objc func copyToLatex() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        let theLatexString = selectedEquation?.toLatex() ?? ""
        pasteboard.setString(theLatexString, forType: NSPasteboard.PasteboardType.string)
        theEquationView.needsDisplay = true
    }
    
    @objc func changeUnit(sender : NSMenuItem) {
        if mouseEquation?.op != "_val" { return }
        let units = (mouseEquation!.value!.unit).unitsOfSameType()
        let selectedUnit = units[sender.tag]
        mouseEquation!.value?.unit = selectedUnit
        theEquationView.needsDisplay = true
    }
    
    @objc func replaceExpression(sender : NSMenuItem) {
        if mouseEquation?.op != "_var" { return }
        let varName = mouseEquation!.string!
        let theExp = theVarExps[varName]!.copyExp()
        theExp.replaceExp(mouseEquation!)
        theEquationView.needsDisplay = true
    }
    
    // ***********
    // Simulations
    // ***********
    
    
    @IBAction func changeTimerBoxState(_ sender: Any) {
        timerBoxOpen = !(timerBoxOpen)
        if timerBoxOpen {
            timerSettingsBox.setFrameSize(NSSize(width: 216, height: 82))
        } else {
            timerSettingsBox.setFrameSize(NSSize(width: 216, height: 27))
        }
    }
    
    @IBAction func resetSimulation(_ sender: Any) {
        mainCtrl.simIterationsLbl.integerValue = 0
        theSim.stopSim()
        pauseRunBtn.state = NSControl.StateValue.off
        theSim.initiate()
        mainDoc.tryAutoSave()
    }
    
    @IBAction func pauseRunSimulation(_ sender: Any) {
        if theSim.running {
            theSim.stopSim()
            pauseRunBtn.state = NSControl.StateValue.off
        } else {
            theSim.pause=SimPauseField.doubleValue
            theSim.startSim()
            pauseRunBtn.state = NSControl.StateValue.on
        }
        mainDoc.tryAutoSave()
    }
    
    @IBAction func changeSimSpeed(_ sender: NSSlider) {
        theSim.simSpeed = pow(10.0,(0.5-simSpeedSlider.doubleValue*3.5))
        mainDoc.tryAutoSave()
        simSpeedFld.stringValue = "\(Int(theSim.simSpeed*1000)) ms"
        if theSim.running {
            theSim.resetSimSpeed()
        }
    }
    
    @IBAction func stepSimulation(_ sender: Any) {
        if theSim.running { return }
        theSim.stepSim()
        SimPauseField.stringValue = ""
        mainDoc.tryAutoSave()
    }
    
    @IBAction func changetimeUnit(_ sender: Any) {
        if timerUnitPopup.indexOfSelectedItem == 0 {
            timerUnit = nil
            simIterationsLbl.integerValue = theSim.loop
        } else {
            timerUnit =  unitsByName[timerUnitPopup.titleOfSelectedItem!]!
            simIterationsLbl.integerValue = Int(theSim.t/timerUnit!.mult)
        }
        theSim.ctrlTimeUnit = timerUnit
    }
    
    // change le temps de simulation (temps simulé par itération)
    @IBAction func changeDeltat(_ sender: Any) {
        let hExp = algebToHierarchic(deltaTField.stringValue)
        var dt = PhysValue(doubleVal: 0)
        if hExp.op != "_val" {
            deltaTField.stringValue = "(real)"
            theSim.vars["dt"] = PhysValue(doubleVal: 0)
        } else {
            if hExp.value!.asDouble == nil {
                deltaTField.stringValue = "(real)"
            } else if hExp.value!.asDouble! <= 0 {
                deltaTField.stringValue = "(real)"
            } else if hExp.value!.unit == Unit() {
                deltaTField.stringValue = deltaTField.stringValue + "[s]"
                dt = PhysValue(numExp: deltaTField.stringValue)
            } else if !hExp.value!.unit.isIdentical(unit: unitsByName["s"]!) {
                deltaTField.stringValue = "(real)"
            } else {
                dt = hExp.value!
                deltaTField.stringValue = dt.stringExp(units: true)
            }
            theSim.vars["dt"] = dt
        }
        if SimPauseField.doubleValue < 0 {
            SimPauseField.doubleValue = 0.0
        }
        theSim.pause = SimPauseField.doubleValue
        theSim.vars["t"] = PhysValue(numExp: "0[s]")
    }
    
    @IBAction func changeViewInterval(_ sender: Any) {
        let vInt = viewIntervalField.integerValue
        if vInt<2 { theSim.viewInterval = 1}
        else { theSim.viewInterval = vInt}
        viewIntervalField.integerValue = theSim.viewInterval
    }
    
    
    // ***************************************
    // Gestion des pages et boutons y relatifs
    // ***************************************
    
    // exécution de l'expression sélectionnée ou d'une page complète
    @IBAction func reRunExp(_ sender: Any) {
        if selectedEquation != nil {
            selectedEquation!.calcResult()
            selectedEquation!.getVarExp()
        } else {
            let result = page!.executeHierarchicScript()
            if result.type == "error" { printToConsole(result.asString!)}
            page!.resetFathers()
        }
        theEquationView.needsDisplay = true
        mainDoc.tryAutoSave() // on enregistre tout !
    }
    

    // Affichage de la page n
    func showPage(n: Int) {
        for aView in theEquationView.subviews {
            aView.removeFromSuperview()
        }
        mainDoc.currentPage = n
        page = thePages[n]
        theEquationView.thePage = page!
        let width = max(page!.draw!.size.width + 20,theEquationView.superview!.bounds.width)
        let height = max(page!.draw!.size.height + 30,theEquationView.superview!.bounds.height)
        theEquationView.frame.size = NSSize(width: width, height: height)
        theEquationView.superview!.scroll(NSPoint(x: 0, y: theEquationView.frame.height))
        
        selectedEquation = nil
        tabsCtrl.activateLayoutTab(self)

        let vBlock = page!.args[0] as! HierGrid
        if vBlock.nArgs == 0 {
            setInputExp(theGrid: (page!.args)[0] as! HierGrid, position: 0)
        } else if vBlock.args[0].isEdit {
            editNewExp(vBlock.args[0])
        } else {
            deselectAll()
        }
        pagesButtonsView.selectButton(n)
        theEquationView.needsDisplay = true
    }
    
    func calcAndShowPage(name: String) -> String {
        selectedEquation = nil
        if thePages[mainDoc.currentPage].name! == name {
            reRunExp(self)
        } else {
            let pageNbr = thePageNames.firstIndex(of: name)
            if pageNbr == nil { return("Error : unknown page " + name) }
            let page = thePages[pageNbr!]
            let result = page.executeHierarchicScript()
            if result.type == "error" { return(result.values[0] as! String)}
            page.resetFathers()
            showPage(n: pageNbr!)
        }
        return ""
    }

    func calcAndShowPage(nbr: Int) -> String {
        selectedEquation = nil
        if mainDoc.currentPage == nbr {
            reRunExp(self)
            return ""
        }
        if nbr < 0 || nbr >= thePages.count { return "wrong page number" }
        let page = thePages[nbr]
        let result = page.executeHierarchicScript()
        if result.type == "error" { return(result.values[0] as! String)}
        page.resetFathers()
        showPage(n: nbr)
        return ""
    }
    
    // Effacement de la page active
    func clearPage() {
        let pageNbr = mainDoc.currentPage
        let name = thePages[pageNbr].name!
        thePages[pageNbr] = HierarchicExp(pageNamed: name)
        showPage(n: pageNbr)
    }
    
    // Clic sur le bouton "ajout d'une page"
    @IBAction func addPage(_ sender: Any) {
        var pageNbr = thePages.count + 1
        var name = "Page \(pageNbr)"
        while thePageNames.contains(name) {
            pageNbr = pageNbr + 1
            name = "Page \(pageNbr)"
        }
        thePages.append(HierarchicExp(pageNamed: name))
        resetPageButtons(thePages.count - 1)
        showPage(n: thePages.count - 1)
        mainDoc.tryAutoSave() // on enregistre tout !
    }
    
    // Clic sur le bouton suppression d'une page
    @IBAction func deletePage(_ sender: Any) {
        if thePages.count > 1 {
            let pageNbr = mainDoc.currentPage
            mainDoc.thePages.remove(at: pageNbr)
            let newPageNbr = pageNbr == 0 ? 0 : pageNbr - 1
            resetPageButtons(newPageNbr)
            showPage(n: newPageNbr)
        }
        mainDoc.tryAutoSave() // on enregistre avant tout !
    }
    
    // **********
    // CONSOLE
    // **********
    
    // clic sur le bouton d'affichage ou masquage de l'éditeur de scripts
    @IBAction func hideOrShowScriptEditor(_ sender: Any) {
        if scriptVisible {
            hideScriptEditor()
        } else {
            showScriptEditor()
        }
    }
    func hideScriptEditor() {
        scriptsPanel.isHidden = true
        scriptVisible = false
          hideScriptEditView.isHidden = true
        showScriptEditView.isHidden = false
        theEquationView.needsDisplay = true
    }
    
    func showScriptEditor() {
        scriptsPanel.isHidden = false
        scriptVisible = true
        scriptsPopupReset()
        hideScriptEditView.isHidden = false
        showScriptEditView.isHidden = true
        if lastScript != nil {showScript(scriptName: lastScript!)}
    }

    // Affichage du script 'scripName' dans l'éditeur de scripts
    func showScript(scriptName : String) {
        scriptsPopupReset()
        runScriptBtn.isEnabled = true
        if (scriptsCombo.objectValues as! [String]).contains(scriptName) {
            scriptsCombo.selectItem(withObjectValue: scriptName)
            let scriptViewController = ScriptViewController()
            scriptViewController.scriptEditView = scriptTextView
            scriptViewController.scriptName = scriptName
            scriptTextView.myController = scriptViewController
            scriptViewController.showScript(nil)
            lastScript = scriptName // pour l'enregistrmeent du document !
        }
    }
    
    @IBAction func scriptInWindow(_ sender: Any) {
        let scriptName = scriptsCombo.objectValueOfSelectedItem as? String
        if scriptName != nil {
            let scriptWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "ScriptWindowController") as! NSWindowController
            scriptWindowController.showWindow(self)
            let scriptWindow = scriptWindowController.window
            let scriptViewController = scriptWindow!.contentViewController as! ScriptViewController
            scriptWindow?.title = scriptName!
            scriptViewController.scriptName = scriptName!
            scriptViewController.showScript(nil)
        }
    }
    
    
    //Recalcul des items du menu popup des scripts
    func scriptsPopupReset() {
        scriptsCombo.removeAllItems()
        for (k,aName) in worldScriptNames.enumerated() {
            if theSim.scripts.keys.contains(aName) {
                scriptsCombo.addItem(withObjectValue: "World." + aName)
            }
            if k==1 {
                for aPop in theSim.pops.keys {
                    for i in 0...2 {
                        if theSim.pops[aPop]!.scripts.keys.contains(popScriptNames[i]) {
                            scriptsCombo.addItem(withObjectValue: aPop + "." + popScriptNames[i])
                        }
                    }
                }
            }
            if k==3 {
                for aPop in theSim.pops.keys {
                    for i in 3...6 {
                        if theSim.pops[aPop]!.scripts.keys.contains(popScriptNames[i]) {
                            scriptsCombo.addItem(withObjectValue: aPop + "." + popScriptNames[i])
                        }
                    }
                }
            }
        }
        scriptsCombo.addItem(withObjectValue: "-")
        for aScript in theScripts.keys {
            scriptsCombo.addItem(withObjectValue: aScript)
        }
    }
    
    // Sélection d'un script dans le combo ScriptsCombo
    @IBAction func selectScript(_ sender: Any) {
        if scriptsCombo.indexOfSelectedItem == -1 && lastScript != nil {
            // On a changé le nom du script
            let newName = scriptsCombo.stringValue
            if newName != "" && theScripts[lastScript!] != nil {
                theScripts[newName] = theScripts[lastScript!]
                theScripts[lastScript!] = nil
                showScript(scriptName: newName)
                theMainDoc!.varsTabCtrl!.theOutlineView.reloadData()
            }
        } else {
            let scriptName = scriptsCombo.objectValueOfSelectedItem as? String
            if scriptName != nil {
                showScript(scriptName: scriptName!)
            }
        }
    }
    
    
    // exécute le script affiché dans le scriptEditor
    @IBAction func runScript(_ sender: Any) {
        let theController = scriptTextView.myController
        if theController == nil { return }
        let hierExp = theController!.saveScript()
        theMainDoc!.currentScript = theController!.scriptName
        let test = hierExp.executeHierarchicScript()
        if test.type == "error" {
            mainCtrl.printToConsole("error: [" + test.asString!
                                        + "] in script: [" + theController!.scriptName
                                        + "] at line: [" + theMainDoc!.currentScriptLine + "]") 
        }
        mainDoc.tryAutoSave() // on enregistre tout !
    }

    
    // Ajoute un script utilisateur
    @IBAction func addScript(_ sender: Any) {
        var name = "New script"
        var c = 2
        while theScripts[name] != nil {
            name = "New script \(c)"
            c = c + 1
        }
        theScripts[name] = HierarchicExp()
        showScript(scriptName: name)
        mainDoc.tryAutoSave() // on enregistre tout !
    }
    
    @IBAction func deleteScript(_ sender: Any) {
        let fullName = scriptsCombo.objectValueOfSelectedItem as? String
        if fullName == nil { return }
        if fullName == "-" || fullName == "" { return }
        if fullName!.contains(".") {
            let splitted = fullName!.split(separator: ".")
            if splitted.count != 2 { return }
            let popName = String(splitted[0])
            let scriptName = String(splitted[1])
            if popName == "World" {
                theSim.scripts[scriptName] = nil
            } else {
                if !theSim.pops.keys.contains(popName) { return }
                theSim.pops[popName]!.scripts[scriptName] = nil
            }
        } else {
            theScripts[fullName!] = nil
        }
        scriptTextView.textContainer?.textView?.string = ""
        scriptsCombo.stringValue = ""
        scriptsPopupReset()
        mainDoc.tryAutoSave() // on enregistre tout !
    }
    
    
    // Output console
  
    @IBAction func showHideConsole(_ sender: Any) {        
        if consoleVisible {
            consoleDivider.setPosition(scriptsPanel.frame.height-27, ofDividerAt: 0)
            clearConsoleBtn.isHidden = true
            consoleVisible = false
        } else {
            consoleDivider.setPosition(scriptsPanel.frame.height * 2/3, ofDividerAt: 0)
            clearConsoleBtn.isHidden = false
            consoleVisible = true
        }
    }
    
    @IBAction func clearConsole(_ sender: Any) {
        consoleTextView.string = ""
    }
    
    func printToConsole(_ text : String) {
        showScriptEditor()
        if !consoleVisible { showHideConsole(self) }
        consoleTextView.string = consoleTextView.string + "\n" + text
        consoleTextView.scrollToEndOfDocument(self)
    }
    
    
    @IBAction func showHelp(_ sender: NSComboBox) {
        consoleTextView.string = ""
        if !scriptVisible { hideOrShowScriptEditor(self)}
        if !consoleVisible { showHideConsole(self) }
        if helpCombo.indexOfSelectedItem == -1 {
            let toFind = helpCombo.stringValue
            for (i,cat) in functionsHelp.enumerated() {
                for (j,f) in cat.functions.enumerated() {
                    let fName = f.funcName
                    if fName.contains(toFind) {
                        consoleTextView.textStorage!.append(getFuncHelp(cat: i, f: j))
                    }
                }
            }
            return
        }
        let catName = helpCombo.stringValue
        for (i,cat) in functionsHelp.enumerated() {
            if cat.catName == catName {
                consoleTextView.textStorage!.append(getFuncHelp(cat: i, f: nil))
                return
            }
        }
        consoleTextView.textStorage!.append(getFuncHelp(cat: nil, f: nil))
    }
    
    func getFuncHelp(cat: Int?, f: Int?) -> NSAttributedString {
        let help = NSMutableAttributedString()
        if cat != nil && f != nil {
            // affiche un élément
            let category = functionsHelp[cat!]
            let function = category.functions[f!]
            for arg in function.definition {
                help.append(arg)
                help.append(NSAttributedString(string: "\n"))
            }
            help.append(NSAttributedString(string: "\n"))
             
        } else if cat != nil {
            // affiche une catégorie
            let category = functionsHelp[cat!]
            for fc in 0..<category.functions.count {
                help.append(getFuncHelp(cat: cat!, f: fc))
            }

        } else if cat == nil && f == nil {
            // affiche tout
            for (j,c) in functionsHelp.enumerated() {
                help.append(NSMutableAttributedString(string: c.catName + "\n\n", attributes: [NSAttributedString.Key.foregroundColor:NSColor.black]))
                help.append(getFuncHelp(cat: j, f: nil))
            }
        }
        return help
    }
    
    
    
    // ******************************
    // Exécution des règles de calcul
    // ******************************
    
    @objc func executeRule(sender : NSMenuItem) {
        executeCurrentRuleNumber(tag: sender.tag)
        mainDoc.tryAutoSave()
    }
    
    func executeCurrentRuleNumber(tag: Int) {
        let newExp = currentRules[tag].newExp
        let level = currentRules[tag].pathLevel
        if selectedEquation == nil { return }
        if selectedEquation!.ancestor == nil { return }
        let drawSettings = selectedEquation!.ancestor!.draw
        newExp.replaceExp(selectedEquation!.nthFather(level))
        let simplified = newExp.ancestor!.simplify()
        simplified.draw = drawSettings
        simplified.replaceExp(newExp.ancestor!)
        selectEquation(equation: simplified)
        selectedEquation!.calcResult()
        theEquationView.needsDisplay = true
    }
    
    @objc func simplifyExp(sender: NSMenuItem) {
        if selectedEquation == nil { return }
        if selectedEquation!.ancestor == nil { return }
        let drawSettings = selectedEquation!.ancestor!.draw
        let simplified = selectedEquation!.ancestor!.simplify()
        simplified.draw = drawSettings
        simplified.replaceExp(selectedEquation!.ancestor!)
        selectEquation(equation: simplified)
        selectedEquation!.calcResult()
        theEquationView.needsDisplay = true
        mainDoc.tryAutoSave() // on enregistre tout !
    }

    @objc func solveEquation() {
        mainDoc.tryAutoSave() // on enregistre avant tout !
        if selectedEquation == nil { return }
        if selectedEquation!.isAncestor { return }
        if selectedEquation!.ancestor == nil { return }
        if selectedEquation!.ancestor!.op != "=" { return }
        let drawSettings = selectedEquation!.ancestor!.draw
        let newExp = selectedEquation!.isolateExp()
        if newExp == nil { return }
        newExp!.replaceExp(selectedEquation!.ancestor!)
        let simplified = newExp!.ancestor!.simplify()
        simplified.draw = drawSettings
        simplified.replaceExp(newExp!.ancestor!)
        mainCtrl.selectEquation(equation: simplified)
        selectedEquation!.calcResult()
    }
    
    func calculateNum() {
        if selectedEquation == nil { return }
        if selectedEquation!.ancestor == nil { return }
        let drawSettings = selectedEquation!.draw
        let simplified = selectedEquation!.calculateNum().simplify()
        simplified.draw = drawSettings
        simplified.replaceExp(selectedEquation!)
        selectEquation(equation: simplified)
        selectedEquation!.ancestor!.calcResult()
        theEquationView.needsDisplay = true
    }
    
    func applyFormula(_ formula : String) {
        if selectedEquation == nil { return }
        if selectedEquation!.ancestor == nil { return }
        let theExp = algebToHierarchic(formula)
        // ici un test de validité !!
        let drawSettings = selectedEquation!.draw
        var simplified : HierarchicExp
        if ["==","=","≤","≥","<",">","≠"].contains(selectedEquation!.op) {
            simplified = HierarchicExp(withOp: selectedEquation!.op)
            simplified.addArg(theExp.replaceVarWithExp(v: "♘", exp: selectedEquation!.args[0]).simplify())
            simplified.addArg(theExp.replaceVarWithExp(v: "♘", exp: selectedEquation!.args[1]).simplify())
        } else {
            simplified = theExp.replaceVarWithExp(v: "♘", exp: selectedEquation!.copyExp()).simplify()
        }
        simplified.draw = drawSettings
        simplified.replaceExp(selectedEquation!)
        selectEquation(equation: simplified)
        selectedEquation!.ancestor!.calcResult()
        theEquationView.needsDisplay = true
    }
    
    // procédure appelée lors de l'action de l'utilisateur sur un contrôle osx
    @objc func controlActivated(sender: NSControl) {
        // le script à exécuter a été stocké dans le .value de l'expression
        let theExp = mainDoc.mySubViews[sender]
        if theExp == nil {
            printToConsole("erreur dans le contrôle cliqué ?")
            return
        }
        if sender is NSSlider {
            let varName = theExp!.getArg(name: "var", n: 0)!.string!
            if theVariables[varName] == nil {
                theVariables[varName] = theExp!.getArg(name: "min", n: 1)!.value
            }
            theVariables[varName]!.values[0] = (sender as! NSSlider).doubleValue
            if theExp!.result == nil {
                theExp!.setResult(HierarchicExp(withPhysVal: theVariables[varName]!))
            } else {
                theExp!.result!.value = theVariables[varName]!
            }
            theEquationView.needsDisplay=true
            if theExp!.value != nil { _ = theExp!.value!.execute() }
        } else if sender is NSPopUpButton {
            let variable = theExp!.getArg(name: "var", n: 0)?.string ?? ""
            let index = theExp!.getArg(name: "index", n: 3)?.value?.asBool ?? false
            if index {
                theVariables[variable] = PhysValue(intVal: (sender as! NSPopUpButton).indexOfSelectedItem)
            } else {
                theVariables[variable] = PhysValue(string: (sender as! NSPopUpButton).titleOfSelectedItem!)
            }
            if theExp!.value != nil { _ = theExp!.value!.execute() }

        } else if sender is NSButton {
            if theExp!.op == "checkbox" {
                let variable = theExp!.args[0].string!
                theVariables[variable] = PhysValue(boolVal: btnState(sender as! NSButton))
            }
            if theExp!.value != nil { _ = theExp!.value!.execute() }
        } else if sender is NSStepper {
            let varName = theExp!.getArg(name: "var", n: 0)!.string!
            theVariables[varName]!.values[0] = (sender as! NSStepper).doubleValue
            if theExp!.result == nil {
                theExp!.setResult(HierarchicExp(withPhysVal: theVariables[varName]!))
            } else {
                theExp!.result!.value = theVariables[varName]!
            }
            theEquationView.needsDisplay=true
            if theExp!.value != nil { _ = theExp!.value!.execute() }
        } else if sender is NSTextField {
            let varName = theExp!.getArg(name: "var", n: 0)!.string!
            let theVal = sender.doubleValue
            if theVariables[varName] != nil {
                let mult = theVariables[varName]!.unit.mult
                theVariables[varName]?.values = [theVal*mult]
            } else {
                theVariables[varName] = PhysValue(doubleVal: theVal)
            }
            if theExp!.value != nil { _ = theExp!.value!.execute() }
        }
        mainDoc.tryAutoSave() // on enregistre tout !
    }

}

extension HierarchicExp {
    
    // vérifie si une exp nécessite l'affichage d'un résultat
    var needsResult : Bool {
        if op == "_val" {return false}
        if op == "," || op == ":" {
            for arg in args { if arg.needsResult { return true } }
            return false
        }
        return true
    }
    
    // Mémorisation éventuelle d'une expression du type var = exp
    func getVarExp(force: Bool = false) {
        if op != "=" { return }
        if nArgs != 2 { return }
        if args[0].op != "_var" { return }
        let varName = args[0].string!
        if theVarExps[varName] == nil || force {
            theVarExps[varName] = args[1]
        }
    }
}
