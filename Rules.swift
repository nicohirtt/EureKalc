//
//  Rules.swift
//  EureKalc
//
//  Created by Nico on 06/01/2020.
//  Copyright © 2020 Nico Hirtt. All rights reserved.
//

import Foundation
import Cocoa

var rulesArray : [mathRule] = []
//var rulesString = ""
var autoRules : [mathRule] = []


class mathRule {
    var type : String = "M"
    var hexp1 : HierarchicExp = HierarchicExp()
    var hexp2 : HierarchicExp = HierarchicExp()
    var path : [Int] = [] // chemin d'accès de l'équation à cliquer
    var name : String = ""
    var label : String = ""
    
    func labelForLanguage(lang: String, def: Bool = true) -> String {
        if lang == "" { return label }
        if rulesTranslations[lang] == nil { return (def ? label : "") }
        return rulesTranslations[lang]![name] ?? (def ? label : "")
    }
        
    init(stringArray : [String] ) {
        self.type = stringArray[0]
        self.hexp1 = fromPolnish(stringArray[1])
        self.hexp1.name = stringArray[1]
        self.hexp2 = fromPolnish(stringArray[2])
        self.hexp2.name = stringArray[2]
        self.path = []
        if stringArray[3] != "." {
            for char in stringArray[3] {
                self.path.append(Int(String(char)) ?? 0)
            }
        }
        self.name = stringArray[4]
        if stringArray.count < 6 {
            self.label = stringArray[4]
        } else {
            self.label = stringArray[5]
        }
    }
    
    init(name: String) {
        self.name = name
    }
    
    // l'équation qu'il faut cliquer pour activer la règle
    var clickedExp : HierarchicExp {
        var hexpc = hexp1
        if path.count > 0 {
            for n in path {
                if hexpc.args.count <= n { return hexp1 }
                hexpc = hexpc.args[n]
            }
        }
        return hexpc
    }
    
    // teste cette règle sur l'expression (cliquée) et retourne nil ou la solution.
    func tryRule(onExp: HierarchicExp) -> (newExp: HierarchicExp, pathLevel: Int)? {
        
        var r1 = self.clickedExp // l'epxression qu'il faut cliquer (cible du path) dans la règle
        var r2 = onExp // l'expression testée
        var pathLevel = path.count // Cette variable spéciale retourne le "level" utilisé dans "executeCurrentRuleNumber" pour savoir quelle cible il faut remplacer !
        var vars : [String:HierarchicExp] = [:]
        // test montant
        if r1.op == "_var" { vars[r1.string! + ""] = r2 }
        else if r1.op != r2.op { return nil }
        while r1.father != nil  {
            r1 = r1.father!
            if r2.father == nil { return nil }
            if r1.op == "_var" {
                r2 = r2.father!
                vars[r1.string! + ""] = r2
            }
            else if r1.op != r2.father!.op {
                let modl = r1
                if !["*","+"].contains(r1.op) { return nil }
                if r1.nArgs != 2 { return nil }
                if r1.args[1].op != "_var" { return nil }
                if r1.args[1].string == nil { return nil }
                let restName = modl.args[1].string!
                if !restName.hasPrefix("r") { return nil }
                let rValue = (modl.op == "*") ? 1.0 : 0.0
                let reste = HierarchicExp(op: r1.op)
                reste.addArg( HierarchicExp(withPhysVal: PhysValue(doubleVal: rValue)))
                vars[restName + ""] = reste
                pathLevel = pathLevel - 1
            } else {
                r2 = r2.father!
            }
        }
        
        // test descendant et copie des valeurs
        let test = r2.testEquivalence(modl: r1, vars: vars)
        if test == nil { return nil }
        // on retourne la solution
        let newExp = self.hexp2.replaceVars(vars: test!)
        return (newExp,pathLevel)
    }
    
}

extension HierarchicExp {
    
