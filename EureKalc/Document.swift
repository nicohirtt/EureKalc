//
//  Document.swift
//  EureKalc
//
//  Created by Nico on 19/08/2019.
//  Copyright © 2019 Nico Hirtt. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers


var theMainDoc : Document?

class Document: NSDocument {
    
    var theVariables : [String:PhysValue] = [:] // dictionnaire des variables
    var theVarExps : [String:HierarchicExp] = [:] // les formules mémorisées (ex: E=m*v^2/2)
    var theFunctions : [String:HierarchicExp] = [:] // dictionnaire des définitions de fonctions utilisateur
    var theScripts : [String:HierarchicExp] = [:] // dictionnaire des scripts
    var namedExps : [String:HierarchicExp] = [:]
    var theSim = Simulation()
    var thePages : [HierarchicExp] = []
    var currentPage : Int = 0

    var mainCtrl : MainController?
    var tabsCtrl : TabButtonsController?
    var layoutTabCtrl : LayoutTabController?
    var mathTabCtrl : MathTabController?
    var graphTabCtrl : GraphTabController?
    var simTabCtrl : SimTabController?
    var varsTabCtrl : VarsTabController?
    
    var undoHistory : [Data] = []
    var redoHistory : [Data] = []
    
    var appDelegate : AppDelegate
    
    var viewScale : CGFloat = 1.00
    var printScale : CGFloat = 0.75
    
    var isSaved : Bool = true
    var cancelledClose = false
    
    // ce tableau permet le lien retour d'une subview vers l'hierexp correspondante
    // il n'est pas enregistré ni tenu à jour lors de suppressions d'exp
    // on le reconstruit si nécessaire au premier appel de EquationView.calcOrDraw
    var mySubViews : [NSView:HierarchicExp] = [:]
    
    var lastScript : String?
    var scriptVisible : Bool?
    var mouseHighlite : Bool?
 
    
    var wFrame: NSRect?
    var currentScript : String = ""
    var currentScriptLine: String = ""
        
    override init() {
        appDelegate = NSApplication.shared.delegate as! AppDelegate
        super.init()
        theMainDoc = self
        // Add your subclass-specific initialization here.
        // Do any additional setup after loading the view.
        if thePages.count == 0 {
            thePages.append(HierarchicExp(pageNamed: "Page 1"))
            thePages.append(HierarchicExp(pageNamed: "Page 2"))
            thePages.append(HierarchicExp(pageNamed: "Page 3"))
        }
        scriptVisible = false
        currentPage = 0
        theSim.running = false
        _ = dataLibrary.useLibrary(ifAuto: true) // chargement des données par défaut
        appDelegate.undoLastAction.menu?.autoenablesItems = false
        appDelegate.undoLastAction.isEnabled = false
        appDelegate.redoPreviousAction.isEnabled = false
     }

