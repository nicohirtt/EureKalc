//
//  AppDelegate.swift
//  EureKalc
//
//  Created by Nico on 19/08/2019.
//  Copyright © 2019 Nico Hirtt. All rights reserved.
//

import Cocoa

var functionReturn = PhysValue() // valeur de retour d'un calcul
var userLanguage = "" // la première langue utilisateur pour laquelle il exisgte des traductions.
var rulesTranslations : [String:[String:String]] = [:] // [langue:[nom:label]
var prefsController : preferencesController?
var dataLibrary : ekLibrary = ekLibrary(name: "Settings data-library")
var permutationsOfIndexes : [Int:[[Int]]] = [:]
var helpString : NSAttributedString = NSAttributedString()
var decimalSep : String = "."
var listSep : String = ","
var maxNumberOfUndos : Int = 10
var maxNumberOfWhile : Int = 10000
var showPageLimits : Bool = false
var defaultViewScale : CGFloat = 1.00
var defaultPrintScale : CGFloat = 0.75
var thisVersion: String = "1.0" // sera comparé au contenu du fichier ekcversion.txt
var lastVersion : String = thisVersion
var functionsHelp : [funcCategory] = [] // 1er élément = description (String)

// éléments suivants = description des arguments (String)

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var DuplicateMenuItem: NSMenuItem!
    @IBOutlet weak var preferencesMenuItem: NSMenuItem!
    @IBOutlet weak var copyPDFMenuItem: NSMenuItem!
    @IBOutlet weak var insertGridItem: NSMenuItem!
    @IBOutlet weak var undoLastAction: NSMenuItem!
    @IBOutlet weak var redoPreviousAction: NSMenuItem!
    @IBOutlet weak var addColumn: NSMenuItem!
    @IBOutlet weak var addRow: NSMenuItem!
    @IBOutlet weak var pageLimitsMenuItem: NSMenuItem!
    @IBOutlet weak var helpMenuItem: NSMenuItem!
    
    var applicationShouldHandleReopen: Bool = true
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        
        // marges d'impression
        NSPrintInfo.shared.leftMargin = 10
        NSPrintInfo.shared.topMargin = 10
        NSPrintInfo.shared.rightMargin = 10
        NSPrintInfo.shared.bottomMargin = 10

        
        // calcul des permutations
        for n in 1...7 {
            permutationsOfIndexes[n] = permutationsOfArray(arr: Array([0,1,2,3,4,5,6].prefix(n)))
        }
        
        // Lecture de l'aide
        if let thePath = Bundle.main.url(forResource: "help", withExtension: "rtf")  {
            do {
                guard let data = try? Data(contentsOf: thePath) else {
                    print("there is a problem")
                    return
                }
                try? helpString =  NSAttributedString(data: data,
                                                   options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf],
                                                   documentAttributes: nil)
            }
        } else { print("there is a problem") }
        
        
        // test du point ou virgule décimal
        if UserDefaults.standard.string(forKey: "decimalSep") == nil {
            decimalSep = NumberFormatter().decimalSeparator!
        } else {
            decimalSep = UserDefaults.standard.string(forKey: "decimalSep")!
        }
        defaultFormatter.decimalSeparator = decimalSep
        listSep = (decimalSep == ".") ? "," : ";"

        
        // symbole pour le produit vectoriel
        let crossProd = UserDefaults.standard.string(forKey: "crossProd") ?? "⋀"
        UserDefaults.standard.setValue(crossProd, forKey: "crossProd")
        opSymb[operatorsList.firstIndex(of: "**")!] = crossProd
        
        // format des nombres
        if UserDefaults.standard.object(forKey: "nbFormatSigDigits") == nil {
            defaultFormatter.usesSignificantDigits = true
            defaultFormatter.maximumSignificantDigits = 5
            defaultFormatter.minimumSignificantDigits = 1
            UserDefaults.standard.setValue(true, forKey: "nbFormatSigDigits")
            UserDefaults.standard.setValue(5, forKey: "nbFormatSize")
        } else {
            defaultFormatter.usesSignificantDigits = UserDefaults.standard.bool(forKey: "nbFormatSigDigits")
            if defaultFormatter.usesSignificantDigits {
                defaultFormatter.maximumSignificantDigits = UserDefaults.standard.integer(forKey: "nbFormatSize")
            } else {
                defaultFormatter.maximumFractionDigits = UserDefaults.standard.integer(forKey: "nbFormatSize")
            }
        }
        
        let theReset = NSEvent.modifierFlags.contains(.control) ? true : false
        loadUnits(reset: theReset)
        loadRulesAndTranslations(reset: theReset) // chargement des règles et leur traductions
        loadLibraries(reset: theReset)
        loadGeneralSettings(reset: theReset)
        loadFuncHelp()
        userLanguage = String(Locale.preferredLanguages[0].prefix(2))
        if theReset {
            _ = dialogOK(message: "All settings have been reset to factory values !")
        }
        
    }
    
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSColor.ignoresAlpha = false
        testversion()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
   
    
    // Reçoit les actions sur les menus qui ne vont pas vers le maincontroller
    @IBAction func menuSelection(_ sender: NSMenuItem) {
        switch sender {
        case DuplicateMenuItem : mainCtrl.duplicateSelection()
        case copyPDFMenuItem : mainCtrl.copyToPDF()
        case insertGridItem : mainCtrl.insertGrid()
        case addColumn : mainCtrl.insertColumn()
        case addRow : mainCtrl.insertRow()
        case preferencesMenuItem :
            let preferencesWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "preferencesWindowController") as! NSWindowController
            preferencesWindowController.showWindow(self)
            let preferencesWindow = preferencesWindowController.window
            let preferencesViewController = preferencesWindow!.contentViewController as! preferencesController
            preferencesViewController.showGeneralPrefs(self)
        case undoLastAction :  mainDoc.undo()
        case redoPreviousAction : mainDoc.redo()
        case pageLimitsMenuItem :
            showPageLimits = !(showPageLimits)
            if showPageLimits {
                pageLimitsMenuItem.title = "Hide page limits"
            } else {
                pageLimitsMenuItem.title = "Show page limits"
            }
            mainCtrl.theEquationView.needsDisplay = true
        case helpMenuItem :
            mainCtrl.helpCombo.selectItem(at: 0)
            mainCtrl.showHelp(mainCtrl.helpCombo)
        default : return
        }
    }
    
    @IBAction func print2(_ sender: Any) {
        mainDoc.printDoc()
    }
    
    @IBAction func runPageLayout2(_ sender: Any) {
        mainDoc.pageLayout()
    }
    
    func testversion() {
        // test de la version
        if let url = URL(string: "https://www.nicohirtt.org/eurekalc/ekcversion.txt") {
            do {
                lastVersion = try String(contentsOf: url)
                if lastVersion != thisVersion {
                    let alert: NSAlert = NSAlert()
                    alert.messageText = "Download version " + lastVersion + " ?"
                    alert.informativeText = "You are using version " + thisVersion + " of EureKalc. Do you want to quit and download the last version ?"
                    alert.alertStyle = NSAlert.Style.warning
                    alert.addButton(withTitle: "OK")
                    alert.addButton(withTitle: "Cancel")
                    let res = alert.runModal()
                    if res == NSApplication.ModalResponse.alertFirstButtonReturn {
                        print(" Download new version")
                        let requiredURL = URL(string: "https://www.nicohirtt.org/eurekalc")!
                        NSWorkspace.shared.open(requiredURL)
                        NSApp.terminate(self)
                    }
                } else {
                    print("It's the good version")
                }

            } catch {
                // contents could not be loaded
            }
        } else {
            // the URL was bad!
        }
        
    }
    
    @IBAction func save(_ sender: Any) {
        mainDoc.save()
    }

    
}