    // teste récursivement si l'expression correspond à un modèle en gérant un dictionnaire de valeurs temporaires ; retourne le nouveau dictionnaire (ou nil si le test échoue).
    // le dernier élément du dictionnaire retourné est la longueur du chemin d'accès effectif (qui peut être plus court que le chemin d'accès théorique si on a un a+r = a ou un a*r = a
    func testEquivalence(modl: HierarchicExp, vars: [String:HierarchicExp]) -> [String:HierarchicExp]? {
        //let comOps = ["*","+","="] // les opérateurs commutatifs n-aires
        var newVars = vars
        // Gestion d'une variable modèle
        if modl.op == "_var" {
            let varName = modl.string! + ""
            // test de valeurs numériques
            if varName.hasPrefix("m") || varName.hasPrefix("n") { // on attend un nombre dans la cible
                if op != "_val" { return nil }
                if !value!.isNumber { return nil }
            } else if varName.hasPrefix("i") || varName.hasPrefix("j") || varName.hasPrefix("k") { // on attend un entier
                if op != "_val" { return nil }
                if !value!.isNumber { return nil }
                if !value!.isInteger { return nil }
            } else if varName.hasPrefix("ct") { // on attend une cte ou une variable supposée indépendante de x)
                if op != "_val" {
                    if op != "_var" { return nil }
                    let xVar = String(varName.dropFirst(2).dropLast())
                    if self.string == xVar { return nil}
                }
            }
            if newVars[varName] == nil {
                // création d'une nouvelle variable
                newVars[varName] = copyExp()
            } else {
                // test d'une variable existante
                if !newVars[varName]!.isIdentical(self) { return nil }
            }
            return newVars
        }
        // comparaison de deux valeurs
        if modl.op == "_val" && op == "_val" {
            if modl.value == nil || value == nil {return nil}
            if !modl.value!.isIdentical(value!) { return nil}
            return newVars
        }
        
        // Opérateurs différents
        if modl.op != op {
            // si opérateur +,* et contient 2 args dont reste et self est équivalent à arg 1 du modèle -> ok
            if ["*","+"].contains(modl.op) && modl.nArgs == 2 {
                if modl.args[1].op == "_var" && modl.args[1].string != nil {
                    let restName = modl.args[1].string!
                    if restName.hasPrefix("r") {
                        let rValue = (modl.op == "*") ? 1.0 : 0.0
                        let reste = HierarchicExp(op: modl.op)
                        reste.addArg( HierarchicExp(withPhysVal: PhysValue(doubleVal: rValue)))
                        newVars[restName + ""] = reste
                        let newNewVars = self.testEquivalence(modl: modl.args[0], vars: newVars)
                        if newNewVars != nil {
                            return newNewVars!
                        }
                    }
                }
            }
            // sinon la règle ne s'applique pas !
            return nil
        }
        
        // opérateurs NON communtatifs
        if !["*","+","="].contains(modl.op) {
            if nArgs !=  modl.nArgs { return nil }
            for (n,modlArg) in modl.args.enumerated() {
                let test = args[n].testEquivalence(modl: modlArg, vars: newVars)
                if test == nil { return nil }
                newVars = test!
            }
            return newVars
        }
        
        // cas d'un opérateur n-aire commutatif ("*","+","=")
        var usedCiblArgs : [Int] = []
        var restName = ""
        var allName = ""
        var befName = ""
        var aftName = ""
        var found = false
        
        let thePerms = permutationsOfIndexes[min(modl.nArgs,7)]! // pas plus de 7 arguments dans le modèle...
        // on parcourt toutes les permutations possibles des arguments du modèle
        for (p,aPerm) in thePerms.enumerated() {
            newVars = vars
            //var n = 0
            usedCiblArgs = []
            restName = ""
            allName = ""
            befName = ""
            aftName = ""
            found = false
            
            // on passe en revue tous les arguments du modèle dans l'ordre de la permutation en cours
            for k in 0...modl.nArgs-1 {
                let modlArg = modl.args[aPerm[k]]
                var treatedArg = false
                
                // est-on arrivé à une variable "r", "all", etc...? => gestion des "restes"
                if modlArg.op == "_var" {
                    if modlArg.string == nil { return nil }
                    let varName = modlArg.string!
                    if varName.hasPrefix("r") {
                        restName = varName
                        treatedArg = true
                    } else if varName.hasPrefix("all") {
                        allName = varName
                        treatedArg = true
                    } else if varName.hasPrefix("bef") {
                        if p != 0 { return nil }
                        befName = varName
                        treatedArg = true
                    } else if varName.hasPrefix("aft") {
                        if p != 0 { return nil }
                        aftName = varName
                        treatedArg = true
                    }
                }
                
                if treatedArg {
                    found = true
                } else {
                    // ce n'est pas une variable de type 'r', "all", "bef", "aft"
                    found = false
                    for (m,ciblArg) in args.enumerated() {
                        if !usedCiblArgs.contains(m) {
                            let test = ciblArg.testEquivalence(modl: modlArg, vars: newVars)
                            if test != nil {
                                usedCiblArgs.append(m)
                                newVars = test!
                                found = true
                                break // trouvé : arrêt boucle arguments de la cible
                            }
                        }
                    }
                }
                if !found { break } // aucune correspondance : arrêt boucle arguments modèle, permutation suivante
            }
            if found { break } // trouvé une permutation qui fonctionne : arrêt de la boucle permutation
        }
        if !found { return nil } // aucune permutation n'a fonctionné : on sort de là
        
        // calcul des listes restantes
        if restName != "" {
            let reste = HierarchicExp(op: op)
            if args.count > 0 {
                for k in 0...args.count-1 {
                    if !usedCiblArgs.contains(k) {
                        reste.addArg(args[k].copyExp())
                    }
                }
            }
            newVars[restName + ""] = reste
        }
        if allName != "" {
            let reste = HierarchicExp(op: op)
            if args.count > 0 {
                for k in 0...args.count-1 {
                    reste.addArg(args[k].copyExp())
                }
            }
            newVars[allName + ""] = reste
        }
        if befName != "" {
            let reste = HierarchicExp(op: op)
            if args.count > 0 {
                for k in 0...args.count-1 {
                    if k < usedCiblArgs[0] {
                        reste.addArg(args[k].copyExp())
                    }
                }
            }
            newVars[befName + ""] = reste
        }
        if aftName != "" {
            let reste = HierarchicExp(op: op)
            if args.count > 0 {
                for k in 0...args.count-1 {
                    if k > usedCiblArgs[0] {
                        reste.addArg(args[k].copyExp())
                    }
                }
            }
            newVars[aftName + ""] = reste
        }
        //Si on n'a pas de reste et trop de variables....
        if ( restName == "" && allName == "" && aftName == "" && befName == "" && args.count > modl.args.count) {
            return nil
        }
        return newVars
    }
    
    
    // remplace récursivement les variables par leur expression dans le résultat et ses arguments
    func replaceVars(vars : [String:HierarchicExp]) -> HierarchicExp {
        let op = self.op
        if op == "_val" {
            return self.copyExp()
        }
        if op == "_var" {
            let varName = self.string! + ""
            if vars[varName] == nil { return self.copyExp() }
            return vars[varName]!.copyExp()
        }
        if op == "_calc" {
            let exp = self.args[0]
            let res = exp.replaceVars(vars: vars)
            return res.calculateNum()
            /*
            let resVal = executeHierarchicScript(theScript: res)
            let r = HierarchicExp(withPhysVal: resVal)
            return r
             */
        }
        if op == "_gcd" {
            var arrayOfInts : [Int] = []
            var smallestInt : Int = 1
            for (i,arg) in self.args.enumerated() {
                let argVal = abs((arg.replaceVars(vars: vars)).executeHierarchicScript().asInteger!)
                arrayOfInts.append(argVal)
                if i == 0 {smallestInt = argVal}
                else if argVal < smallestInt { smallestInt = argVal }
            }
            if smallestInt < 1 { smallestInt = 1}
            for k in 1...smallestInt {
                let div = smallestInt-k+1
                var test = true
                for anInt in arrayOfInts {
                    if anInt % div != 0 {
                        test = false
                        break
                    }
                }
                if test == true {
                    return HierarchicExp(withPhysVal: PhysValue(intVal: div))
                }
            }
            
        }
        let r = HierarchicExp(op: op)
        for arg in self.args {
            var argTreated = false
            if arg.op == "_var" {
                let varName = arg.string! + ""
                if varName.hasPrefix("r") || varName.hasPrefix("all") || varName.hasPrefix("bef") || varName.hasPrefix("aft") {
                    argTreated = true
                    let theRest = vars[varName] ?? HierarchicExp(op: op)
                    if theRest.nArgs == 0 {
                        if theRest.op == "*" {
                            r.addArg(HierarchicExp(withPhysVal: PhysValue(doubleVal: 1.0)))
                        } else {
                            r.addArg(HierarchicExp(withPhysVal: PhysValue(doubleVal: 0.0)))
                        }
                    } else {
                        for restArg in theRest.args {
                            //let newArg = replaceVars(inExp: restArg.copyExp(), vars: vars)
                            //r.addArg(newArg)
                            r.addArg(restArg.copyExp())
                        }
                    }
                }
                
            }
            else if ["_each","_first","_last","_firsts","_lasts"].contains(arg.op) {
                var subExp : HierarchicExp?
                var listName : String = ""
                if arg.nArgs == 2 {
                    subExp = arg.args[0].copyExp()
                    listName = arg.args[1].string!
                } else {
                    listName = arg.args[0].string!
                }
                var listArgs = vars[listName + ""]!.args
                if listArgs.count > 0 && arg.op != "_each" {
                    switch arg.op {
                    case "_first" : listArgs = [listArgs.first!]
                    case "_last" : listArgs = [listArgs.last!]
                    case "_firsts" : listArgs.removeLast()
                    case "_lasts" : listArgs.removeFirst()
                    default : listArgs = []
                    }
                }
                for element in listArgs {
                    if subExp == nil {
                        let newArg = element.replaceVars(vars: vars)
                        r.addArg(newArg)
                    } else {
                        var newVars = vars
                        newVars["v"] = element
                        let newArg = subExp!.replaceVars(vars: newVars)
                        r.addArg(newArg)
                    }
                }
                argTreated = true
            }
            
            if !argTreated {
                let newArg = arg.replaceVars(vars: vars)
                r.addArg(newArg)
            }
     
        }
        return r
    }
    
