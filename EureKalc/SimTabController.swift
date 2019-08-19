//
//  SimTabController.swift
//  EureKalc
//
//  Created by Nico on 28/03/2020.
//  Copyright © 2020 Nico Hirtt. All rights reserved.
//

import Cocoa


class SimTabController: NSViewController {

    @IBOutlet var worldDimsPopup: NSPopUpButton!
    @IBOutlet var popCombo: NSComboBox!
    @IBOutlet var dimPopup: NSPopUpButton!
    @IBOutlet var worldMinSizeField: NSTextField!
    @IBOutlet var worldMaxSizeField: NSTextField!
    @IBOutlet var deletePopBtn: NSButton!
    @IBOutlet var mecaPopup: NSPopUpButton!
    @IBOutlet var neighboursGridField: NSTextField!
    @IBOutlet var leftBorderPopup: NSPopUpButton!
    @IBOutlet var rightBorderPopup: NSPopUpButton!

    @IBOutlet var borderEnergy: NSSlider!
    @IBOutlet var borderEnergyLabel: NSTextField!
    @IBOutlet var popsubBox: NSBox!
    
    @IBOutlet var ws1: NSButton!
    @IBOutlet var ws2: NSButton!
    @IBOutlet var ws3: NSButton!
    @IBOutlet var ws4: NSButton!
    @IBOutlet var ws5: NSButton!
    
    @IBOutlet var worldBox: NSBox!
    @IBOutlet var popBox: NSBox!

    @IBOutlet var vs1: NSButton!
    @IBOutlet var vs2: NSButton!
    @IBOutlet var vs3: NSButton!
    @IBOutlet var vs4: NSButton!
    @IBOutlet var vs5: NSButton!
    @IBOutlet var vs6: NSButton!
    @IBOutlet var vs7: NSButton!
    
    var popNames : [String] = []
    var selectedPop : String = ""

    var wsButtons : [NSButton] = []
    var vsButtons : [NSButton] = []
  

    override func viewDidLoad() {
        super.viewDidLoad()
        var y = self.view.frame.height - 29
        y = placePanel(panel: worldBox, at: y)
        y = placePanel(panel: popBox, at: y)
        wsButtons = [ws1,ws2,ws3,ws4,ws5]
        vsButtons = [vs1,vs2,vs3,vs4,vs5,vs6,vs7]

        worldTabSettings()
        worldDimsPopup.selectItem(at: theSim.dim)
        resetPopCombo(pop: selectedPop)
        mainDoc.simTabCtrl = self
        popsubBox.isHidden = true
    }
    
