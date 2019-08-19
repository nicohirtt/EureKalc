//
//  HierarchicExp.swift
//  testCalc1
//
//  Created by Nico on 13/08/2019.
//  Copyright © 2019 Nico Hirtt. All rights reserved.
//

import Cocoa

var operatorsList = ["==","=","≤","≥","<",">","≠",",",";",":","+","-","_minus","•","***","**","//","*","/","%","^","#","@","∈"]
var operatorsSymb = ["==","=","≤","≥","<",">","≠",",",",",":","+","-","-","•","***","**","//","*","/","%","^","#","","∈"]
var opSymb = ["=="," = ","≤","≥","<",">","≠",",",";",":","+","-","-","•","⨂","⋀","//","⋅","/","%","^","#","","∈"]

let zeroHexp = HierarchicExp(withPhysVal: PhysValue(doubleVal: 0))
let oneHexp = HierarchicExp(withPhysVal: PhysValue(doubleVal: 1))

var bracketsList = ["(",")","[","]","{","}"]
var wordsWithArguments = ["IF","PRINT","WHILE","FOR","FUNCTION","RUN","RETURN"]
var scriptLanguageKeyWords = ["IF","ELSE","ENDIF","WHILE","LOOP","FOR","NEXT","FUNCTION","END","RETURN"]


class HierarchicExp : NSObject, NSSecureCoding {
    
    var op = "" // opérateur (ou mot-clé ou "_var" ou "_func" ou "_val" )
    var args : [HierarchicExp] = []
    var result : HierarchicExp?
    var father : HierarchicExp? = nil
    var name : String? // un nom éventuel pour désigner une expression
    var value : PhysValue? // la valeur si op est _val
    var string : String? // la chaine si op est _edit ou le nom de la variable si op est "_var"
    var atString : NSAttributedString? // pour les textes complexes
    var image : NSImage?
    var draw : HierDraw? // les paramètres de dessin (voir plus bas)
    var graph: Grapher? // un graphique éventuel
    var view: NSView? // ceci ne sera jamais enregistré : à reconstituer dès que nécessaire
    var viewSize : NSSize?
    var editing: Bool = false
    var localVars: [String:PhysValue?] = [:]

    // Encodage et décodage
    
