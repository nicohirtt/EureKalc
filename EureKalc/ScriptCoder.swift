//
//  calculator.swift
//  calculator
//
//  Created by Nico on 17/10/14.
//  Copyright (c) 2014 Nico Hirtt. All rights reserved.
//

import Foundation

// Ce fichier fournit des fonctions permettant la transformation d'un script ou d'une expression mathématique
// depuis la notation courante (algébrique avec parenthèses) vers la notation polonaise ou la notation hiérarchique

// gestion des scripts en format hiérarchique

var functionNames = ["abs","sqrt","int","round","bool","sin","cos","tan","exp","ln","Log","log","atan","asin","acos","not","text","table","button","checkbox","slider","image","simtime","population","populate","break","clearconsole","console","sequence","normaldis","uniformdis","randombool","repeat","count","sum","mean","variance","std","min","max","norm","density","uniformclasses","quantiles","frequency","freq","rfreq","rfrequency","means","totals","cov","r2","dims","dim","type","matrix","indexed","field","color","grey","gray","colors","plot","page","print","run","extract","vec","list"]

func codeScriptHierarchic(script : String) -> HierarchicExp {
    // script contient plusieurs lignes d'instructions qui peuvent être des notations algébriques ordinaires ou des commandes de script
    // commandes autorisées : IF...ELSE...ENDIF, WHILE...LOOP, FOR...NEXT, FUNCTION...END
    let scriptArray = script.components(separatedBy: "\n")
    let theScript = HierarchicExp()
    theScript.string = ""
    theScript.op = "SCRIPT_BLOC"
    var findNext = ""
    var counter = 0 // compteur de boucles imbriquées
    var blocScript = ""
    var blocArg = HierarchicExp()
    for scriptLn in scriptArray {
        let scriptLine = scriptOperatorsToFunctions(algExp: keyWordInString(theString: scriptLn))
        switch findNext {
            // recherche de la fin ou de la suite d'un bloc conditionnel ou répétitif si nécessaire
        
        case "ELSE" :
            if scriptLine.hasPrefix("IF(") {
                counter += 1
                blocScript += ( scriptLine + "\n")
            }
            else if (scriptLine == "ENDIF") && counter>0 {
                counter += -1
                blocScript += ( scriptLine + "\n")
            }
            else if (scriptLine == "ELSE") && counter==0 {
                findNext = "ENDIF"
                blocArg.addArg(codeScriptHierarchic(script: blocScript))
                blocScript = ""
            }
            else if (scriptLine == "ENDIF") && counter==0 {
                findNext = ""
                blocArg.addArg(codeScriptHierarchic(script: blocScript))
                theScript.addArg(blocArg)
            }
            else {
                blocScript += ( scriptLine + "\n")
            }

            
        case "ENDIF" :
            if scriptLine.hasPrefix("IF(") {
                counter += 1
                blocScript += ( scriptLine + "\n")
            }
            else if (scriptLine == "ENDIF")  && counter>0 {
                counter += -1
                blocScript += ( scriptLine + "\n")
            }
            else if scriptLine == "ENDIF" && counter == 0 {
                findNext = ""
                blocArg.addArg(codeScriptHierarchic(script: blocScript))
                theScript.addArg(blocArg)
            }
            else {
                blocScript += ( scriptLine + "\n")
            }
         
        case "END" :
            if scriptLine.hasPrefix("FUNCTION") {
                counter += 1
                blocScript += ( scriptLine + "\n")
            }
            else if (scriptLine == "END")  && counter>0 {
                counter += -1
                blocScript += ( scriptLine + "\n")
            }
            else if scriptLine == "END" && counter == 0 {
                findNext = ""
                blocArg.addArg(codeScriptHierarchic(script: blocScript))
                theScript.addArg(blocArg)
            }
            else {
                blocScript += ( scriptLine + "\n")
            }
            

        case "LOOP" :
            if scriptLine.hasPrefix("WHILE") {
                counter += 1
                blocScript += ( scriptLine + "\n")
            }
            else if scriptLine == "LOOP"  && counter>0 {
                counter += -1
                blocScript += ( scriptLine + "\n")
            }
            else if scriptLine == "LOOP" && counter == 0 {
                findNext = ""
                blocArg.addArg(codeScriptHierarchic(script: blocScript))
                theScript.addArg(blocArg)
            }
            else {
                blocScript += ( scriptLine + "\n")
            }

          
        case "NEXT" :
            if scriptLine.hasPrefix("FOR") {
                counter += 1
                blocScript += ( scriptLine + "\n")
            }
            else if scriptLine == "NEXT"  && counter>0 {
                counter += -1
                blocScript += ( scriptLine + "\n")
            }
            else if scriptLine == "NEXT" && counter == 0 {
                findNext = ""
                blocArg.addArg(codeScriptHierarchic(script: blocScript))
                theScript.addArg(blocArg)
            }
            else {
                blocScript += ( scriptLine + "\n")
            }

        default :
            // on n'est pas (encore) dans un bloc            
            let codedLine = algebToHierarchic(scriptLine)
            if codedLine.op == "error" { return codedLine }
            
            switch codedLine.op {
                    
            case "IF" :
                blocScript = ""
                findNext = "ELSE"
                counter = 0
                blocArg = codedLine
                
            case "WHILE" :
                blocScript = ""
                findNext = "LOOP"
                counter = 0
                blocArg = codedLine
                
            case "FOR" :
                blocScript = ""
                findNext = "NEXT"
                counter = 0
                blocArg = codedLine
                
            case "FUNCTION" :
                blocScript = ""
                findNext = "END"
                counter = 0
                blocArg = codedLine
                
            default :
                blocArg = codedLine
                if scriptLine != "" {
                    theScript.addArg(blocArg)
                }
            }
        }
        
     }
    return theScript
}