    func worldTabSettings() {

        worldMinSizeField.isEnabled = false
        worldMaxSizeField.isEnabled = false
        worldMinSizeField.stringValue = ""
        worldMaxSizeField.stringValue = ""
        leftBorderPopup.isEnabled = false
        rightBorderPopup.isEnabled = false
        borderEnergy.isEnabled = false
        borderEnergyLabel.stringValue = ""

        resetWorldScriptButtons()
        
        if selectedPop != "" {
            if !theSim.pops.keys.contains(selectedPop) { selectedPop = "" }
        } else {
            if theSim.pops.count > 0 { selectedPop = Array(theSim.pops.keys)[0] }
        }
        resetPopCombo(pop: selectedPop)
        
        let dims = theSim.dim
        borderEnergy.isEnabled = false
        
        if dims == 0 {
            dimPopup.removeAllItems()
            dimPopup.isEnabled = false
            dimPopup.select(nil)
            return
        }
        if dims > 0 {
            dimPopup.isEnabled = true
            worldMinSizeField.isEnabled = true
            worldMaxSizeField.isEnabled = true
            let nItems = dimPopup.numberOfItems
            if dims == 1 && nItems != 1 {
                dimPopup.removeAllItems()
                dimPopup.addItem(withTitle: "x")
                dimPopup.selectItem(at: 0)
            } else if dims > 1 && nItems != dims+1 {
                dimPopup.removeAllItems()
                dimPopup.addItems(withTitles: Array(["All","x","y","z"].prefix(upTo: dims+1)))
                dimPopup.selectItem(at: 0)
            }
            var selectedDim = dimPopup.indexOfSelectedItem-1

            if selectedDim <= -1  {
                // toutes coordonnées égales à x
                if dims > 1 {
                    for i in 1...dims-1 {
                        theSim.min[i] = theSim.min[0]
                        theSim.max[i] = theSim.max[0]
                        theSim.leftBorder[i] = theSim.leftBorder[0]
                        theSim.rightBorder[i] = theSim.rightBorder[0]
                    }
                }
            }
            if selectedDim > dims-1 {
                selectedDim = dims-1
                dimPopup.selectItem(at: dims)
            }
            if selectedDim == -1 { selectedDim = 0 } // afficher "x" si "all"
            if selectedDim > -1 {
                worldMinSizeField.stringValue = theSim.vars["min"]!.physValn(n: selectedDim).stringExp(units: true)
                worldMaxSizeField.stringValue = theSim.vars["max"]!.physValn(n: selectedDim).stringExp(units: true)
                let left = theSim.leftBorder[selectedDim]
                let right = theSim.rightBorder[selectedDim]
                if (theSim.min[selectedDim]) > -(Double.infinity) {
                    leftBorderPopup.isEnabled = true
                    leftBorderPopup.selectItem(at: ["cycle":0,"bounce":1,"stop":2,"delete":3][left]!)
                }
                if (theSim.max[selectedDim]) < (Double.infinity) {
                    rightBorderPopup.isEnabled = true
                    rightBorderPopup.selectItem(at: ["cycle":0,"bounce":1,"stop":2,"delete":3][right]!)
                }
                if left == "bounce" || right == "bounce" {
                    borderEnergy.isEnabled = true
                    if theSim.vars["borderEnergy"] == nil {
                        theSim.vars["borderEnergy"] = PhysValue(doubleVal: 100.0)
                    }
                    let energy = Int(theSim.vars["borderEnergy"]!.asDouble!)
                    borderEnergyLabel.stringValue = "E=\(energy)%"
                    borderEnergy.integerValue = energy
                }
            }
        }

    }
    
    func resetWorldScriptButtons() {
        for (i,aScript) in worldScriptNames.enumerated() {
            if theSim.scripts[aScript] != nil {
                wsButtons[i].state = NSControl.StateValue.on
            } else {
                wsButtons[i].state = NSControl.StateValue.off
            }
        }
    }
    
    @IBAction func chooseDimensions(_ sender: Any) {
        // remise à zero de toutes les variables de dimension
        let dims = Int(worldDimsPopup.titleOfSelectedItem!)!
        theSim.dim = dims
        if dims > 0 {
            theSim.vars["min"] = PhysValue(numExp: "-∞[m]", dim: [dims])
            theSim.vars["max"] = PhysValue(numExp: "∞[m]", dim: [dims])
            theSim.leftBorder = Array(repeating: "Delete", count: dims)
            theSim.rightBorder = Array(repeating: "Delete", count: dims)
            dimPopup.isEnabled = true
            dimPopup.selectItem(at: 0)
        }
        worldTabSettings()
        chooseDim(self)
    }
    
    
    @IBAction func chooseDim(_ sender: Any) {
        worldTabSettings()
    }
    
 
    