// fonctions pour faciliter l'usage des boutons radio et checkbox
// transforme un booléen en state
func stateValue(_ test : Bool) -> NSControl.StateValue {
    if test { return NSControl.StateValue.on }
    return NSControl.StateValue.off
}

// set l'état d'un bouton suivant un booléen
func setBtnState(_ button: NSButton, set: Bool = true) {
    button.state = stateValue(set)
}

// retourne l'état d'un bouton sous forme de booléen
func btnState(_ button: NSButton) -> Bool {
    if button.state == NSControl.StateValue.on { return true }
    return false
}

// pour faire des dialogues...
typealias promptResponseClosure = (_ strResponse:String, _ bResponse:Bool) -> Void

func promptForReply(_ strMsg:String, vc:MainController, completion:promptResponseClosure) {
    
    let alert: NSAlert = NSAlert()
    
    alert.addButton(withTitle: "OK")      // 1st button
    alert.addButton(withTitle: "Cancel")  // 2nd button
    alert.messageText = strMsg
    
    let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    txt.stringValue = ""
    
    alert.accessoryView = txt
    let response: NSApplication.ModalResponse = alert.runModal()
    
    var bResponse = false
    if (response == NSApplication.ModalResponse.alertFirstButtonReturn) {
        bResponse = true
    }
    
    completion(txt.stringValue, bResponse)
    
}