    // Applique récursivement les règles de siplification
    func simplify() -> HierarchicExp {
        let copy = self.copyExp()
        for arg in copy.args {
            arg.simplify().replaceExp(arg)
        }
        var old = copy
        var new = copy.applyFirstAutoRule()
        var k : Int = 0 // éviter qu'on boucle à l'infini s'il y a des incohérences dans les règles...
        while new != nil && k < 500 && !new!.isIdentical(old, commute: false){
            old = new!
            new = new!.applyFirstAutoRule()
            k = k + 1
        }
        return old
    }

    // Retourne une expression simplifiée par la première règle auto trouvée
    // ou nil si aucune règle n'a été appliquée
    func applyFirstAutoRule() -> HierarchicExp? {
        
        // Exécution des règles préprogrammées
        let copy = self.copyExp()
        
        
        if copy.op == "_minus" {
            if copy.nArgs == 0 { return zeroHexp }
            else if copy.nArgs == 1 && copy.args[0].op == "_val" {
                let theValue = copy.args[0].value!
                if theValue.type == "double" {
                    let newVals = (theValue.values as! [Double]).map({ -($0) })
                    copy.args[0].value!.values = newVals
                    return copy.args[0]
                } else if theValue.type == "int" {
                    let newVals = (theValue.values as! [Int]).map({ -($0) })
                    copy.args[0].value!.values = newVals
                    return copy.args[0]
                }
            }
        }
        
        
        if copy.op == "+" {
            if copy.nArgs == 0 { return zeroHexp }
            else if copy.nArgs == 1 { return copy.args[0] }
            else {
                // somme de sommes
                let foundSum = self.findArgWithOp(theOp: "+")
                if foundSum != nil {
                    var n = foundSum!
                    let theSum = (copy.args[foundSum!]).copyExp()
                    copy.removeArg(foundSum!)
                    for anArg in theSum.args {
                        copy.insertArg(at: n, newExp: anArg)
                        n = n + 1
                    }
                    return copy
                }
            }
        }

        else if copy.op == "*" {
            // produit sans facteur
            if copy.nArgs == 0 { return oneHexp }
            else if copy.nArgs == 1 { return copy.args[0] }
            else {
                // produit avec un facteur comportant un opérateur moins => le moins devant
                let foundMinus = copy.findArgWithOp(theOp: "_minus")
                if foundMinus != nil {
                    let newfac = copy.args[foundMinus!].args[0].copyExp()
                    copy.replaceArg(n: foundMinus!, newExp: newfac)
                    return HierarchicExp(op: "_minus", [copy.copyExp()]).simplify()
                } else {
                    // idem mais avec une valeur numérique négative.
                    let foundMinVal = copy.findArgWithNegVal()
                    if foundMinVal != nil {
                        let newfac = copy.args[foundMinVal!]
                        newfac.value!.values[0] = -(newfac.value!.asDouble!)
                        copy.replaceArg(n: foundMinVal!, newExp: newfac)
                        return HierarchicExp(op: "_minus", [copy.copyExp()]).simplify()
                    }
                }
            }
        }

        
        // Exécution des règles "utilisateur" dans le fichier
         for rule in autoRules {
             let test = rule.tryRule(onExp: copy)
             if test != nil {
                 return test!.newExp
             }
         }
        return nil
    }
    