// transforme une ligne d'expression en format "hiérarchique"
func algebToHierarchic(_ algExp : String) -> HierarchicExp {
    // traitement des commentaires
    if algExp.hasPrefix("#") {
        let result = HierarchicExp()
        result.op = "_comment"
        result.string = String(algExp.dropFirst())
        return result
    }
    // traitement des majuscules et minuscules dans les noms de fonctions
    var clearedExp = algExp
    for aFuncName in functionNames {
        if aFuncName != "log" && aFuncName != "Log" {
            let upper = aFuncName.uppercased() + "("
            let caped = aFuncName.capitalized + "("
            let lower = aFuncName.lowercased() + "("
            clearedExp = clearedExp.replacingOccurrences(of: upper, with: aFuncName + "(")
            clearedExp = clearedExp.replacingOccurrences(of: caped, with: aFuncName + "(")
            clearedExp = clearedExp.replacingOccurrences(of: lower, with: aFuncName + "(")
        }
    }
    let newExp = firstScriptExpTreatment(algExp: clearedExp)
    let result = algebToHierarchicIterate(newExp)
    if result.op == "_err" {
        let result2 = HierarchicExp(op: "_val")
        result2.value = PhysValue(string: algExp)
        result.args = [result2]
    }
    return result
}


func algebToHierarchicIterate(_ algExp : String) -> HierarchicExp {
    // transforme une ligne d'expression en format "hiérarchique"
    let result = HierarchicExp()
    let expArray = mainOpInExpression(algExp: clearparsInAlgExp(algExp: algExp)) // opérateur suivi des opérandes (en chaînes)
    let op = keyWordInString(theString: expArray[0] )
    if op == "_var" {
        result.op = "_var"
        result.string = expArray[1]
        if expArray.count>2 {
            result.value = PhysValue(numExp: "0.0["+expArray[2]+"]")
        }
    }
    else if op == "_val" {
        result.op = "_val"
        result.value = PhysValue(numExp: expArray[1])
        result.string = expArray[1]
    } else if op == "_bool" {
        result.op = "_val"
        result.value = PhysValue(boolVal: (expArray[1] == "TRUE"))
        result.string = expArray[1]
    } else if op == "_string" {
        result.op = "_val"
        result.value = PhysValue(unit: Unit(num:false), type : "string", values: [expArray[1]])
        result.string = expArray[1]
    } else {
        result.op = op
        var resname = ""
        for resItem in expArray.dropFirst() {
            let itemExp = algebToHierarchicIterate(resItem)
            resname = resname + (itemExp.string ?? "") + op
            let newArg = algebToHierarchicIterate(resItem)
            if newArg.op == "_err" {
                result.op = "_err"
                return result
            }
            result.addArg(newArg)
        }
        result.string = resname
    }
    return result
}