    override var isDocumentEdited: Bool {
        return !isSaved
    }
    
    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! mainWindowController
        self.addWindowController(windowController)
        windowController.myDocument = self
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type, throwing an error in case of failure.
        // Alternatively, you could remove this method and override fileWrapper(ofType:), write(to:ofType:), or write(to:ofType:for:originalContentsURL:) instead.
        let aCoder = NSKeyedArchiver(requiringSecureCoding: true)
        if NSApplication.shared.mainWindow != nil {
            aCoder.encode(NSApplication.shared.mainWindow!.frame, forKey: "wFrame")
        }
        aCoder.encode(theVariables, forKey: "theVariables")
        aCoder.encode(theFunctions, forKey: "theFunctions")
        aCoder.encode(theScripts, forKey: "theScripts")
        aCoder.encode(thePages, forKey: "thePages")
        aCoder.encode(currentPage, forKey: "currentpage")
        aCoder.encode(theSim, forKey: "theSim")
        aCoder.encode(mainCtrl!.lastScript ?? "",forKey: "lastScript")
        aCoder.encode(mainCtrl!.scriptVisible, forKey: "scriptVisible")
        aCoder.encode(mainCtrl!.mouseHighlite, forKey: "mouseHighlite")
        aCoder.encode(Float(viewScale), forKey: "viewScale")
        aCoder.encode(Float(printScale), forKey: "printScale")
        aCoder.finishEncoding()
        return aCoder.encodedData
        //throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type, throwing an error in case of failure.
        // Alternatively, you could remove this method and override read(from:ofType:) instead.
        // If you do, you should also override isEntireFileLoaded to return false if the contents are lazily loaded.
        do {
            let aDecoder = try NSKeyedUnarchiver(forReadingFrom: data)
            wFrame = aDecoder.decodeRect(forKey: "wFrame")
            theVariables = aDecoder.decodeObject(of: [NSDictionary.self, PhysValue.self, NSString.self], forKey: "theVariables") as! [String:PhysValue]
            theFunctions = aDecoder.decodeObject(of: [NSDictionary.self, HierarchicExp.self, NSString.self], forKey: "theFunctions") as? [String:HierarchicExp] ?? [:]
            theScripts = aDecoder.decodeObject(of: [NSDictionary.self, HierarchicExp.self, NSString.self], forKey: "theScripts") as! [String:HierarchicExp]
            for aScriptName in theScripts.keys {
                let aScript = theScripts[aScriptName]
                aScript!.resetFathers()
                theScripts[aScriptName] = aScript
            }
            thePages = aDecoder.decodeObject(of: [NSArray.self, HierarchicExp.self], forKey: "thePages") as! [HierarchicExp]
            lastScript = aDecoder.decodeObject(of: [NSString.self], forKey: "lastScript") as? String
            for aPage in thePages {
                aPage.resetFathers()
                aPage.blockToGrid() // *********** temporaire *************
                resetNames(inExp: aPage)
            }
            currentPage = Int(aDecoder.decodeInt32(forKey: "currentpage"))
            theSim = aDecoder.decodeObject(of: [Simulation.self], forKey: "theSim") as! Simulation
            scriptVisible = aDecoder.containsValue(forKey: "scriptVisible") ? aDecoder.decodeBool(forKey: "scriptVisible") : false
            mouseHighlite = aDecoder.containsValue(forKey: "mouseHighlite") ? aDecoder.decodeBool(forKey: "mouseHighlite") : false
            viewScale = aDecoder.containsValue(forKey: "viewScale") ? CGFloat(aDecoder.decodeFloat(forKey: "viewScale")) : defaultViewScale
            printScale = aDecoder.containsValue(forKey: "printScale") ? CGFloat(aDecoder.decodeFloat(forKey: "printScale")) : defaultPrintScale
            
            // Pour ouvrir temporairement les vieux sims *******************
            if theSim.scripts.keys.contains("START_INIT") {
                theSim.scripts["INIT"]=theSim.scripts["START_INIT"]
                theSim.scripts["START_INIT"] = nil
            }
            if theSim.scripts.keys.contains("START_LOOP") {
                theSim.scripts["LOOP"]=theSim.scripts["START_LOOP"]
                theSim.scripts["START_LOOP"] = nil
            }
            if theSim.scripts.keys.contains("DISPLAY") {
                theSim.scripts["VIEW"]=theSim.scripts["DISPLAY"]
                theSim.scripts["DISPLAY"] = nil
            }
            for aPopName in theSim.pops.keys {
                if theSim.pops[aPopName]!.scripts.keys.contains("START_INIT") {
                    theSim.pops[aPopName]!.scripts["INIT"]=theSim.pops[aPopName]!.scripts["START_INIT"]
                    theSim.pops[aPopName]!.scripts["START_INIT"] = nil
                }
                if theSim.pops[aPopName]!.scripts.keys.contains("START_LOOP") {
                    theSim.pops[aPopName]!.scripts["LOOP"]=theSim.pops[aPopName]!.scripts["START_LOOP"]
                    theSim.pops[aPopName]!.scripts["START_LOOP"] = nil
                }
            }
            // *****************
            
        } catch {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
    }
    
    func resetNames(inExp: HierarchicExp) {
        if inExp.name != nil {
            namedExps[inExp.name!] = inExp
        }
        for arg in inExp.args {
            if arg.isAncestor || arg.isBlockOrPage {
                resetNames(inExp: arg)
            }
        }
    }
    
    // met à jour les historiques undo/redo et marque le document comme non enregistré
    func tryAutoSave() {
        do {
            let theData = try self.data(ofType: "String")
            undoHistory.append(theData)
            isSaved = false
        }
        catch {
            Swift.print("erreur d'historique undo")
        }
        redoHistory = []
        appDelegate.redoPreviousAction.isEnabled = false
        appDelegate.undoLastAction.isEnabled = true
        if undoHistory.count > maxNumberOfUndos {
            undoHistory.removeFirst()
        }
    }
    
    // annule la dernière opération effectuée et revient au dernier état enregistré
    func undo() {
        if undoHistory.count > 1 {
            let n = currentPage
            let redoData = undoHistory.last!
            undoHistory.removeLast()
            redoHistory.append(redoData)
            let theData = undoHistory.last!
            do { try self.read(from: theData, ofType: "String") }
            catch { Swift.print("erreur dans le undo")}
            mainCtrl!.showPage(n: n)
            appDelegate.redoPreviousAction.isEnabled = true
            if undoHistory.count == 0 {
                appDelegate.undoLastAction.isEnabled = false
            }
        }
    }
    