    // recherche toutes les règles applicables à l'expression exp
    func getRulesForExp(type : String = "M") -> [(rule: mathRule, newExp: HierarchicExp, pathLevel: Int)] {
        var result : [(rule: mathRule, newExp: HierarchicExp, pathLevel : Int)] = []
        var foundRulesResults : [String] = [self.stringExp()]
        for rule in rulesArray {
            if !rule.name.hasPrefix("//") {
                let ruleResult = rule.tryRule(onExp: self)
                if ruleResult != nil {
                    let simplified = ruleResult!.newExp.simplify()
                    if !foundRulesResults.contains(simplified.stringExp()) {
                        result.append((rule: rule, newExp: simplified, pathLevel: ruleResult!.pathLevel))
                        foundRulesResults.append(simplified.stringExp())
                    }
                }
            }
        }
        
        result.sort(by: { (object1, object2) -> Bool in
                 return object1.pathLevel < object2.pathLevel
        })
        
        return result
    }

    
    // tenter d'isoler cet élément dans l'équation. Retourne l'ancêtre après résolution ou nil.
    func isolateExp() -> HierarchicExp? {
        let theRules = self.getRulesForExp()
        for aRule in theRules {
            if aRule.rule.type == "I"  {
                return aRule.newExp
            }
        }
        // On n'a pas trouvé de règle directe : on travaille sur le père puis on revient
        let fath = self.father
        if fath == nil { return nil }
        let k = self.argInFather
        let intermediate = fath!.isolateExp()
        if intermediate == nil { return nil }
        let nextExp = intermediate!.args[0].args[k]
        let solution = nextExp.isolateExp()
        return solution
    }