func mainOpInExpression(algExp : String) -> [String] {
    // Cette fonction retourne un array contenant l'opérateur principal (1er item) et ses arguments éventuels
    // L'expression algébrique est supposée ne plus contenir que des variables, fonctions, nombres au format produit par 'retrieveNames'
    var algExpCleared = clearparsInAlgExp(algExp: algExp)
    // on crée d'abord une copie de l'expression où les éléments entre () sont remplacés par des blancs
    let withoutPars = copyWithoutLowLevelPars(algExp: algExpCleared)
    if withoutPars == "_err" { return ["_err"] }
    if withoutPars.count > algExpCleared.count {
        let dif = withoutPars.count - algExpCleared.count
        let sup = withoutPars.suffix(dif)
        algExpCleared = algExpCleared + sup
    }
    var algExpHighLevel = withoutPars as NSString
    var unitString = ""
    // teste si c'st un forcage d'unité
    
    if algExpHighLevel.hasSuffix("]") {
        let splitted = algExpCleared.split(separator: "[")
        unitString = String(splitted.last!.dropLast())
        algExpHighLevel = String(algExpCleared.dropLast(unitString.count + 2)) as NSString
    }
    
    // ensuite on cherche l'opérateur principal : on parcourt les opérateurs n-aires dans l'ordre, puis les fonctions
    for op in operatorsList {
        var loc = (algExpHighLevel.range(of: op)).location
        if loc != NSNotFound {
            var result = [op == "//" ? "/" : op] as [String]
            let args = algExpHighLevel.components(separatedBy: op) as [String]
            // que faire s'il n'y a qu'un seul argument ???
            if op == "-" {
                if args[0] == "" {
                    result[0] = "_minus"
                    let arg = String(String(algExpCleared).dropFirst())
                    result.append(arg)
                } else if args.count == 2 {
                    result[0] = "+"
                    loc = 0
                    result.append((algExpCleared as NSString).substring(with: NSRange(location : loc , length : args[0].count)))
                    loc = loc + args[0].count + (op as NSString).length
                    let arg2 = "-(" + (algExpCleared as NSString).substring(with: NSRange(location : loc , length : args[1].count)) + ")"
                    result.append(arg2)
                } else {
                    result[0] = "+"
                    var arg1 = args[0] as String
                    for i in 1...args.count-2 {
                        arg1 += op
                        arg1 += (args[i] as String)
                    }
                    var len = arg1.count
                    result.append((algExpCleared as NSString).substring(with: NSRange(location : 0, length : len)))
                    loc = len + 1
                    len = args[args.count-1].count
                    let arg2 = (algExpCleared as NSString).substring(with: NSRange(location : loc, length : len))
                    result.append("-(" + arg2 + ")")
                }
            }
            else if (op == "/" || op == "%"  || op == "^" || op == "#" || op == "@" ) && args.count < 2 {
                return ["_err"]
            }
            else if (op == "/" || op == "%"  || op == "^" || op == "#" || op == "@" ) && args.count > 2 {
                // dans le cas des - et /, il faut retenir une opération binaire avec le dernier opérateur
                loc = 0
                var arg1 = args[0] as String
                for i in 1...args.count-2 {
                    arg1 += op
                    arg1 += (args[i] as String)
                }
                var len = arg1.count
                result.append((algExpCleared as NSString).substring(with: NSRange(location : 0, length : len)))
                loc += len + 1
                len = args[args.count-1].count
                result.append((algExpCleared as NSString).substring(with: NSRange(location : loc, length : len)))
            }
            else {
                loc = 0
                for arg in args {
                    if arg == "" { return ["_err"] }
                    let len = arg.count
                    result.append((algExpCleared as NSString).substring(with: NSRange(location : loc , length : len)))
                    loc += len + (op as NSString).length
                }
            }
            if unitString != "" {
                if op == "," || op == "_var" {
                    result = ["_setunit",String(algExpHighLevel),"_val(1["+unitString+"])"]
                } else if result.count > 1 {
                    let last = result.last! + "[" + unitString + "]"
                    result = result.dropLast(1)
                    result.append(last)
                }
            }
            return result
        }
    }
    // s'il y a un ")" à la fin, on traite comme une fonction
    if algExpHighLevel.hasSuffix(")") {
        let location = (algExpHighLevel.range(of: "(")).location
        let funcName = algExpHighLevel.substring(to: location) as String
        var result = [funcName]
        var arg = (unitString != "" && funcName == "_var") ?
            (algExpHighLevel as NSString).substring(from: location+1) as NSString :
            (algExpCleared as NSString).substring(from: location+1) as NSString
        let l = arg.length
        arg = arg.substring(to: l-1) as NSString
        if funcName == "_string" {
            result.append(arg as String)
            return result
        }
        let arg2 = copyWithoutLowLevelPars(algExp: arg as String)
        let args = arg2.components(separatedBy: ",")
        var loc = 0
        for theArg in args {
            // il faut récupérer le contenu des parenthèses !
            let len = theArg.count
            let theFullArg = arg.substring(with: NSRange(location : loc, length : len))
            if theFullArg.count > 0 {
                result.append(theFullArg as String)
            }
            loc += (len + 1)
        }
        if unitString != "" && funcName  == "_var" {
            result = ["_setunit","_var(" + String(arg) + ")","_val(1["+unitString+"])"]
        }
        return result
    }
    
    // simple commande
    return [algExpCleared]
}