    class var supportsSecureCoding: Bool { return true }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(op, forKey: "op")
        aCoder.encode(args, forKey: "args")
        if let name = name { aCoder.encode(name, forKey: "name")}
        if let value = value {aCoder.encode(value, forKey: "value")}
        if let string = string { aCoder.encode(string, forKey: "string")}
        if op == "text" && view != nil {
            atString = (view as! NSTextView).attributedString()
        }
        if let atString = atString { aCoder.encode(atString, forKey: "atString")}
        if let image = image { aCoder.encode(image, forKey: "image")}
        if op == "table" && view != nil {
            self.setSetting(key: "tablesettings", value: (view as! ekTableScrollView).drawSettings)
        }
        if let draw = draw { aCoder.encode(draw, forKey: "draw")}
        if let result = result {aCoder.encode(result, forKey: "result")}
        if let graph = graph {  aCoder.encode(graph, forKey: "graph") }
        if let viewSize = viewSize { aCoder.encode(viewSize, forKey: "viewSize") }
    }
    
    required init?(coder: NSCoder) {
        op = coder.decodeObject(of: [NSString.self], forKey: "op") as! String
        args = coder.decodeObject(of: [NSArray.self, HierarchicExp.self], forKey: "args") as! [HierarchicExp]
        name = coder.decodeObject(of: [NSString.self], forKey: "name") as? String
        value = coder.decodeObject(of: [PhysValue.self], forKey: "value") as? PhysValue
        string = coder.decodeObject(of: [NSString.self], forKey: "string") as? String
        atString = coder.decodeObject(of: [NSAttributedString.self], forKey: "atString") as? NSAttributedString
        image = coder.decodeObject(of: [NSImage.self], forKey: "image") as? NSImage
        draw = coder.decodeObject(of: [HierDraw.self], forKey: "draw") as? HierDraw
        result = coder.decodeObject(of: [HierarchicExp.self], forKey: "result") as? HierarchicExp
        graph = coder.decodeObject(of: [Grapher.self], forKey: "graph") as? Grapher
        viewSize = coder.decodeSize(forKey: "viewSize")
    }
    
    
    // initialisateurs particuliers
    override init() {}
    
    init(withPhysVal: PhysValue) {
        op = "_val"
        value = withPhysVal
    }
    
    init(withOp : String) {
        op = withOp
    }
    
    init(withText: String) {
        op = "_edit"
        string = withText
    }
    
    
    init(withScript: String) {
        op = "_script"
        name = withScript
    }
    
    init(withOp: String, args: [HierarchicExp]) {
        super.init()
        op = withOp
        self.args = args
        for arg in self.args {
            arg.father = self
        }
    }
    
    init(withVar: String) {
        super.init()
        op = "_var"
        self.string = withVar
    }
    
    init(op: String, _ args: [HierarchicExp]? = nil) {
        super.init()
        self.op = op
        if args == nil { self.args = [] }
        else { self.args = args! }
        for arg in self.args {
            arg.father = self
        }
    }
    
    init(withNode: String, args: [HierarchicExp]) {
        super.init()
        op = "_node"
        name = withNode
        self.args = args
        for arg in self.args {
            arg.father = self
        }
    }
    
    // Création d'une nouvelle page
    init(pageNamed: String) {
        super.init()
        op = "_page"
        name = pageNamed
        draw = HierDraw(withSettings: defaultSettings)
        draw!.size = NSSize(width: 500, height: 6000)
        let mainGrid = HierGrid(cols: 1, rows: 1, arguments: [HierarchicExp(withText: " ")])
        //mainGrid.draw = HierDraw()
        //mainGrid.draw!.size = NSSize(width: 0, height: 15)
        //mainGrid.draw!.offset = 15
        addArg(mainGrid)
    }
    
    // crée un _grid
    init(cols: Int, rows: Int) {
        op = "_grid"
        draw = HierDraw()
        var settings : [String:Any] = [:]
        settings["gridsize"] = [cols,rows]
        settings["colwidths"] = Array(repeating: CGFloat(10), count: cols)
        settings["rowheights"] = Array(repeating: CGFloat(10), count: rows)
        settings["gridwidth"] = "fit"
        settings["gridheight"] = "fit"
        settings["haligns"] = Array(repeating: "left", count: cols)
        settings["valigns"] = Array(repeating: "top", count: rows)
        settings["hmargin"] = CGFloat(4)
        settings["vmargin"] = CGFloat(4)
        draw!.settings = settings
        let nArgs = cols * rows
        for _ in 0..<nArgs { args.append(HierarchicExp(withText: " ")) }
    }
    
 
    var isEdit : Bool {
        if op == "_edit" { return true }
        return false
    }
    
    var nArgs : Int { return args.count }
    
    //  propriétés du tracé de l'équation : extraction du contenu de "draw"
    // on suppose que draw a été testé pour ne pas être nil
    var origin : NSPoint { return drawok.origin }
    var size : NSSize { return drawok.size }
    var innerSize : NSSize { return drawok.innersize }
    var offset : CGFloat { return drawok.offset }
    var pars : Bool { return drawok.pars }
    
    // les réglages de dessin
    var drawSettings: [String:Any]? {
        if draw == nil { return nil}
        return draw!.settings
    }
        
    // retourne la fonte de l'expression ou celle de l'exp supérieure
    var theFont: NSFont {
        if drawSettings != nil {
            if drawSettings!["font"] != nil {
                return drawSettings!["font"] as! NSFont
            }
        }
        if father != nil { return father!.theFont}
        return defaultFont
    }
    
    // le NSRect qui entoure une expression
    var theRect : NSRect? {
        if draw == nil { return nil}
        var orgn = self.origin
        orgn.y = orgn.y - self.size.height + 2 // because NSRect a son origine au coin inférieur gauche
        return NSRect(origin: orgn, size: NSSize(width: self.size.width, height: self.size.height-4))
    }
    
    // le petit carré pour changer la taille
    var resizingDotRect : NSRect? {
        if !isScalable { return nil }
        return NSRect(x: theRect!.maxX - 4, y: theRect!.minY - 4, width: 8, height: 8)
    }
    
    // Vérifie si c'est l'expression d'entrée encore vide
    var isInputExp : Bool {
        if op != "_edit" { return false }
        if string == nil {return false }
        if string == "" { return true }
        return false
    }
    
    // Vérifie si c'est une valeur "chaine vide"
    var isEmptyString : Bool {
        if op != "_val" { return false }
        if value!.isEmptyString() { return true }
        return false
    }
    
    // Vérifie si l'expression est un block
    var isBlock : Bool {
        if op == "_hblock" || op == "_vblock" || op == "_grid" {return true}
        return false
    }
    
    // Vérifie si l'expression est un block ou une page
    var isBlockOrPage : Bool {
        if op == "_hblock" || op == "_vblock" || op == "_page" || op == "_grid" {return true}
        return false
    }
    
    // vérifie si une équation peut être effacée (équation ancestor ou bloc, mais pas le premier d'une page)
    var isDeletable : Bool {
        if self.isAncestor { return true}
        if self.father == nil { return true }
        if self.isBlock && self.father!.op != "_page" { return true }
        return false
    }
    
    // vérifie si une équation est redimensionable
    var isScalable : Bool {
        if isGraph { return true}
        if ["text","table","slider","hslider","vslider","cslider","button","checkbox","image","imagebox","popup","menu","input","radiobuttons",].contains(op) { return true }
        return false
    }
    
    // Vérifie si l'expression est une expression complète (true) ou une partie d'expression (false)
    var isAncestor : Bool {
        if self.isBlock { return true }
        if op == "_solvedcalc" { return true}
        if father == nil {return false}
        if father!.isBlock {return true}
        return false
    }
    
    // vérifie s'il s'agit d'un graphique
    var isGraph : Bool {
        if ["plot","lineplot","scatterplot","histo","histogram","barplot","stairs"].contains(op) {return true}
        return(false)
    }
    
    var isError: Bool {
        if op == "_val" {
            if value?.type == "error" { return true}
        }
        return false
    }
    
    // ancêtre (expression complète) de l'expression donnée (ou nil si inexistant)
    var ancestor : HierarchicExp? {
        if self.isAncestor { return self }
        if father != nil { return father!.ancestor }
        return nil
    }
    
    // block contenant cette expression
    var myBlock : HierarchicExp? {
        if self.isBlock {
            return self
        } else {
            if father == nil { return nil }
            return father!.myBlock!
        }
    }
    
    // numéro de l'expression dans les arguments de son père (ou -1 si pas de père)
    var argInFather : Int {
        if father == nil { return -1 }
        var n = 0
        for arg in father!.args {
            if arg == self { return n}
            n = n + 1
        }
        return -1
    }
    
    var isGrid : Bool {
        if op == "_grid" { return true }
        return false
    }
    
    var isCustomGrid : Bool {
        if !isGrid { return false}
        return (self as! HierGrid).isCustomGrid
    }
    
    
    // retourne le père du père du père... n fois
    func nthFather(_ n : Int) -> HierarchicExp {
        if n==0 { return self }
        if n==1 { return self.father! }
        return self.father!.nthFather(n-1)
    }
    
    
    func copyExp(removeView: Bool = true) -> HierarchicExp {
        if op == "_grid" {
            let theCopy = (self as! HierGrid).copyGrid()
            return theCopy
        }
        let theCopy = HierarchicExp()
        theCopy.op = op
        theCopy.name = name
        theCopy.value = value?.dup()
        theCopy.string = string
        theCopy.draw = draw?.copyDraw()
        theCopy.result = result?.copyExp()
        theCopy.graph = graph
        if removeView && self.view != nil {
            self.view!.removeFromSuperview()
        }
        for arg in args {
            theCopy.addArg(arg.copyExp(removeView: removeView))
        }
        theCopy.father = father
        return theCopy
    }

    var polnish: String {
        if op == "_var" { return self.string!}
        if op == "_val" { return self.value!.stringExp(units: false)}
        var result = self.op + "("
        for arg in self.args {
            result.append(arg.polnish + ",")
        }
        result.removeLast()
        result.append(")")
        return result
    }
    
    // vérifie si une expression contient une autre(fils, petit-fils...)
    func contains(_ exp : HierarchicExp) -> Bool {
        if self == exp { return true }
        if exp.father == nil { return false }
        return self.contains(exp.father!)
    }
    
    func drawSettingForKey(key : String) -> Any? {
        let settings = drawSettings
        if settings != nil {
            if settings!.keys.contains(key) { return settings![key]}
        }
        return nil
    }
    
    func setSetting(key: String, value: Any?) {
        if draw == nil {draw = HierDraw() }
        var settings = drawSettings
        if value == nil {
            settings?.removeValue(forKey: key)
        } else {
            if settings == nil {
                settings = [key:value!]
            } else {
                settings![key] = value
            }
        }
        self.draw!.settings = settings!
    }

    
    func removeSetting(key: String) {
        if drawSettings == nil {return}
        var settings = drawSettings!
        if settings.keys.contains(key) {
            settings.removeValue(forKey: key)
            self.draw!.settings = settings
        }
    }
    
    var font : NSFont? {
        if drawSettings == nil {return nil }
        if drawSettings!.keys.contains("font") { return (drawSettings!["font"] as! NSFont)}
        return nil
    }
    
    var textColor : NSColor? {
        if drawSettings == nil {return nil }
        if drawSettings!.keys.contains("textcolor") { return (drawSettings!["textcolor"] as! NSColor)}
        return nil
    }
    
    func setSize(_ size: NSSize) {
        if draw == nil { draw = HierDraw() }
        draw!.size = size
    }
    
    func setInnerSize(_ size: NSSize) {
        if draw == nil { draw = HierDraw() }
        draw!.innersize = size
    }
    
    func setOrigin(_ origin: NSPoint) {
        if draw == nil { draw = HierDraw() }
        draw!.origin = origin
    }
    
    func setOffset(_ offset: CGFloat) {
        if draw == nil { draw = HierDraw() }
        draw!.offset = offset
    }
    
    func setPars(_ pars: Bool) {
        if draw == nil { draw = HierDraw() }
        draw!.pars = pars
    }
        
    // ajoute un argument à une expression (à la fin)
    func addArg(_ theArg: HierarchicExp) {
        var args = self.args
        args.append(theArg)
        theArg.father = self
        self.args = args
    }
    
    
    // insérer un argument (sans père actuel !) à la position n (en déplaçant les autres)
    func insertArg(at: Int, newExp: HierarchicExp) {
        args.insert(newExp, at: at)
        newExp.father = self
    }
    
    // supprime un argument
    func removeArg(_ n: Int) {
        if n == -1 || nArgs <= n { return }
        var args = self.args
        args[n].deleteSubviews()
        args.remove(at: n)
        self.args = args
    }
    
    // suppression des view s'il y en a...
    func deleteSubviews() {
        if view != nil {
            view!.removeFromSuperview()
        }
        for arg in args {
            arg.deleteSubviews()
        }
    }
    
    // remplace l'équation fournie en argument dans son père (supposé existant)
    func replaceExp(_ exp : HierarchicExp) {
        exp.deleteSubviews()
        let n = exp.argInFather
        let f = exp.father!
        f.replaceArg(n: n, newExp: self)
    }
    
    // remplace le n-ème argument par celui fourni
    func replaceArg(n : Int, newExp: HierarchicExp) {
        if nArgs<=n || n == -1 {return}
        let oldExp = args[n]
        oldExp.deleteSubviews()
        oldExp.father = nil
        newExp.father = self
        newExp.resetFathers()
        args[n] = newExp
    }
    
    // remplace oldExp par newExp dans les args du père (et retourne oldExp avec father = nil)
    func replaceArg(oldExp: HierarchicExp, newExp: HierarchicExp) {
        let n = oldExp.argInFather
        if n == -1 { return}
        replaceArg(n: n, newExp: newExp)
    }
    
    // échange les arguments d'index n1 et n2 et retourne le résultat
    func exchangeArgs(n1 : Int, n2 : Int) -> HierarchicExp {
        let r = self.copyExp(removeView: false)
        let arg = r.args[n1]
        r.args[n1] = r.args[n2]
        r.args[n2] = arg
        return r
    }

    // échange les arguments d'index n1 et n2
    func exchangeMyArgs(n1 : Int, n2 : Int) {
        let arg1 = args[n1]
        let arg2 = args[n2]
        args[n1] = arg2
        args[n2] = arg1
    }
    
    // déplace une exp de son father actuel vers un nouvel emplacement
    func moveExp(at: Int, newFather: HierarchicExp) {
        if father != nil {
            let n = self.argInFather
            father!.removeArg(n)
        }
        father = newFather
        newFather.insertArg(at: at, newExp: self)
    }
    
    // Supprime une expression de son père
    func removeFromFather() {
        if father != nil {
            self.deleteSubviews()
            let n = self.argInFather
            father!.removeArg(n)
            father = nil
        }
    }
    
    // recherche le premier argument d'un type donné dans l'expression
    func findArgWithOp(theOp: String) -> Int? {
        var n=0
        for arg in self.args {
            if arg.op == theOp { return n}
            n = n + 1
        }
        return nil
    }
    
    // recherche le premier argument nombre négatif
    func findArgWithNegVal() -> Int? {
        var n=0
        for arg in self.args {
            if arg.op == "_val" && arg.value != nil {
                let val = arg.value!
                if (val.type == "double" || val.type == "int") && val.values.count == 1 {
                    if val.asDouble! < 0 { return n }
                }
            }
            n = n + 1
        }
        return nil
    }
    
    // recherche dans l'expression un argument identique à celui fourni
    func findIdenticalArg(_ exp: HierarchicExp) -> Int? {
        var n = 0
        for arg in self.args {
            if arg.isIdentical(exp) { return n}
            n = n + 1
        }
        return nil
    }
    
    // vérifie si deux expressions sont identiques
    func isIdentical(_ exp : HierarchicExp, commute: Bool = true) -> Bool {
        if op != exp.op { return false }
        if nArgs != exp.nArgs { return false}
        if op == "_val" {
            if value == nil || exp.value == nil { return false }
            if !value!.isIdentical(exp.value!) { return false }
            return true
        }
        if op == "_var" {
            if string == nil || exp.string == nil { return false }
            if string! == exp.string { return true}
            return false
        }
        if ["+","*","=","≠","<>","==","!="].contains(op) && commute {
            // traitement des opérateurs communatatifs
            let copie = exp.copyExp()
            for arg1 in args {
                var ok = false
                for arg2 in copie.args {
                    if arg1.isIdentical(arg2) {
                        arg2.removeFromFather()
                        ok = true
                        break
                    }
                }
                if !ok {return false}
            }
            return true
        } else if nArgs > 0 {
            // traitement de tous les autres opérateurs
            for n in 0 ... nArgs-1 {
                if args[n].isIdentical(exp.args[n]) == false { return false }
            }
            return true
        }
        return false
    }
    
    // teste si c'est un (certain) nom de variable
    func isVar(_ v : String? = nil) -> Bool {
        if op != "_var" { return false }
        if v == nil { return true }
        if string! == v! { return true }
        return false
    }
    
    // produit une expression algébrique classique sous forme de chaine avec gestion des parenthèses
    func stringExp() -> String {
        var result = ""
        var needpars = false
        if op == "" { return "" }
        if op == "_var" { return(string!) }
        if op == "_err" { return args[0].value!.asString! }
        if op == "_val" {
            if value!.type == "string" {
                return( "\"" + value!.stringExp(units: false) + "\"")
            } else {
                return(value!.stringExp(units: true))
            }
            
        }
        if op == "_edit" {
            return ""
        }
        if op == "_setunit" {
            if nArgs != 2 { return ""}
            let arg = args[0]
            let unit = args[1].value?.unit
            if unit == nil {
                return arg.stringExp()
            } else {
                return args[0].stringExp() + "[" + unit!.name + "]"
            }
        }
        if operatorsList.contains(op) && op != "_minus" {
            if op == "," {result = "("}
            let p1 = operatorsList.firstIndex(of: op)!
            var n = 0
            for arg in args {
                let argExp = arg.stringExp()
                if n>0 && op == "@" {
                    result = result + "{" + argExp + "}"
                } else {
                    if n>0 {
                        if op == "@" { result = result + "{" }
                        else if op == "," && listSep == ";" { result = result + ";"}
                        else if op == "," { result = result + ","}
                        else {result = result + operatorsSymb[p1] }
                    }
                    if operatorsList.contains(arg.op) {
                        let p2 = operatorsList.firstIndex(of: arg.op)!
                        if p2 < p1 || (p2 == p1 && op != "+" && op != "*") {
                            needpars = true
                        } else {
                            needpars = false
                        }
                        
                        if needpars {
                            result = result + "("
                        }
                        result = result + argExp
                        if needpars {
                            result = result + ")"
                        }
                    } else {
                        result = result + argExp
                    }
                }
                n = n + 1
            }
            if op == "," { result.append(")")}
        } else if op == "_minus" {
            result = "-"
            let arg = args[0]
            if ["≤","≥","<",">","≠","=",":","+","-"].contains(arg.op) {
                result = result + "(" + arg.stringExp() + ")"
            } else {
                result = result + arg.stringExp()
            }
        } else if op == "_comment" {
            result.append("#" + string!)
        } else {
            result = op + "("
            for (i,arg) in args.enumerated() {
                if i > 0 { result = result + ","}
                result = result + arg.stringExp()
            }
            result.append(")")
        }
        result = result.replacingOccurrences(of: "+-", with: "-")
        return result
    }
    
    // transforme tout un script en texte éditable
    func toText() -> String {
        var result = ""
        if op == "SCRIPT_BLOC" {
            for arg in args {
                result = result + arg.toText() + "\n"
            }
        } else if op == "IF" {
            result = "IF(" + args[0].stringExp() + ")" + "\n"
            result = result + args[1].toText()
            if nArgs == 3 {
                result = result + "ELSE" + "\n" + args[2].toText()
            }
            result = result + "ENDIF"
        } else if op == "WHILE" {
            result = "WHILE(" + args[0].stringExp() + ")" + "\n"
            result = result + args[1].toText()
            result = result + "LOOP"
        } else if op == "FOR" {
            result = "FOR(" + args[0].stringExp() + "," + args[1].stringExp() + ")" + "\n"
            result = result + args[2].toText()
            result = result + "NEXT"
        } else if op == "FUNCTION" {
            result = "FUNCTION( " + args[0].stringExp() + " )" + "\n"
            result = result + args[1].toText()
            result = result + "END"
        } else {
            result = stringExp()
        }
        return result
    }
    
    // fonction récursive pour retrouver les pères des toutes les sous-équations
    func resetFathers() {
        for arg in args {
            arg.father = self
            arg.resetFathers()
        }
        if result != nil { result!.father = self }
    }
    
    // Clacul d'une expression et ajout de son résultat
    func calcResult()  {
        let r = executeHierarchicScript()
        if r.values.count > 0 {
            let newResult = HierarchicExp(withPhysVal: r)
            self.setResult(newResult)
        } else {
            self.result = nil
        }
    }
    
    // Place un résultat dans une exp et le lie à son père
    func setResult(_ exp: HierarchicExp) {
        // on récupère les settings !
        let oldResult = self.result?.value
        if oldResult !== nil {
            let oldUnit = oldResult!.unit
            if exp.value != nil {
                if oldUnit.isIdentical(unit: exp.value!.unit) {
                    exp.value!.unit = oldUnit
                }
            }
        }
        if self.result?.drawSettings != nil {
            exp.draw=HierDraw()
            exp.draw!.settings = self.result!.drawSettings!
        }
        result = exp
        exp.father = self
    }
    
    // calculer les valeurs numériques dont arguments sont des nombres
    // par exemple (1+x+3) -> (x+4) et x+sin(0) -> x
    func calculateNum() -> HierarchicExp {
        if nArgs == 0 {
            return self
        }
        var newArgs : [HierarchicExp] = []
        var allNumbers = true
        var sumorprod :PhysValue?
        for arg in args {
            let newArg = arg.calculateNum()
            if newArg.op != "_val" {
                allNumbers = false
                newArgs.append(newArg)
            }
            else if !newArg.value!.isNumber {
                allNumbers = false
                newArgs.append(newArg)
            }
            else if op == "*" || op == "+" {
                if sumorprod == nil {
                    sumorprod = newArg.value!
                } else if op == "+" {
                    sumorprod = sumorprod!.plus(newArg.value!)
                } else if op == "*" {
                    sumorprod = sumorprod!.mult(newArg.value!)
                }
            } else {
                newArgs.append(newArg)
            }
        }
        if sumorprod != nil {
            if allNumbers {
                return HierarchicExp(withPhysVal: sumorprod!)
            } else {
                newArgs.append(HierarchicExp(withPhysVal: sumorprod!))
            }
        }
        let newExp = HierarchicExp(withOp: op, args: newArgs)
        if allNumbers {
            return HierarchicExp(withPhysVal: newExp.executeHierarchicScript())
        } else {
            return newExp
        }
    }
    

    
    // transforme une expression (de type $ ou non) en physvalue de type "exp"
    func scriptToPhysValExp() -> PhysValue {
        if op == "$" {
            return PhysValue(unit: Unit(), type: "exp", values: args)
        } else {
            return PhysValue(unit: Unit(), type: "exp", values: [self])
        }
    }
    
    //
    // procédure provisoire pour récupérer les vieux fichiers avec "vBlock" et "hBlock"
    func blockToGrid() {
        for (n,arg) in args.enumerated() {
            
            if arg.op == "_hblock" {
                let newArg = HierGrid(cols: arg.nArgs, rows: 1, arguments: arg.args)
                newArg.blockToGrid()
                replaceArg(n: n, newExp: newArg)
            }
            
            if arg.op == "_vblock" {
                let newArg = HierGrid(cols: 1, rows: arg.nArgs, arguments: arg.args)
                newArg.blockToGrid()
                replaceArg(n: n, newExp: newArg)
            }
            
        }
    }
    
    // vérifie si l'expression contient la variable v donnée
    func containsVar(_ v : String) -> Bool {
        if op == "_var" {
            if string! == v { return true }
        }
        for arg in args {
            if arg.containsVar(v) { return true }
        }
        return false
    }
    
    // retourne la liste des variables utilisées dans l'expression
    func listOfMyVars() -> [String] {
        if op == "_var" { return [self.string!] }
        var r : [String] = []
        for arg in args {
            r.append(contentsOf: arg.listOfMyVars())
        }
        return r
    }
    
    var drawok : HierDraw {
        if draw == nil { draw = HierDraw() }
        return draw!
    }
    
}