    func replaceVarWithExp(v: String, exp: HierarchicExp) -> HierarchicExp {
        if self.op == "_var" {
            if self.string == v {
                return exp.copyExp()
            }
            return self.copyExp()
        } else if self.op == "_val" {
            return self.copyExp()
        } else {
            let r = HierarchicExp(op: self.op)
            for arg in self.args {
                let newArg = arg.replaceVarWithExp(v: v, exp: exp)
                r.addArg(newArg)
            }
            return r
        }
    }
    
}



// ***********************************

// retourne une représentation des règles sous forme de chaîne exportable
func rulesArrayToString(missing: Bool = false) -> String {
    let sep = "\t"
    var theString = "#RULES\n\n"
    for aRule in rulesArray {
        var pathString = ""
        if aRule.path.count == 0 { pathString = "." }
        for x in aRule.path {
            pathString = pathString + String(x)
        }
        if aRule.name.hasPrefix("//") {
            theString.append(aRule.name + "\n")
        } else {
            let aRuleString = aRule.type + sep + (aRule.hexp1.name ?? "") + sep + (aRule.hexp2.name ?? "") + sep + pathString + sep + aRule.name + sep + aRule.label + "\n"
            theString.append(aRuleString)
        }
     }
    for lang in rulesTranslations.keys {
        theString.append("\n\n#LANG" + sep + lang + "\n")
        for aRule in rulesArray {
            if !theString.contains("\n" + aRule.name + sep) && !aRule.name.hasPrefix("//") {
                let translation = aRule.labelForLanguage(lang: lang, def: false)
                if missing && translation == "" {
                    theString.append(aRule.name + sep + "***missing***" + "\n")
                } else {
                    theString.append(aRule.name + sep + translation + "\n")
                }
            }
         }
    }
    return(theString)
}

// transforme le contenu d'un fichier de règles en tableaux de règles et de langues
func rulesStringToArray(rulesString: String) {
    rulesArray = []
    autoRules = []
    rulesTranslations = [:]
    let sep = Character("\t")
    let lines = rulesString.split(separator: "\n")
    var mode = ""
    for aLine in lines {
        if aLine.hasPrefix("#") {
            if aLine.hasPrefix("#RULES") { mode = "rules" }
            else if aLine.hasPrefix("#LANG") && aLine.contains(sep) && aLine.count > 6 {
                mode = String(aLine.split(separator: sep ,maxSplits: 1)[1])
                rulesTranslations[mode] = [:]
            } else { mode = "" }
        }
        else if mode == "rules" {
            var ruleDef : [String] = []
            if !String(aLine).hasPrefix("//") && String(aLine) != "" {

                let splittedLine = String(aLine).split(separator: sep, maxSplits: 5,omittingEmptySubsequences: false)
                for element in splittedLine {
                    ruleDef.append(String(element))
                }
                if ruleDef[0] == "A" {
                    autoRules.append(mathRule(stringArray: ruleDef))
                }
            } else if String(aLine).hasPrefix("//") {
                ruleDef = ["","","","",String(aLine),""]
            }
            rulesArray.append(mathRule(stringArray: ruleDef))
        } else if mode != "" {
            if !String(aLine).hasPrefix("//") && String(aLine) != "" {
                let langLineElements = aLine.split(separator: sep, maxSplits: 1)
                if langLineElements.count == 2 {
                    rulesTranslations[mode]![String(langLineElements[0])] = String(langLineElements[1])
                }
            }
        }

    }
}