func copyWithoutLowLevelPars(algExp:String) -> String {
    // crée une copie où les contenus des parenthèses sont vides
    var algExp2 = ""
    var nivPar = 0
    var typePar : [Character] = []
    let parCorrespondances : [Character:Character] = ["(":")","[":"]","{":"}"]
    for c in algExp {
        if c == "(" || c == "[" || c == "{" {
            nivPar = nivPar + 1
            typePar.append(c)
            algExp2 = algExp2 + String(c)
        }
        else if (c == ")" || c == "]" || c == "}") && nivPar > 0 {
            nivPar = nivPar-1
            typePar.removeLast()
            algExp2 = algExp2 + String(c)
        }
        else {
            if nivPar>0 {
                algExp2 = algExp2 + " "
            }
            else {
                algExp2 = algExp2 + String(c)
            }
        }
    }
    // on ferme les parenthèses si l'usager a oublié !
    while nivPar > 0 {
        algExp2.append(parCorrespondances[typePar.last!]!)
        typePar.removeLast()
        nivPar = nivPar-1
    }
    return algExp2
}

func clearparsInAlgExp(algExp : String) -> String {
    // Cette fonction nettoie une expression algébrique string de ses parenthèses superflues
    var nivPar = 0
    let l = algExp.count
    for c in algExp {
        if c == "(" || c == "{" {
            nivPar = nivPar + 1
        }
        else if c == ")" || c == "}" {
            nivPar = nivPar-1
        }
        else if nivPar==0 {
            return algExp // tout n'est pas sous parenthèses donc on peut rentrer à la maison
        }
    }
    if l>2 {
        // on efface les parenthèses extérieures et on re-nettoie
        return clearparsInAlgExp(algExp: ((algExp as NSString).substring(to: l-1) as NSString).substring(from: 1))
    }
    return algExp
}

func scriptOperatorsToFunctions(algExp : String) -> String {
    // Cette fonction transforme les instruction de type "IF x<10" en "IF(x<10)"
    var clearedExp = algExp.trimmingCharacters(in: CharacterSet.whitespaces) // supprime les espaces devant et derrière
    while (clearedExp as NSString).range(of: "  ").location != NSNotFound {
        clearedExp = clearedExp.replacingOccurrences(of: "  ",with:" ") // supprime les doubles espaces
    }
    clearedExp = clearedExp.replacingOccurrences(of: " (", with:"(") // supprime les espaces devant parenthèses
    for word in wordsWithArguments {
        if (clearedExp as NSString).hasPrefix(word + " ") {
            clearedExp = clearedExp.replacingOccurrences(of: word + " (", with: word+"(") // "word (" -> "word("
            clearedExp = clearedExp.replacingOccurrences(of: word + " ", with: word+"(") + ")" // "word " -> "word(  )"
            return clearedExp
        }
    }
    return clearedExp
}