    @IBAction func changeWorldSize(_ sender: Any) {
        let selectedDim = dimPopup.indexOfSelectedItem-1
        let dims = theSim.dim
        if worldMinSizeField.stringValue == "" { worldMinSizeField.doubleValue = -(Double.infinity) }
        if worldMaxSizeField.stringValue == "" { worldMaxSizeField.doubleValue = Double.infinity }
        if leftBorderPopup.selectedItem == nil { leftBorderPopup.selectItem(at: 0) }
        if rightBorderPopup.selectedItem == nil { rightBorderPopup.selectItem(at: 0) }
        let left = ["cycle","bounce","stop","delete"][leftBorderPopup.indexOfSelectedItem]
        let right = ["cycle","bounce","stop","delete"][rightBorderPopup.indexOfSelectedItem]
        if left == "bounce" || right == "bounce" {
            borderEnergy.isEnabled = true
            if theSim.vars["borderEnergy"] == nil {
                theSim.vars["borderEnergy"] = PhysValue(doubleVal: 100.0)
            }
            let energy = Int(theSim.vars["borderEnergy"]!.asDouble!)
            borderEnergyLabel.stringValue = "E=\(energy)%"
            borderEnergy.integerValue = energy
        } else {
            borderEnergy.isEnabled = false
            borderEnergyLabel.stringValue = ""
        }

        if worldMinSizeField.stringValue == "" { worldMinSizeField.stringValue = "-∞[m]"}
        let vMin = PhysValue(numExp: worldMinSizeField.stringValue)
        if vMin.unit.isNilUnit() { vMin.unit = Unit(unitExp: "m")}
        if !vMin.unit.isIdentical(unit: Unit(unitExp: "m")) {
            worldMinSizeField.stringValue
            = theSim.vars["min"]!.physValn(n: selectedDim).stringExp(units: true)
        }
         
        if worldMaxSizeField.stringValue == "" { worldMaxSizeField.stringValue = "∞[m]"}
        let vMax = PhysValue(numExp: worldMaxSizeField.stringValue)
        if vMax.unit.isNilUnit() { vMax.unit = Unit(unitExp: "m")}
        if !vMax.unit.isIdentical(unit: Unit(unitExp: "m")) {
            worldMaxSizeField.stringValue
            = theSim.vars["max"]!.physValn(n: selectedDim).stringExp(units: true)
        }
 
        if selectedDim == -1 {
            for i in 0..<dims {
                theSim.vars["min"]!.values[i] = vMin.asDouble!
                theSim.vars["max"]!.values[i] = vMax.asDouble!
                theSim.vars["max"]!.unit = vMax.unit
                theSim.vars["min"]!.unit = vMin.unit
                theSim.leftBorder[i] = left
                theSim.rightBorder[i] = right
            }
        } else {
            theSim.vars["min"]!.values[selectedDim] = vMin.asDouble!
            theSim.vars["max"]!.values[selectedDim] = vMax.asDouble!
            theSim.vars["min"]!.unit = vMin.unit
            theSim.vars["max"]!.unit = vMax.unit
            theSim.leftBorder[selectedDim] = left
            theSim.rightBorder[selectedDim] = right
        }
        worldTabSettings()
    }
    
    @IBAction func changeLeftEnergySlider(_ sender: Any) {
        let energy = borderEnergy.integerValue
        theSim.vars["borderEnergy"] = PhysValue(doubleVal: Double(energy))
        borderEnergyLabel.stringValue = "E=\(energy)%"
    }
    
    
    // ***********************
    // Gestion des populations
    // ***********************
    