func dialogOKCancel(question: String, text: String) -> Bool {
    let alert: NSAlert = NSAlert()
    alert.messageText = question
    alert.informativeText = text
    alert.alertStyle = NSAlert.Style.warning
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    let res = alert.runModal()
    if res == NSApplication.ModalResponse.alertFirstButtonReturn {
        return true
    }
    return false
}

func dialogOK(message: String) -> Bool {
    let alert: NSAlert = NSAlert()
    alert.messageText = message
    alert.informativeText = ""
    alert.alertStyle = NSAlert.Style.warning
    alert.addButton(withTitle: "OK")
    let res = alert.runModal()
    if res == NSApplication.ModalResponse.alertFirstButtonReturn {
        return true
    }
    return false
}

// Pour transformer des arrays d'un type en l'autre
extension Collection where Iterator.Element == Double {
    var doubleToInt: [Int] {
        return compactMap{ Int($0) }
    }
}

extension Collection where Iterator.Element == Int {
    var intToDouble: [Double] {
        return compactMap{ Double($0) }
    }
}


func asDouble(_ x: Any) -> Double? {
    if x is Double { return x as? Double}
    if x is Int { return Double(x as! Int)}
    return nil
}


// une classe pour la gestion des boutons de choix de pages
class multipleButtons : NSView {
    var names : [String] = []
    var selectedButton : Int = 0
    var target : Any?
    var action : Selector?
    var rects : [NSRect] = []
    var y0 : CGFloat = 3
    
    func resetButtons(titles: [String], select: Int, maxWidth: CGFloat) {
        names = titles
        self.subviews.removeAll()
        var x : CGFloat = 0
        rects = []
        for aTitle in titles {
            if x < maxWidth {
                let theButton = NSButton(title: aTitle, target: target, action: action)
                theButton.setButtonType(NSButton.ButtonType.pushOnPushOff)
                theButton.isBordered = false
                theButton.font = NSFont.systemFont(ofSize: 11)
                let theWidth = 40 + CGFloat(aTitle.count * 5)
                theButton.frame = NSRect(x: x, y: y0, width: theWidth, height: 30)
                rects.append(NSRect(x: x + 5, y: y0, width: theWidth-10, height: 30))
                x = x + theWidth - 12
                self.subviews.append(theButton)
            } else {
                break
            }
        }
        self.setFrameSize(NSSize(width: x + 12, height: self.frame.height))
        self.needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        if rects.count > selectedButton {
            let bckgndRect = NSBezierPath(rect: rects[selectedButton])
            let theColor = NSColor(named: NSColor.Name("customPageBtnColor"))!
            theColor.setFill()
            bckgndRect.fill()
        }
    }
    
    func titleOfBtn(_ n : Int) -> String? {
        if n > names.count - 1 || n < 0 { return nil}
        return names[n]
    }
    
    func indexOfBtn(_ name : String) -> Int? {
        if names.contains(name) {
            return names.firstIndex(of: name)
        }
        return nil
    }
    
    func selectButton(_ n : Int) {
        if n < names.count && n > -1 {
            selectedButton = n
        } else {
            selectedButton = 0
        }
        self.needsDisplay = true
    }
    
    func selectButton(_ name : String) {
        let n = indexOfBtn(name)
        if n != nil { selectedButton = n! }
        else { selectedButton = 0 }
        self.needsDisplay = true
    }
}