    // supprime l'annulation précédente et rétablit la situation enregistrée
    func redo() {
        if redoHistory.count > 0 {
            let n = currentPage
            let theData = redoHistory.last!
            redoHistory.removeLast()
            undoHistory.append(theData)
            if undoHistory.count > maxNumberOfUndos {
                undoHistory.removeFirst()
            }
            do { try self.read(from: theData, ofType: "String") }
            catch { Swift.print("erreur dans le undo")}
            mainCtrl!.showPage(n: n)
            if redoHistory.count == 0 {
                appDelegate.redoPreviousAction.isEnabled = false
            }
            appDelegate.undoLastAction.isEnabled = true
        }
    }
    
    
    // Exporte le contenu de la variable sous forme de fichier CSV.
    // si url n'est pas spécifié, l'utilisateur choisit. Retourn une physval d'erreur si nécessaire.
    func exportCSV(_ variable: String, sep: Character = "\t", dec: Character = ".") -> PhysValue? {
        var fileUrl : URL?
         
        let phVal = theVariables[variable]
        if phVal == nil { return errVal("Undefinded variable")}
        if phVal!.values.count == 0 { return errVal("Empty variable")}
        var dataString : String = ""
        if phVal!.type == "dataframe" {
            dataString = variable
            let nRows = (phVal!.values[0] as! PhysValue).values.count
            let nCols = phVal!.values.count
            var strings : [[String]] = [phVal!.names![1]]
            for j in 0..<nCols {
                let colPhval = phVal!.values[j] as! PhysValue
                let colType = colPhval.type
                var unit = ""
                if colType == "string" {
                    strings.append(colPhval.asStrings!)
                } else if colType == "int" || colType == "double" {
                    let values = colPhval.valuesInUnit
                    if !colPhval.unit.isNilUnit() { unit = " [" + colPhval.unit.name + "]"}
                    var colString = values.map{ String($0 ) }
                    if dec != "." {
                        colString = colString.map{ $0.replacingOccurrences(of: ".", with: String(dec) ) }
                    }
                    strings.append(colString)
                } else if colType == "bool" {
                    strings.append(colPhval.values.map{ ($0 as! Bool) ? "TRUE" : "FALSE" })
                } else {
                    return errVal("can't export data of type " + colType)
                }
                dataString = dataString + "\t" + (phVal!.names![0])[j] + unit
            }
            
            for i in 0..<nRows {
                dataString = dataString + "\r"
                for j in 0...nCols {
                    if j > 0 { dataString = dataString + String(sep)}
                    dataString = dataString + strings[j][i]
                }
            }
            
        } else {
            let dims = phVal!.dims()
            if dims.count > 2 { return errVal("can't export hypermatrices")}
            var stringVals : [String]
            let theType = phVal!.type
            if theType == "string" {
                stringVals = phVal!.asStrings!
            } else if theType == "double" || theType == "int" {
                let values = phVal!.valuesInUnit
                stringVals = values.map{ String($0 ) }
                if dec != "." {
                    stringVals = stringVals.map{ $0.replacingOccurrences(of: ".", with: String(dec)) }
                }
            } else if theType == "bool" {
                stringVals = phVal!.values.map{ ($0 as! Bool) ? "TRUE" : "FALSE" }
            } else {
                return errVal("can't export data of type " + theType)
            }
            
            if dims.count == 2 {
                for i in 0..<dims[1] {
                    if i != 0 { dataString = dataString + "\r"}
                    for j in 0..<dims[0] {
                        if j != 0 { dataString = dataString + "\t"}
                        dataString = dataString + stringVals[j + i*dims[0]]
                    }
                }
            } else {
                for i in 0..<stringVals.count {
                    dataString = dataString + stringVals[i] + "\r"
                }
            }
            
        }
        
        let myFileDialog = NSSavePanel()
        myFileDialog.runModal()
        fileUrl = myFileDialog.url
        do {
            try dataString.write(to: fileUrl!, atomically: true, encoding: String.Encoding.utf8)
            return PhysValue(string: fileUrl!.description)
        } catch {
            return errVal(error.localizedDescription)
        }
    }
    
    
    func importCSV(_ variable: String, sep: Character = "\t", dec: Character = ".", ftype: String = "a") -> PhysValue? {
        var fileUrl : URL?
        let myFileDialog = NSOpenPanel()
        myFileDialog.runModal()
        fileUrl = myFileDialog.url
        var dataString : String
        if fileUrl == nil { return nil}
        do {
            try dataString = String(NSString(contentsOf: fileUrl!, encoding: String.Encoding.utf8.rawValue ))
        } catch {
            return errVal(error.localizedDescription)
        }
        
         dataString = dataString.replacingOccurrences(of: "\n", with: "\r")
        var sep2 = sep
        if dataString.contains("\t") { sep2 = "\t"}
        if !dataString.contains(sep) && dataString.contains(";") { sep2 = ";"}
        if !dataString.contains(sep) && dataString.contains(",") { sep2 = ","}

        let allRows = dataString.split(separator: "\r").map{ String($0) }
        let nRows = allRows.count
        if nRows == 1 {
            // importation d'un vecteur
            let strings = dataString.split(separator: sep2).map { String($0) }
            if Double(strings[0]) == nil {
                return PhysValue(unit: Unit(), type: "string", values: strings)
            } else {
                return PhysValue(unit: Unit(), type: "double", values: strings.map{ Double($0) ?? Double.nan })
            }
        }
         if !dataString.contains(sep2) {
             // une seule colonne : c'est encore un vecteur
             if Double(allRows[0]) == nil {
                 return PhysValue(unit: Unit(), type: "string", values: allRows)
             } else {
                 return PhysValue(unit: Unit(), type: "double", values: allRows.map{ Double($0) ?? Double.nan })
             }
         }
         var strings : [[String]] = []
         var nCols : Int = 0
         for (n,aRow) in allRows.enumerated() {
             var rowStrings : [String]
             if sep != "." {
                 rowStrings = aRow.split(separator: sep2,omittingEmptySubsequences: false).map { String($0.replacingOccurrences(of: String(dec), with: String("."))) }
             } else {
                 rowStrings = aRow.split(separator: sep2,omittingEmptySubsequences: false).map { String($0) }
             }
             if nCols == 0 { nCols = rowStrings.count}
             if nCols != rowStrings.count { return errVal("Wrong number of items in row \(n)")}

             strings.append(rowStrings)
         }
         if nCols < 2 || nRows < 2 { return errVal("Unknow error in csv file")}
         
         if (Double(strings[0][1]) == nil && Double(strings[1][0]) == nil && ftype=="a") || ftype == "d" {
             // si la première ligne contient du texte et la première colonne aussi -> dataframe
             let result = PhysValue()
             result.type = "dataframe"
             var colNames : [String] = []
             var rowNames : [String] = []
             for c in 0..<nCols {
                 var values : [Any] = []
                 var type = "string"
                 var unit = Unit()
                 if c>0 {
                     var colName = strings[0][c]
                     let oneVal = strings[1][c]
                     if Double(oneVal) != nil {
                         type = "double"
                         if colName.hasPrefix("[") { colName = "C \(c-1)" + colName}
                         if colName.contains("[") && colName.hasSuffix("]") {
                             let unitName = String(colName.split(separator: "[")[1].dropLast())
                             colName = String(colName.split(separator: "[")[0])
                             unit = Unit(unitExp: unitName)
                         }
                     }
                     else if oneVal == "TRUE" || oneVal == "FALSE" { type = "bool"}
                     colNames.append(colName)
                 }
                 for r in 1..<nRows{
                     if c == 0 {
                         rowNames.append(strings[r][0])
                     } else {
                         if type == "string" { values.append(strings[r][c])}
                         else if type == "bool" { values.append(strings[r][c] == "TRUE")}
                         else { values.append(Double(strings[r][c]) ?? Double.nan)}
                     }
                 }
                 if c>0 {
                     let colPhVal = PhysValue(unit: unit, type: type, values: values)
                     result.values.append(colPhVal)
                 }
             }
             result.names = [colNames,rowNames]
             result.dim = [nCols-1]
             return result
             
         } else {
             // sinon c'est une matrice
             dataString = dataString.replacingOccurrences(of: "\r", with: String(sep2))
             let stringValues = dataString.split(separator: sep2).map { String($0) }
             var values : [Any]
             var type = "string"
             if Double(stringValues[0]) != nil {
                 type = "double"
                 if dec != "." {
                     values = stringValues.map{ Double($0.replacingOccurrences(of: String(dec), with: String("."))) ?? Double.nan }
                 } else {
                     values = stringValues.map{ Double($0) ?? Double.nan }
                 }
             }
             else if stringValues[0] == "FALSE" || stringValues[0] == "TRUE" {
                 type = "bool"
                 values = stringValues.map({ $0 == "TRUE" })
             } else {
                 values = stringValues
             }
             let result = PhysValue(unit: Unit(), type: type, values: values)
             result.dim = [nCols,nRows]
             return result
         }

    }
    