    func resetPopCombo(pop: String) {
        popCombo.removeAllItems()
        popNames = Array(theSim.pops.keys)
        popCombo.addItems(withObjectValues: Array(theSim.pops.keys))
        selectedPop = pop
        mecaPopup.isEnabled = false
        leftBorderPopup.isEnabled = false
        rightBorderPopup.isEnabled = false

        if theSim.pops.count == 0 || selectedPop == "" {
            popsubBox.isHidden = true
            selectedPop = ""
            popCombo.isEditable = false
        } else {
            popsubBox.isHidden = false
            popCombo.selectItem(withObjectValue: pop)
            popCombo.isEditable = true
            deletePopBtn.isEnabled = true
            if theSim.dim > 0 {
                mecaPopup.isEnabled = true
                neighboursGridField.isEnabled = true
                neighboursGridField.isEditable = true
            }
            if theSim.pops[selectedPop] == nil {
                mainCtrl.printToConsole("unknown population ???")
                return
            }
            let thePop = theSim.pops[selectedPop]!
            let meca = thePop.meca
            if meca == "" {
                mecaPopup.selectItem(at: 0)
            } else {
                mecaPopup.selectItem(at: ["x":1,"v":2,"a":3,"f":4][meca]!)
            }
            let grid = thePop.fieldGrid
            if grid == nil {
                neighboursGridField.stringValue = ""
            } else {
                neighboursGridField.stringValue = grid!.stringExp(units: true)
            }
            
            for (i,aScript) in popScriptNames.enumerated() {
                if theSim.pops[selectedPop]!.scripts[aScript] != nil {
                    vsButtons[i].state = NSControl.StateValue.on
                } else {
                    vsButtons[i].state = NSControl.StateValue.off
                }
            }
        }
        resetVarsCombo(varName: "")
    }
    
    
    @IBAction func choosePopulation(_ sender: Any) {
        
        let newName = popCombo.stringValue
        let theIndex = popCombo.indexOfSelectedItem
        
        if newName == "" {
            resetPopCombo(pop: "")
            return
        }
        
        if theIndex > -1 {
            if popNames[theIndex] != selectedPop {
                selectedPop = popNames[theIndex]
            }
        }
        if newName != selectedPop {
            // on a tapé qq chose dans la zone texte -> modification du nom de la pop
            if theSim.pops[newName] != nil {
                // ce nom existe déjà !
                popCombo.stringValue = selectedPop
                popCombo.selectItem(withObjectValue: selectedPop)
                resetPopCombo(pop: selectedPop)
                return
            }
            theSim.pops[newName] = theSim.pops[selectedPop]
            theSim.pops.removeValue(forKey: selectedPop)
        }
        resetPopCombo(pop: newName)

    }
    
    @IBAction func addPopulation(_ sender: Any) {
        let name = "New population"
        let pop = Population()
        theSim.pops[name] = pop
        resetPopCombo(pop: name)
        popCombo.selectText(self)
    }
    
    @IBAction func deletePop(_ sender: Any) {
        if selectedPop == "" { return }
        if theSim.pops[selectedPop] == nil { return }
        theSim.pops.removeValue(forKey: selectedPop)
        resetPopCombo(pop: "")
    }
    