class HierGrid : HierarchicExp {
    var cols: Int = 1
    var rows: Int = 1
    var colWidths : [CGFloat] = [10]
    var rowHeights : [CGFloat] = [10]
    var rowOffsets: [CGFloat] = [5]
    var gridWidth = "fit"
    var gridHeight = "fit"
    var hAligns : [String] = ["left"]
    var vAligns : [String] = ["baseline"]
    var hMargin : CGFloat = 20
    var vMargin : CGFloat = 4
    var showGrid : Bool = false
    //var eqnPositions : [CGFloat]?
    
    override class var supportsSecureCoding: Bool {
           return true
    }

    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(cols,forKey: "cols")
        aCoder.encode(rows,forKey: "rows")
        aCoder.encode(colWidths,forKey: "colWidths")
        aCoder.encode(rowHeights, forKey: "rowHeights")
        aCoder.encode(rowOffsets, forKey: "rowOffsets")
        aCoder.encode(gridWidth,forKey: "gridWidth")
        aCoder.encode(gridHeight,forKey: "gridHeight")
        aCoder.encode(hAligns,forKey: "hAligns")
        aCoder.encode(vAligns,forKey: "vAligns")
        aCoder.encode(Float(hMargin),forKey: "hMargin")
        aCoder.encode(Float(vMargin),forKey: "vMargin")
        aCoder.encode(showGrid, forKey: "showGrid")
    }
    
    required init?(coder: NSCoder) {
        super .init(coder: coder)
        cols = coder.decodeInteger(forKey: "cols")
        rows = coder.decodeInteger(forKey: "rows")
        colWidths = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "colWidths") as! [CGFloat]
        rowHeights = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "rowHeights") as! [CGFloat]
        rowOffsets = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "rowOffsets") as! [CGFloat]
        gridWidth = coder.decodeObject(of: [NSString.self], forKey: "gridWidth") as! String
        gridHeight = coder.decodeObject(of: [NSString.self], forKey: "gridHeight") as! String
        hAligns = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "hAligns") as! [String]
        vAligns = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "vAligns") as! [String]
        hMargin = CGFloat(coder.decodeFloat(forKey: "hMargin"))
        vMargin = CGFloat(coder.decodeFloat(forKey: "vMargin"))
        showGrid = coder.decodeBool(forKey: "showGrid")
    }
    
    override init() {
        super.init()
    }
    
    override init(withText : String) {
        super.init(withOp: "_grid", args: [HierarchicExp(withText: " ")])
    }

    func copyGrid() -> HierGrid {
        let theCopy = HierGrid()
        theCopy.op = op
        theCopy.name = name
        theCopy.value = value
        theCopy.string = string
        theCopy.draw = draw?.copyDraw()
        if graph != nil {
            do {
               let data = try NSKeyedArchiver.archivedData(withRootObject: graph!, requiringSecureCoding: false)
                do {
                    theCopy.graph = try NSKeyedUnarchiver.unarchivedObject(ofClass: Grapher.self, from: data)
                } catch {
                    print("Couldn't decode")
                }
            } catch {
                print("Couldn't encode")
            }
        }
        theCopy.result = result?.copyExp()
        for arg in args {
            theCopy.addArg(arg.copyExp(removeView: false))
        }
        theCopy.father = father
        theCopy.cols = cols
        theCopy.rows = rows
        theCopy.colWidths = colWidths
        theCopy.rowHeights = rowHeights
        theCopy.gridWidth = gridWidth
        theCopy.gridHeight = gridHeight
        theCopy.hAligns = hAligns
        theCopy.vAligns = vAligns
        theCopy.hAligns = hAligns
        theCopy.hMargin = hMargin
        theCopy.vMargin = vMargin
        theCopy.showGrid = showGrid
        return theCopy
    }
    
    
    init(cols: Int, rows: Int, arguments: [HierarchicExp] = []) {
        let n = cols * rows
        var theArgs = arguments
        if arguments.count > n {
            theArgs.removeLast(arguments.count - n)
        }
        while theArgs.count < n {
            theArgs.append(HierarchicExp(withText: " "))
        }
        super.init(withOp: "_grid", args: theArgs)
        self.cols = cols
        self.rows = rows
        colWidths = Array(repeating: 10, count: cols)
        rowHeights = Array(repeating: 10, count: rows)
        rowOffsets = Array(repeating: 5, count: cols)
        hAligns = Array(repeating: "left", count: cols)
        vAligns = Array(repeating: "baseline", count: rows)
    }
    
    // création d'une gridLine
    init(gridLineArgs: [HierarchicExp] = []) {
        super.init(withOp: "_grid", args: gridLineArgs)
        cols = gridLineArgs.count
        rows = 1
        colWidths = Array(repeating: 10, count: cols)
        rowHeights = Array(repeating: 10, count: 1)
        rowOffsets = Array(repeating: 5, count: cols)
        hAligns = Array(repeating: "left", count: cols)
        vAligns = Array(repeating: "baseline", count: 1)
        vMargin = defaultvMargin
        hMargin = defaulthMargin
    }
    
    // détermination s'il s'agit de la grille de base d'une page
    var isBaseGrid : Bool {
        if father == nil { return false }
        if father!.op == "_page" && argInFather == 0 { return true}
        return false
    }
    
    //...ou d'une grille-ligne
    var islineGrid : Bool {
        if rows > 1 { return false }
        if isBaseGrid { return false }
        if father == nil { return false }
        if father!.father == nil { return false}
        if father!.father!.op == "_page" {return true}
        return false
    }
    
    override var isCustomGrid : Bool {
        if isBaseGrid { return false }
        if islineGrid { return false }
        if father == nil { return false }
        if father!.op != "_grid" { return false}
        return true
    }
    
    // fonctions pour ajouter ou supprimer des rangs et colonnes
    func addColumn(col : Int) {
        cols = cols + 1
        (0..<rows).forEach({ row in
            let n = row * cols + col
            insertArg(at: n, newExp: HierarchicExp(withText: " "))
        })
        colWidths.insert(10, at: cols-1)
        hAligns.insert(hAligns[0], at : cols-1)
    }
    
    func deleteColumn(col: Int) {
        if col < 0 || col >= cols {return}
        (0..<rows).forEach({ r in
            let row = rows - r - 1
            let n = row * cols + col
            args[n].deleteSubviews()
            args.remove(at: n)
        })
        cols = cols - 1
        colWidths.remove(at: cols)
        hAligns.remove(at: cols)
    }
    
   
    func addRow(row : Int) {
        rows = rows + 1
        (0..<cols).forEach({ col in
            let n = row * cols + col
            insertArg(at: n, newExp: HierarchicExp(withText: " "))
         })
        rowHeights.insert(10, at: rows-1)
        rowOffsets.insert(10, at: rows-1)
        vAligns.insert(vAligns[0], at : rows-1)
    }
    
    func deleteRow(row : Int) {
        if row < 0 || row >= rows { return }
        (0..<cols).forEach({ c in
            let col = cols - c - 1
            let n = row * cols + col
            args[n].deleteSubviews()
            args.remove(at: n)
         })
        rows = rows - 1
        rowHeights.remove(at: rows)
        rowOffsets.remove(at: rows)
        vAligns.remove(at: rows)
    }
    
    // insère des arguments en rang ou en colonne
    func insertArgs(col: Int, args: [HierarchicExp]) {
        if args.count != rows { return }
        cols = cols + 1
        (0..<rows).forEach({ row in
            let n = row * cols + col
            insertArg(at: n, newExp: args[row])
        })
        colWidths.insert(10, at: cols-1)
        hAligns.insert(hAligns[0], at : cols-1)
    }
    
    func insertArgs(row: Int, args: [HierarchicExp]) {
        if args.count != cols { return }
        rows = rows + 1
        (0..<cols).forEach({ col in
            let n = row * cols + col
            insertArg(at: n, newExp: args[col])
        })
        rowHeights.insert(10, at: rows-1)
        rowOffsets.insert(10, at: rows-1)
        vAligns.insert(vAligns[0], at : rows-1)
    }
    
    // scinde une grille-ligne en retournant les deux parties (sous forme de grilles ou d'éléments selon le cas)
    func splitLineGrid(at: Int) -> [HierarchicExp?] {
        var exp1 : HierarchicExp?
        var exp2 : HierarchicExp?
        if at < -1 || at > cols - 1 { return [nil,nil] }
        if at == -1 {
            exp1 = HierarchicExp(withText: " ")
        } else if at == 0 {
            exp1 = args.first!
        } else {
            exp1 = HierGrid(gridLineArgs: Array(args.dropLast(cols-at-1)))
        }
        if at < cols - 2 {
            exp2 = HierGrid(gridLineArgs: Array(args.dropFirst(at+1)))
        } else if at == cols - 2 {
            exp2 = args.last!
        } else if at == cols - 1 {
            exp2 = HierarchicExp(withText: " ")
        }
        return [exp1,exp2]
    }
    
    func testGrid() {
        let n = rows * cols
        while nArgs < n {
            addArg(HierarchicExp(withText: " "))
            print("il manque un arg ?")
        }
        if nArgs > n && cols == 1 {
            rows = n
            print("un arg de trop ?")
        }
        else if nArgs < n && rows == 1 {
            cols = n
            print("un arg de trop ?")
        }
        while nArgs > n {
            removeArg(nArgs-1)
            print("un arg de trop ?")
        }
    }
    
    func resetToEmpty() {
        deleteSubviews()
        rows = 1
        cols = 1
        args = []
        addArg(HierarchicExp(withText: " "))
    }
    

    // rang et colonne pour l'argument n° n dans une grid
    func colAndRow(ofArg: Int) -> (col:Int, row: Int) {
        let row = ofArg / cols
        let col = ofArg % cols
        return (col,row)
    }
    
    // numéro de l'argument référencé pour une grid
    func argNumber(col: Int, row: Int) -> Int {
        return row * cols + col
    }
    
    // argument pour une grid
    func argAt(col: Int, row: Int) -> HierarchicExp {
        return args[argNumber(col: col, row: row)]
    }
}