func loadGeneralSettings(reset: Bool = false) {
    let myDefaults = UserDefaults.standard
    let dicDefaults = myDefaults.dictionaryRepresentation()
    maxNumberValuesShown = myDefaults.integer(forKey: "maxVecSize")
    if maxNumberValuesShown == 0 || reset == true { maxNumberValuesShown = 10 }
    var fontName = myDefaults.string(forKey: "fontName")
    var fontSize = myDefaults.integer(forKey: "fontSize")
    varItalic = dicDefaults.keys.contains("varItalic") ? myDefaults.bool(forKey: "varItalic") : true
    if fontName == nil || reset == true { fontName = "Helvetica" }
    if fontSize == 0 || reset == true { fontSize = 12 }
    var theFontMask : NSFontTraitMask
    theFontMask = NSFontTraitMask.unboldFontMask
    theFontMask = NSFontTraitMask(rawValue: theFontMask.rawValue | NSFontTraitMask.unitalicFontMask.rawValue)
    let theFont = NSFontManager.shared.font(withFamily: fontName!, traits: theFontMask, weight: 5, size: CGFloat(fontSize))
    if theFont != nil { defaultFont = theFont! }
    else { defaultFont = NSFont(name: "Helvetica", size: 12)!}
    defaultSettings = ["textcolor":defaultTextColor,"font":defaultFont]
}

func loadRulesAndTranslations(reset : Bool = false) {
    let myDefaults = UserDefaults.standard
    var rulesString = ""
    if myDefaults.string(forKey: "rules") == nil || reset == true {
        // si on "reset", on charge le fichier de règles et traductions par défaut du bundle
        if let rulesPath = Bundle.main.path(forResource: "rules", ofType: "txt")  {
            do {
                rulesString = try String(contentsOfFile: rulesPath)
            } catch { /* not loaded */  }
        } else { print("there is a problem") }
        myDefaults.set(rulesString, forKey: "rules")
    } else {
        rulesString = myDefaults.string(forKey: "rules")!
    }
    rulesStringToArray(rulesString: rulesString)
}

func loadLibraries(reset : Bool = false) {
    let myDefaults = UserDefaults.standard
    var libString = ""
    if myDefaults.string(forKey: "library") == nil || reset == true {
        // si on "reset", on charge le fichier par défaut du bundle
        if let thePath = Bundle.main.path(forResource: "library", ofType: "txt")  {
            do {
                libString = try String(contentsOfFile: thePath)
            } catch { /* not loaded */  }
        } else { print("there is a problem") }
        myDefaults.set(libString, forKey: "library")
    } else {
        libString = myDefaults.string(forKey: "library")!
    }
    dataLibrary = ekLibrary(fromString: libString)
}

func loadUnits(reset : Bool = false) {
    let myDefaults = UserDefaults.standard
    var unitsString = ""
    if myDefaults.string(forKey: "units") == nil || reset == true {
        // si on "reset", on charge le fichier par défaut du bundle
        if let thePath = Bundle.main.path(forResource: "units", ofType: "txt")  {
            do {
                unitsString = try String(contentsOfFile: thePath)
            } catch { /* not loaded */  }
        } else { print("there is a problem") }
        myDefaults.set(unitsString, forKey: "units")
    } else {
        unitsString = myDefaults.string(forKey: "units")!
    }
    unitsDefs = []
    unitsByName = [:]
    unitsByType = [:]
    getUnitsFromString(unitsString)
}