func firstScriptExpTreatment(algExp : String) -> String {
    // cette fonction lit une expression algébrique puis y remplace tous les nombres et variables
    // par des expressions du type _var("variable"), _val("nombre")
    
    // si l'expfression commence ou se termine par un espace, on la traite comme un label
    if algExp.hasPrefix(" ") { return "label(_string(" + algExp.dropFirst() + "))"}
    if algExp.hasSuffix(" ") { return "label(_string(" + algExp.dropLast() + "))"}

    var state = ""
    var newAlgExp = ""
    var value = ""
    var prev = ""
    var unit = ""
    var waitingString = ""
    var awaitedQuote = ""
    let openQuotes = ["\"","«","\'"]
    let closeQuotes = ["\"","»","\'"]
    var clearedExp = algExp.replacingOccurrences(of: " ", with:" ") // suppression des blancs durs
    clearedExp = clearedExp.replacingOccurrences(of: "<=", with: "≤")
    clearedExp = clearedExp.replacingOccurrences(of: ">=", with: "≥")
    clearedExp = clearedExp.replacingOccurrences(of: "!=", with: "≠")
    clearedExp = clearedExp.replacingOccurrences(of: "{", with: "@(") // l'opérateur @ => la fonction @
    clearedExp = clearedExp.replacingOccurrences(of: "}", with: ")")
    clearedExp = clearedExp.replacingOccurrences(of: "∙", with: "*")
    clearedExp = clearedExp.replacingOccurrences(of: " AND ", with: "*")
    clearedExp = clearedExp.replacingOccurrences(of: " OR ", with: "+")


    for c in clearedExp {
        var ch = String(c)
        
        if state == "divisionOrUnit?" {
            if ch == " " { ch = "" }
            //waitingString += ch

            if unitsByName[unit+ch] != nil {
                // c'était bien une unité : on clôture
                state = "unit"
                value += "/"
                //value += ch
                waitingString = ""
            }
            else {
                // c'était une simple division !
                state = ""
                value += "]"
                newAlgExp += "_val(" + value + "])" + waitingString
                waitingString = ""
                unit = ""
            }
        }
        
        if state == "" {
            if ch == " " {  }
            else if isLetter(c: ch) { // début de lecture d'un nom (variable ou fonction)
                state = "name"
                value = ch
            }
            else if isQuote(c: ch) { // début de lecture d'une chaine
                let q = openQuotes.firstIndex(of: ch)
                awaitedQuote = closeQuotes[q!]
                state = "string"
                value = ""
            }
            else if isDigit(c: ch) { // début de lecture d'un nombre
                state = "num"
                value = ch
            }
            else if ch == "[" {
                state = "unitOnly"
                value = ch
            }
            else {
                newAlgExp += ch
            }
        }
        else if state == "num" {
            if ch == " " { }
            else if ch == "." || isDigit(c: ch) || (isExpSign(c: ch) && isDigit(c: prev)) || ((ch == "+") || ch == "-") && (isExpSign(c: prev)) {
                value += ch // ajouter ce caractère au nombre
            }
            else if ch == "[" {
                state = "unitBrackets"
                value += ch // commencer à lire l'unité associée au nombre
            }
            else if ( isOperator(c: ch) == false && ch != ")" ) {
                state = "unit"
                value += "[" + ch // commencer à lire l'unité associée au nombre
                unit += ch
            }
            else {
                state = ""
                newAlgExp += "_val(" + value + ")" + ch // fin de lecture du nombre
            }
        }
        else if state == "name" {
            if ch == " " { }
            else if isVarChar(c: ch) {
                value += ch // continuer la lecture du nom
            }
            else if ch == "[" {
                newAlgExp += "_var(" + value + ")[" // précision de l'unité forcée de la variable
                value = ""
                state = "unitOnly"
            }
            else if ch == "(" {
                newAlgExp += value + "(" // fin de la lecture du nom de la fonction
                state = ""
            }
            else {
                if ["TRUE","FALSE","True","False","true","false"].contains(value) {
                    newAlgExp += "_bool(" + value.uppercased() + ")" + ch
                } else {
                    newAlgExp += "_var(" + value + ")" + ch // fin de lecture de variable
                }
                state = ""
            }
        }
        else if state == "string" {
            if ch == awaitedQuote {
                newAlgExp += "_string(" + value + ")" // fin de lecture  d'une chaine
                state = ""
            }
            else {
                value += ch
            }
        }
        else if state == "unit" {
              // unité qui n'est pas entre [] => seul opérateur éventuellement accepté = "/"
            if ch == " " { ch = "" }
            else if ch == "/" {
                state = "divisionOrUnit?"
                unit += "/"
                waitingString = "/"
            }
            else if isOperator(c: ch) || ch==")" {
                state = ""
                newAlgExp += "_val(" + value + "])" + ch // fin de lecture d'un nombre avec unité
            }
            else {
                unit += ch
                value += ch
            }
        }
        else if state == "unitOnly" {
            if ch == " " {  }
            else if ch == "]" {
                state = ""
                newAlgExp += value + "]" // fin de lecture d'une unité seule (comme argument ou comme déclaration de type du résultat d'un calcul)
            }
            else {
                value += ch
            }
        }
        else if state == "unitBrackets" {
            // si l'unité est entre [] on accepte les opérateurs
            if ch == " " {ch = "." }
            if ch == "*" {ch = "." }
            if ch == "^" {ch = "" }
            if ch == "]" {
                value += "]"
                state = ""
                newAlgExp += "_val(" + value + ")" // fin de lecture d'un nombre avec unité
            }
            else {
                value += ch
            }
        }
        /*
        else if state == "divisionOrUnit?" {
            if ch == " " {
                ch = ""
            }
            unit += ch
            waitingString += ch

            if unitsByName[unit] != nil {
                // c'était bien une unité : on clôture
                state = "unit"
                value += "/"
                value += ch
                //newAlgExp += "_val(" + value + waitingString
                waitingString = ""
            }
            else {
                // c'était une simple division !
                state = ""
                value += "]"
                newAlgExp += "_val(" + value + "])" + waitingString
                waitingString = ""
                unit = ""
            }
        }
         */
        prev = ch
    }
    if state == "name" {
        if ["TRUE","FALSE","True","False","true","false"].contains(value) {
            newAlgExp += "_bool(" + value.uppercased() + ")"
        } else {
            newAlgExp += "_var(" + value + ")" // fin de lecture de variable
        }
    }
    if state == "num" {
        newAlgExp += "_val(" + value + ")" // fin de lecture du nombre
    }
    if state == "unit" {
        newAlgExp += "_val(" + value + "])" // fin de lecture du nombre avec unité
    }
    return newAlgExp
}