// Cette classe contient les paramètres de dessin de l'expression

class HierDraw : NSObject, NSSecureCoding {
    var origin : NSPoint = NSPoint(x: 0, y: 0) // position du coin supérieur gauche
    var size : NSSize = NSSize(width: 0, height: 0) // dimensions
    var innersize : NSSize  = NSSize(width: 0, height: 0)  // dimensions internes (sans cadres et connecteurs mais avec pars)
    var offset : CGFloat = 0 // décalage de la ligne de base par rapport au sommet (= theTop)
    var calcHeight : CGFloat = 0 // hauteur sans tenir compte du résultat)
    var calcOffset : CGFloat = 0 // idem pour le offset
    var pars : Bool = false // faut-il entourer de parenthèses ?
    var eqnPosition : CGFloat?
    var connectorOffset : CGFloat?
    var settings : [String:Any]?
        // "font" : NSFont
        // "textcolor" : NScolor
        // "framewidth": CGFloat (si nil => pas de cadre)
            // "framecolor": NSColor
            // "framefillcolor" : NSColor (si nil => pas de remplissage)
            // "innergrid" : Bool (si nil => pas de grille) - blocs seulement
            // "framemargin": CGFloat (marge entre cadre et contenu)
        // "connector" : Character
        // "leftpar" : Character
        // "rightpar" : Character
        // "blockspacing" : nil = fit, 0 = auto, >0 = fixed
        // "gridsize" : [Int]
        // "colwidths" [CgFloat] = largeur des colonnes d'un grid
        // "rowheigths" [CGFloat] = hauteur des rangs d'un grid
        // "rowoffsets" [CGFloat] = décalage de la ligne d'écriture des équations par rapport au sommet du rang
        // "gridwidth" : String "fit", "equal", "prop" (garde les proportions), "manual" ajuste seulement si manque de place
        // "gridheight" : idem
        // "haligns" : [String]
        // "valigns" : [String]
        // "hmargin", "vmargin" espaces  auour de chaque élément
        // "halign" : "left" (=défaut), "right", "center"
        // "valign" : "top", "bottom", "baseline" = défaut
        // "format" : "float", "sci" , "auto" = défaut
        // "digits" : bool (vrai -> la précision indique le nbre de chiffres significatifs, sinon le nbre de décimales)
        // "precision" : integer
        // "smalldiv" : bool (si vrai, on écrit la division comme a/b au lieu de a sur b)
        // "hypermatview" : [Int] (numéro de la dimension et de l'indice pour le "slice" à visualiser
    
