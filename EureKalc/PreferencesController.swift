//
//  preferencesController.swift
//  EureKalc
//
//  Created by Nico on 06/11/2020.
//  Copyright © 2020 Nico Hirtt. All rights reserved.
//

import Cocoa

class preferencesController: NSViewController {
    
    @IBOutlet var mathRules: NSView!
    @IBOutlet var generalPrefs: NSView!
    @IBOutlet var dataPrefs: NSView!
    @IBOutlet var unitPrefs: NSView!
    
    
    var mathRulesController : rulesPrefsController?
    var dataLibController : libraryPrefsController?
    var unitsController: unitsPrefsController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prefsController = self
        // Do view setup here.
    }
    
    @IBAction func showGeneralPrefs(_ sender: Any) {
        generalPrefs.isHidden = false
        mathRules.isHidden = true
        dataPrefs.isHidden = true
        unitPrefs.isHidden = true
   }
    
    @IBAction func showMathRules(_ sender: Any) {
        generalPrefs.isHidden = true
        mathRules.isHidden = false
        dataPrefs.isHidden = true
        unitPrefs.isHidden = true
      }
    
    @IBAction func showDataPrefs(_ sender: Any) {
        dataPrefs.isHidden = false
        generalPrefs.isHidden = true
        mathRules.isHidden = true
        unitPrefs.isHidden = true
    }
    
    @IBAction func showUnitsPrefs(_ sender: Any) {
        dataPrefs.isHidden = true
        generalPrefs.isHidden = true
        mathRules.isHidden = true
        unitPrefs.isHidden = false
    }
}


class generalPrefsController : NSViewController {
    
