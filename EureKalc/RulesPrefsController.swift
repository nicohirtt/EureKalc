//
//  RulesPrefsController.swift
//  EureKalc
//
//  Created by Nico on 02/02/2021.
//  Copyright © 2021 Nico Hirtt. All rights reserved.
//

import Cocoa


class rulesPrefsController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    
    @IBOutlet var rulesTable: NSTableView!
    @IBOutlet var languagePopup: NSPopUpButton!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        prefsController!.mathRulesController = self
        rulesTable.delegate = self
        rulesTable.dataSource = self
        languagePopup.removeAllItems()
        languagePopup.addItem(withTitle: "")
        for preflanguage in Locale.preferredLanguages {
            let lang = String(preflanguage.prefix(2))
            languagePopup.addItem(withTitle: lang)
        }
        if userLanguage != "" && rulesTranslations.keys.contains(userLanguage) {
            languagePopup.selectItem(withTitle: userLanguage)
        } else {
            languagePopup.selectItem(at: 0)
        }
    }
    
    
    @IBAction func chooseLanguage(_ sender: Any) {
        rulesTable.reloadData()
    }
    
    // nombre de lignes du tableau
    func numberOfRows(in tableView: NSTableView) -> Int {
        return rulesArray.count
    }
    
    // remplit le tableau en utilisant le rulesArray
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let theRule = rulesArray[row]
        let colNumber = tableView.column(withIdentifier: tableColumn!.identifier)
        var returnString = ""
        switch colNumber {
        case 0 : returnString = theRule.name
        case 1 : returnString = theRule.type
        case 2 :
            var pathString = ""
            if theRule.path.count == 0 { pathString = "." }
            for x in theRule.path {
                pathString = pathString + String(x)
            }
            returnString = pathString
        case 3 : returnString = theRule.hexp1.name ?? ""
        case 4 : returnString = theRule.hexp2.name ?? ""
        case 5 : returnString = theRule.labelForLanguage(lang: "")
        case 6 :
            returnString = (languagePopup.title == "") ? "" : theRule.labelForLanguage(lang: languagePopup.title,
                                                                                       def: false)
        default : returnString = ""
        }
        return returnString
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
        let colNbr = rulesTable.column(for: sender)
        let rowNbr = rulesTable.row(for: sender)
        let value = sender.stringValue
        switch colNbr {
        case 0 : rulesArray[rowNbr].name = value
        case 1 : rulesArray[rowNbr].type = value
        case 2 :
            var path : [Int] = []
            for char in value {
                if char != "." { path.append(Int(String(char))!) }
            }
            rulesArray[rowNbr].path = path
        case 3 :
            rulesArray[rowNbr].hexp1 = fromPolnish(value)
            rulesArray[rowNbr].hexp1.name = value
        case 4 :
            rulesArray[rowNbr].hexp2 = fromPolnish(value)
            rulesArray[rowNbr].hexp2.name = value
        case 5 : rulesArray[rowNbr].label = value
        case 6 :
            let name = rulesArray[rowNbr].name
            let lang = languagePopup.title
            if lang != "" {
                if rulesTranslations[lang] == nil {
                    rulesTranslations[lang] = [:]
                }
                rulesTranslations[lang]![name] = value
            }
        default : print("bizarre !")
        }
        saveRules()
    }

    
    @IBAction func addRule(_ sender: Any) {
        let row = rulesTable.selectedRow
        if row < 0 { return }
        let newRule = mathRule(name: "new_rule")
        rulesArray.insert(newRule, at: row + 1)
        rulesTable.reloadData()
        rulesTable.selectRowIndexes(IndexSet(integer: row+1), byExtendingSelection: false)
        saveRules()
    }
    
    @IBAction func duplicateRule(_ sender: Any) {
        let row = rulesTable.selectedRow
        if row < 0 { return }
        let selectedRule = rulesArray[row]
        let newRule = mathRule(name: selectedRule.name)
        newRule.type = selectedRule.type
        newRule.hexp1 = selectedRule.hexp1.copyExp()
        newRule.hexp2 = selectedRule.hexp2.copyExp()
        newRule.label = selectedRule.label
        newRule.path = selectedRule.path
        rulesArray.insert(newRule, at: rulesTable.selectedRow + 1)
        rulesTable.reloadData()
        rulesTable.selectRowIndexes(IndexSet(integer: row+1), byExtendingSelection: false)
        saveRules()
    }
    
    @IBAction func moveRuleDown(_ sender: Any) {
        let row = rulesTable.selectedRow
        if row < 0 || row >= rulesArray.count - 1 { return }
        let selectedRule = rulesArray[row]
        let nextRule = rulesArray[row + 1]
        rulesArray[row] = nextRule
        rulesArray[row + 1] = selectedRule
        rulesTable.reloadData()
        rulesTable.selectRowIndexes(IndexSet(integer: row+1), byExtendingSelection: false)
        saveRules()
       }
    
    @IBAction func moveRuleUp(_ sender: Any) {
        let row = rulesTable.selectedRow
        if row < 1 { return }
        let selectedRule = rulesArray[row]
        let nextRule = rulesArray[row - 1]
        rulesArray[row] = nextRule
        rulesArray[row - 1] = selectedRule
        rulesTable.reloadData()
        rulesTable.selectRowIndexes(IndexSet(integer: row-1), byExtendingSelection: false)
        saveRules()
    }
    
    @IBAction func deleteRule(_ sender: Any) {
        let row = rulesTable.selectedRow
        if row < 0 { return }
        rulesArray.remove(at: row)
        rulesTable.reloadData()
        rulesTable.selectRowIndexes(IndexSet(integer: max(row-1,0)), byExtendingSelection: false)
        saveRules()
    }
    
    
    func saveRules() {
        let theRulesString = rulesArrayToString()
        UserDefaults.standard.set(theRulesString,forKey: "rules")
        loadRulesAndTranslations( reset: false)
    }
    
    @IBAction func resetDefaults(_ sender: Any) {
        loadRulesAndTranslations( reset: true)
        rulesTable.reloadData()
    }
    
    @IBAction func clearAllRules(_ sender: Any) {
        rulesArray.removeAll()
        rulesTable.reloadData()
    }
    
    // exportation des règles et des langues utilisateur sous forme de fichiers texte
    @IBAction func exportRules(_ sender: Any) {
        let theOutput = rulesArrayToString(missing: true)
        let savePanel = NSSavePanel()
        savePanel.begin { (result) in
             if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                let filename = savePanel.url!
                do {
                    try theOutput.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
                } catch {
                    // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                }
             }
         }
    }
    
    @IBAction func importRules(_ sender: Any) {
        let openPanel = NSOpenPanel()
        var theString = ""
        openPanel.begin { (result) in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
               let filename = openPanel.url!
                do {
                    theString = try String.init(contentsOf: filename)
                    rulesStringToArray(rulesString: theString)
                    self.rulesTable.reloadData()
                } catch {
                   // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
               }
            }
        }
    }
    
    
}