func isDigit(c : String) -> Bool {
    // c est un chiffre
    if c == "∞" { return true }
    if c >= "0" && c <= "9" { return true }
    return false
}

func isQuote(c : String) -> Bool {
    // c est un guillemet
    if c == "\""  || c == "«" || c == "»" || c=="\'" { return true }
    return false
}

func isExpSign(c : String) -> Bool {
    // c est le symbole de l'exposant des nombres en notation scientifique
    if c == "e" || c == "E" { return true }
    return false
}

func isBracket(c: String) -> Bool {
    if (bracketsList as NSArray).contains(c) { return true }
    return false
}

func isLetter(c: String) -> Bool {
    // c est une lettre (et peut donc être le premier caractère d'un nom de variable)
    if isDigit(c: c) == false && isOperator(c: c) == false && isBracket(c: c) == false && isQuote(c: c) ==  false { return true}
    return false
}

func isVarChar(c : String) -> Bool {
    // c est un caractère autorisé dans les noms de variables (à partir de la deuxième position)
    if isOperator(c: c) == false && isBracket(c: c) == false  && isQuote(c: c) ==  false { return true}
    return false
}

func isOperator(c : String) -> Bool {
    if (operatorsList as NSArray).contains(c) { return true }
    return false
}

func keyWordInString(theString : String) -> String {
    // teste si la chaine commence par l'un des mots-clés du langage et retourne la chaine en ayant remplacé par le mot clé en version majuscules
    for key in scriptLanguageKeyWords {
        let n = key.count
        if theString.count >= n {
            let substring = theString.prefix(n)
            if key == substring.uppercased() {
                return key + (theString as NSString).substring(from: n)
            }
        }
    }
    return theString
}

// Crée une hierexp à partir d'une notation polonaise inverse
// initialisation à partir d'une chaine en notation polonaise inverse
func fromPolnish(_ pol : String) -> HierarchicExp {
    let polString = pol
    /*
    polString = polString.replacingOccurrences(of: "+", with: "_sum")
    polString = polString.replacingOccurrences(of: "*", with: "_prod")
    polString = polString.replacingOccurrences(of: "/", with: "_div")
    polString = polString.replacingOccurrences(of: "^", with: "_pow")
    */
    //polString = polString.replacingOccurrences(of: "-", with: "_minus")
    let hexp = algebToHierarchic(polString)
    clearFromPolnish(hexp)
    return hexp
}

// re-remplace les opérateurs fonctionnels par leur symbole normal
func clearFromPolnish(_ exp: HierarchicExp) {
    let newExp = exp
    let op = newExp.op
    switch op {
    case "_sum" : newExp.op = "+"
    case "_prod" : newExp.op = "*"
    case "_div" : newExp.op = "/"
    case "_pow" : newExp.op = "^"
    //case "_minus" : newExp.op = "-"
    default: newExp.op = op
    }
    for arg in exp.args {
        clearFromPolnish(arg)
    }
}