    @IBOutlet var maxVecSizeFld: NSTextField!
    @IBOutlet var fontNamePopup: NSPopUpButton!
    @IBOutlet var fontSizeField: NSTextField!
    @IBOutlet var crossProdSymbol1: NSButton!
    @IBOutlet var crossProdSymbol2: NSButton!
    @IBOutlet var decSepAuto: NSButton!
    @IBOutlet var decSepDot: NSButton!
    @IBOutlet var decSepComma: NSButton!
    @IBOutlet var listSepLabel: NSTextField!
    @IBOutlet var decimalsFormatBtn: NSButton!
    @IBOutlet var sigDigitsFormatBtn: NSButton!
    @IBOutlet var nbrDigitsField: NSTextField!
    @IBOutlet var nbrDigitsStepper: NSStepper!
    @IBOutlet var varsItalicBtn: NSButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        maxVecSizeFld.intValue = Int32(maxNumberValuesShown)
        fontNamePopup.removeAllItems()
        fontNamePopup.addItems(withTitles: theFontNames)
        fontNamePopup.selectItem(withTitle: defaultFont.fontName)
        fontSizeField.intValue = Int32(Int(defaultFont.pointSize))
        let decSetting = UserDefaults.standard.string(forKey: "decimalSep")
        decSepAuto.state = NSControl.StateValue.off
        decSepDot.state = NSControl.StateValue.off
        decSepComma.state = NSControl.StateValue.off
        if decSetting == nil {
            decSepAuto.state = NSControl.StateValue.on
        } else {
            if decSetting == "." { decSepDot.state = NSControl.StateValue.on }
            else { decSepComma.state = NSControl.StateValue.on }
        }
        let crossProdSetting = UserDefaults.standard.string(forKey: "crossProd")
        if crossProdSetting == crossProdSymbol1.title {
            crossProdSymbol1.state = NSControl.StateValue.on
            crossProdSymbol2.state = NSControl.StateValue.off
        } else {
            crossProdSymbol1.state = NSControl.StateValue.off
            crossProdSymbol2.state = NSControl.StateValue.on
        }
        if defaultFormatter.usesSignificantDigits {
            decimalsFormatBtn.state = NSControl.StateValue.off
            sigDigitsFormatBtn.state = NSControl.StateValue.on
            let n = defaultFormatter.maximumSignificantDigits
            nbrDigitsField.integerValue = n
            nbrDigitsStepper.integerValue = n
        } else {
            decimalsFormatBtn.state = NSControl.StateValue.off
            sigDigitsFormatBtn.state = NSControl.StateValue.on
            let n = defaultFormatter.maximumFractionDigits
            nbrDigitsField.integerValue = n
            nbrDigitsStepper.integerValue = n
        }
    }
    
    
    @IBAction func changeVecDisplaySize(_ sender: Any) {
        let n = (sender as! NSTextField).integerValue
        if n < 4 { maxVecSizeFld.integerValue = maxNumberValuesShown }
        else if n > 100 {maxVecSizeFld.integerValue = maxNumberValuesShown }
        else { maxNumberValuesShown = n }
        UserDefaults.standard.setValue(maxNumberValuesShown, forKey: "maxVecSize")
    }
    
    @IBAction func changeCrossProductSymbol(_ sender: NSButton) {
        let crossProd = sender.title
        UserDefaults.standard.setValue(crossProd, forKey: "crossProd")
        opSymb[operatorsList.firstIndex(of: "**")!] = crossProd
    }
    
    @IBAction func changeDecimalSep(_ sender: NSButton) {
        if sender.title == "." || sender.title == "," {
            decimalSep = sender.title
            UserDefaults.standard.setValue(decimalSep, forKey: "decimalSep")
        } else {
            decimalSep = decimalFormatter.decimalSeparator!
            UserDefaults.standard.removeObject(forKey: "decimalSep")
        }
        listSep = (decimalSep == ".") ? "," : ";"
        listSepLabel.stringValue = "⇒ preferred list separator is \" \(listSep) \" "
    }
    
    @IBAction func changeNumberFormat(_ sender: Any) {
        if decimalsFormatBtn.state == NSControl.StateValue.on {
            defaultFormatter.usesSignificantDigits = false
            UserDefaults.standard.setValue(false, forKey: "nbFormatSigDigits")
            defaultFormatter.maximumFractionDigits = nbrDigitsStepper.integerValue
            defaultFormatter.minimumFractionDigits = 0
        } else {
            defaultFormatter.usesSignificantDigits = true
            UserDefaults.standard.setValue(true, forKey: "nbFormatSigDigits")
            defaultFormatter.maximumSignificantDigits = nbrDigitsStepper.integerValue
            defaultFormatter.minimumSignificantDigits = 1
        }
        nbrDigitsField.integerValue = nbrDigitsStepper.integerValue
        UserDefaults.standard.setValue(nbrDigitsStepper.integerValue, forKey: "nbFormatSize")
    }
    
    @IBAction func changeFont(_ sender: Any) {
        var fontFamily = fontNamePopup.titleOfSelectedItem ?? defaultFont.familyName!
        var fontSize = CGFloat(fontSizeField.intValue)
        if fontSize < 5 || fontSize > 30 {
            fontSize = 12
            fontSizeField.intValue = 12
        }
        var theFontMask : NSFontTraitMask
        theFontMask = NSFontTraitMask.unboldFontMask
        theFontMask = NSFontTraitMask(rawValue: theFontMask.rawValue | NSFontTraitMask.unitalicFontMask.rawValue)
        let theFont = NSFontManager.shared.font(withFamily: fontFamily, traits: theFontMask, weight: 5, size: fontSize)
        if theFont != nil {
            defaultFont = theFont!
            defaultSettings = ["textcolor":defaultTextColor,"font":defaultFont]

        }
        else {
            fontFamily = defaultFont.fontName
            fontNamePopup.selectItem(withTitle: fontFamily)
            fontSize = defaultFont.pointSize
            fontSizeField.integerValue = Int(fontSize)
        }
        varItalic = (varsItalicBtn.state == NSControl.StateValue.on)
        UserDefaults.standard.setValue(varItalic, forKey: "varItalic")
        UserDefaults.standard.setValue(fontSize, forKey: "fontSize")
        UserDefaults.standard.setValue(fontFamily, forKey: "fontName")
    }
    
}