    @IBAction func changeMechanics(_ sender: Any) {
        if selectedPop == "world" || selectedPop == "" {
            neighboursGridField.stringValue = ""
            return
        }
        let oldmeca = theSim.pops[selectedPop]?.meca ?? ""
        let newmeca = ["","x","v","a","f"][mecaPopup.indexOfSelectedItem]
        let c = ["","x","y","z"]
        let pop = theSim.pops[selectedPop]!
        pop.meca = newmeca
        if newmeca == "" {
            neighboursGridField.stringValue = ""
            pop.fieldGrid = nil
        }
        
        if oldmeca != newmeca {
            let test = oldmeca != "" ?
                dialogOKCancel(question: "This will delete the previous MECHANICS script", text: "Continue ?") : true
            if test == true {
                // Suppression des variables précédentes
                for d in 1...3 {
                    if ["x","v","a","f"].contains(oldmeca) {
                        pop.vars[c[d]] = nil
                    }
                    if ["v","a","f"].contains(oldmeca) {
                        pop.vars["v"+c[d]] = nil
                    }
                    if ["a","f"].contains(oldmeca) {
                        pop.vars["a"+c[d]] = nil
                    }
                    if oldmeca == "f" {
                        pop.vars["F"+c[d]] = nil
                    }
                }
                if oldmeca == "f" {
                    pop.vars["m"] = nil
                }
                theSim.pops[selectedPop]?.scripts["MECHANICS"] = HierarchicExp()
                
                var theScript = ""
                // création des variables et du script
                if ["x","v","a","f"].contains(newmeca) {
                    for d in 1...theSim.dim {
                        addVar(name: c[d], defVal: PhysValue(numExp: "0[m]"))
                    }
                }
                if ["v","a","f"].contains(newmeca) {
                    for d in 1...theSim.dim {
                        addVar(name: "v"+c[d], defVal: PhysValue(numExp: "0[m/s]"))
                        theScript.append(
                            "." + c[d] + "=" + "." + c[d] + "+"
                            + ".v" + c[d] + "*" + "world.dt" + "\n") // x = x + v*dt
                    }
                }
                if ["a","f"].contains(newmeca) {
                    for d in 1...theSim.dim {
                        addVar(name: "a"+c[d], defVal: PhysValue(numExp: "0[m/s2]"))
                        theScript.append(
                            ".v" + c[d] + "=" + ".v" + c[d] + "+"
                            + ".a" + c[d] + "*" + "world.dt" + "\n") // v = v + a*dt
                    }
                }
                if newmeca == "f" {
                    for d in 1...theSim.dim {
                        addVar(name: "F"+c[d], defVal: PhysValue(numExp: "0[N]"))
                        theScript.append(".a" + c[d] + "=" + ".F" + c[d] + "/" + ".m" + "\n") // a = F/m
                    }
                    addVar(name: "m", defVal: PhysValue(numExp: "0[kg]"))
                    
                }

                pop.scripts["MECHANICS"] = codeScriptHierarchic(script: theScript)
            }
        }
        let scriptName = selectedPop + ".MECHANICS"
        mainCtrl.showScriptEditor()
        mainCtrl.showScript(scriptName: scriptName)
        
        resetPopCombo(pop: selectedPop)
        
    }
    
    func addVar(name : String, defVal: PhysValue? = nil) {
        if name == "" { return }
        if selectedPop == "" {
            theSim.vars[name] = PhysValue()
            if defVal != nil {
                theSim.vars[name] = defVal!
            }
        } else {
            theSim.pops[selectedPop]!.vars[name] = PhysValue()
            if defVal != nil {
                theSim.pops[selectedPop]!.vars[name] = defVal!
            }
        }
        resetVarsCombo(varName: name)
    }
  
 
    
    @IBAction func changedGrid(_ sender: Any) {
        if selectedPop == "world" || selectedPop == "" {
            neighboursGridField.stringValue = ""
            return
        }
        let pop = theSim.pops[selectedPop]!
        
        // initialisation éventuelle de la grille de positions
        if theSim.vars["min"]!.asDoubles! .contains(Double.infinity) ||
            theSim.vars["min"]!.asDoubles! .contains(-Double.infinity) ||
            theSim.vars["max"]!.asDoubles! .contains(Double.infinity) ||
            theSim.vars["max"]!.asDoubles! .contains(-Double.infinity) {
            neighboursGridField.stringValue = ""
            pop.fieldGrid = nil
        } else if neighboursGridField.stringValue == "" {
            pop.fieldGrid = nil
        } else  {
            let codedVal = algebToHierarchic(neighboursGridField.stringValue)
            if codedVal.op != "_val" {
                pop.fieldGrid = nil
                neighboursGridField.stringValue = ""
                resetPopCombo(pop: selectedPop)
                return
            }
            let gridSize = codedVal.value!
            if gridSize.asDouble == nil {
                pop.fieldGrid = nil
                neighboursGridField.stringValue = ""
            }
            if gridSize.unit.isNilUnit() { gridSize.unit = Unit(unitExp: "m") }
            if gridSize.unit.isIdentical(unit: Unit(unitExp: "m")) && gridSize.asDouble! > 0 {
                pop.fieldGrid = gridSize
                pop.calcGrid()
            } else {
                pop.fieldGrid = nil
                neighboursGridField.stringValue = ""
            }
        }
        resetPopCombo(pop: selectedPop)
    }
    