func loadFuncHelp() {
    var theString = ""
    if let thePath = Bundle.main.path(forResource: "functions", ofType: "txt")  {
        do {
            theString = try String(contentsOfFile: thePath)
        } catch { /* not loaded */  }
    } else {
        print("there is a problem")
        return
    }
    functionsHelp = []
    let theLines = theString.split(separator: "\n")
    var categoryName = ""
    var category = funcCategory()
    var functionName = ""
    var functionDesc = NSMutableAttributedString()
    var function = funcDef()
    var argCounter : Int = 0
    for aLine in theLines {
        if functionName != "" && (aLine.hasPrefix("#") || !aLine.hasPrefix("\t")) {
            // il faut achever la fonction en cours
            if functionDesc.string.hasSuffix("( ") {
                functionDesc = NSMutableAttributedString(string: functionName, attributes: [NSAttributedString.Key.foregroundColor:NSColor.black])
            } else {
                functionDesc.append(NSAttributedString(string : " )", attributes: [NSAttributedString.Key.foregroundColor:NSColor.black]))
            }
            function.definition.insert(functionDesc, at: 0)
            category.functions.append(function)
            functionName = ""
            functionDesc = NSMutableAttributedString()
        }
        if aLine.hasPrefix("#") {
            // nouvelle catégorie, on sauvagarde la précédente...
            if categoryName != "" {
                functionsHelp.append(category)
            }
            categoryName = String(aLine.dropFirst(1))
            category = funcCategory()
            category.catName = categoryName
            argCounter = 0
        } else if !aLine.hasPrefix("\t") {
            // c'est un nom de fonction, on sauvagarde la précédente
            functionName = String(aLine)
            functionDesc.append(NSAttributedString(string: functionName + "( ", attributes: [NSAttributedString.Key.foregroundColor:NSColor.black]))
            function = funcDef()
            function.funcName = functionName
            argCounter = 0
        } else {
            let shortLine = String(aLine.dropFirst())
            if shortLine.count > 0 {
                // c'est une composante d'une fonction
                if argCounter > 0 {
                    if argCounter > 1 { functionDesc.append(NSAttributedString(string: " , ", attributes: [NSAttributedString.Key.foregroundColor:NSColor.black])) }
                    let splitted = shortLine.split(separator: " ")
                    if splitted[0].hasSuffix(":") {
                        // C'est un argument nommé
                        let argName = splitted[0]
                        functionDesc.append(NSAttributedString(string: String(argName.dropLast()), attributes: [NSAttributedString.Key.foregroundColor:NSColor.black] ))
                        function.definition.append(NSAttributedString(string: "\t" + shortLine, attributes: [NSAttributedString.Key.foregroundColor:NSColor.blue]))
                    } else {
                        functionDesc.append(NSAttributedString(string: "_", attributes: [NSAttributedString.Key.foregroundColor:NSColor.black]))
                        function.definition.append(NSAttributedString(string: "\t_ : " + shortLine, attributes: [NSAttributedString.Key.foregroundColor:NSColor.blue]))
                    }
                } else {
                    function.definition.append(NSAttributedString(string: shortLine, attributes: [NSAttributedString.Key.foregroundColor:NSColor.lightGray]))
                }
                argCounter = argCounter + 1
            }
        }
    }
}

func permutationsOfArray(arr: [Int]) -> [[Int]] {
    var result : [[Int]] = []
    if arr.count == 1 { return [arr]}
    for (n,elem) in arr.enumerated() {
        var rest = arr
        rest.remove(at: n)
        let restperms = permutationsOfArray(arr: rest)
        for aRest in restperms {
            var aPerm = [elem]
            aPerm.append(contentsOf: aRest)
            result.append(aPerm)
        }
    }
    return result
}

extension StringProtocol {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}

extension NSTextField {
    func formatValue(_ dVal: Double?) {
        if dVal == nil {
            self.stringValue = ""
            return
        }
        let newFormatter = NumberFormatter()
        newFormatter.decimalSeparator = decimalSep
        if (abs(dVal!) > 0 && (abs(dVal!) > 100000 || abs(dVal!) < 0.00001))  {
            newFormatter.numberStyle = NumberFormatter.Style.scientific
            //newFormatter.exponentSymbol = "E"
        } else {
            newFormatter.numberStyle = NumberFormatter.Style.decimal
            
        }
        defaultFormatter.usesSignificantDigits = true
        let precision = 4
         newFormatter.usesSignificantDigits = true
        newFormatter.minimumSignificantDigits = 1
        newFormatter.maximumSignificantDigits = precision
        self.cell?.formatter = newFormatter
        self.doubleValue = dVal!
    }
}

struct funcCategory {
    var catName : String = ""
    var functions : [funcDef] = []
}

struct funcDef {
    var funcName : String = ""
    var definition : [NSAttributedString] = []
}