    static var supportsSecureCoding: Bool = true
    
    override init() {
        origin = NSPoint(x: 0, y: 0)
        size = NSSize(width: 0, height: 0)
        offset = CGFloat(0)
        pars = false
    }
    
    convenience init(withSettings : [String:Any]) {
        self.init()
        self.settings = withSettings
    }
    
    var rect : NSRect {
        let newOrigin = NSPoint(x: origin.x, y: origin.y - size.height)
        return NSRect(origin: newOrigin, size: size)
    }
    
    func copyDraw() -> HierDraw {
        let r = HierDraw()
        r.origin = origin
        r.size = size
        r.innersize = innersize
        r.offset = offset
        r.pars = pars
        r.settings = settings
        return r
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(origin,forKey: "origin")
        aCoder.encode(size,forKey: "size")
        aCoder.encode(Float(offset),forKey: "offset")
        aCoder.encode(pars, forKey: "pars")
        if let settings = settings {aCoder.encode(settings, forKey: "settings")}
    }
    
    required init?(coder: NSCoder) {
        origin = coder.decodePoint(forKey: "origin")
        size = coder.decodeSize(forKey: "size")
        offset = CGFloat(coder.decodeFloat(forKey: "offset"))
        pars = coder.decodeBool(forKey: "pars")
        settings = coder.decodeObject(of: [NSDictionary.self, NSArray.self, NSColor.self, NSFont.self, Unit.self, NSString.self, NSNumber.self], forKey: "settings") as? [String : Any]
    }
    
}

// ajoute ou modifie des settings dans un drawsetting
// si new contient une clé "size" ou "resize" ou "trait", old doit contenir "font" et la valeur doit être CGFloat (= taille ou facteur de taille de la police) ou NSFontTraitMask
func drawSettings(old: [String:Any], new: [String: Any]) -> [String:Any] {
    var newSettings = old
    for item in new.keys {
        if item == "size" {
            let theFont = old["font"] as! NSFont
            newSettings["font"] = NSFontManager.shared.convert(
                theFont,
                toSize: new[item] as! CGFloat)
        } else if item == "resize" {
            let theFont = old["font"] as! NSFont
            newSettings["font"] = NSFontManager.shared.convert(
                theFont,
                toSize: theFont.pointSize * (new[item] as! CGFloat))
        } else if item == "trait" {
            newSettings["font"] = NSFontManager.shared.convert(old["font"] as! NSFont, toHaveTrait: new[item] as! NSFontTraitMask)
        }
        else {
            newSettings[item] = new[item]
        }
    }
    return newSettings
}