    // *********************
    // Gestion des variables
    // *********************
    
    func resetVarsCombo(varName : String) {
          if selectedPop == "" {
        } else {
            
            let thePop = theSim.pops[selectedPop]!
            let meca = thePop.meca
            if meca == "" {
                mecaPopup.selectItem(at: 0)
            } else {
                mecaPopup.selectItem(at: ["x":1,"v":2,"a":3,"f":4][meca]!)
            }
            
            let grid = thePop.fieldGrid
            if grid == nil {
                neighboursGridField.stringValue = ""
            } else {
                neighboursGridField.stringValue = grid!.stringExp(units: true)
            }
            
        
            
        }
        
    }
    
    
    
    
    // ********************
    // Gestion des scripts
    // ********************
    
    @IBAction func worldScript(_ sender: Any) {
        let btn = sender as! NSButton
        let title = btn.title
        if title.count == 1 {
            // c'est un checkbox : activer ou désactiver le script
            let n = Int(title)!-1
            let selectedName = worldScriptNames[n]
            if btn.state == NSControl.StateValue.on {
                if theSim.oldScripts[selectedName] != nil {
                    theSim.scripts[selectedName] = theSim.oldScripts[selectedName]
                } else { theSim.scripts[selectedName] = HierarchicExp() }
            } else {
                if theSim.scripts[selectedName] != nil {
                    theSim.oldScripts[selectedName] = theSim.scripts[selectedName]
                }
                theSim.scripts[selectedName] = nil
            }
        } else {
            // c'est un bouton de script : l'activer si nécessaire et le montrer
            let selectedName = title
            if theSim.scripts[selectedName] == nil {
                if theSim.oldScripts[selectedName] != nil {
                    theSim.scripts[selectedName] = theSim.oldScripts[selectedName]
                } else {
                    theSim.scripts[selectedName] = HierarchicExp()
                }
            }
            let scriptName = "World." + selectedName
            mainCtrl.showScriptEditor()
            mainCtrl.showScript(scriptName: scriptName)
        }
        resetWorldScriptButtons()
    }
    
    @IBAction func varScript(_ sender: Any) {
        if selectedPop == "" { return}
        if theSim.pops[selectedPop] == nil { return }
        let btn = sender as! NSButton
        let title = btn.title
        if title.count == 1 {
            // c'est un checkbox : activer ou désactiver le script
            let n = Int(title)!-1
            let selectedName = popScriptNames[n]
            if btn.state == NSControl.StateValue.on {
                if theSim.pops[selectedPop]!.oldScripts[selectedName] != nil {
                    theSim.pops[selectedPop]!.scripts[selectedName] = theSim.pops[selectedPop]!.oldScripts[selectedName]
                } else { theSim.pops[selectedPop]!.scripts[selectedName] = HierarchicExp() }
            } else {
                if theSim.pops[selectedPop]!.scripts[selectedName] != nil {
                    theSim.pops[selectedPop]!.oldScripts[selectedName] = theSim.pops[selectedPop]!.scripts[selectedName]
                }
                theSim.pops[selectedPop]!.scripts[selectedName] = nil
            }
        } else {
            // c'est un bouton de script : l'activer si nécessaire et le montrer
            let selectedName = title
            if theSim.pops[selectedPop]!.scripts[selectedName] == nil {
                if theSim.pops[selectedPop]!.oldScripts[selectedName] != nil {
                    theSim.pops[selectedPop]!.scripts[selectedName] = theSim.pops[selectedPop]!.oldScripts[selectedName]
                } else {
                    theSim.pops[selectedPop]!.scripts[selectedName] = HierarchicExp()
                }
            }
  
            let scriptName = selectedPop + "." + selectedName
            mainCtrl.showScriptEditor()
            mainCtrl.showScript(scriptName: scriptName)
        }
        resetPopCombo(pop: selectedPop)
    }
    
 
    
}