    func printDoc() {
        NSPrintInfo.shared.scalingFactor = printScale
        printInfo.scalingFactor = printScale
        if mainCtrl != nil {
            mainCtrl!.theEquationView.printView(self)
        }
      }
    
    func pageLayout() {
        NSPrintInfo.shared.scalingFactor = printScale
        printInfo.scalingFactor = printScale
        self.runModalPageLayout(with: self.printInfo, delegate: self, didRun: #selector(self.changedPageLayout), contextInfo: nil)
      }
    
    @objc func changedPageLayout() {
        printScale = self.printInfo.scalingFactor
        if mainCtrl != nil {
            mainCtrl!.theEquationView.needsDisplay = true
        }
     }
    
    
    func save() {
        NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
        isSaved = true
    }
    
}


// Ces variables permettent d'accéder aux données propres au document actif sans avoir à le spécifier à chaqe fois

var mainDoc : Document { return theMainDoc! } // juste pour ne pas avoir à mettre un ! à mainDoc tout le temps...

var mainCtrl : MainController { return mainDoc.mainCtrl! }

var tabsCtrl : TabButtonsController { return mainDoc.tabsCtrl! }

var layoutTabCtrl : LayoutTabController {  return mainDoc.layoutTabCtrl!}

var mathTabCtrl : MathTabController { return mainDoc.mathTabCtrl! }

var graphTabCtrl : GraphTabController { return mainDoc.graphTabCtrl! }

var simTabCtrl : SimTabController { return mainDoc.simTabCtrl! }


var selectedEquation : HierarchicExp? { return mainCtrl.selectedEquation }

var theVariables : [String:PhysValue] {
    get { return mainDoc.theVariables }
    set(x) { mainDoc.theVariables = x }
}

var theVarExps : [String:HierarchicExp] {
    get { return mainDoc.theVarExps }
    set(x) { mainDoc.theVarExps = x }
}

var theFunctions : [String:HierarchicExp] {
    get { return mainDoc.theFunctions }
    set(x) { mainDoc.theFunctions = x }
}

var theScripts : [String:HierarchicExp] {
    get { return mainDoc.theScripts }
    set(x) { mainDoc.theScripts = x }
}

var thePages : [HierarchicExp] {
    get { return mainDoc.thePages}
    set(x) { mainDoc.thePages = x }
}

var thePageNames : [String] {
    var theNames : [String] = []
    for aPage in thePages {
        theNames.append(aPage.name!)
    }
    return theNames
}

var thePage : HierarchicExp { return thePages[mainDoc.currentPage] }

var theSim : Simulation {
    get {return mainDoc.theSim }
    set(x) { mainDoc.theSim = x }
}

/// True if the application is in dark mode, and false otherwise
var inDarkMode: Bool {
    let mode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
    return mode == "Dark"
}

// retourne un script global, ou un script de simulation (word ou pop) selon son nom
func getScriptByName(_ name : String) -> (pop:String?, script: HierarchicExp?) {
    var pop : String?
    var script : HierarchicExp?
    if name.contains(".") {
        let split = name.split(separator: ".")
        pop = String(split[0])
        if pop == nil { return (nil,nil)}
        let type = String(split[1])
        if type == "" { return (nil,nil)}
        if pop == "world" {
            script = theSim.scripts[type]
        } else {
            if theSim.pops[pop!] == nil { return (nil,nil)}
            script = theSim.pops[pop!]!.scripts[type]
        }
        return (type, script)
    } else {
        script = theScripts[name]
        return (nil, script)
    }
}

// Le contrôleur et le delegate de la fenêtre principale de l'application
class mainWindowController : NSWindowController, NSWindowDelegate {
    
    @IBOutlet var mainWindow: NSWindow!
    var myDocument: Document?
    
    override func windowDidLoad() {
        mainWindow.delegate = self
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        theMainDoc = myDocument!
        if myDocument!.mainCtrl != nil {
            mainWindow!.makeFirstResponder(myDocument!.mainCtrl!.theEquationView)
        }
        if myDocument!.wFrame != nil {
            //mainWindow?.setFrame(myDocument!.wFrame!, display: true)
        }
    }
    
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let path = document!.fileURL??.path ?? "nil"
        if mainDoc.isSaved { return true }
        //return true
        if path != "nil" {
            do { try document!.write(to: document!.fileURL!, ofType: "String") }
            catch { Swift.print("erreur de sauvegarde") }
        }
        return true
    }
    
    
    
   
}
