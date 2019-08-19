//
//  Calculator.swift
//  calculator
//
//  Created by Nico on 17/10/14.
//  Copyright (c) 2014 Nico Hirtt. All rights reserved.
//

import Foundation
import Cocoa

var pi = 3.141592653589793238462643383279

func errorExpWithMessage(message : String) -> HierarchicExp {
    let theExp = HierarchicExp()
    theExp.op = "error"
    theExp.value = PhysValue(error:"message")
    return theExp
}


struct funcArgument {
    var name : String
    var requested : Bool // argument requis ou non ?
    var type: String // l'un des types de physval ou "exp" ou "popvar"
    var op: String? // l'opérateur requis si type = exp
    var unit : Unit?
    var dims : Int? // nombre de dimensions
    var dim : [Int]? // dimensions
    var defVal : PhysValue? // valeur par défaut
    var limits: [String:Double]? // genre ["≤":5,">":10] pour ≤5 et >10
    var repeating: Bool // Cet argument peut être répété (il doit se trouver à la fin). Avec les noms "1", "2", "3"...
    var mustBeNamed : Bool // reçoit la variable par défaut si pas nommément définie
    
    init(_ name: String, type: String = "any", op: String? = nil, requested: Bool = true, unit: Unit? = nil, dims: Int? = nil, dim : [Int]? = nil, defVal: PhysValue? = nil, limits: [String:Double]? = nil, repeating : Bool = false, mustBeNamed : Bool = false) {
        self.name = name
        if defVal != nil {
            self.requested = false
        } else {
            self.requested = requested
        }
        self.type = type
        self.op = op
        self.unit = unit
        self.dims = dims
        self.dim = dim
        self.defVal = defVal
        self.limits = limits
        self.repeating = repeating
        self.mustBeNamed = mustBeNamed
    }
}

extension HierarchicExp {
    
    // une procédure pour la gestion des arguments des fonctions...
    // analyse un array de funcArgument et retourne l'exp et/ou la valeur de chaque argument (ou "error")
    func testArguments(structure : [funcArgument]) -> [String:(exp:HierarchicExp?, phVal:PhysValue?)] {
        
        var acceptMore = -1
        var moreCounter : Int = 0
        let names = structure.map { $0.name }
        var r : [String:(exp:HierarchicExp?, phVal:PhysValue?)] = [:]
        var unused = Array(0..<structure.count)
        var defaultPop = ""
        let missingVar: Bool = false
        var repeatingVar = ""
        
        // écriture de le structure si argument unique = "?"
        if args.count == 1 {
            if args[0].isVar("?") {
                var message = op + "( "
                for (i,arg) in structure.enumerated() {
                    if i > 0 { message = message + " , "}
                    message = message + arg.name + " = [" + arg.type + "]"
                }
                message = message + " )"
                return ["error":(exp:HierarchicExp(withOp: "functiondescription", args: []), phVal: PhysValue(error: message))]
            }
        }
        
        for (argNum,arg) in args.enumerated() {
            var argName = ""
            var n = -1
            var argexp = arg.copyExp()
            if arg.op == "=" && arg.nArgs == 2 {
                // est-ce un argument nommé ?
                if arg.args[0].op == "_var" && arg.args[0].string != nil {
                    argName = arg.args[0].string!
                    argexp = arg.args[1]
                    if !names.contains(argName) {
                        // on accepte les noms d'arguments tronqués
                        let testPrefix = names.first(where: {$0.hasPrefix(argName)})
                        if testPrefix == nil {
                            return ["error":(exp:nil, phVal: PhysValue(error: "Wrong argument name " + argName))]
                        }
                        argName = testPrefix!
                    }
                    n = names.firstIndex(of: argName)!
                    unused.removeAll(where: {$0 == n})
                    acceptMore = -1
                } else {
                    return ["error":(exp:nil, phVal: PhysValue(error: "Assigning within an expression"))]
                }
                
            } else if unused.count > 0 && acceptMore == -1 {
                // ce n'est pas un argument nommé : alors on applique dans l'ordre...
                n=argNum
                argName = names[n]=="" ? "\(n)" : names[n]
                unused.removeAll(where: {$0 == n})

            } else {
                // tout ce qui reste...
                if acceptMore == -1 {
                    return ["error":(exp:nil, phVal: PhysValue(error: "Too much arguments"))]
                }
                moreCounter = moreCounter + 1
                n = acceptMore
                argName = names[n]=="" ? "\(n)" : names[n]
            }
            
            if n > -1 {
                let type = structure[n].type
                if structure[n].repeating == true && acceptMore == -1 {
                    // c'est une variable répétitive : à partir de maintenant, toutes les entrées sans nom sont de ce type
                    acceptMore = n
                    moreCounter = 0
                    repeatingVar = argName
                }
                if acceptMore > -1 {
                    argName = argName + String(moreCounter)
                }
                if type == "exp" {
                    // il ne faut pas retourner de valeur, seulement l'expression h.
                    if structure[n].op != nil {
                        if argexp.op != structure[n].op! {
                            return ["error":(exp:nil, phVal: PhysValue(error: "Wrong expression in " + argName))]
                        }
                    }
                    r[argName] = (exp: argexp, phVal: nil)
                } else if type == "popvar" {
                    // si on attend un nom de variable et/ou de population
                    var name = argexp.string
                    if argexp.op != "_var" || name == nil {
                        return ["error":(exp:nil, phVal: PhysValue(error: "Argument " + argName + " is not a valid population (variable) name"))]
                    }
                    if !(name!.contains(".")) {
                        if theSim.hasPop(name!) {
                           r[argName] = (exp:argexp, phVal: PhysValue(string: "population"))
                            defaultPop = name!
                        } else if defaultPop != "" {
                            name = defaultPop + "." + name!
                            argexp.string = name // on retourne le nom complet
                        } else {
                            return ["error":(exp:nil, phVal: PhysValue(error: "Argument " + argName + " is not a valid population (variable) name"))]
                        }
                    }
                    if name!.contains(".") {
                        let comps = theSim.varComponents(varExp: name!)
                        if comps.pop == nil {
                            return ["error":(exp:nil, phVal: PhysValue(error: "Argument " + argName + " is not a valid population (variable) name"))]
                        }
                        defaultPop = comps.pop!
                        r[argName] = (exp:argexp, phVal: comps.value)
                    }
                } else {
                    // on effectue les tests nécessaires
                    var val = argexp.executeHierarchicScript()
                    if val.type == "error" {
                        return ["error":(exp:nil, phVal: PhysValue(error: "Error in argument " + argName))]
                    }
                    if val.type == "" {
                        return ["error": (exp:nil, phVal: errVal("Wrong argument " + argexp.stringExp()) ), argName: (exp:argexp, phVal: val)]
                        //missingVar = true
                    } else {
                        if type == "list" {
                            val = val.asList
                        } else if val.type != type && type != "any" && type != "" {
                            if (type == "string" && (val.type == "double" || val.type == "int")) {
                                return ["error":(exp:nil, phVal: PhysValue(error: "Error in argument " + argName))]
                                //val.values = val.asStrings!
                                //val.type = "string"
                            } else if !((type == "int" && val.type == "double") || ( type == "double" && val.type == "int")) {
                                return ["error":(exp:nil, phVal: PhysValue(error: "Wrong argument " + argName + " in " + self.stringExp() ))]
                            }
                            
                        }
                        if structure[n].unit != nil {
                            if !structure[n].unit!.isIdentical(unit: val.unit) {
                                return ["error":(exp:nil, phVal: PhysValue(error: "Wrong unit in " + argName))] }
                        }
                        if structure[n].dim != nil {
                            if structure[n].dim! != val.dim {
                                return ["error":(exp:nil, phVal: PhysValue(error: "Wrong dimensions in " + argName))] }
                        }
                        if structure[n].dims != nil {
                            if structure[n].dims! != val.dim.count {
                                return ["error":(exp:nil, phVal: PhysValue(error: "Wrong dimensions in " + argName))] }
                        }
                        if structure[n].limits != nil {
                            let errResult : [String:(exp:HierarchicExp?, phVal:PhysValue?)] = ["error":(exp: nil, phVal: PhysValue(error: argName + " out of limits"))]
                            for (key, limit) in structure[n].limits! {
                                for aVal in val.asDoubles! {
                                    switch key {
                                    case ">" : if aVal <= limit { return errResult }
                                    case "<" : if aVal >= limit { return errResult }
                                    case "≤" : if aVal > limit { return errResult }
                                    case "≥" : if aVal < limit { return errResult }
                                    case "≠" : if aVal == limit { return errResult }
                                    default : return errResult
                                    }
                                }
                                
                            }
                        }
                        r[argName] = (exp:argexp, phVal: val)
                    }
                }
            }
        }
        // on assigne la valeur par défaut aux arguments non trouvés
        for n in unused {
            let argName = names[n]=="" ? "\(n)" : names[n]
            if structure[n].requested {
                return ["error":(exp:nil, phVal: PhysValue(error: "Missing argument " + argName))] }
            r[argName] = (exp: nil, phVal: structure[n].defVal)
        }
        if repeatingVar != "" {
            // une variable nommée  "x" de type "repeating" retourne le nombre d'entrées pour cette variable
            // les entrées proprement dites se trouvent en "x1", "x2", "x3"
            r[repeatingVar] = (exp:nil, phVal: PhysValue(intVal: moreCounter+1))
        }
        if missingVar { return ["error": (exp:nil, phVal: errVal("Missing variable") )]} // variable non définie
        return r
    }
    
    
    
    // retourne la valeur calculée des arguments de theScript
    func calculatedArguments() -> [PhysValue] {
        var result = [PhysValue]()
        for arg in args {
            result.append(arg.executeHierarchicScript())
        }
        return result
    }
    
    // retourne un argument nommé
    func getArg(name: String, n: Int) -> HierarchicExp? {
        for arg in args {
            if arg.op == "=" && arg.args[0].op == "_var" && arg.args[0].string != nil {
                if name.hasPrefix(arg.args[0].string!) && arg.args.count==2 {
                    return arg.args[1]
                }
            }
        }
        if args.count > n { return args[n] }
        return nil
    }
    
    // Appel des fonctions par opérateur
    func executeHierarchicScript(editing: Bool = true) -> PhysValue {
        // Si getArgs != nil, retourne une physval "list" contenant les arguments demandés
        // utilisé occasionnellement par EquationView pour retrouver des arguments nommés
                
        if op == "" { return PhysValue() }
        switch op {
        
        
        // *********************
        // Boutons et interfaces
        // *********************
        
        
        // une boite de texte éditable
        case "text" : return xText()
            
        // un label de texte en une ligne (pour écrire un texte sans guillemets !)
        case "label" : return xLabel()
            
        // affichage d'un tableau (utilise la classe ekTableScrollView)
        case "table" : return xTable()
            
        // Affichage d'un bouton d'action
        case "button" : return xButton()
            
        // Affichage d'un popupbox
        case "popup", "menu" : return xPopup()
            
        // Affichage d'une checkbox
        case "checkbox" : return xCheckbox()
            
        // Affichage d'une série de boutons radio
        case "radiobuttons" : return xRadiobuttons()
            
        // Affichage d'un inputbox
        case "input" : return xInput()
        
        // Affichage d'un slider
        case "slider", "hslider", "vslider", "cslider" : return xSlider()
            
        // Affichage d'un stepper (pourquoi ça ne marche pas ???)
        case "stepper" : return xStepper()
            
        // Affichage d'une image
        case "image", "imagebox" : return xImage()
        
        // Exportation, importation
        case "export" : return xExport()
        case "import" : return xImport()
            
        // ***********
        // simulations
        // ***********
        
        // retourne le temps de la simulation
        case "simtime", "t" : return(theSim.vars["t"]!)
            
        // retourne le numéro de l'itération
        case "iteration" : return(PhysValue(intVal: theSim.loop))
            
        // création ou ajout de n éléments d'une population
        case "population", "populate" : return xPopulate()
            
        // suppression d'éléments d'une population
        case "remove" : return xRemove()
            
        // arrêt d'un script
        case "break", "BREAK" : return errVal("simulation stopped with break instruction")
            
        // nettoyage de la console
        case "clearconsole", "console" : mainCtrl.consoleTextView.string = ""
            
        // initialise la simulation
        case "initsim" : theSim.initiate()

        // démarre la simulation
        case "startsim" :
            theSim.initiate()
            theSim.startSim()
            
        // pause ou relance la simulation selon son état
        case "pausesim" :
            mainCtrl.pauseRunSimulation(self)
            
        // relance la simulation arrêtée
        case "runsim" : theSim.startSim()
            
        // arrête la simulation
        case "stopsim" : theSim.stopSim()
            
        // modifiecation du timer de la simulation
        case "simtimer" : return xSimtimer()
            
        // calcule les coordonnées i,j d'une cellule de la grille
        case "gridcell" : return xPopgridCoords()
            
        // recherche des individus voisins de coord dans une population
        case "neighbours" : return xNeighbours()
        
        // champ scalaire contenant le nombre d'individus ou la moyenne (ou somme) d'une variable
        case "gridfield", "gridsize" : return xPopulationGrid()
            
            
        // ************************
        // statistiques et vecteurs
        // ************************
        
        // séquence régulière (suite artithm. ou géom.)
        case "sequence" : return xSequence()
            
        // distribution normale centrée
        case "normaldis": return xNormaldis()
            
        // distribution log-normale
        case "lognormaldis": return xLogNormalDis()
            
        // distribution log-normale
        case "boltzmann", "maxwell": return xBoltzmann()
            
        // retourne n nombres aléatoires (distribution uniforme)
        case "uniformdis": return xUniformdis()
            
        // Choisit n nombre entiers entre 1 et k (k catégories) avec les probabilités spécifiées
        case "choose": return xChoose()
            
        // n  booléens avec des probabilités données par une ou des valeurs (0-1)
        case "randombool", "rndbool", "randbool" : return xRandombool()
            
        // vecteur répétant n fois la valeur x
        case "repeat" : return xRepeat()
            
        // nommbre d'éléments d'un vecteur (qui sont égaux au 2e argument, si indiqué)
        case "count" : return xCount()
            
        // limite les valeurs entre min et max (éventuellement en lissant avec smooth)
        case "limited" : return xLimited()
            
        // transforme les valeurs en index compris entre min et max (en recentrant avec center et pente slope)
        case "makeindex" : return xMakeIndex()
            
        // retourne le vecteur x rangé
        case "sorted", "sort": return xSorted()
            
        // retourne le vecteur x renversé
        case "reversed", "reverse": return xReversed()

        // Rotation d'une matrice
        case "rotate" : return xRotate()

        // fonction statistique sur un vecteur (sum, mean, variance, std, min, max, norm, median)
        case "sum", "prod", "mean", "variance", "var", "std", "sd", "stdev", "min", "max", "norm", "median" : return xStatfunctions()
            
        // calcul de classes, quantiles et densités
        case "classes", "density": return xClasses()
           
        // calcul de classes, quantiles et densités
        case "quantiles": return xQuantiles()
            
        // diverses fonctions statistiques opérant sur des classes
        case "stat", "stats", "statistics", "discrete", "freq", "sums", "rfreq","means", "vars", "stdevs" ,"stds", "sds", "medians", "dens", "densities"  :
            return xStats()
            
        // corrélation, covariance, R2, etc.
        case "cov","covariance", "r2","rsquare", "corr", "correlation" : return xCorrelations()
            
        // classification d'une séquence
        case "classify" : return xClassify()
            
            
            
        // ******************
        // Matrices et champs
        // ******************
        
        // dimensions d'une physval
        case "dims", "dim" : return xDim()
            
        // Création d'une matrice (ou hypermatrice) à partir de valeurs
        case "matrix" : return xMatrix()
            
        // Transposée d'une matrice (ou permutation des dimensions d'une hypermatrice)
        case "transpose" : return xTranspose()
            
        // Déterminant d'une matrice 2D carrée
        case "det", "determinant" : return xDeterminant()
            
        // Produit matriciel
        case "mprod", "matmult", "matprod" : return xMatrixProd()
            
        // création d'un champ à partir de données ou d'une fonction
        case "field" : return xField()
        case "matrixfield": return xMatfield()
            
        // valeur d'un champ au(x) point(s) de coordonnées (x, y, z)
        case "fieldval" : return xFieldVal()
            
        // doublement ou réduction de la résolution d'un champ par extrapolation
        case "doublefield", "reducefield" : return xDoubleField()
            
        // lissage d'un champ
        case "smoothfield" : return xSmoothField()

        // décalage des éléments d'une n-matrice
        case "shift", "shifted" : return xShiftmatrix()
            
        // ensemble de fonctions pour extraire (ou assigner) des parties de vecteurs, matrices et hyper-matrices
        case "indexed", "#", "slice", "submatrix", "submat", "@", "extract", "first", "last" :
            return xIndexesOfArray()
            
        // gradiant d'un champ scalaire -> retourne un champ vectoriel
        case "grad", "gradiant" : return xGradiant()
            
        // divergence d'un champ vectoriel -> retourne un champ scalaire
        case "div", "divergence" : return xDivergence()
        
        // informations sur un champ
        case "fieldorigin", "cellsize", "fieldsize", "fieldvector", "fieldinfo" : return xFieldInfo()
            
        // crée un dataframe à partir de colonnes de même longueur. Par défaut le nom de colonne est l'exp. Le nom de ligne est 1, 2, 3...
        case "dataframe" : return xDataframe()
            
        // retourne les noms de colonnes d'un dataframe
        case "colnames", "rownames" : return xColnames()
            
            
            
        // ********
        // Graphes
        // ********
        
        // retourne une physVal contenant une (ou des) couleurs à partir des composants r,g,b,a ou du nom
        case "color", "colour", "col" : return xColor()
            
        // retourne une physval contenant une couleur grise
        case "grey", "gray" : return xGray()
            
        // transforme un vecteur de doubles en vecteur de couleurs variables entre "start" et "end"
        // optionnellement, on peut spécifier les valeurs doubles "min" et "max" correspondantes
        // variante : x est un vecteur de booleens et on a deux couleurs possibles
        case "colors", "colours", "cols" : return xColors()
            
        // Dessin d'un graphe (chaque argument peut être une liste d'arguments $(...) )
        case "plot", "histo", "histogram", "lineplot", "scatterplot" : return xPlot()
            
        // Dessin d'un diagramme à barres
        case "barplot" : return xBarplot()
            
            
            
            
            
        // *******
        // scripts
        // *******
        
        // un commentaire : on ne fait rien !
        case "_comment" : return PhysValue()
            
        // retourne une physval contenant l'expression (au lieu d'exécuter cette expression)...
        case "$" : return PhysValue(unit: Unit(), type: "exp", values: args)
            
        // Ecrit le résultat des args dans la console
        case "print", "Print", "PRINT" : return xPrint()
            
        // Exécute les arguments (ou l'exp contenue dans la variable ou l'exp identifiée par son nom)
        case "execute", "do", "Do", "DO" : return xExecute()
            
        // Exécution d'un script identifié par son nom
        case "run", "Run", "RUN" : return xRun()
            
        // recalcul complet d'une page (identifiée par son nom ou son numéro)
        case "page", "Page", "PAGE" : return xPage()
            
        // structure conditionnelle
        case "IF", "If", "if" : return xIf()
            
        // structure répétitive 'tant que'
        case "WHILE", "While", "while" : return xWhile()
            
        // structure répétitive 'for next'
        case "FOR", "For", "for" : return xFornext()
            
        // définition d'une fonction complexe
        case "FUNCTION", "Function", "function" : return xFunction()
            
        // quitte la fonction en cours d'exécution en retournant un résultat
        case "RETURN", "Return", "return" : return xReturn()
            
        // un bloc d'expressions dans un script
        case "SCRIPT_BLOC" : return xScriptBloc()
            
        // définition de variables locales
        case "local", "Local", "LOCAL" : return xLocal()
            
            
            
        // *********************
        // opérateurs internes
        // *********************
        
        // l'objet actuellement en cours d'édition
        case "_edit" : return PhysValue()
            
        // bloc d'expressions
        case "_hblock", "_vblock", "_page", "_grid" : return xSysBloc()
            
        // retourne la valeur d'une variable
        case "_var" : return xSysVar()
            
        // retourne une valeur littérale
        case "_val" : return PhysValue(physval: value!)
            
        // lorsque l'interprétation de la commande est incompréhensible
        case "_err" : return errVal("Syntax error")
    
            
            
        // *********************
        // Mathématiques simples
        // *********************
        
        // fonctions unaires
        case "abs", "sqrt", "_minus", "int", "round", "bool" : return xMathfunc()
            
        // un nombre aléatoire
        case "rnd", "random" : return xRnd()
            
        // fonctions numériques sans unité
        case "sin","cos","tan","cot","sinh","cosh","tanh","coth","exp","ln","Log","atan","asin","acos", "acot" : return xTrigofunc()
            
        // logarithme en base quelconque
        case "log" : return xLogab()
            
        // négation d'un booléen
        case "not", "Not", "NOT" : return xNot()
            
        // opération n-aire
        case "+", "*" : return xAddmult()
            
        // opérations binaires
        case "-" , "/", "%", "^", "==", "≤", "≥" , ">", "<", "≠", "•", "**" : return xBinaryop()
            
        // forçage de l'unité
        case "_setunit" : return xSetunit()
            
        // produit externe
        case "***" , "outer" : return xOuter()
            
        // *******************
        // Calcul symbolique
        // *******************
            
        case "deriv", "derivative" : return xDeriv()
            
        case "integ", "integral" : return xIntegral()
            
        // *******************
        // Traitement de texte
        // *******************
        
        // transforme des nombres et boolsen chaînes
        case "string" : return xString()
            
        // transforme un vecteur de nombres en caractères 1=A, 2=B, etc...
        case "alpha" : return xAlpha()
            
        // codes ascii ou unicode -> chaine(s) ou l'inverse
        case "ascii", "unicode" : return xAscii()
            
        // longueur d'une chaine
        case "length" : return xLength()
            
        // extraction de n caractères (à gauche ou à droite) après omission évenuelle des 'drop' premiers (ou derniers)
        case "left", "right" : return xLeftright()
            
        // position d'une sous-chaine dans une chaine. Retourne -1 si inexistant
        case "position" : return xPosition()
            
        // Traite les arguments (expressions) comme des chaînes
        case "strings" : return xAsstrings()
        
        // Traite les chaines comme des expressions
        case "asexp" : return xAsexp()
            
        // Remplace des chaines par d'autres
        case "replace" : return xReplace()
            
            
        // ***********
        // Miscellanés
        // ***********
        
        // simple équation ou affectation d'une valeur à une variable ou définition de fonction
        case "=" : return xEquation()
            
        // effacement d'une variable ou de toutes les variables
        case "delete", "clear" : return xDelete()
            
        // Détermination du type d'un argument
        case "type" : return xType()
            
        // création d'un vecteur ou d'une liste
        case ",", "vec", "list" : return xVeclist()
            
        // séquence de nombres par a:b:c
        case ":" : return xQuicksequence()
            
        // appel de données ou fonctions de la librairie
        case "use" : return xUseLibElement()
            
        // **************************
        // Une fonction utilisateur ?
        // **************************
        
        default : return xCalcuserfunc()
            
        }
        
        return PhysValue()
    }
    
}

// Exécution des fonctions
extension HierarchicExp {
    
    // Calcule l'expression.
    // Si le résultat est une chaîne, exécute le script ou l'exp de ce nom s'il existe
    // s'il n'existe pas cherche une expression de ce nom.
    
    func calcIfNamed() -> PhysValue {
        let result = self.executeHierarchicScript()
        if result.type == "string" {
            let scriptName = result.asString!
            if theScripts[scriptName] != nil {
                theMainDoc!.currentScript = scriptName
                let test = theScripts[scriptName]!.executeHierarchicScript()
                if test.type == "error" {
                    mainCtrl.printToConsole("error: [" + result.asString!
                                                + "] in script: [" + scriptName
                                                + "] at line: [" + theMainDoc!.currentScriptLine + "]")
                }
                return PhysValue()
            } else if mainDoc.namedExps[scriptName] != nil {
                let keepSelection = mainCtrl.selectedEquation
                mainCtrl.selectedEquation = mainDoc.namedExps[scriptName]!
                mainCtrl.reRunExp(self)
                mainCtrl.selectedEquation = keepSelection
                return PhysValue()
            } else {
                return errVal("No script or expression named '" + scriptName + "'")
            }
        } else {
            return result
        }
    }
    
    // *********************
    // Boutons et interfaces
    // *********************
        
    // une boite de texte éditable
    func xText() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("string",type: "string", defVal: PhysValue(string: ""))])
        if test["error"] != nil { return test["error"]!.phVal! }
        let text = test["string"]!.phVal!.asString!
        if self.view == nil {
            var theSize : NSSize
            let theView = NSTextView()
            theView.importsGraphics = true
            theView.isRichText = true
            theView.drawsBackground = false
            self.view = theView
            mainDoc.mySubViews[theView] = self
            mainCtrl.theEquationView.subviews.append(theView)
            if self.atString == nil {
                theView.string = text
                self.atString = theView.attributedString()
                theSize = NSSize(width: 102, height: 52)
                if self.viewSize != nil {
                    theSize = self.viewSize!
                }
                self.setSize(theSize)
            } else {
                theSize = self.size
                theView.string = ""
                theView.textStorage!.setAttributedString(self.atString!)
            }
            theView.frame.size = NSSize(width: theSize.width-2, height: theSize.height-2)
        }
        return PhysValue()
    }
    
    // un label de texte en une ligne (pour écrire un texte sans guillemets !)
    func xLabel() -> PhysValue {
        let test = testArguments(structure: [
                                    funcArgument("string",type: "string")])
        if test["error"] != nil { return test["error"]!.phVal! }
        return PhysValue()
    }
    
    // affichage d'un tableau (utilise la classe ekTableScrollView)
    func xTable() -> PhysValue {
        let showLabels = self.drawSettingForKey(key: "showLabels") as? Bool ?? false
        self.setSetting(key: "showLabels", value: showLabels)
        let theArgs = self.op == "_var" ? [self] : self.args
        if view == nil {
            let theTable = ekTableScrollView()
            let test = theTable.initialise(cExps: theArgs, theExp: self, new: true)
            if test.type == "error" { return test }
            mainCtrl.theEquationView.subviews.append(theTable)
            mainDoc.mySubViews[theTable] = self
            view = theTable
            let prefWidth = min(theTable.colNames.count * 100,500)
            if draw != nil {
                if size.width > 0 {
                    theTable.resize(size)
                } else {
                    theTable.resize(NSSize(width: prefWidth, height: 100))
                    setSize(NSSize(width: prefWidth+2, height: 102))
                }
            } else {
                theTable.resize(NSSize(width: prefWidth, height: 100))
                if viewSize != nil {
                    theTable.resize(viewSize!)
                }
                setSize(NSSize(width: prefWidth+2, height: 102))
            }
            return PhysValue()
        } else {
            let returnValue = (view as! ekTableScrollView).initialise(cExps: theArgs, theExp: self, new: true)
            if returnValue.type == "error" {view!.removeFromSuperview() }
            return returnValue
        }
    }
    
    // Affichage d'un bouton d'action
    func xButton() -> PhysValue {
        if !editing && view != nil { return PhysValue() }
        let test = testArguments(structure:[
            funcArgument("script",type: "exp"),
            funcArgument("label",type: "string", defVal: PhysValue(string: ""))
        ])
        
        if test["error"] != nil { return test["error"]!.phVal! }
        let label = test["label"]!.phVal!.asString!
        value = test["script"]!.exp!.scriptToPhysValExp()
        if view == nil {
            let theButton = NSButton(title: label, target: mainCtrl, action: #selector(mainCtrl.controlActivated))
            mainCtrl.theEquationView.subviews.append(theButton)
            theButton.frame.size = NSSize(width: 100, height: 22)
            if viewSize != nil {
                theButton.frame.size =  viewSize!
            }
            view = theButton
            //mainDoc.mySubViews[theButton] = self
        } else {
            (view! as! NSButton).title = label
        }
        mainDoc.mySubViews[view!] = self
        return PhysValue()
    }
    
    // Affichage d'une checkbox
    func xCheckbox() -> PhysValue {
        if !editing && view != nil { return PhysValue() }
        let test = testArguments(structure:[
            funcArgument("var",type: "exp", op: "_var"),
            funcArgument("label",type: "string", requested: false),
            funcArgument("script", type: "exp", requested: false)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let varName = test["var"]!.exp!.string!
        let label = test["label"]?.phVal?.asString ?? varName
        if theVariables[varName] == nil {
            theVariables[varName] = PhysValue(boolVal: false)
        }

        value = (test["script"]!.exp == nil) ? nil: test["script"]!.exp!.scriptToPhysValExp()
        
        if view == nil {
            let theButton = NSButton(checkboxWithTitle: label, target: mainCtrl, action: #selector(mainCtrl.controlActivated))
            mainCtrl.theEquationView.subviews.append(theButton)
            theButton.frame.size = NSSize(width: 60, height: 20)
            if viewSize != nil {
                theButton.frame.size =  viewSize!
            }
            view = theButton
            mainDoc.mySubViews[theButton] = self
        }
        return PhysValue()
    }
    
    func xRadiobuttons() -> PhysValue {
        return errVal("This function is not yet implemented")
    }
    
    func xPopup() -> PhysValue {
        if !editing && view != nil { return PhysValue() }
        let test = testArguments(structure:[
            funcArgument("var",type: "exp", op: "_var"),
            funcArgument("items",type: "string", defVal: PhysValue(string: "")),
            funcArgument("script", type: "exp", requested: false),
            funcArgument("index", type: "bool", defVal: PhysValue(boolVal: false))
        ])
        
        if test["error"] != nil { return test["error"]!.phVal! }
        let varName = test["var"]!.exp!.string!
        let theItems = test["items"]!.phVal!.asStrings!
        if theVariables[varName] == nil {
            theVariables[varName] = PhysValue(boolVal: false)
        }
        value = (test["script"]!.exp == nil) ? nil: test["script"]!.exp!.scriptToPhysValExp()
        
        if view == nil {
            let theButton = NSPopUpButton()
            theButton.target = mainCtrl
            theButton.action = #selector(mainCtrl.controlActivated)
            theButton.frame.size = NSSize(width: 60, height: 20)
            theButton.removeAllItems()
            theButton.addItems(withTitles: theItems)
            if viewSize != nil {
                theButton.frame.size =  viewSize!
            }
            view = theButton
            mainCtrl.theEquationView.subviews.append(theButton)
            mainDoc.mySubViews[theButton] = self
        }
        return PhysValue()
        
        
    }
    
    // Affichage d'un champ d'entrée INPUT
    func xInput() -> PhysValue {
        if !editing && view != nil { return PhysValue() }
        let test = testArguments(structure: [
            funcArgument("var",type: "exp"),
            funcArgument("value", type: "double", requested: false),
            funcArgument("script", type: "exp", requested: false),
            funcArgument("label", type: "string", requested: false)
        ])
        
        if test["error"] != nil { return test["error"]!.phVal! }
        let varExp = test["var"]!.exp!
        if varExp.op != "_var" {return PhysValue(error:"wrong variable name") }
        let varName = varExp.string!
        value = (test["script"]!.exp == nil) ? nil: test["script"]!.exp!.scriptToPhysValExp()

        let val = test["value"]?.phVal
        if val != nil { theVariables[varName] = val! }
        
        var inputField : NSTextField
        
        if view == nil {
            inputField = NSTextField()
            inputField.target = mainCtrl
            inputField.action = #selector(mainCtrl.controlActivated)
            if val != nil { inputField.doubleValue = val!.valueInUnit }

            mainCtrl.theEquationView.subviews.append(inputField)
            if viewSize != nil {
                inputField.frame.size = viewSize!
            } else {
                inputField.frame.size = NSSize(width: 100, height: 20)
            }
            view = inputField
        } else {
            inputField = view! as! NSTextField
        }
        mainDoc.mySubViews[inputField] = self
        return PhysValue()
    }
    
    // Affichage d'un slider
    func xSlider() -> PhysValue {
        if !editing && view != nil { return PhysValue() }
        let sliderType = ["slider":"H","hslider":"H","vslider":"V","cslider":"C"][op]!
        let test = testArguments(structure: [
            funcArgument("var",type: "exp"),
            funcArgument("min", type: "double", requested: false, defVal: PhysValue(doubleVal: 0.0)),
            funcArgument("max", type: "double", requested: false, defVal: PhysValue(doubleVal: 1.0)),
            funcArgument("ticks", type: "int", requested: false),
            funcArgument("step", type: "double", requested: false),
            funcArgument("script", type: "exp", requested: false),
            funcArgument("label", type: "string", requested: false),
            funcArgument("value", type: "bool", defVal: PhysValue(boolVal: true)),
            funcArgument("continuous",type: "bool", requested: false)
        ])
        
        if test["error"] != nil { return test["error"]!.phVal! }
        let varExp = test["var"]!.exp!
        if varExp.op != "_var" {return PhysValue(error:"wrong variable name") }
        let varName = varExp.string!
        setSetting(key: "hideresult", value: !test["value"]!.phVal!.asBool!)
        let min = test["min"]!.phVal!
        let max = test["max"]!.phVal!
        if min.unit.isNilUnit() { min.unit = max.unit}
        if max.unit.isNilUnit() { max.unit = min.unit}
        if !min.unit.isIdentical(unit: max.unit) {return PhysValue(error:"min and max units should be of same type") }
        if min.asDouble! >= max.asDouble! {return PhysValue(error:"min > max ?") }
        var theSlider : NSSlider
        value = (test["script"]!.exp == nil) ? nil: test["script"]!.exp!.scriptToPhysValExp()
        
        if view == nil {
            let initV = theVariables[varName]?.asDouble ?? min.asDouble!
            theSlider = NSSlider(value: initV, minValue: min.asDouble!, maxValue: max.asDouble!, target: mainCtrl, action: #selector(mainCtrl.controlActivated))
            theSlider.isContinuous = false
            mainCtrl.theEquationView.subviews.append(theSlider)
            if theVariables[varName]?.isNumber ?? false {
                theSlider.doubleValue = theVariables[varName]!.asDouble!
            } else {
                theVariables[varName] = min
                theSlider.doubleValue = min.asDouble!
            }
        } else {
            theSlider = view! as! NSSlider
            theVariables[varName] = PhysValue(doubleVal: theSlider.doubleValue)
        }

        
        if sliderType == "c" || sliderType == "C" {
            theSlider.sliderType = NSSlider.SliderType.circular
            theSlider.frame.size = NSSize(width: 30, height: 30)
        } else {
            theSlider.sliderType = NSSlider.SliderType.linear
            if sliderType == "v" || sliderType == "V" {
                theSlider.isVertical = true
                theSlider.frame.size = NSSize(width: 21, height: 80)
            } else {
                theSlider.isVertical = false
                theSlider.frame.size = NSSize(width: 80, height: 21)
            }
            theSlider.controlSize = NSControl.ControlSize.small
        }
        if viewSize != nil {
            theSlider.frame.size = viewSize!
        }
        if test["ticks"]!.phVal != nil {
            theSlider.numberOfTickMarks = test["ticks"]!.phVal!.asInteger!
            theSlider.allowsTickMarkValuesOnly = true
        }
        if test["step"]!.phVal != nil {
            let step = test["step"]!.phVal!
            if !step.unit.isIdentical(unit: min.unit) { return errVal("wrong unit for step")}
            let n = 1 + Int((max.asDouble! - min.asDouble!)/step.asDouble!)
            theSlider.numberOfTickMarks = n
            theSlider.allowsTickMarkValuesOnly = true
        }
        // slider continu par défaut si pas de script
        if test["continuous"]?.phVal == nil {
            theSlider.isContinuous = (value == nil) ? true : false
        } else {
            theSlider.isContinuous = test["continuous"]!.phVal!.asBool!
        }

        theSlider.minValue = min.asDouble!
        theSlider.maxValue = max.asDouble!
        view = theSlider
        mainDoc.mySubViews[theSlider] = self
        return theVariables[varName]!
    }
    
    // Affichage d'un stepper
    
    func xStepper() -> PhysValue {
        if !editing && view != nil { return PhysValue() }
        let test = testArguments(structure: [
            funcArgument("var",type: "exp"),
            funcArgument("min", type: "double", requested: false, defVal: PhysValue(doubleVal: 0.0)),
            funcArgument("max", type: "double", requested: false, defVal: PhysValue(doubleVal: 100.0)),
            funcArgument("step", type: "double", requested: false, defVal: PhysValue(doubleVal: 1.0)),
            funcArgument("script", type: "exp", requested: false),
            funcArgument("label", type: "string", requested: false),
            funcArgument("value", type: "bool", defVal: PhysValue(boolVal: true))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let varExp = test["var"]!.exp!
        if varExp.op != "_var" {return PhysValue(error:"wrong variable name") }
        let varName = varExp.string!
        setSetting(key: "hideresult", value: !test["value"]!.phVal!.asBool!)
        let min = test["min"]!.phVal!
        let max = test["max"]!.phVal!
        if min.unit.isNilUnit() { min.unit = max.unit}
        if max.unit.isNilUnit() { max.unit = min.unit}
        if !min.unit.isIdentical(unit: max.unit) {return PhysValue(error:"min and max units should be of same type") }
        if min.asDouble! >= max.asDouble! {return PhysValue(error:"min > max ?") }
        if theVariables[varName] == nil { theVariables[varName] = min }
        if !theVariables[varName]!.unit.isIdentical(unit: min.unit) { theVariables[varName] = min  }
        if theVariables[varName]!.asDouble! < min.asDouble! { theVariables[varName] = min }
        if theVariables[varName]!.asDouble! > max.asDouble! { theVariables[varName] = max }
        var theStepper : NSStepper
        value = (test["script"]!.exp == nil) ? nil: test["script"]!.exp!.scriptToPhysValExp()
        if view == nil {
            theStepper = NSStepper()
            theStepper.frame.size = NSSize(width: 13, height: 21)
            theStepper.valueWraps = false
            theStepper.target = mainCtrl
            theStepper.action = #selector(mainCtrl.controlActivated)
            theStepper.controlSize = NSControl.ControlSize.small
        } else {
            theStepper = view! as! NSStepper
        }
        theStepper.isEnabled=true
        theStepper.minValue = min.asDouble!
        theStepper.maxValue = max.asDouble!
  
        if test["step"]!.phVal != nil {
            let step = test["step"]!.phVal!
            if !step.unit.isIdentical(unit: min.unit) { return errVal("wrong unit for step")}
            theStepper.increment = step.asDouble!
        }
        view = theStepper
        mainDoc.mySubViews[theStepper] = self
        return theVariables[varName]!
    }
     
    
    // Affichage d'une image
    func xImage() -> PhysValue {
        if !editing && view != nil { return PhysValue() }
        if view == nil {
            var theSize : NSSize
            if image == nil {
                image = NSImage()
                theSize = NSSize(width: 102, height: 52)
                setSize(theSize)
            } else {
                theSize = self.size
            }
            let theView = NSImageView()
            theView.isEditable = true
            theView.allowsCutCopyPaste = true
            theView.image = image
            theView.frame.size = NSSize(width: theSize.width-2, height: theSize.height-2)
            mainDoc.mySubViews[theView] = self
            mainCtrl.theEquationView.subviews.append(theView)
            self.view = theView
        }
        return PhysValue()
    }
    
    func xExport() -> PhysValue {
        if !editing && view != nil { return PhysValue() }
        let test = testArguments(structure: [
            funcArgument("var",type: "exp"),
            funcArgument("sep", type: "string", defVal: PhysValue(string: "\t")),
            funcArgument("dec", type: "string", requested: false)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let varExp = test["var"]!.exp!
        if varExp.op != "_var" {return PhysValue(error:"wrong variable name") }
        let varName = varExp.string!
        let sep = (test["sep"]!.phVal!.asString!)[0]
        let dec = (test["dec"]?.phVal?.asString ?? decimalSep)[0]
        return mainDoc.exportCSV(varName, sep: sep, dec: dec) ?? PhysValue()
    }
    
    func xImport() -> PhysValue {
        if !editing && view != nil { return PhysValue() }
        let test = testArguments(structure: [
            funcArgument("var",type: "exp"),
            funcArgument("sep", type: "string", defVal: PhysValue(string: "\t")),
            funcArgument("dec", type: "string", requested: false),
            funcArgument("type", type: "string", defVal: PhysValue(string: "auto"))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let varExp = test["var"]!.exp!
        if varExp.op != "_var" {return PhysValue(error:"wrong variable name") }
        let varName = varExp.string!
        let sep : Character = (test["sep"]!.phVal!.asString!)[0]
        let dec : Character = (test["dec"]?.phVal?.asString ?? decimalSep)[0]
        let type = String((test["type"]!.phVal!.asString! + "a").first!)
        let result = mainDoc.importCSV(varName, sep: sep, dec: dec,ftype: type)
        if result == nil { return PhysValue() }
        theVariables[varName] = result
        return PhysValue()
    }
    
    // ***********
    // simulations
    // ***********
    
    // création ou ajout de n éléments d'une population. Eventuellement répartis spatialement suivant un champ de densité "field"
    func xPopulate() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("pop", type: "string"),
            funcArgument("n", type: "int"),
            funcArgument("field", type: "double", requested: false)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let pop = test["pop"]!.phVal!.asString
        let n = test["n"]!.phVal!.asInteger
        if !theSim.hasPop(pop!) { return PhysValue(error:"Wrong population name") }
        if op == "population" {
            theSim.pops[pop!]!.create(n: n!)
        } else {
            theSim.pops[pop!]!.addElements(n: n!)
        }
        if test["field"]?.phVal != nil {
            let f = test["field"]!.phVal!
            if !f.isField {return errVal("field argument is not a valid field !")}
            if theSim.dim != f.dim.count { return errVal("densitiy field should have same dimensions as the simulation world")}
            let dims = f.dim
            let dx = f.fieldDx!.asDouble!
            let origin = f.fieldOrigin!
            let mins = origin.asDoubles!

            for k in 0..<n! {
                var t = false
                var intx : [Int] = []
                while !t {
                    intx = []
                    for i in 0..<theSim.dim {
                        intx.append(Int(arc4random_uniform(UInt32(dims[i]))))
                    }
                    let fVal = f.getMatValueWithIndexes(coord: intx) as! Double
                    t = ( fVal > drand48() )
                }
                for i in 0..<theSim.dim {
                    let v = ["x","y","z"][i]
                    let x = mins[i] + (Double(intx[i]) + drand48() - 0.5) * dx
                    theSim.pops[pop!]!.vars[v]!.values[k] = x
                }
            }
        }
        return PhysValue()
    }
    
    // Suppression d'éléments d'une population
    func xRemove() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("pop", type: "string"),
            funcArgument("members", type: "int"),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let popName = test["pop"]!.phVal!.asString
        if !theSim.hasPop(popName!) { return PhysValue(error:"Wrong population name") }
        let thePop = theSim.pops[popName!]!
        let n = thePop.id.count
        let elems = test["members"]!.phVal!.asIntegers!.sorted(by: >)
        if elems[0] >= n { return errVal("wrong index")}
        for varName in thePop.vars.keys {
            let varVal = thePop.vars[varName]!
            if varVal.values.count == n {
                let newVals = varVal.values.enumerated().compactMap({
                    return (elems.contains($0) ? nil : $1)
                })
                varVal.values = newVals
                thePop.vars[varName] = varVal
            }
        }
        thePop.id.removeLast(elems.count)
        return PhysValue()
    }
    
    // modifiecation du timer de la simulation
    func xSimtimer() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("timerinterval",type:"double")
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        theSim.simSpeed = test["timerinterval"]!.phVal!.asDouble!
        theSim.resetSimSpeed()
        return PhysValue()
    }
    
    
    // retourne la liste des numéros des éléments voisins de la position coord dans la population pop
    // utilise la grille de proximité en incluant les cellules à distance n
    func xNeighbours() -> PhysValue {
        if theSim.pops.count == 0 { return errVal("The simulation has no population")}
        let defPop = Array(theSim.pops.keys)[0]
        let test = testArguments(structure: [
            funcArgument("coords", type: "double"),
            funcArgument("pop",type:"string",defVal: PhysValue(string: defPop)),
            funcArgument("dis", type: "int", defVal: PhysValue(intVal: 1))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let coord = test["coord"]!.phVal!.asDoubles!
        if theSim.dim != coord.count { return errVal("Wrong number of coordinates")}
        let popName = test["pop"]!.phVal!.asString
        if popName == nil { return errVal("No such population") }
        if !theSim.pops.keys.contains(popName!) { return errVal("No such population") }
        let pop = theSim.pops[popName!]!
        if pop.fieldGrid == nil { return errVal("Population " + popName! + " has no grid")}
        let dx = pop.fieldGrid!.asDouble!
        let min = theSim.vars["min"]!.asDoubles!
        let gridCoord = coord.enumerated().map({ Int(trunc(($1 - min[$0])/dx)) })
        let dis = test["dis"]!.phVal!.asInteger!
        var neighbours : [Int] = []
        let N = pop.gridEls!.count
        if dis == 0 {
            let n = indexFromCoords(dim: pop.gridDims!, coord: gridCoord)
            neighbours = pop.gridEls![n]
        } else {
            let closeGridCoords = getNeighboursCoords(ndims: theSim.dim)
            closeGridCoords.forEach({ closeCoord in
                let newCoords = gridCoord.enumerated().map ({
                    $1 + closeCoord[$0]
                })
                let n = indexFromCoords(dim: pop.gridDims!, coord: newCoords)
                if n>0 && n<N {
                    neighbours.append(contentsOf: pop.gridEls![n])
                }
            })
        }
        return PhysValue(unit: Unit(), type: "int", values: neighbours, dim: [neighbours.count])
    }
    
    // retourne les coordonnées i,j... d'une cellule de la grille de population donnée par son n°
    func xPopgridCoords() -> PhysValue {
        if theSim.pops.count == 0 { return errVal("The simulation has no population")}
        let test = testArguments(structure: [
            funcArgument("pop",type:"string"),
            funcArgument("index", type: "double"),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let popName = test["pop"]!.phVal!.asString
        if popName == nil { return errVal("No such population") }
        if !theSim.pops.keys.contains(popName!) { return errVal("No such population") }
        let pop = theSim.pops[popName!]!
        if pop.fieldGrid == nil { return errVal("Population " + popName! + " has no grid")}
        let i = test["index"]?.phVal?.asInteger
        if i==nil { return errVal("no index given")}
        let dims = pop.gridDims
        if dims == nil {return errVal("Grid has not yet been initialised")}
        let nCells = dims!.reduce(1, *)
        if i!<0 || i!>nCells-1 { return errVal("Index out of bonds")}
        if dims!.count == 1 {
            let ix = i!
            return PhysValue(unit: Unit(), type: "int", values: [ix])
        } else if dims?.count == 2 {
            let iy = i!/dims![0]
            let ix = i!%dims![0]
            return PhysValue(unit: Unit(), type: "int", values: [ix,iy])
        } else {
            let iz = i!/dims![0]
            let r = i!%dims![0]
            let iy = r/dims![1]
            let ix = r%dims![1]
            return PhysValue(unit: Unit(), type: "int", values: [ix,iy, iz])
        }
    }
    
    // champ de densité de population ou de moyenne d'une variable liée à une population
    func xPopulationGrid() -> PhysValue {
        if theSim.pops.count == 0 { return errVal("The simulation has no population")}
        let test = testArguments(structure: [
            funcArgument("pop",type:"string"),
            funcArgument("calc", type: "string", defVal: PhysValue(string: "count")), // "count", "density", "mean", "sum"
            funcArgument("var", type: "string", requested: false),
            funcArgument("reset",type: "bool",defVal: PhysValue(boolVal: false))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let popName = test["pop"]!.phVal!.asString
        if popName == nil { return errVal("No such population") }
        if !theSim.pops.keys.contains(popName!) { return errVal("No such population") }
        let pop = theSim.pops[popName!]!
        if pop.fieldGrid == nil { return errVal("Population " + popName! + " has no grid")}
        let dx = pop.fieldGrid!
        let min = theSim.vars["min"]!
        if op == "gridsize" { return dx }
        let calc = test["calc"]!.phVal!.asString!
        if test["reset"]!.phVal!.asBool! || pop.gridEls == nil {
            pop.calcGrid()
        }
        if test["var"]!.phVal == nil {
            // si pas de variable indiquée : nombre d'individus ou densité
            let count = pop.gridEls!.map({ $0.count })
            if calc.hasPrefix("d") {
                let sdx = dx.binaryOp(op: "*", v2: dx)
                let values = count.map({ Double($0) / sdx.asDouble! })
                let densUnit = (PhysValue(doubleVal: 1).binaryOp(op: "/", v2: sdx)).unit
                return PhysValue(unit: densUnit, type: "double", values: values, dim: pop.gridDims!,
                        field: ["origin" : min, "dx" : dx, "vec" : PhysValue(boolVal: false) ])
            } else {
                return PhysValue(unit: Unit(), type: "int", values: count, dim: pop.gridDims!,
                        field: ["origin" : min, "dx" : dx, "vec" : PhysValue(boolVal: false) ])
            }
        } else {
            // sinon moyenne ou somme de la variable
            let theVarName = test["var"]!.phVal!.asString!
            if !pop.vars.keys.contains(theVarName) { return errVal("No such variable") }
            let theVar = pop.vars[theVarName]!
            let theValues = theVar.asDoubles!
            if calc.hasPrefix("s") {
                let sums : [Double] = pop.gridEls!.map({ celElems in
                    return celElems.reduce(0) { $0 + theValues[$1] }
                })
                return PhysValue(unit: theVar.unit, type: "double", values: sums, dim: pop.gridDims!,
                                 field: ["origin" : min, "dx" : dx, "vec" : PhysValue(boolVal: false) ])
            } else {
                let means : [Double] = pop.gridEls!.map({ celElems in
                    if celElems.count > 0 {
                        let sum = celElems.reduce(0) { $0 + theValues[$1] }
                        let mean = sum / Double(celElems.count)
                        return mean
                    } else {
                        return 0.0
                    }
                })
                return PhysValue(unit: theVar.unit, type: "double", values: means, dim: pop.gridDims!,
                                 field: ["origin" : min, "dx" : dx, "vec" : PhysValue(boolVal: false) ])
            }
        }
    }
    
    // ************************
    // statistiques et vecteurs
    // ************************
    
    // séquence régulière (suite artithm. ou géom.)
    func xSequence() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("min",type: "double", requested: true, dim: [1]),
            funcArgument("max",type: "double", requested: false, dim: [1]),
            funcArgument("step",type: "double", requested: false, dim: [1]),
            funcArgument("mult",type: "double", requested: false, dim: [1]),
            funcArgument("n",type: "int", requested: false, dim: [1]) // nombre de valeurs !
        ])
        if test["error"] != nil {
            let test2 = xStatfunctions()
            if !test2.isError { return test2 }
            return test["error"]!.phVal!
        }
        let min = test["min"]!.phVal
        let fromValue = min!.asDouble!
        let max = test["max"]!.phVal
        let toValue = max?.asDouble
        var step = test["step"]!.phVal
        let mult = test["mult"]!.phVal
        var n = test["n"]!.phVal
        let returnValue = PhysValue()
        
        if max != nil {
            if n != nil {
                //n = n!.plus(PhysValue(doubleVal: -1.0))
                step = max!.minus(min!).div(n!.plus(PhysValue(doubleVal: -1.0))) // (max-min)/(n-1)
            } else if step != nil {
                n = max!.minus(min!).div(step!).int().plus(PhysValue(doubleVal: 1.0))  // int(1 + (max-min)/step)
            } else if mult != nil {
                n = (max!.div(min!).Log().div(mult!.Log())).int()  // int(Log(max/min)/Log(mult))
            } else {
                step = toValue!>fromValue ? PhysValue(doubleVal: 1.0) : PhysValue(doubleVal: -1.0)
                step!.unit = min!.unit
                n = max!.minus(min!).div(step!).int()
            }
        }
        let nVals = n!.asInteger!
        if nVals < 1 { return errVal("Wrong arguments for sequence")}
        if min != nil && step != nil && n != nil {
            // suite arithmétique
            let unit = min!.unit
            let stepNumber = step!.asDouble!
            let theArray = Array(0..<nVals).map{fromValue + Double($0)*stepNumber}
            returnValue.addElements(theArray)
            returnValue.unit = unit
            returnValue.type = "double"
            
        } else if min != nil && mult != nil && n != nil {
            // suite géométrique
            let unit = (min!.mult(mult!)).unit
            let nVals = n!.asInteger!
            let multNumber = mult!.asDouble!
            let theArray = Array(0..<nVals).map{fromValue * pow(multNumber,Double($0)) }
            returnValue.addElements(theArray)
            returnValue.unit = unit
            returnValue.type = "double"
        } else {
            return errVal("no valid sequence arguments")
        }
        return returnValue
    }
    
    // distribution normale centrée
    func xNormaldis() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("n",type: "int", requested: true, limits: [">":0]),
            funcArgument("mean", defVal: PhysValue(doubleVal: 0.0)),
            funcArgument("sd", defVal: PhysValue(doubleVal: 1.0)),
            funcArgument("min", requested: false, defVal: PhysValue(doubleVal: -(Double.infinity))),
            funcArgument("max", requested: false, defVal: PhysValue(doubleVal: Double.infinity))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let n = test["n"]!.phVal!.asInteger!
        let m = test["mean"]!.phVal!.asDouble!
        let sd = test["sd"]!.phVal!.asDouble!
        let min = test["min"]!.phVal!.asDouble!
        let max = test["max"]!.phVal!.asDouble!
        let distrib = Distributions.Normal(mean: m, sd: sd)
        var values = distrib.random(n)
        if min > -(Double.infinity) && max < Double.infinity {
            let d = max-min
            values = values.map({
                if $0 < min || $0 > max {
                    return(drand48() * d + min)
                } else {
                    return($0)
                }
            })
        } else if min > -(Double.infinity) {
            let d = -min*2
            values = values.map({
                if $0 < min {
                    return(drand48() * d + min)
                } else {
                    return($0)
                }
            })
        } else if max < Double.infinity {
            let d = max*2
            values = values.map({
                if $0 > max {
                    return(drand48() * d - max)
                } else {
                    return($0)
                }
            })
        }
        //let values = statsNormalDis(min: min, max: max, mean: m, sd: sd, n: n)
        var unit = test["mean"]!.phVal!.unit
        if unit.isNilUnit() {
            unit = test["sd"]!.phVal!.unit
        }
        return PhysValue(unit: unit, type: "double", values: values)
    }
    
    // distribution lognormale
    func xLogNormalDis() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("n",type: "int", requested: true, limits: [">":0]),
            funcArgument("mean", defVal: PhysValue(doubleVal: 0.0)),
            funcArgument("sd", defVal: PhysValue(doubleVal: 1.0))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let n = test["n"]!.phVal!.asInteger!
        let m = test["mean"]!.phVal!.asDouble!
        let sd = test["sd"]!.phVal!.asDouble!
        let distrib = Distributions.LogNormal(meanLog: m, sdLog: sd)
        let values = distrib.random(n)
        var unit = test["mean"]!.phVal!.unit
        if unit.isNilUnit() {
            unit = test["sd"]!.phVal!.unit
        }
        return PhysValue(unit: unit, type: "double", values: values)
    }
    
    // distribution de Maxwell-Boltzmann
    func xBoltzmann() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("n",type: "int", requested: true, limits: [">":0]),
            funcArgument("mean",type: "int", requested: false, limits: [">":0]),
            funcArgument("a", type:"double", requested: false, limits: [">":0]),
            funcArgument("m", type:"double", requested: false, unit: Unit(unitExp: "kg"),limits: [">":0]),
            funcArgument("T", type:"double", requested: false, unit:Unit(unitExp: "K"), limits: [">":0]),

        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        
        let n = test["n"]!.phVal!.asInteger!
        var a = test["a"]!.phVal != nil ? test["a"]!.phVal!.asDouble! : 1
        var unit = Unit()
        
        if test["mean"]!.phVal != nil {
            let mean = test["mean"]!.phVal!
            a = mean.asDouble!*sqrt(pi/8)
            unit = mean.unit
        } else if test["m"]!.phVal != nil {
            if test["T"]!.phVal == nil { return errVal("m and T must both be specified")}
            let T=test["T"]!.phVal!.asDouble!
            let m=test["m"]!.phVal!.asDouble!
            a=sqrt(1.380649e-23*T/m)
            unit=Unit(unitExp: "m/s")
        }
        let distrib = Distributions.Boltzmann(a: a)
        let values = distrib.random(n)
        return PhysValue(unit: unit, type: "double", values: values)
    }
    
    // retourne n nombres aléatoires (distribution uniforme)
    func xUniformdis() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("n",type: "int",defVal: PhysValue(intVal: 1), limits: [">":0]),
            funcArgument("min", type: "double", defVal: PhysValue(doubleVal: 0.0)),
            funcArgument("max",type: "double", defVal: PhysValue(doubleVal: 1.0))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let n = test["n"]!.phVal!.asInteger!
        let min = test["min"]!.phVal!.asDouble!
        let max = test["max"]!.phVal!.asDouble!
        if max <= min {
            return PhysValue(error:"max-value should be greater than min-value")
        }
        if n == 1 {
            return PhysValue(unit: Unit(), type: "double", values: [drand48() * (max-min) + min])
        } else {
            var unit = test["min"]!.phVal!.unit
            if unit.isNilUnit() {
                unit = test["max"]!.phVal!.unit
            }
            let distrib = statsUniformDis(min: min, max: max, n: n)
            return  PhysValue(unit: unit, type: "double", values: distrib)
        }
    }
    
    // Choisit n nombres entiers parmi k catégories ayant chacune une probabilité définie
    func xChoose() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("probs", type: "double"),
            funcArgument("n", type: "int", defVal: PhysValue(intVal: 1))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let probs = test["probs"]!.phVal!.asDoubles!
        let n = test["n"]!.phVal!.asInteger!
        if n == 0 { return PhysValue() }
        let probsSum = probs.reduce(0, { x,y in x+y })
        if !(probsSum > 0) { return errVal("All probabilities are zero or NaN !")}
        var resultVals : [Int] = []
        for _ in 0..<n {
            let random = Double.random(in: 0...probsSum)
            var cat = 0
            var runSum = probs[0]
            while random >= runSum {
                cat = cat + 1
                runSum = runSum + probs[cat]
            }
            resultVals.append(cat)
        }
        return PhysValue(unit: Unit(), type: "int", values: resultVals, dim: [n])
    }
    
    // n  booléens avec des probabilités données par une ou des valeurs (0-1)
    func xRandombool() -> PhysValue {
        let test = testArguments(structure:[
            funcArgument("n",type: "int",defVal: PhysValue(intVal: 1), limits: [">":0]),
            funcArgument("prob", type: "double", defVal: PhysValue(doubleVal: 0.5))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        
        let n = test["n"]!.phVal!.asInteger!
        let prob = test["prob"]!.phVal!.asDoubles!
        if n == 1 && prob.count == 1  {
            return PhysValue(boolVal: (prob[0] > drand48() ))
        } else if n <= 1 {
            return PhysValue(unit: Unit(), type: "bool", values: prob.map{ $0 > drand48() } )
        } else  {
            return PhysValue(unit: Unit(), type: "bool", values: Array(repeating: 1.0, count: n).map{ $0*prob[0] > drand48() } )
        }
    }
    
    // vecteur répétant n fois la valeur x
    func xRepeat() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("n", type: "int", limits: ["≥":0]),
            funcArgument("x", type: "")
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let n = test["n"]!.phVal!.asInteger!
        let x = test["x"]!.phVal!
        return PhysValue(unit: x.unit, type: x.type, values: Array(repeating: x.values[0], count: n))
    }
    
    // nommbre d'éléments d'un vecteur (qui sont égaux au 2e argument, si indiqué)
    func xCount() -> PhysValue {
        // nommbre d'éléments d'un vecteur (qui sont égaux au 2e argument, si indiqué)
        let test = testArguments(structure:[
            funcArgument("x", type:"any",requested: false),
            funcArgument("test", type:"any", requested: false)
        ])
        if test["x"]?.phVal == nil { return PhysValue(intVal: 0)}
        if test["x"]!.phVal!.values.count == 0 { return PhysValue(intVal: 0)}
        if test["error"] != nil { return test["error"]!.phVal! }
        if test["test"]!.phVal == nil {
            return PhysValue(intVal: test["x"]!.phVal!.values.count)
        } else {
            let testPhVal = test["test"]!.phVal!
            let xPhVal = test["x"]!.phVal!
            
            if xPhVal.isNumber {
                if !testPhVal.isNumber { return PhysValue(error:"Test value for count should be same type as vector") }
                let x = xPhVal.asDoubles!
                let testVal = testPhVal.asDouble!
                let xVals = x.filter { $0 == testVal }
                return PhysValue(intVal: xVals.count)
            }
            else if xPhVal.type == "bool" {
                if testPhVal.type != "bool" { return PhysValue(error:"Test value for count should be same type as vector") }
                let x = xPhVal.asBools!
                let testVal = testPhVal.asBool!
                let xVals = x.filter { $0 == testVal }
                return PhysValue(intVal: xVals.count)
            }
            else if xPhVal.type == "string" {
                if testPhVal.type != "string" { return PhysValue(error:"Test value for count should be same type as vector") }
                let x = xPhVal.asStrings!
                let testVal = testPhVal.asString!
                let xVals = x.filter { $0 == testVal }
                return PhysValue(intVal: xVals.count)
            } else {
                return PhysValue(error:"count applies only on numbers, bools and strings")
            }
        }
    }
    
    // retourne les valeurs numériques de x limitées par min et max
    // rupture brutale (smooth=false) ou via atan(x) si smooth = true
    func xLimited() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x",type: "double"),
            funcArgument("min",type: "double"),
            funcArgument("max",type: "double"),
            funcArgument("smooth",type: "bool", defVal: PhysValue(boolVal: true)),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!.asDoubles!
        let unit = test["x"]!.phVal!.unit
        let min = test["min"]!.phVal!.asDouble!
        let max = test["max"]!.phVal!.asDouble!
        if !unit.isIdentical(unit: test["min"]!.phVal!.unit) || !unit.isIdentical(unit: test["max"]!.phVal!.unit)  {
            return PhysValue(error: "Incompatible units in x, min and max")
        }
        var r : [Double] = x
        if test["smooth"]!.phVal!.asBool! {
            let mid = (max+min)/2
            let a = (max-min)/pi
            r = x.map { mid + (a * atan(($0-mid)/a)) }
        } else {
            r = x.map {
                if $0 > max { return max }
                else if $0 < min { return min }
                else { return $0 }
            }
        }
        return PhysValue(unit: unit, type: "double", values: r, dim: test["x"]!.phVal!.dim)
    }
    
    func xMakeIndex() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x",type: "double"),
            funcArgument("min",type: "double"),
            funcArgument("max",type: "double"),
            funcArgument("slope", type: "double", defVal: PhysValue(doubleVal: 1.0)),
            funcArgument("center", type: "double", defVal: PhysValue(doubleVal: 0.0)),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!.asDoubles!
        //let unit1 = test["x"]!.phVal!.unit
        let min = test["min"]!.phVal!.asDouble!
        let max = test["max"]!.phVal!.asDouble!
        let c = test["center"]!.phVal!.asDouble!
        let d = test["slope"]!.phVal!.asDouble!
        var r : [Double] = x
        let mid = (max+min)/2
        let a = (max-min)/pi
        r = x.map { mid + (a * atan(($0-c)*d/a)) }
        return PhysValue(unit: Unit(), type: "double", values: r, dim: test["x"]!.phVal!.dim)
    }
    
    // retourne le vecteur x rangé
    func xSorted() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x"),
            funcArgument("descending", type: "bool", defVal: PhysValue(boolVal: false))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!
        let desc = test["descending"]!.phVal!.asBool!
        var sorted: [Any]
        if x.type == "double" {
            sorted = desc ? x.asDoubles!.sorted(by: >) : x.asDoubles!.sorted()
        } else if x.type == "int" {
            sorted = desc ? x.asIntegers!.sorted(by: >) : x.asIntegers!.sorted()
        } else if x.type == "string" {
            sorted = desc ? x.asStrings!.sorted(by: >) : x.asStrings!.sorted()
        } else {
            return errVal("argument should be numbers or strings")
        }
        return PhysValue(unit: x.unit, type: x.type, values: sorted, dim: x.dim)

    }
    
    // retourne le vecteur renversé
    func xReversed() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x", requested: true),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!
        return PhysValue(unit: x.unit, type: x.type, values: x.values.reversed(), dim: x.dim)
    }
    
    // Rotation d'une séquence
    func xRotate() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x", requested: true),
            funcArgument("n", type: "int", defVal: PhysValue(intVal: 1)) // n<0 rotation gauche
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!
        let n = test["n"]!.phVal!.asInteger!
        var vals = x.asDoubles!
        let N=vals.count
        if N<2 { return x.dup() }
        if abs(n) > N { return errVal("n should be smaller than length of sequence")}
        if n>0 {
            let firsts = vals.prefix(N-n)
            vals = vals.suffix(n)
            vals.append(contentsOf: firsts)
        } else if n<0 {
            let firsts = vals.prefix(-n)
            vals = vals.suffix(N+n)
            vals.append(contentsOf: firsts)
        }
        return PhysValue(unit: x.unit, type: x.type, values: vals, dim: x.dim)

    }
    
    // fonction statistique sur un vecteur (sum, mean, variance, std, min, max, norm, median)
    func xStatfunctions() -> PhysValue {
        // somme (etc) d'éléments d'un vecteur    sum(x: [Double])
        // ou somme d'une expression pour une variable parcourant indexes
        // sum(exp : hierexp, var: hierexp, indexes: [int])
        let test1 = testArguments(structure:[
            funcArgument("x",type: "double"),
            funcArgument("weights", type: "double", requested: false)
        ])
        var physVal = PhysValue()
        if test1["error"] == nil {
            physVal = test1["x"]!.phVal!
        } else if nArgs == 3 {
            let test2 = testArguments(structure:[
                funcArgument("exp",type: "exp"),
                funcArgument("var", type: "exp", op: "_var"),
                funcArgument("indexes", type: "double")
            ])
            if test2["error"] != nil { return test2["error"]!.phVal! }
            let exp = test2["exp"]!.exp!
            let varName = test2["var"]!.exp!.string!
            let indexes = test2["indexes"]!.phVal!.asDoubles
            if indexes == nil { return PhysValue() }
            let temp = theVariables[varName]
            for (j,i) in indexes!.enumerated() {
                theVariables[varName] = PhysValue(doubleVal: i)
                if j == 0 {
                    physVal = exp.executeHierarchicScript()
                    if physVal.type != "double" && physVal.type != "int" { return PhysValue() }
                } else {
                    let newVal = exp.executeHierarchicScript()
                    if newVal.type != "double" && physVal.type != "int"  { return PhysValue() }
                    physVal.addElement(newVal.values[0])
                }
            }
            theVariables[varName]=temp
            if physVal.values.count == 0 { return PhysValue() }
            if op == "sequence" { return physVal }
        } else {
            return PhysValue()
        }
        let w = test1["weights"]?.phVal?.asDoubles
        switch op {
        case "sum" :
            return PhysValue(unit: physVal.unit, type: "double", values: [statsSum(physVal.asDoubles!, w: w)])
        case "prod" :
            return PhysValue(unit: Unit(), type: "double", values: [statsProd(physVal.asDoubles!)])
        case "mean" :
            return PhysValue(unit: physVal.unit, type: "double", values: [statsMean(physVal.asDoubles!, w: w)])
        case "variance", "var" :
            let unit = physVal.unit.multiplyWith(unit: physVal.unit, exp1: 1, exp2: 1)
            return PhysValue(unit: unit, type: "double", values:
                                [statsVariance( physVal.asDoubles!, w: w)])
        case "std", "sd", "stdev" :
            return PhysValue(unit: physVal.unit, type: "double", values: [sqrt(statsVariance(physVal.asDoubles!, w: w))])
        case "min" :
            return PhysValue(unit: physVal.unit, type: "double", values: [physVal.asDoubles!.min()!] )
        case "max" :
            return PhysValue(unit: physVal.unit, type: "double", values: [physVal.asDoubles!.max()!] )
        case "norm" :
            return PhysValue(unit: physVal.unit, type: "double", values: [statsNorm(physVal.asDoubles!)])
        case "median" :
            return PhysValue(unit: physVal.unit, type: "double", values: [statsMedian(physVal.asDoubles!, w: w)])
        default :
            return PhysValue(intVal: physVal.values.count)
        }
    }


    // calcul des limites de classes ou de quantiles ou les densités
    func xClasses() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x"),
            funcArgument("n", type: "int", requested: false), // nombre de classes
            funcArgument("min",type: "double", requested: false),
            funcArgument("max",type: "double", requested: false),
            funcArgument("centers", type: "bool", defVal: PhysValue(boolVal: false))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        if test["n"]!.phVal == nil && op == "classes" {
            // discrete classes of x
            let x = test["x"]!.phVal!
            let theType = x.type
            let v = statsGetDiscreteClasses(theType: theType, liste: x.values)
            return PhysValue(unit: x.unit, type: theType, values: v, dim: [v.count], field: nil)
        }
        if !test["x"]!.phVal!.isNumber { return errVal("x should contain numbers")}
        let vals = test["x"]!.phVal!.asDoubles!
        let n = test["n"]!.phVal?.asInteger ?? 10
        var min = 0.0
        var max = 0.0
        if test["min"]!.phVal == nil { min = vals.min()! } else { min = test["min"]!.phVal!.asDouble! }
        if test["max"]!.phVal == nil { max = vals.max()! } else { max = test["max"]!.phVal!.asDouble! }
        let centers = test["centers"]!.phVal!.asBool!
        let unit = test["x"]!.phVal!.unit

        if op == "density" {
            let classes = statsUniformClasses(min: min, max: max, nc: n)
            let dUnit = Unit()
            dUnit.powers = multiplyUnitPowers(powers1: Unit().powers, exp1: 1, powers2: unit.powers, exp2: -1)
            return PhysValue(unit: dUnit.baseUnit(), type: "double", values:
                                statsByClasses(liste: vals, classes: classes, calc: "dens"))
        } else {
            let classes = statsUniformClasses(min: min, max: max, nc: n)
            if centers {
                return PhysValue(unit: unit, type: "double", values: statsMiddleOfClasses(classes))
            } else {
                return PhysValue(unit: unit, type: "double", values: classes)
            }
        }
    }
    
    // calcul des quantiles
    func xQuantiles() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x"),
            funcArgument("n", type: "int", requested: false, defVal: PhysValue(intVal: 4)), // nombre de classes
            funcArgument("all", type: "bool", defVal: PhysValue(boolVal: true)),
            funcArgument("centers", type: "bool", defVal: PhysValue(boolVal: false)),
            funcArgument("weights", requested: false) // pondération
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        if !test["x"]!.phVal!.isNumber { return errVal("x should contain numbers")}
        let vals = test["x"]!.phVal!.asDoubles!
        let n = test["n"]!.phVal!.asInteger!
        let weights = test["weights"]?.phVal?.asDoubles
        if weights != nil {
            if weights!.count != vals.count { return errVal("x and weight should have same length")}
        }
        let all = test["all"]!.phVal!.asBool!
        let centers = test["centers"]!.phVal!.asBool!
        let unit = test["x"]!.phVal!.unit
        let classes = statsNtiles(vals, n: n, all: all,w: weights)
        if centers {
            return PhysValue(unit: unit, type: "double", values: statsMiddleOfClasses(classes))
        } else {
            return PhysValue(unit: unit, type: "double", values: classes)
        }

    }
    // diverses fonctions statistiques opérant sur des classes
    func xStats() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x"), // séquence de base pour le calcul
            funcArgument("limits", type : "double", requested: false),// limites de classes contigües pour x réel
            funcArgument("by", requested: false), // classement éventuel en catégories discrètes (même longueur que x)
            funcArgument("in", requested: false), // valeurs à retenir pour x (supposé discret) ou dans le classement (si existant)
            funcArgument("weights", requested: false), // pondération
            funcArgument("dim", type: "int", requested: false)
        ])
        
        if test["error"] != nil { return test["error"]!.phVal! }
        let xPhval = test["x"]!.phVal!
        let theType = xPhval.isNumber ? "double" : xPhval.type
        let weights = test["weights"]?.phVal?.asDoubles
        if weights != nil {
            if weights!.count != xPhval.values.count { return errVal("x and weight should have same length")}
        }
        
        if xPhval.dim.count > 1 && theType == "double" && test["dim"]?.phVal != nil {
            // opération de somme sur une rangée d'une matrice
            if op != "sums" && op != "means" {
                return errVal("This 'dim' syntax works only with sums or means")
            }
            let d = test["dim"]!.phVal!.asInteger
            if d == nil {return errVal("dim should be positive integer < number of dims") }
            if d! < 0 || d! > (xPhval.dim.count - 1) { return errVal("dim should be positive integer < number of dims")}
            let xn = xPhval.values.count
            let xDim = xPhval.dim
            let dd=Double(xDim[d!])
            let xValues = xPhval.asDoubles!
            let xIndexesTable = getAllCoordsIndexes(dim: xDim)
            var rDim = xDim
            rDim.remove(at: d!)
            let result = xPhval.dup()
            result.dim = rDim
            var rValues = Array(repeating: 0.0, count: rDim.reduce(1,*))
            (0..<xn).forEach({
                var coord = xIndexesTable[$0]
                coord.remove(at: d!)
                let rn = indexFromCoords(dim: rDim, coord: coord)
                rValues[rn] = rValues[rn] + xValues[$0]
            })
            if op=="means" {
                rValues=rValues.map({ $0/dd })
            }
            result.values = rValues
            return result
            
        } else if test["limits"]!.phVal != nil  {
            //Classement par valeurs limites d'une variable numérique continue
            if theType != "double" { return errVal("x should be numeric")}
            let xVals = xPhval.asDoubles!
            let unit = xPhval.unit
            let cl = test["limits"]!.phVal!.asDoubles!
            switch op {
            case "rfreq" :
                return PhysValue(unit: Unit(), type: "double",
                                 values: statsByClasses(liste: xVals, classes: cl, calc: "rfreq", w: weights))
            case "means" :
                return PhysValue(unit: unit, type: "double",
                                 values: statsByClasses(liste: xVals, classes: cl, calc: "mean", w: weights))
            case "dens", "densities" :
                let resultUnit = Unit().multiplyWith(unit: unit, exp1: 0, exp2: -1)
                return PhysValue(unit: resultUnit, type: "double",
                                 values: statsByClasses(liste: xVals, classes: cl, calc: "dens", w: weights))
            case "sums" :
                return PhysValue(unit: unit, type: "double",
                                 values: statsByClasses(liste: xVals, classes: cl, calc: "sum", w: weights))
            case "vars" :
                let resultUnit = unit.multiplyWith(unit: unit, exp1: 1, exp2: 1)
                return PhysValue(unit: resultUnit, type: "double",
                                 values: statsByClasses(liste: xVals, classes: cl, calc: "var", w: weights))
            case "stds", "sds", "stdevs":
                return PhysValue(unit: unit, type: "double",
                                 values: statsByClasses(liste: xVals, classes: cl, calc: "std", w: weights))
            case "medians" :
                return PhysValue(unit: unit, type: "double",
                                 values: statsByClasses(liste: xVals, classes: cl, calc: "median", w: weights))
            default :
                return PhysValue(unit: Unit(), type: "double",
                                 values: statsByClasses(liste: xVals, classes: cl, calc: "freq", w: weights))
            }
            
            
            
        } else if test["by"]!.phVal != nil {
            // classement suivant les valeurs discrètes d'une variable 'by' de classement (même longueur que x)
            // éventuellement limitées aux valeurs spécifiées dans 'in'
            if theType != "double" { return errVal("x should be numeric")}
            if test["by"]!.phVal!.values.count != xPhval.values.count { return errVal("x and by should have same length")}
            let byPhval = test["by"]!.phVal!
            var testValues: PhysValue
            if test["in"]!.phVal != nil {
                // on retient les valeurs indiquées dans 'in''
                testValues = test["in"]!.phVal!
            } else {
                // on utilise toutes les valeurs possibles de la variable by
                if byPhval.isStrings() {
                    let v = statsGetDiscreteClasses(theType: "string", liste: byPhval.asStrings!)
                    testValues = PhysValue(unit: Unit(), type: "string", values: v, dim: [v.count])
                } else if byPhval.isNumber {
                    let v = statsGetDiscreteClasses(theType: "double", liste: byPhval.asDoubles!)
                    testValues = PhysValue(unit: Unit(), type: "double", values: v, dim: [v.count])
                } else {
                    return(errVal("'by' parameter should contain strings or numbers"))
                }
            }
            
            
            var rInt : [Int] = []
            var rDoub : [Double] = []
            let n = testValues.values.count
            if !xPhval.isNumber { return errVal("x should be numeric when 'by' is specified")}
            let xvalues = xPhval.asDoubles!.enumerated()
            let N = xPhval.values.count
            
            let byVals = byPhval.asStrings!

            for v in testValues.asStrings! {
                let thisValues = xvalues.compactMap({ byVals[$0] == v ? $1 : nil })
                let w = weights == nil ? nil : weights!.enumerated().compactMap({ byVals[$0] == v ? $1 : nil })
                switch op {
                case "rfreq" :
                    rDoub.append(Double(thisValues.count)/Double(N))
                case "means" :
                    rDoub.append(statsMean(thisValues,w: w))
                case "sums" :
                    rDoub.append(statsSum(thisValues))
                case "vars" :
                    rDoub.append(statsVariance(thisValues))
                case "stds", "sds", "stdevs" :
                    rDoub.append(sqrt(statsVariance(thisValues)))
                case "medians" :
                    rDoub.append((statsMedian(thisValues)))
                default : // calcul de fréquences d'une population
                    rInt.append(thisValues.count)
                }
                 
            }
            
            switch op {
            case "rfreq" :
                return PhysValue(unit: Unit(), type: "double", values: rDoub, dim: [n])
            case "means", "stds", "sds", "stdevs", "medians", "sums" :
                return PhysValue(unit: xPhval.unit, type: "double", values: rDoub, dim: [n])
            case "vars" :
                let resultUnit = xPhval.unit.multiplyWith(unit: xPhval.unit, exp1: 1, exp2: 1)
                return PhysValue(unit: resultUnit, type: "double", values: rDoub, dim: [n])
            default :
                return PhysValue(unit: Unit(), type: "int", values: rInt, dim: [n])
            }
            
            
        } else {
            // classement par valeurs (supposées discrètes) de x
            var classes : [Any]
            if test["in"]!.phVal == nil {
                if xPhval.isStrings() {
                    classes = statsGetDiscreteClasses(theType: "string", liste: xPhval.asStrings!)
                } else if xPhval.isNumber {
                    classes = statsGetDiscreteClasses(theType: "double", liste: xPhval.asDoubles!)
                } else {
                    return(errVal("x should contain strings or numbers"))
                }
            } else {
                if theType != "double" && theType != test["in"]!.phVal!.type {
                    return errVal("x and in are of different type")
                }
                classes = test["in"]!.phVal!.values
            }
            let x = theType == "double" ? test["x"]!.phVal!.asDoubles! : test["x"]!.phVal!.values
            if op == "freq" {
                return PhysValue(unit: Unit(), type: "double", values:
                                    statsByDiscreteClasses(theType: theType, liste: x, classes: classes, calc: "freq"))
            } else if op == "rfreq" {
                return PhysValue(unit: Unit(), type: "double", values:
                                    statsByDiscreteClasses(theType: theType, liste: x, classes: classes, calc: "rfreq"))
            } else {
                return errVal("operator " + op + " not applicable on discrete data x")
            }
        }
    }
        
    // Classement d'une séquence
    func xClassify() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x"), // séquence de base pour le calcul
            funcArgument("limits", type : "double", requested: false),// limites de classes contigües pour x réel
            funcArgument("n", type: "int", requested: false), // nombre de classes de taille uniforme
            funcArgument("min",type: "double", requested: false),
            funcArgument("max",type: "double", requested: false),
            funcArgument("q", type : "int", requested: false), //quantiles
            funcArgument("weights", requested: false), // pondération
            funcArgument("names", type: "string", requested: false) // noms des classes
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        
        if !test["x"]!.phVal!.isNumber { return errVal("x should contain numbers")}
        let vals = test["x"]!.phVal!.asDoubles!
        if vals.count < 1 { return errVal("x should have at least one element")}
        let unit = test["x"]!.phVal!.unit
        let weights = test["weights"]?.phVal?.asDoubles
        if weights != nil {
            if weights!.count != vals.count { return errVal("x and weight should have same length")}
        }
        var limits : [Double]
        var n = test["n"]!.phVal?.asInteger
        let q = test["q"]!.phVal?.asInteger
        if q != nil {
            if q!<2 { return errVal("q should be greater or equal to 2") }
            n = q!
            limits = statsNtiles(vals, n: q!, all: true, w: weights)
        } else if test["limits"]!.phVal != nil {
            limits = test["limits"]!.phVal!.asDoubles!
            if !test["limits"]!.phVal!.unit.isIdentical(unit: unit) {
                return errVal("x and limits have different units")}
            n = limits.count - 1
        } else {
            if n == nil { return errVal("At least one of the arguments n, q, limits must be given !")}
            var min = vals.min()!
            var max = vals.max()!
            if test["min"]!.phVal != nil {
                if !test["min"]!.phVal!.unit.isIdentical(unit: unit) { return errVal("x and min have different units")}
                min = test["min"]!.phVal!.asDouble!
            }
            if test["max"]!.phVal != nil {
                if !test["max"]!.phVal!.unit.isIdentical(unit: unit) { return errVal("x and max have different units")}
                max = test["max"]!.phVal!.asDouble!
            }
            limits = statsUniformClasses(min: min, max: max, nc: n!)
        }
        
        let indexes = vals.map({ a in
            a == limits[0] ? 0 : (limits.firstIndex(where: {$0 >= a }) ?? 0) - 1
        })
        if test["names"]?.phVal != nil {
            let names = test["names"]!.phVal!.asStrings!
            if names.count < n! { return errVal( "not enough names for your classes")}
            let other = names.count > n! ? names[n!] : "Other"
            let strings = indexes.map({  $0 > -1 ? names[$0] : other })
            return PhysValue(unit: Unit(), type: "string", values: strings)
        }
        return PhysValue(unit: Unit(), type: "int", values: indexes)
    }
      
    // corrélation, covariance, R2.
    func xCorrelations() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x",type: "double"),
            funcArgument("y",type: "double")
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!.asDoubles!
        let y = test["y"]!.phVal!.asDoubles!
        if x.count != y.count { return PhysValue(error: "x and y vectors must have same length")}
        if op.hasPrefix("cov") {
            let unit = test["x"]!.phVal!.unit.multiplyWith(unit: test["y"]!.phVal!.unit, exp1: 1, exp2: 1)
            return PhysValue(unit: unit, type: "double", values: [statsCovariance(x: x, y: y)])
        } else if op.hasPrefix("r") {
            return PhysValue(doubleVal : statsRSquare(x: x, y: y))
        } else {
            let cov = statsCovariance(x: x, y: y)
            let vv = statsVariance(x)*statsVariance(y)
            return PhysValue(doubleVal: cov / sqrt(vv) )
        }
    }
    
    // ******************
    // Matrices et champs
    // ******************
    
    // dimensions d'une physval
    func xDim() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x"),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let dims = test["x"]?.phVal!.dim
        return PhysValue(unit: Unit(), type: "int", values: dims!)
    }
    
    // Création d'une matrice 2D à partir de valeurs
    func xMatrix() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("dim",type: "int"),
            funcArgument("data", defVal: PhysValue(intVal: 0)),
            funcArgument("f",type: "exp", requested: false), // fonction de i,j,k,l,m
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let dims = test["dim"]!.phVal!.asIntegers!
        for d in dims {
            if d<1 { return errVal("dimensions must be positive integers")}
        }
        if dims.count > 5 { return errVal("maximum 5 dimensions are supported in hypermatrix")}
        let vecSize = dims.reduce(1,*)
        var data = test["data"]!.phVal!.values
        var unit = test["data"]!.phVal!.unit
        var type = test["data"]!.phVal!.type
        if data.count == 0 {
            type = "double"
            data = Array(repeating: 0.0, count: vecSize)
        } else if data.count == 1 {
            data = Array(repeating: data[0], count: vecSize)
        }
        while data.count < vecSize { data.append(contentsOf: data) }
        if data.count > vecSize { data = data.dropLast(data.count-vecSize)}
        if test["f"]!.exp != nil {
            let coordsByIndex = getAllCoordsIndexes(dim: dims)

            var dataVals : [Any] = []
            let theVars = ["i","j","k","l","m","n"].prefix(dims.count)
            let f = test["f"]!.exp!
            var savedVars = Dictionary<String,PhysValue>()
            for aVar in theVars { if theVariables[aVar] != nil { savedVars[aVar] = theVariables[aVar] } }
            for counter in 0..<vecSize {
                let coords = coordsByIndex[counter]
                for (n,v) in theVars.enumerated() {
                    theVariables[v] = PhysValue(intVal: coords[n])
                }
                let t = f.executeHierarchicScript()
                if t.isError { return t }
                if (t.values.count < 1) { return errVal("error while calculating function") }
                dataVals.append(t.asDouble!)
                if counter == 0 {
                    type = t.type
                    unit = t.unit
                }
            }
            for aVar in theVars { if savedVars[aVar] != nil { theVariables[aVar] = savedVars[aVar] } }
            data = dataVals

        }
        return PhysValue(unit: unit, type: type, values: data, dim: dims)
    }
    
    // produit (ou autre) externe
    func xOuter() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x", type: "double", requested: true),
            funcArgument("y", type: "double", requested: true),
            funcArgument("f", type: "exp", requested: false)
        ])
        
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal
        let y = test["y"]!.phVal
        var d1 = x!.dim
        var d2 = y!.dim
        d1.removeAll(where: { $0 == 1} )
        d2.removeAll(where: { $0 == 1} )
        let exp = test["f"]?.exp
        var r: PhysValue
        var rv : [Double] = []
        if exp == nil {
            // produit externe : les arguments doivent être deux vecteurs ou matrices
            r = x!.physValn(n: 0).mult(y!.physValn(n: 0))
            let v1 = x!.asDoubles!
            let v2 = y!.asDoubles!
            v2.forEach { a in
                rv.append(contentsOf: v1.map({ a*$0 }) )
            }
            r.values = rv
            d1.append(contentsOf: d2)
            r.dim = d1
            return r
        } else {
            // les arguments sont deux vecteurs x et y et une fonction de variables locales x et y
            let temporX = theVariables["x"]
            let temporY = theVariables["y"]
            theVariables["x"] = x!.physValn(n: 0)
            theVariables["y"] = y!.physValn(n: 0)
            r = exp!.executeHierarchicScript()
            let n1 = x!.values.count
            let n2 = y!.values.count
            for j in 0..<n2 {
                for i in 0..<n1 {
                    theVariables["x"] = x!.physValn(n: i)
                    theVariables["y"] = y!.physValn(n: j)
                    let rr = exp!.executeHierarchicScript().asDouble
                    if rr != nil { rv .append(rr!)}
                    else {
                        theVariables["x"] = temporX
                        theVariables["y"] = temporY
                        return errVal("error in calculation at x\(i) y\(j)")
                    }
                }
            }
            theVariables["x"] = temporX
            theVariables["y"] = temporY
        }
        r.values = rv
        d1.append(contentsOf: d2)
        r.dim = d1
        return r
    }
    
    // transposée d'une matrice
    func xTranspose() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x", type: "double", requested: true),
            funcArgument("perm", type: "int", requested: false)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!
        let p = test["perm"]!.phVal?.asIntegers ?? nil
        return x.transpose(p: p)
    }
    
    func xDeterminant() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x", type: "double", requested: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!
        return x.determinant()
    }
    
    // produit matriciel
    func xMatrixProd() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x", type: "double", requested: true),
            funcArgument("y", type: "double", requested: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!
        let y = test["y"]!.phVal!
        let d1 = x.dim
        let d2 = y.dim
        if d1.count != 2 || d2.count != 2 { return errVal("Arguments should be 2-D matrices")}
        if d1[0] != d2[1] { return errVal("number of columns in x shoud be equal to number of rows in y")}
        let vx = x.asDoubles!
        let vy = y.asDoubles!
        let r = x.physValn(n: 0).mult(y.physValn(n: 0))
        var vals : [Double] = []
        var val : Double = 0
        for i in 0..<d1[1] {
            for j in 0..<d2[0] {
                val = 0
                for k in 0..<d1[0] {
                    let v1 = vx[indexFromCoords(dim: d1, coord: [k,i])]
                    let v2 = vy[indexFromCoords(dim: d2, coord: [j,k])]
                    val = val + v1*v2
                }
                vals.append(val)
            }
        }
        r.values = vals
        r.dim = [d2[0],d1[1]]
        return r
    }
    
    // création d'un champ
    func xField() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("f",type: "exp"), // fonction de x,y,z ou de i,j,k
            funcArgument("size",type: "double"), // taille du champ (en m ou autre dimension))
            funcArgument("dx", type: "double"), // taille d'une cellule (par défaut = 1m). Doit être un sous-multiple des dim.
            funcArgument("center", type: "double", requested: false), // default = (0,0)
            funcArgument("origin", type: "double", requested: false),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let f = test["f"]!.exp!
        let size = test["size"]!.phVal!
        let dx = test["dx"]!.phVal!
        if !size.unit.isIdentical(unit: dx.unit) { return errVal("size and dx should have similar units")}
        var dims = (size.binaryOp(op: "/", v2: dx)).asDoubles!.map({ Int(round($0))})
        let nDims = size.values.count
        
        let center = test["center"]?.phVal ?? PhysValue(unit: size.unit, type: "double", values: Array(repeating: 0, count: nDims))
        if !center.unit.isIdentical(unit: dx.unit) { return errVal("center and size should have similar units")}
        
        let origin = test["origin"]?.phVal ?? center.binaryOp(op: "+", v2: size.numericFunction(op: "_minus").binaryOp(op: "/", v2: PhysValue(doubleVal: 2)))
        if !origin.unit.isIdentical(unit: dx.unit) { return errVal("start and size should have similar units")}
        
        let cell0 = origin.binaryOp(op: "+", v2: dx.div(PhysValue(doubleVal: 2))) // la première cellule du champ
        
        // sauvegarde des variables
        let theVars = ["x","y","z"]
        var savedVars = Dictionary<String,PhysValue>()
        for aVar in theVars {
            if theVariables[aVar] != nil { savedVars[aVar] = theVariables[aVar] }
        }
   
        // test du calcul de la fonction
          theVariables["x"] = origin.physValn(n: 0)
        if nDims > 1 {theVariables["y"] = origin.physValn(n: 1)}
        if nDims == 3 {theVariables["z"] = origin.physValn(n: 2)}
        var t = f.executeHierarchicScript()
        if t.values.count > 3 || t.type != "double"  {
            return errVal("Function f should return scalar or 2-D or 3-D vector")}
        if t.values.count == 0 {
            return errVal("Unknown error in function defining field")
        }
        let vector = t.values.count
                
        var dataVals : [Any] = []
        var dataVals2 : [Any] = []
        var dataVals3 : [Any] = []
        
        let dxVal = dx.asDouble!
        
        if nDims == 3 {
           
            theVariables["z"] = cell0.physValn(n: 2)
            theVariables["y"] = cell0.physValn(n: 1)
            theVariables["x"] = cell0.physValn(n: 0)
            let valz0 = theVariables["z"]!.asDouble!
            let valy0 = theVariables["y"]!.asDouble!
            let valx0 = theVariables["x"]!.asDouble!
            for i in 0..<dims[2] {
                theVariables["z"]!.values[0] = valz0 + Double(i) * dxVal
                for j in 0..<dims[1] {
                    theVariables["y"]!.values[0] = valy0 + Double(j) * dxVal
                    for k in 0..<dims[0] {
                        theVariables["x"]!.values[0] = valx0 + Double(k) * dxVal
                        t = f.executeHierarchicScript()
                        if t.isError { return t }
                        dataVals.append(t.values[0])
                        if vector > 1 {
                            dataVals2.append(t.values[1])
                            if vector == 3 { dataVals3.append(t.values[2]) }
                        }
                    }
                }
            }
        } else if nDims == 2 {
            theVariables["y"] = cell0.physValn(n: 1)
            theVariables["x"] = cell0.physValn(n: 0)
            let valy0 = theVariables["y"]!.asDouble!
            let valx0 = theVariables["x"]!.asDouble!
            for j in 0..<dims[1] {
                theVariables["y"]!.values[0] = valy0 + Double(j) * dxVal
                for k in 0..<dims[0] {
                    theVariables["x"]!.values[0] = valx0 + Double(k) * dxVal
                    t = f.executeHierarchicScript()
                    if t.isError { return t }
                    dataVals.append(t.values[0])
                    if vector > 1 {
                        dataVals2.append(t.values[1])
                        if vector == 3 { dataVals3.append(t.values[2]) }
                    }
                }
            }
        } else if nDims == 1 {
            theVariables["x"] = cell0.physValn(n: 0)
            let valx0 = theVariables["x"]!.asDouble!
            theVariables["x"] = cell0.physValn(n: 0)
            for k in 0..<dims[0] {
                theVariables["x"]!.values[0] = valx0 + Double(k) * dxVal
                t = f.executeHierarchicScript()
                if t.isError { return t }
                dataVals.append(t.values[0])
                if vector > 1 {
                    dataVals2.append(t.values[1])
                    if vector == 3 { dataVals3.append(t.values[2]) }
                }
            }
        } else {
            return errVal("Calculated fields should have 1, 2 or 3 dimensions")
        }
        
        if vector > 1 {
            dataVals.append(contentsOf: dataVals2)
            if vector == 3 { dataVals.append(contentsOf: dataVals3) }
        }

        for aVar in theVars {
            if savedVars[aVar] != nil {
                theVariables[aVar] = savedVars[aVar]
            } else {
                theVariables[aVar] = nil
            }
        }
        
        
        let vec = vector > 1 ? true : false
        if vec { dims.append(vector)}
        return PhysValue(unit: t.unit,
                         type: t.type,
                         values: dataVals,
                         dim: dims,
                         field: ["origin" : origin, "dx" : dx, "vec" : PhysValue(boolVal: vec)])
    }
    
    func xMatfield() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("matrix", requested: false),
            funcArgument("dx", type: "double", defVal: PhysValue(unit: Unit(unitExp: "m1"), type: "double", values: [1.0])), // taille d'une cellule (par défaut = 1m)
            funcArgument("origin", type: "double", requested: false),
            funcArgument("vector", type: "int", defVal: PhysValue(intVal: 0)), // 0 pour un champ scalaire
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let mat = test["matrix"]!.phVal!
        let vector = test["vector"]!.phVal!.asInteger!
        if vector > 3 { return errVal("Only vector fields of 2 or 3-dimensional vectors are accepted")}
        let vec = vector > 0 ? true : false
        let dim = vec ? (mat.dim).count - 1 : (mat.dim).count
        let dx = test["dx"]!.phVal!
        let origin = test["origin"]?.phVal == nil ?
            PhysValue(unit: dx.unit, type: "double", values: Array(repeating: 0, count: dim))
            : test["origin"]!.phVal!
        return PhysValue(unit: mat.unit, type: mat.type, values: mat.values, dim: mat.dim,
                         field: ["origin" : origin, "dx" : dx, "vec" : PhysValue(boolVal: vec)])
    }
    
    // valeurs(x) d'une champ aux points x, y, z
    func xFieldVal() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("field", type: "double"),
            funcArgument("at", type: "double", requested: false, repeating: true),
            funcArgument("x", type: "double", requested: false),
            funcArgument("y", type: "double", requested: false),
            funcArgument("z", type: "double", requested: false),
            funcArgument("extrapolate", type: "bool", defVal: PhysValue(boolVal: false))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let field = test["field"]!.phVal!
        if !field.isField { return errVal("first argument of fieldval() must be a field")}
        let fDim = field.isVec ? field.dim.count - 1 : field.dim.count
        var res = PhysValue(unit: field.unit, type: "double", values: [], dim: [fDim])
        let ex = test["extrapolate"]!.phVal!.asBool!
        if test["at"]?.phVal != nil {
            let n = test["at"]!.phVal!.asInteger!
            if field.isVec && n > 1 {res.type = "list" }
            for k in 0..<n {
                let p = test["at\(k)"]!.phVal!
                if p.values.count != fDim { return errVal("wrong dimensions") }
                if !field.fieldContains(point: p) { return errVal("point is outside field limits")}
                let v = field.getFieldValWithCoord(coord: p, extra: ex)
                if v == nil { return errVal("error while getting field value at " + p.stringExp(units: true))}
                if res.type == "list" {
                    res.values.append(v!)
                } else if n > 1 {
                    res.values.append(v!.asDouble!)
                } else {
                    res = v!
                }
            }
        } else {
            var coordVals : [[Double]] = []
            let x = test["x"]?.phVal
            if x == nil { return errVal("missing x coordinates")}
            coordVals.append(x!.asDoubles!)
            let n = x!.values.count
            if field.isVec && n > 1 {res.type = "list" }
            if fDim > 1 {
                let y = test["y"]?.phVal
                if y == nil { return errVal("missing y coordinates")}
                if y!.values.count != n { return errVal("wrong number of y coordinates")}
                coordVals.append(y!.asDoubles!)
            }
            if fDim > 2 {
                let z = test["z"]?.phVal
                if z == nil { return errVal("missing z coordinates")}
                if z!.values.count != n { return errVal("wrong number of z coordinates")}
                coordVals.append(z!.asDoubles!)
            }
            for k in 0..<n {
                let p = x!
                p.values = []
                for i in 0..<fDim {
                    p.values.append(coordVals[i][k])
                }
                if !field.fieldContains(point: p) { return errVal("point is outside field limits")}
                let v = field.getFieldValWithCoord(coord: p, extra: ex)
                if v == nil { return errVal("error while getting field value for \(k)")}
                if res.type == "list" {
                    res.values.append(v!)
                } else if n > 1 {
                    res.values.append(v!.asDouble!)
                } else {
                    res = v!
                }
            }
         }
        res.dim = [res.values.count]
        return res
    }
    
    // doublement ou réduction de la résolution d'un champ par extrapolation ou élimination
    func xDoubleField() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("field", type: "double"), // le champ scalaire
            funcArgument("n", type: "int", defVal: PhysValue(intVal: 1))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        if !test["field"]!.phVal!.isField { return errVal("first argument of " + op + "() must be a field")}
        var x = test["field"]!.phVal!.dup()
        let n = test["n"]!.phVal!.asInteger!
        if n<1 || n>10 { return errVal("argument n should be a positive integer less than 10")}
        if op == "doublefield" {
            for _ in 1...n { x = x.doubleField() }
        } else {
            for _ in 1...n { x = x.reduceField()}
        }
        return x
    }
    
    // atténuement d'un champ (avec ou sans conservation des extremums)
    func xSmoothField() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("field", type: "double"),
            funcArgument("n", type: "int", defVal: PhysValue(intVal: 1)),
            funcArgument("keepmaxmin", type: "bool", defVal: PhysValue(boolVal: true))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        if !test["field"]!.phVal!.isField { return errVal("first argument of " + op + "() must be a field")}
        var x = test["field"]!.phVal!.dup()
        let n = test["n"]!.phVal!.asInteger!
        if n<1 || n>10 { return errVal("argument n should be a positive integer less than 10")}
        let keep = test["keepmaxmin"]!.phVal!.asBool!
        for _ in 1...n { x = x.smoothField(keep: keep) }
        return x
    }
    
    // décalage des éléments d'une n-matrice
    func xShiftmatrix() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x",type: "double", requested: true),
            funcArgument("d",type: "int",requested: true),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!
        let dx = test["d"]!.phVal!
        let dims = x.dim
        if dx.dim.count != 1 { return PhysValue(error: "dx must be a vector of integers with a length equal to number of dims of x")}
        if dx.dim[0] != dims.count { return PhysValue(error: "dx must be a vector of integers with a length equal to number of dims of x")}
        
        let rVals = shiftMatrix(m: x.asDoubles!, dim: x.dim, dx: dx.asIntegers!)
        return PhysValue(unit: x.unit, type: x.type, values: rVals, dim: x.dim)
    }
    
    // retourne une sous-physval (si getVal est false elle contient juste les numéros d'indices)
    // tient éventuellement compte de vec
    func xIndexesOfArray(getVal : Bool = true) -> PhysValue {
        
        switch op {
        
        // extrait une hypermatrice à partir d'une liste de coordonnées (coords array)
        // exemple list((0,1,2),-1,5) = col 0, 1 et 2 de toutes les lignes du plan 5
        case "submatrix", "submat" :
            let test = testArguments(structure: [
                funcArgument("m",type: "double", requested: true),
                funcArgument("coord",type: "list",requested: true)
            ])
            if test["error"] != nil { return test["error"]!.phVal! }
            let x = test["m"]!.phVal!
            
            let coordList = test["coord"]!.phVal!
            var coordArray : [[Int]] = []
            if x.isVec { coordList.values.append([-1]) }
            if coordList.values.count != x.dim.count { return PhysValue(error: "list of coordinates should be same length as dimensions of x")}
            for coord in coordList.values {
                let newCoords = (coord as? PhysValue ?? PhysValue(intVal: -1)).asIntegers ?? [-1]
                coordArray.append(newCoords)
            }
            if getVal { return x.subMatrix(coords: coordArray) //.reduceDims()
            } else { return PhysValue(indexes: x.coordArrayToIndexes(coords: coordArray)) }
            
        // extrait une "tranche" d'une hyper-matrice
        case "slice" :
            let test = testArguments(structure: [
                funcArgument("x",type: "double", requested: true),
                funcArgument("dim",type: "int",requested: true),
                funcArgument("index",type: "int",requested: true),
            ])
            if test["error"] != nil { return test["error"]!.phVal! }
            let x = test["x"]!.phVal!
            let dims = x.dim
            let dim = test["dim"]!.phVal!.asInteger!
            if dim < 0 || dim > dims.count-1 { return PhysValue(error: "wrong dim value")}
            let index = test["index"]!.phVal!.asInteger!
            if index < 0 || index > dims[dim] - 1 { return PhysValue(error: "wrong index value")}
            var coordArray : [[Int]] = Array(repeating: [-1], count: dims.count)
            coordArray[dim] = [index]
            if getVal { return x.subMatrix(coords: coordArray).reduceDims()
            } else { return PhysValue(indexes: x.coordArrayToIndexes(coords: coordArray)) }
            
        // retourne les n derniers ou n premiers élément
        
        case "last", "first" :
            let test = testArguments(structure: [
                funcArgument("x"),
                funcArgument("n", type: "int", defVal: PhysValue(intVal: 1))
            ])
            if test["error"] != nil { return test["error"]!.phVal! }
            let x = test["x"]!.phVal!
            let N = x.values.count
            var n = test["n"]!.phVal!.asInteger!
            if n < 0 {
                n = N + n
            }
            if x.dim.count > 1 { return errVal("applies only ont sequences or lists") }
            if N < n || n < 1 { return errVal("n greater than sequence length")}
            let newVals = (op == "last" || n < 0) ? x.values.suffix(from: N-n) : x.values.prefix(upTo: n)
            return PhysValue(unit: x.unit, type: x.type, values: Array(newVals))
                            
            
        // extrait une partie à patir d'indices
        case "indexed", "#" :
            let test = testArguments(structure: [
                funcArgument("x"),
                funcArgument("indexes", type: "exp")
            ])
            if test["error"] != nil { return test["error"]!.phVal! }
            let x = test["x"]!.phVal!
            let indexExp = test["indexes"]!.exp!
            let indexes = indexExp.executeHierarchicScript()
            var indexName = indexExp.op == "_var" ? indexExp.string : nil
            
            if x.type == "dataframe" {
                var coord : [String]? = []
                if indexes.isNumber && indexes.values.count > 0 {
                    let intIndexes = indexes.asIntegers!
                    if (x.names![0]).count > intIndexes[0] {
                        coord!.append((x.names![0])[intIndexes[0]])
                    }
                    if intIndexes.count == 2 {
                        if (x.names![1]).count > intIndexes[1] {
                            coord!.append((x.names![1])[intIndexes[1]])
                        }
                    }
                } else if indexes.isString() && indexes.values.count > 0 {
                    coord = indexes.asStrings
                } else {
                    if indexExp.op == "," {
                        for arg in indexExp.args {
                            if arg.op == "_var" {
                                coord!.append(arg.string!)
                            } else {
                                if arg.op == "_val" {
                                    if arg.value!.type == "string" {
                                        coord!.append(arg.value!.asString!)
                                    } else if arg.value!.isNumber {
                                        let i = arg.value!.asInteger!
                                        let n = coord!.count
                                        coord!.append((x.names![n])[i])
                                    } else {
                                        return PhysValue(error: "indexes should be strings")
                                    }
                                }
                            }
                        }
                    } else if indexExp.op == "_var" {
                        coord = [indexExp.string!]
                    }
                }
                if coord!.count == 1 && getVal {
                    indexName = coord![0]
                    if x.names![0].contains(indexName!) {
                        let colNbr = x.names![0].firstIndex(of: indexName!)!
                        return (x.values[colNbr] as! PhysValue)
                    } else if x.names![1].contains(indexName!) {
                        let rowNbr = x.names![1].firstIndex(of: indexName!)!
                        let result = x.dup()
                        for (k,aColumn) in result.values.enumerated() {
                            let aColRed = (aColumn as! PhysValue).physValn(n: rowNbr)
                            result.values[k] = aColRed
                        }
                        result.names![1] = [indexName!]
                        return result
                    } else {
                        return errVal("wrong column or row name")
                    }
                }
                if coord!.count != 2 { return PhysValue(error: "two indexes needed") }
                let colNbr = x.names![0].firstIndex(of: coord![0])
                let rowNbr = x.names![1].firstIndex(of: coord![1])
                if colNbr == nil { return PhysValue(error: "wrong column name " + coord![0]) }
                if rowNbr == nil { return PhysValue(error: "wrong row name " + coord![1])}
                
                if getVal {
                    return (x.values[colNbr!] as! PhysValue).physValn(n: rowNbr!)
                } else {
                    let index = x.indexFromCoords(coord: [colNbr!,rowNbr!])
                    if index == nil { return PhysValue(error: "wrong index in dataframe")}
                    return PhysValue(indexes: [index!]) // ne pas faire ceci ???
                }
                
            } else if x.isVec && (indexes.values.count == 1 || ["x","y","z"].contains(indexName)) {
                // pour les champs vectoriels, on accepte les indices uniques x, y, z et 'x, 'y', 'z' et 1, 2, 3, 4...
                let dim = test["x"]!.phVal!.dim
                var coord = indexes.asInteger
                let coordName = ["x","y","z"].contains(indexName) ? test["indexes"]!.exp?.string! : indexes.asString
                if coordName != nil { coord = ["x":0,"y":1,"z":2][coordName] }
                if coord == nil { return PhysValue(error: "wrong coordinate name or number")}
                if coord! < 0 || coord! > dim.last! - 1 { return PhysValue(error: "wrong coordinate")}
                var coordArray : [[Int]] = Array(repeating: [-1], count: dim.count)
                coordArray[dim.count - 1] = [coord!]
                if getVal { return x.subMatrix(coords: coordArray).reduceDims()
                } else { return PhysValue(indexes: x.coordArrayToIndexes(coords: coordArray)) }
                
            } else {
                if indexes.values.count == 0 {  return errVal("Wrong indexes") }
                let dim = test["x"]!.phVal!.dim
                let coord = indexes.asIntegers
                if coord == nil { return PhysValue(error: "indexes should be integers") }
                if x.isVec {
                    // on retourne un vecteur
                    if coord!.count != dim.count - 1 { return PhysValue(error: "Wrong number of dimensions") }
                    var coordArray : [[Int]] = []
                    for c in coord! {
                        coordArray.append([c])
                    }
                    coordArray.append([-1])
                    if getVal { return x.subMatrix(coords: coordArray).reduceDims()
                    } else { return PhysValue(indexes: x.coordArrayToIndexes(coords: coordArray)) }
                    
                } else {
                    // on retourne un scalaire
                    if dim.count != coord!.count { return PhysValue(error: "Wrong number of dimensions") }
                    let index = x.indexFromCoords(coord: coord!)
                    if index == nil { return PhysValue(error: "error in index")}
                    if getVal {
                        return x.physValn(n: index!)
                    } else {
                        return PhysValue(indexes: [index!])
                    }
                }
            }
            
        // extraction de valeurs par une liste d'indices ou un vecteur booleen (@ remplace {..} )
        case "@", "extract" :
            if args.count != 2 {return PhysValue(error:"not exactly two arguments in binary operation") }
            let value1 = args[0].executeHierarchicScript()
            if value1.type == "error" {return value1 }
            let value2 = args[1].executeHierarchicScript()
            if value2.type == "error" {return value2 }
            var indexes : [Int]
            if value2.type == "" {
                // membre par défaut dans un script
                // utilise la variable "scriptMember" de la simulation pour identifier le contexte
                if theSim.scriptMember == nil {return PhysValue(error:"no default member in this context") }
                indexes = [theSim.scriptMember!]
            }
            else if value2.type == "bool" {
                let boolVals = value2.asBools
                if boolVals == nil {return PhysValue(error: "wrong boolean index") }
                if boolVals!.count != value1.values.count {return PhysValue(error: "vector and bool indexes not of same length") }
                indexes = boolVals!.indices.filter{ boolVals![$0] == true }
                
            } else {
                let indexesTest = value2.asIntegers
                if indexesTest == nil {return PhysValue(error:"wrong index") }
                indexes = indexesTest!
            }
            if getVal {
                return value1.subPhysVal(indexes: indexes)
            } else {
                return PhysValue(indexes: indexes)
            }
            
        default:
            return PhysValue(error: "wrong operator ???")
        }
    }
    
    // gradiant d'un champ scalaire -> retourne un champ vectoriel
    func xGradiant() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("field", type: "double", requested: true), // le champ scalaire
            funcArgument("at", type: "double", requested: false)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["field"]!.phVal!
        if x.isVec || x.field == nil { return PhysValue(error: "argument of grad should be scalar field ")}
        if test["at"]?.phVal == nil {
            return x.gradiant()
        } else {
            return x.gradiant() // A modifier ultérieurement...
        }
        
    }
    
    // divergence d'un champ vectoriel -> retourne un champ scalaire
    func xDivergence() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x") // le champ vectoriel
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!.dup()
        let xVals = x.asDoubles!
        if !x.isVec || x.field == nil { return PhysValue(error: "argument of div should be a vector field ")}
        let xdims = x.dim
        let dims = Array(xdims.dropLast())
        let coords = getAllCoordsIndexes(dim: dims)
        let n = dims.reduce(1, *)
        let nDims = dims.count // nombre de dimensions (1, 2 ,3...)
        var resultVals : [Double] = Array(repeating: 0, count: n)
        
        coords.enumerated().forEach( {i, c in
            (0..<nDims).forEach({ d in
                let v = xVals[i + n * d]
                var cNext = c
                var cPrev = c
                cNext[d] = cNext[d] + 1
                cPrev[d] = cPrev[d] - 1
                let iSelf = indexFromCoords(dim: dims, coord: c)
                if cNext[d] < dims[d] && cPrev[d] > -1 {
                    let iPrev = indexFromCoords(dim: dims, coord: cPrev) + n*d
                    let iNext = indexFromCoords(dim: dims, coord: cNext) + n*d
                    resultVals[iSelf] = resultVals[iSelf] + (xVals[iNext] - xVals[iPrev])/2
                } else if cNext[d] < dims[d] {
                    let iNext = indexFromCoords(dim: dims, coord: cNext) + n*d
                    resultVals[iSelf] = resultVals[iSelf] + (xVals[iNext] - v)
                } else if cPrev[d] > -1 {
                    let iPrev = indexFromCoords(dim: dims, coord: cPrev) + n*d
                    resultVals[iSelf] = resultVals[iSelf] + (v - xVals[iPrev])
                }
            })
        })
        
        var result = PhysValue(unit: x.unit, type: x.type, values: resultVals, dim: dims, field: x.field)
        result.setVec(false) // un champ scalaire
        result = result.binaryOp(op: "/", v2: x.field!["dx"]!)
        return result
    }
    
    func xFieldInfo() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x") // le champ
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!
        if x.field == nil { return PhysValue(error: "argument should be a field ")}
        let orig = x.field!["origin"]!
        let dx = x.field!["dx"]!
        let dims = PhysValue(unit: Unit(), type: "double", values: x.dim )
        let size = dx.binaryOp(op: "*", v2: dims)
        let vec = x.field!["vec"]!.asBool!
        let vecdim = PhysValue(intVal: 0)
        if vec {
            vecdim.values = [dims.values.last as! Int]
            dims.values.removeLast()
        }
        switch op {
        case "fieldorigin" : return orig
        case "fieldcell" : return dx
        case "fieldsize" : return size
        case "fieldvector" : return vecdim
        default :
            let result = PhysValue(unit: Unit(), type: "list", values: [orig,dx,size,vecdim], dim: [4])
            result.names = [["origin","cell size","field size","vector"],[""]]
            return result
        }
    }
    
    // crée un dataframe à partir de colonnes de même longueur.
    // Par défaut le nom de colonne est l'exp. Le nom de ligne est 1, 2, 3...
    func xDataframe() -> PhysValue {
        let test = testArguments(structure:[
            funcArgument("data", type: "any", requested: true, repeating: true),
            funcArgument("columns", type: "string", requested: false),
            funcArgument("rows", type: "string", requested: false)
        ])
        
        if test["error"] != nil { return test["error"]!.phVal! }
        
        var nCols = test["data"]!.phVal!.asInteger!
        if nCols<1 { return errVal("A dataframe must have at least one column")}
        if nCols>100 { return PhysValue(error: "Too much columns (max = 100)") }
        var nRows = test["data\(0)"]!.phVal!.values.count
        let returnValue = PhysValue(unit: Unit(), type: "dataframe", values: [], dim: [nCols] )
        
        var colNames: [String] = []
        for col in 0...nCols - 1 {
            if test["data\(col)"]!.phVal == nil { return PhysValue(error: "Error in column \(col)")}
            let colData = test["data\(col)"]!.phVal!
            if col == 0 && colData.type == "dataframe" {
                nRows = (colData.values[0] as! PhysValue).values.count
                nCols = nCols + colData.values.count - 1
                colNames.append(contentsOf: colData.names![0])
                returnValue.values.append(contentsOf: colData.values)
                returnValue.dim = [nCols]
            } else {
                if colData.values.count != nRows {
                    return PhysValue(error: "Wrong number of data in column \(col)")
                }
                returnValue.values.append(colData)
                colNames.append(test["data\(col)"]!.exp!.string!)
            }
        }
        
        if test["columns"]!.phVal != nil {
            if test["columns"]!.phVal!.asStrings == nil { return PhysValue(error: "Unknown error in column names")}
            colNames = test["columns"]!.phVal!.asStrings!
            if colNames.count != nCols { return PhysValue(error: "Wrong number of column names")}
        }
        
        var rowNames : [String]?
        if test["rows"]!.phVal != nil {
            rowNames = test["rows"]!.phVal!.asStrings
            if rowNames == nil { return PhysValue(error: "Row names should be strings or convertible to strings" ) }
            if rowNames!.count != nRows { return errVal("Wrong number of row names") }
        } else {
            rowNames = Array(0..<nRows).map{ "R\($0)" }
        }
        
        returnValue.names = [colNames,rowNames!]
        returnValue.dim = [colNames.count]
        return returnValue
    }
    
    func xColnames() -> PhysValue {
        let test = testArguments(structure:[
            funcArgument("df", type: "dataframe", requested: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let names = test["df"]!.phVal!.names
        let d = (op == "colnames") ? 0 : 1
        if names == nil { return errVal("Dataframe has no column names ???")}
        return PhysValue(unit: Unit(), type: "string", values: names![d])
    }
    
    // *******************
    // Graphes et couleurs
    // *******************
    
    // retourne une physVal contenant une (ou des) couleurs à partir des composants r,g,b,a ou du nom
    func xColor() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("r",type: "double", defVal: PhysValue(doubleVal: 0.5), limits: ["≥":0,"≤":1]),
            funcArgument("g",type: "double", defVal: PhysValue(doubleVal: 0.5), limits: ["≥":0,"≤":1]),
            funcArgument("b",type: "double", defVal: PhysValue(doubleVal: 0.5), limits: ["≥":0,"≤":1]),
            funcArgument("a",type: "double", defVal: PhysValue(doubleVal: 1.0), limits: ["≥":0,"≤":1])
        ])
        // on regarde éventuellement si on a donné un nom de couleur
        if test["error"] != nil {
            let test2 = testArguments(structure: [
                funcArgument("name",type: "string"),
                funcArgument("a",type: "double", defVal: PhysValue(doubleVal: 1.0), limits: ["≥":0,"≤":1])
            ])
            if test2["error"] != nil { return test["error"]!.phVal! }
            let a = test2["a"]!.phVal!.asDouble!
            if a == 1 {
                let name = test2["name"]?.phVal!.asString!
                switch name {
                case "b","blue": return PhysValue(color: NSColor.blue)
                case "r","red" : return PhysValue(color: NSColor.red)
                case "o","orange": return PhysValue(color: NSColor.orange)
                case "brown": return PhysValue(color: NSColor.brown)
                case "g","green": return PhysValue(color: NSColor.green)
                case "y","yellow": return PhysValue(color: NSColor.yellow)
                case "gray", "grey": return PhysValue(color: NSColor.gray)
                case "pink": return PhysValue(color: NSColor.systemPink)
                case "teal": return PhysValue(color: NSColor.systemTeal)
                case "indigo": if #available(OSX 10.15, *) {
                    return PhysValue(color: NSColor.systemIndigo)
                } else {
                    return PhysValue(color: NSColor.purple)
                }
                case "purple": return PhysValue(color: NSColor.purple)
                case "black": return PhysValue(color: NSColor.black)
                default: return PhysValue(color: NSColor.white)
                }
            } else {
                let name = test2["name"]?.phVal!.asString!
                switch name {
                case "b","blue": return PhysValue(color: NSColor.blue.withAlphaComponent(a))
                case "r","red" : return PhysValue(color: NSColor.red.withAlphaComponent(a))
                case "o","orange": return PhysValue(color: NSColor.orange.withAlphaComponent(a))
                case "brown": return PhysValue(color: NSColor.brown.withAlphaComponent(a))
                case "g","green": return PhysValue(color: NSColor.green.withAlphaComponent(a))
                case "y","yellow": return PhysValue(color: NSColor.yellow.withAlphaComponent(a))
                case "gray", "grey": return PhysValue(color: NSColor.gray.withAlphaComponent(a))
                case "pink": return PhysValue(color: NSColor.systemPink.withAlphaComponent(a))
                case "teal": return PhysValue(color: NSColor.systemTeal.withAlphaComponent(a))
                case "indigo": if #available(OSX 10.15, *) {
                    return PhysValue(color: NSColor.systemIndigo.withAlphaComponent(a))
                } else {
                    return PhysValue(color: NSColor.purple.withAlphaComponent(a))
                }
                case "purple": return PhysValue(color: NSColor.purple.withAlphaComponent(a))
                case "black": return PhysValue(color: NSColor.black.withAlphaComponent(a))
                default: return PhysValue(color: NSColor.white.withAlphaComponent(a))
                }
            }
        }
        
        let r = test["r"]!.phVal!.asDoubles!
        let g = test["g"]!.phVal!.asDoubles!
        let b = test["b"]!.phVal!.asDoubles!
        let a = test["a"]!.phVal!.asDoubles!
        let nc = max(r.count,g.count,b.count,a.count)
        if r.count != 1 && r.count != nc { return PhysValue(error:"wrong number of color components") }
        if g.count != 1 && g.count != nc { return PhysValue(error:"wrong number of color components")}
        if b.count != 1 && b.count != nc { return PhysValue(error:"wrong number of color components") }
        if a.count != 1 && a.count != nc { return PhysValue(error:"wrong number of color components") }
        var colors : [NSColor] = []
        var dim : [Int] = [1]
        var field : [String:PhysValue]?
        for c in ["r","g","b","a"] {
            if test[c]!.phVal!.dim.count > 1 {
                dim = test[c]!.phVal!.dim
                field = test[c]!.phVal!.field
            }
        }
        
        for k in 0...nc-1 {
            var red = r[0]
            if r.count == nc { red = r[k] }
            var green = g[0]
            if g.count == nc { green = g[k]}
            var blue = b[0]
            if b.count == nc { blue = b[k]}
            var alpha = a[0]
            if a.count == nc { alpha = a[k]}
            colors.append(NSColor(cgColor: CGColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)))!)
        }
        return PhysValue(unit: Unit(), type: "color", values: colors, dim: dim, field: field)
    }
    
    // retourne une physval contenant une couleur grise
    func xGray() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("level",type: "double", defVal: PhysValue(doubleVal: 0.5), limits: ["≥":0,"≤":1]),
            funcArgument("a",type: "double", defVal: PhysValue(doubleVal: 1.0), limits: ["≥":0,"≤":1])
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let levels = test["level"]!.phVal!.asDoubles!
        let a = test["a"]!.phVal!.asDouble!
        let dim = test["level"]!.phVal!.dim
        let field = test["level"]!.phVal!.field
        let colors = levels.map{ NSColor(cgColor: CGColor(
                                            red: CGFloat($0),
                                            green: CGFloat($0),
                                            blue: CGFloat($0),
                                            alpha: CGFloat(1)))!.withAlphaComponent(a)
        }
        return PhysValue(unit: Unit(), type: "color", values: colors,dim: dim, field: field)
    }
    
    // transforme un vecteur de doubles en vecteur de couleurs variables entre "start" et "end"
    // optionnellement, on peut spécifier les valeurs doubles "min" et "max" correspondantes
    // variante : x est un vecteur de booleens et on a deux couleurs possibles
    func xColors() -> PhysValue {
        let red = NSColor(cgColor: CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1))!
        let blue = NSColor(cgColor: CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1))!
        var colors : [NSColor] = []
        var dim : [Int]
        var field : [String:PhysValue]?
        let test = testArguments(structure: [
            funcArgument("x",type: "double"),
            funcArgument("start", type: "color", defVal: PhysValue(color: red)),
            funcArgument("end",type: "color", defVal: PhysValue(color: blue)),
            funcArgument("min", type: "double", requested: false),
            funcArgument("max", type: "double", requested: false)
        ])
        if test["error"] != nil {
            let test2 = testArguments(structure: [
                funcArgument("x",type: "bool"),
                funcArgument("col1", type: "color", defVal: PhysValue(color: red)),
                funcArgument("col2",type: "color", defVal: PhysValue(color: blue)),
            ])
            if test2["error"] != nil { return test["error"]!.phVal! }
            let values = test2["x"]!.phVal!.asBools!
            dim = test2["x"]!.phVal!.dim
            field = test2["x"]!.phVal!.field
            let falseColors = test2["col2"]!.phVal!.asColors!
            if falseColors.count != 1 && falseColors.count != values.count {
                return PhysValue(error:"wrong number of colors for 'false' in 'colors()'")
            }
            let trueColors = test2["col1"]!.phVal!.asColors!
            if trueColors.count != 1 && trueColors.count != values.count {
                return PhysValue(error:"wrong number of colors for 'false' in 'colors()'")
            }
            if trueColors.count == 1 && falseColors.count == 1 {
                colors = values.map{ $0 ? trueColors[0] : falseColors[0]}
            } else if trueColors.count == 1 {
                colors = values.indices.map{ values[$0] ? trueColors[0] : falseColors[$0]}
            } else if falseColors.count == 1{
                colors = values.indices.map{ values[$0] ? trueColors[$0] : falseColors[0]}
            } else {
                colors = values.indices.map{ values[$0] ? trueColors[$0] : falseColors[$0]}
            }
        } else {
            let values = test["x"]!.phVal!.asDoubles!
            let minPhv = test["min"]!.phVal
            let maxPhv = test["max"]!.phVal
            var min = values.min()!
            if minPhv != nil { min = minPhv!.asDouble! }
            var max = values.max()!
            if maxPhv != nil { max = maxPhv!.asDouble! }
            let start = test["start"]!.phVal!.asColor!
            let end = test["end"]!.phVal!.asColor!
            dim = test["x"]!.phVal!.dim
            field = test["x"]!.phVal!.field
            colors = colorField(values: values, min: min, max: max, start: start, end: end)
        }
        
        return PhysValue(unit: Unit(), type: "color", values: colors, dim: dim, field: field)
    }
    
    // Dessin d'un graphe (chaque argument peut être une liste d'arguments $(...) )
    func xPlot() -> PhysValue {
        let plotStruct = [
            funcArgument("x", type: "double", requested: false),
            funcArgument("y",type: "double", requested: false, repeating: true),
            funcArgument("xmin", type: "double", requested: false),
            funcArgument("xmax", type: "double", requested: false),
            funcArgument("ymin", type: "double", requested: false),
            funcArgument("ymax", type: "double", requested: false),
            funcArgument("autox", type: "bool", defVal: PhysValue(boolVal: false)),
            funcArgument("autoy", type: "bool", defVal: PhysValue(boolVal: false)),
            funcArgument("linewidth",type: "double", requested: false, limits: ["≥":0, "<":100]),
            funcArgument("linetype", type: "int", requested: false, dim: [1], limits: ["≥":0,"≤":3]),
            funcArgument("linecolor",type: "color", requested: false),
            funcArgument("dottype",type: "int", requested: false, limits: ["≥":0,"≤":10]),
            funcArgument("dotsize",type: "double",requested: false),
            funcArgument("dotinterval",type: "int",requested: false, dim: [1], limits: ["≥":0]),
            funcArgument("dotcolor",type: "color",requested: false),
            funcArgument("name",type: "string",requested: false, dim: [1]),
            funcArgument("secondaxis",type: "bool",requested: false, dim: [1]),
            funcArgument("xerror",type: "double",requested: false),
            funcArgument("yerror",type: "double",requested: false),
            funcArgument("field", type: "double", requested: false), // un champ scalaire ou vectoriel
            funcArgument("fcolor", type: "color", requested: false), // couleur(s) pour un champ
            funcArgument("fminmax", type: "double", requested: false), // valeurs min et max pour la colorisation
        ]
        
        //Création du graphique s'il n'existe pas encore
        if args.count < 1 { return errVal("No arguments in plot ?")}
        
        let newGraph = (self.graph == nil)
        let theGraph = self.graph ?? Grapher()
        
        // S'il y a une seule série d'arguments, on transforme en un argument du type $(...)

        var allArgs = args
        var testOneGraph = false // une seule série x ou plusieurs avec $(x...)
        if args[0].op != "$" {
            if args[0].op == "_var" {
                // une variable non définie ou ne contenant pas une expression => une seule série d'argumeents
                if theVariables[args[0].string!] == nil { testOneGraph = true }
                else if theVariables[args[0].string!]!.type != "exp" { testOneGraph = true }
            } else { testOneGraph = true }
        }
        if testOneGraph {
            allArgs = [HierarchicExp(withOp: "$", args: args)]
        }
        if allArgs.count > 10 { return PhysValue(error:"maximum 10 plots") }
        
        // initialisations avant de parcourir les séries d'arguments
        var nPlot : Int = 0
        var nField : Int = 0
        theGraph.xyData = nil
        theGraph.fields = nil
        
        // on parcourt toutes les séries d'arguments $(...)
        for (c,arg) in allArgs.enumerated() {
            // début du traitement : on crée une expression hiérarchique à tester
            // (éventuellement à partir du contenu d'une variable)
            var pExp = HierarchicExp(withOp: "$")
            if arg.op == "_var" {
                if (arg.string == nil ? theVariables["^*kldfj§"] : theVariables[arg.string!]) == nil {
                    return PhysValue(error: "Wrong plot argument number \(c)")
                }
                if theVariables[arg.string!]!.type != "exp" {
                    return PhysValue(error:"arguments of multiple plots must be of type $")
                }
                pExp.args = theVariables[arg.string!]!.values as! [HierarchicExp]
            } else {
                if arg.op != "$" { return PhysValue(error:"Error in plot definition") }
                pExp = arg.copyExp()
            }
            // test de la syntaxe
            let test = pExp.testArguments(structure: plotStruct)
            if test["error"] != nil { return test["error"]!.phVal! }
            
            // ***********************************************
            // Cas général de lignes et points ou histogrammes
            // ***********************************************
            if test["x"]?.phVal != nil && test["y0"]?.phVal != nil {
                
                // traitement des data x,y d'un plot
                let xPhysVals = test["x"]!.phVal!
                let n = xPhysVals.values.count
                let testHistogram = op.hasPrefix("histo")
                
                //let nY = testOneGraph ? test["y"]!.phVal!.asInteger! : 1
                let nY = test["y"]!.phVal!.asInteger!

                for kY in 0..<nY { // si "testOneGraph" mais plusieurs séries y...
                    //let yPhysVals = testOneGraph ? test["y\(kY)"]!.phVal! : test["y"]!.phVal!
                    let yPhysVals = test["y\(kY)"]!.phVal!

                    if (yPhysVals.values.count == n-1) && testHistogram {
                        theGraph.histogram[nPlot] = true
                    } else if yPhysVals.values.count != n && !testHistogram {
                        return PhysValue(error:"x and y vectors should have same length")
                    } else if testHistogram {
                        return PhysValue(error:"x should have one more data than y")
                    }
                    if theGraph.xyData == nil {
                        theGraph.xyData = [[xPhysVals,yPhysVals]]
                    } else {
                        theGraph.xyData!.append([xPhysVals,yPhysVals])
                    }
                    // unités (à modifier si l'on ajoute un second axe y !!)
                    if theGraph.axesUnit == nil { theGraph.axesUnit = [xPhysVals.unit,yPhysVals.unit] }
                    else if !theGraph.axesUnit![1].isIdentical(unit: yPhysVals.unit) {
                        return errVal("incompatible units in y-values")
                    }
                    // limites min, max et unités d'axes
                    if theGraph.axesMinMax == nil { theGraph.axesMinMax = [xPhysVals.limits(),yPhysVals.limits()] }
                    else {
                        var lims = theGraph.axesMinMax![1].asDoubles!
                        let newLims = yPhysVals.limits().asDoubles!
                        lims[0]=min(lims[0],newLims[0])
                        lims[1]=max(lims[1],newLims[1])
                        theGraph.axesMinMax![1].values = lims
                    }
                    
                    
                    //if newGraph {
                        if test["xmin"]!.phVal != nil { theGraph.axesMinMax![0].values[0] = test["xmin"]!.phVal!.asDouble! }
                        if test["xmax"]!.phVal != nil { theGraph.axesMinMax![0].values[1] = test["xmax"]!.phVal!.asDouble! }
                        if test["ymin"]!.phVal != nil { theGraph.axesMinMax![1].values[0] = test["ymin"]!.phVal!.asDouble! }
                        if test["ymax"]!.phVal != nil { theGraph.axesMinMax![1].values[1] = test["ymax"]!.phVal!.asDouble! }
                    //}
                    
                    // traitement des lignes
                    //theGraph.lineWidth[nPlot] = 1
                    if test["linewidth"]!.phVal != nil {
                        let lineWidth = test["linewidth"]!.phVal!
                        if lineWidth.values.count == 1 {
                            theGraph.lineWidth[nPlot] = CGFloat(test["linewidth"]!.phVal!.asInteger!)
                            theGraph.removeExtraData(dataType: "linewidth")
                        } else if lineWidth.values.count >= n-1 {
                            theGraph.addExtraData(n: nPlot, dataType: "linewidth", data: lineWidth.asDoubles!.map({CGFloat($0)}))
                        } else {
                            theGraph.removeExtraData(dataType: "linewidth")
                            return PhysValue(error:"not enough values in linewidth for graph \(nPlot)")
                        }
                    }
                    
                    if test["linetype"]!.phVal != nil {
                        var type = test["linetype"]!.phVal!.asInteger!
                        if type < 0 || type > 3 { type = 0 }
                        theGraph.lineType[nPlot] = type
                    }
                    if test["linecolor"]!.phVal != nil {
                        let linecolors = test["linecolor"]!.phVal!.asColors!
                        if linecolors.count > 1 {
                            if linecolors.count < n-1 { return PhysValue(error:"wrong number of line colors") }
                            theGraph.addExtraData(n: nPlot, dataType: "linecolor", data: linecolors)
                        } else {
                            theGraph.lineColor[nPlot] = linecolors[0]
                        }
                    }
                    
                    // traitement des dots
                    if op == "lineplot" {
                        theGraph.dotType[nPlot] = ""
                    } else if test["dottype"]!.phVal != nil {
                        theGraph.dotType[nPlot] = graphDotTypes[test["dottype"]!.phVal!.asInteger!]
                    } else if op == "scatterplot" {
                        theGraph.lineWidth[nPlot] = 0
                        if newGraph {
                            theGraph.dotType[nPlot] = graphDotTypes[nPlot+1]
                        }
                    }
                    if newGraph && op == "plot" && n > 25 {
                        theGraph.dotInterval[nPlot] = n / 25
                    }
                    
                    if test["dotsize"]!.phVal != nil {
                        let dotSizes = test["dotsize"]!.phVal!.asDoubles!.map({CGFloat($0)})
                        if dotSizes.count > 1 {
                            if dotSizes.count != n {
                                return PhysValue(error:"wrong number of dotsizes")
                            }
                            theGraph.addExtraData(n: nPlot, dataType: "dotsize", data: dotSizes)
                            theGraph.dotSize[nPlot] = CGFloat(6)
                        } else {
                            theGraph.dotSize[nPlot] = CGFloat(dotSizes[0])
                        }
                    }
                    
                    // barres d'erreur
                    if test["xerror"]!.phVal != nil {
                        let xerrors = test["xerror"]!.phVal!.asDoubles!
                        if xerrors.count != n { return PhysValue(error:"wrong number of x-errors") }
                        theGraph.addExtraData(n: nPlot, dataType: "xerror", data: xerrors)
                    }
                    
                    if test["yerror"]!.phVal != nil {
                        let yerror = test["yerror"]!.phVal!.asDoubles!
                        if yerror.count != n { return PhysValue(error:"wrong number of y-errors") }
                        theGraph.addExtraData(n: nPlot, dataType: "yerror", data: yerror)
                    }
                    
                    
                    if test["dotinterval"]!.phVal != nil {
                        theGraph.dotInterval[nPlot] = test["dotinterval"]!.phVal!.asInteger!
                    }
                    if test["dotcolor"]!.phVal != nil {
                        let dotcolors = test["dotcolor"]!.phVal!.asColors!
                        if dotcolors.count > 1 {
                            if dotcolors.count != n { return PhysValue(error:"wrong number of dotcolors") }
                            theGraph.addExtraData(n: nPlot, dataType: "dotcolor", data: dotcolors)
                        } else {
                            theGraph.dotColor[nPlot] = dotcolors[0]
                        }
                    }
                    
                    // titres
                    if theGraph.axesTitles == ["?","?"] {
                        let xTitle = test["x"]!.exp!.stringExp()
                        let yTitle = test["y0"]!.exp!.stringExp()
                        theGraph.axesTitles = [xTitle,yTitle]
                    }
                    
                    // pour éviter les bugs
                    if testHistogram {
                        theGraph.dotType[nPlot] = ""
                        theGraph.lineWidth[nPlot] = 2
                        theGraph.lineType[nPlot] = 0
                    }
                    
                    nPlot = nPlot + 1
                }

            }
         
            
            // **************
            // cas d'un champ
            // **************
             
            if test["field"]?.phVal != nil || (test["x"]?.phVal != nil && test["y0"]?.phVal == nil && test["field"]?.phVal == nil) {
                
                // traitement des données du champ
                let field = test["field"]?.phVal ?? test["x"]!.phVal!
                if !field.isField { return(errVal("Missing y-argument and x-arg is not a field"))}
                let fieldDef = field.field
                if fieldDef == nil { return errVal("wrong field definition for graph") }
                let dim = field.fieldDim // dimensions du champ (ou d'une composante si vec)
                if dim.count != 2 { return errVal("only 2D fields can be plotted")}
                
                if theGraph.fields == nil  {
                    theGraph.fields = [field]
                } else {
                    theGraph.fields!.append(field)
                }
                
                // Limites d'extension du champ
                let origin = fieldDef!["origin"]!
                let dx = fieldDef!["dx"]!
                if theGraph.axesMinMax == nil {
                    let xLims = origin.physValn(n: 0)
                    xLims.addElement(origin.getDouble(n: 0) + Double(dim[0] - 1) * dx.asDouble!)
                    let yLims = origin.physValn(n: 1)
                    yLims.addElement(origin.getDouble(n: 1) + Double(dim[1] - 1) * dx.asDouble!)
                    theGraph.axesMinMax=[xLims,yLims]
                }
                
                // titres et unités des axes...
                if theGraph.axesUnit == nil {
                    theGraph.axesUnit = [dx.unit,dx.unit]
                }
                if theGraph.axesTitles == ["?","?"] {
                    theGraph.axesTitles = ["x","y"]
                }
                
                // valeurs min et max pour la colorisation du champ fournies dans la commande
                if theGraph.fieldLimits == nil || (theGraph.fieldLimits?.count ?? 0) < nField+1 {
                    var fminmax = test["fminmax"]?.phVal
                    if fminmax != nil  {
                        if fminmax!.asDoubles!.last! <=  fminmax!.asDoubles![0] {
                            return errVal("Wrong min and max values for field graph")
                        }
                    } else {
                        let values = field.asDoubles!
                        if field.isVec {
                            fminmax = PhysValue(unit: field.unit, type: "double", values: [0,values.max()!])
                        } else {
                            fminmax = PhysValue(unit: field.unit, type: "double", values: [values.min()!,values.max()!])
                        }
                    }
                    if theGraph.fieldLimits == nil {
                        theGraph.fieldLimits = [fminmax!]
                    } else {
                        theGraph.fieldLimits!.append(fminmax!)
                    }
                }
                
                // couleurs des champs
                if theGraph.fieldColors == nil || (theGraph.fieldColors?.count ?? 0) < nField+1 {
                    var fcolor = test["fcolor"]?.phVal
                    if fcolor == nil {
                        let col1 = NSColor(red: 0.1, green: 0.1, blue: 0.9, alpha: 1)
                        let col2 = NSColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
                        let col3 = NSColor(red: 0.1, green: 0.9, blue: 0.1, alpha: 1)
                        fcolor = PhysValue(unit: Unit(), type: "color", values: [col1,col2,col3])
                    } else {
                        if fcolor!.values.count < 2 {
                            return PhysValue(error: "two colors needed in fcolor argument")
                        }
                    }
                    if theGraph.fieldColors == nil {
                        theGraph.fieldColors = [fcolor!]
                    } else if theGraph.fieldColors!.count <= nField {
                        theGraph.fieldColors!.append(fcolor!)
                    }
                }
                
                // taille des vecteurs
                if theGraph.fieldVecSizes == nil || (theGraph.fieldVecSizes?.count ?? 0) < nField+1 {
                    if theGraph.fieldVecSizes == nil {
                        theGraph.fieldVecSizes = [theGraph.fieldLimits![nField].physValn(n: 1)]
                    } else {
                        theGraph.fieldVecSizes!.append(theGraph.fieldLimits![nField].physValn(n: 1))
                    }
                }
                
                // noms des champs
                if theGraph.fieldNames == nil || (theGraph.fieldNames?.count ?? 0) < nField+1 {
                    if theGraph.fieldNames == nil {
                        theGraph.fieldNames = ["field 1"]
                    } else {
                        theGraph.fieldNames!.append("field \(nField+1)")
                    }
                }
                
                nField = nField + 1
            }
            
            //**********
            // légende
            //**********
            if test["name"]!.phVal != nil {
                theGraph.legend = true
                theGraph.graphLegend[c] = test["name"]!.phVal!.asString!
            }
             
            if test["autox"]!.phVal!.asBool! {theGraph.axesAuto[0] = true }
            if test["autoy"]!.phVal!.asBool! {theGraph.axesAuto[1] = true }
            
        }
        
        // Initialisation du view contenant le graphe et initialisation du titre
        if graph == nil {
            theGraph.frameRect = NSRect(x: 0, y: 0, width: 400, height: 300)
            if theGraph.fields != nil || theGraph.xyData != nil {
                if theGraph.axesMinMax == nil {
                    theGraph.autoLimits(j: 0)
                    theGraph.autoLimits(j: 1)
                } else {
                    theGraph.autoDivs(j: 0)
                    theGraph.autoDivs(j: 1)
                }
                
                if theGraph.histogram.contains(true) {
                    theGraph.axesMinMax![1].values[0] = min(0,theGraph.axesMinMax![1].asDoubles![0])
                    theGraph.autoLimits(j: 1)
                }
            }
            if theGraph.mainTitle == "" {
                theGraph.mainTitle = String(stringExp().prefix(150))
            }
        }
        graph = theGraph
        return PhysValue()
    }
    
    
    func xBarplot() -> PhysValue {
        
        let plotStruct = [
            funcArgument("data", type: "double", requested: true),
            funcArgument("labels", type: "string", requested: false),
            funcArgument("type", type: "string", defVal: PhysValue(string: "V")),
            funcArgument("stacked", type: "bool", defVal: PhysValue(boolVal: false)),
            funcArgument("colspace", type: "double", defVal: PhysValue(doubleVal: 0)),
            funcArgument("space", type: "double", defVal: PhysValue(doubleVal: 0.7)),
            funcArgument("names", type: "string", requested: false)
        ]
        var theGraph = Grapher()
        if graph != nil { theGraph = graph! }

        let test = testArguments(structure: plotStruct)
        if test["error"] != nil { return test["error"]!.phVal! }
        let data = test["data"]!.phVal!
        if data.dim.count == 1 {
            // une seule série
            theGraph.barData = [data.asDoubles!]
        } else {
            var start = 0
            let n = data.dim[0]
            theGraph.barData = []
            for _ in 1...data.dim[1] {
                theGraph.barData!.append(Array(data.asDoubles![start..<start+n]))
                start = start + n
            }
        }
        if theGraph.axesUnit == nil { theGraph.axesUnit = [Unit(),data.unit] }
        
        let orientation = test["type"]!.phVal!.asString!.uppercased()
        theGraph.histoOrientation = orientation
        theGraph.histoS1 = CGFloat(test["colspace"]!.phVal!.asDouble!)
        theGraph.histoS2 = CGFloat(test["space"]!.phVal!.asDouble!)
        theGraph.histoStacked = test["stacked"]!.phVal!.asBool!
 
        if graph == nil || theGraph.axesMinMax == nil  {
            if orientation == "V" {
                theGraph.axesMinMax = [PhysValue(unit: Unit(), type: "int", values: [0,data.dim[0]]),data.limits()]
                theGraph.autoLimits(j: 1)
              } else {
                theGraph.axesMinMax = [data.limits(),PhysValue(unit: Unit(), type: "int", values: [0,data.dim[0]])]
                  theGraph.autoLimits(j: 0)
            }
        }
      
        if graph == nil  {
            theGraph.frameRect = NSRect(x: 0, y: 0, width: 400, height: 300)
            if orientation == "V" {
                theGraph.tickLabels = [false,true]
                theGraph.grids = [(false,false),(true,true)]
                theGraph.ticks = [(false,false),(true,true)]
            } else {
                theGraph.tickLabels = [true,false]
                   theGraph.grids = [(true,true),(false,false)]
                theGraph.ticks = [(true,true),(false,false)]
            }
        }
        
        if test["labels"]!.phVal != nil {
            theGraph.histoLabels = test["labels"]!.phVal!.asStrings!
        } else {
            theGraph.histoLabels = []
        }
        
        if test["names"]!.phVal != nil {
            theGraph.graphLegend = test["names"]!.phVal!.asStrings!
            theGraph.legend = true
        } else {
            theGraph.graphLegend = Array(repeating: "", count: data.dim[0])
        }
        
        graph = theGraph
        return PhysValue()
    }
    
    // *******
    // scripts
    // *******
    
    // Exécute les arguments (ou l'exp contenue dans la variable)
    func xExecute() -> PhysValue {
        var result = PhysValue()
        for arg in args {
            if arg.op == "_val" {
                // Exécution d'une expression désignée par son nom (name)
                if arg.value!.type == "string" {
                    let expName = arg.value!.asString!
                    if mainDoc.namedExps[expName] != nil {
                        let keepSelection = mainCtrl.selectedEquation
                        mainCtrl.selectedEquation = mainDoc.namedExps[expName]!
                        mainCtrl.reRunExp(self)
                        mainCtrl.selectedEquation = keepSelection
                    } else {
                        return errVal("Unknown expression or page '" + expName + "'")
                    }
                } else {
                    return arg.value!
                }
            } else if arg.op == "_var" {
                // Exécution d'une expression contenue dans une variable
                let scriptPhval = theVariables[arg.string!]
                if scriptPhval == nil { return PhysValue(error: "Unexisting variable")}
                if scriptPhval!.type == "exp" {
                    result = scriptPhval!.execute()
                } else {
                    result = arg.executeHierarchicScript()
                }
            } else {
                // Exécution des arguments
                if arg.op == "$" {
                    let newScriptPhval = PhysValue(unit: Unit(), type: "exp", values: arg.args)
                    result = newScriptPhval.execute()
                } else {
                    result = arg.executeHierarchicScript()
                }
            }
        }
        return result
    }
    
    // Ecrit le résultat des args dans la console
    func xPrint() -> PhysValue {
        if args.count>0 {
            var printString = ""
            for arg in args {
                printString = printString + arg.executeHierarchicScript().stringExp(units: true) + "  "
            }
            printString.removeLast(2)
            mainCtrl.printToConsole(printString)
        }
        return PhysValue()
    }
    
    // Exécution d'un script identifié par son nom
    func xRun() -> PhysValue {
        if args.count>0 {
            for aScript in args {
                let outValue = aScript.executeHierarchicScript()
                if outValue.type != "string" { return PhysValue(error:"args of RUN should be strings") }
                else {
                    let scriptName = outValue.values[0] as! String
                    if theScripts[scriptName] == nil { return PhysValue(error:" script " + scriptName + " does not exist" )
                    } else {
                        let theExp = theScripts[scriptName]!
                        theMainDoc!.currentScript = scriptName
                        let test = theExp.executeHierarchicScript()
                        if test.type == "error" {
                            mainCtrl.printToConsole("error: [" + test.asString!
                                                        + "] in script: [" + scriptName
                                                        + "] at line: [" + theMainDoc!.currentScriptLine + "]")
                        }
                        return test
                    }
                }
            }
        }
        return PhysValue()
    }
    
    // affichage (et recalcul complet) d'une page (identifiée par son nom ou son numéro)
    func xPage() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("page",type: "exp"),
            funcArgument("recalc",type: "bool", requested: false, defVal: PhysValue(boolVal: true))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let pageExp = test["page"]!.exp!
        
        if pageExp.value == nil { return PhysValue(error:"page must have a page-name or number as first argument") }
        var pageNbr : Int? = 0
        var pageName = ""
        if (self.father?.isGrid ?? true) { return errVal("page() must be used in scripts or do() ")}

        //if (mainDoc.currentScript == "") { return errVal("page() may be used only in scripts")}
        if pageExp.value!.isNumber {
            pageNbr = pageExp.value!.asInteger! - 1
            pageName = "\(pageNbr!)"
        } else if pageExp.value!.type == "string" {
            let pageName = pageExp.value?.values[0] as! String
            pageNbr = thePageNames.firstIndex(of: pageName)
            
        } else {
            return PhysValue(error:"page must have a page-name or page number as first argument")
        }
        if pageNbr == nil { return errVal("Unknown page " + pageName) }
        if pageNbr! < 0 || pageNbr! >= thePages.count { return errVal("wrong page number") }
        if test["recalc"]!.phVal!.asBool! {
            let r = mainCtrl.calcAndShowPage(nbr: pageNbr!)
            if r != "" { return errVal(r) }
        } else {
            mainCtrl.showPage(n: pageNbr!)
        }
        return PhysValue()
    }
    
    // structure conditionnelle
    func xIf() -> PhysValue {
        // premier argument est boolén, deuxième et troisième (Else) arguments sont des SCRIPT_BLOC
        if args.count<2 { return PhysValue(error:"Syntax error in IF statement" ) }
        let testVal = args[0].executeHierarchicScript()
        if testVal.type != "bool" { return PhysValue(error:"First arg of IF statement should be boolean") }
        if testVal.values.count > 1 { return errVal(" First argument of IF statement should be a single boolean")}
        if Bool(truncating: testVal.values[0] as! NSNumber) == true {
            return args[1].executeHierarchicScript()
        }
        else if args.count == 3 {
            return args[2].executeHierarchicScript()
        }
        return PhysValue()
    }
    
    // structure répétitive 'tant que'
    func xWhile() -> PhysValue {
        // premier argument est booléen, deuxième est un SCRIPT_BLOC
        if args.count != 2 { return PhysValue(error:"Syntax error in WHILE statement" ) }
        var testVal = args[0].executeHierarchicScript()
        if testVal.type != "bool" { return PhysValue(error:"First arg of IF statement should be boolean") }
        var c: Int = 0
        while Bool(truncating: testVal.values[0] as! NSNumber) == true && c < maxNumberOfWhile {
            let r = args[1].executeHierarchicScript()
            if r.isError { return r }
            testVal = args[0].executeHierarchicScript()
            c = c+1
        }
        return PhysValue()
    }
    
    // structure répétitive 'for next'
    func xFornext() -> PhysValue {
        // premier argument est une variable
        // 2e = expression contenant les valeurs de cette var
        // 3e argument est un SCRIPT_BLOC
        if args.count != 3 { return PhysValue(error:"Syntax error in FOR statement" ) }
        if args[0].op != "_var" {
            return PhysValue(error:"First argument of FOR statement schould be a variable name ")
        }
        let theVarName = args[0].string!
        let theValues = args[1].executeHierarchicScript()
        let thePhysValue = theValues.dup()
        for theValue in theValues.values {
            thePhysValue.values = [theValue]
            theVariables[theVarName] = thePhysValue
            let r = args[2].executeHierarchicScript()
            if r.isError { return r}
        }
        return PhysValue()
    }
    
    // définition d'une fonction complexe
    func xFunction() -> PhysValue {
        // premier argument est un nom de fonction
        // 2e = définition de la fonction
        if args.count != 2 { return PhysValue(error:"Syntax error in function definition" ) }
        if isOperator(c: args[0].op) == true {
            return PhysValue(error:"Argument of FUNCTION statement schould be of type f(x)")
        }
        let funcName = args[0].op
        let funcArgs = args[0].args
        for funcArg in funcArgs {
            if funcArg.op != "_var" { return PhysValue(error:"function args should be variable names") }
        }
        mainDoc.theFunctions[funcName] = self
        return PhysValue(unit: Unit(num:false), type: "function_definition", values: [])
    }
    
    // quitte la fonction en cours d'exécution en retournant éventuellement un résultat
    func xReturn() -> PhysValue {
        // quitte la (dernière) fonction en cours d'exécution
        if args.count == 0 {
            functionReturn = PhysValue()
        } else if args.count == 1 {
            functionReturn = args[0].executeHierarchicScript()
        } else {  return PhysValue(error:"Syntax error in return definition" ) }
        return functionReturn
    }
    
    func xLocal() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("v",type: "exp",repeating: true),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let n = test["v"]!.phVal!.asInteger!
        for k in 0..<n {
            let varName = test["v\(k)"]!.exp!.stringExp()
            if father != nil {
                father!.localVars[varName] = theVariables[varName]
            }
        }
        return PhysValue()
    }
    
    
    // *********************
    // opérateurs internes
    // *********************
    
    // un bloc d'expressions dans un script
    func xScriptBloc() -> PhysValue {
        var r = PhysValue()
        for scriptLine in args {
            theMainDoc!.currentScriptLine = String(scriptLine.stringExp().suffix(100))
            r = scriptLine.executeHierarchicScript(editing: false)
            if r.isError { return r }
            if functionReturn.type != "" {
                for varName in localVars.keys {
                    theVariables[varName] = localVars[varName] ?? nil
                }
                return PhysValue()
            }
        }
        for varName in localVars.keys {
            theVariables[varName] = localVars[varName] ?? nil
        }
        return r
    }
    
    
    func xSysBloc() -> PhysValue {
        if op == "_grid" {
            let theGrid = self as! HierGrid
            theGrid.testGrid()
            let n = theGrid.rows * theGrid.cols
            while nArgs < n {
                addArg(HierarchicExp(withText: ""))
                print("il manque un arg dans le grid ?")
            }
            if nArgs > n && theGrid.cols == 1 {
                theGrid.rows = n
                print("un arg de trop ?")
            }
            else if nArgs < n && theGrid.rows == 1 {
                theGrid.cols = n
                print("un arg de trop ?")
            }
            while nArgs > n {
                removeArg(nArgs-1)
                print("un arg de trop ?")
            }
        }
        if nArgs == 0 { return PhysValue() }
        for anArg in args {
            let result = anArg.executeHierarchicScript(editing: false)
            if result.type == "error" { return result }
            if anArg.isAncestor && result.values.count > 0 {
                if anArg.result == nil {
                    anArg.result = HierarchicExp(withPhysVal: result)
                } else {
                    anArg.setResult(HierarchicExp(withPhysVal: result))
                }
            }
        }
        return PhysValue()
    }
    
    // retourne la valeur d'une variable
    func xSysVar() -> PhysValue {
        let varName = string!
        if varName.contains(".") {
            // cas d'une utilisation du . comme indice d'un dataframe
            let splitted = varName.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let theVar = String(splitted[0])
            let theIndex = String(splitted[1])
            if theVar != "" && theIndex != "" {
                if theVariables[theVar] != nil {
                    if theVariables[theVar]!.type == "dataframe" {
                        if theIndex.first!.isNumber {
                            let newExp = algebToHierarchic(theVar + "#" + theIndex)
                            return newExp.executeHierarchicScript()
                        } else {
                            let newExp = algebToHierarchic(theVar + "#'" + theIndex + "'")
                            return newExp.executeHierarchicScript()
                        }
                    }
                }
            }
            
            //
            // c'est une variable du simulateur
            //
            let components = theSim.varComponents(varExp: varName)
            if components.pop == nil {
                return PhysValue(error:"wrong population name before '.'") }
            if components.value == nil { return PhysValue(error:"wrong var name after '.'") }
            return components.value!
        } else {
            // c'est une variable ordinaire
            if varName == "" { return PhysValue(error:"variable without name ??") }
            if theVariables[varName] == nil {return PhysValue() }
            let returnValue = theVariables[varName]!.dup()
            if value != nil {
                if !(value!.unit).isNilUnit() {
                    returnValue.unit = (value!).unit
                }
            }
            theVariables[varName] = returnValue
            return returnValue
        }
    }
    
    // *********************
    // Mathématiques simples
    // *********************
    
    // fonction unaire
    func xMathfunc() -> PhysValue {
        let physVal = args[0].executeHierarchicScript()
        if physVal.isEmpty { return PhysValue() }
        return physVal.numericFunction(op: op)
    }
    
    // un nombre aléatoire
    func xRnd() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x",type: "double",defVal: PhysValue(doubleVal: 1),limits: ["≥":0]),
            funcArgument("n", type: "int", defVal: PhysValue(intVal: 1)),
            funcArgument("integer", type: "bool", defVal: PhysValue(boolVal: false))
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!.asDouble!
        let unit = test["x"]!.phVal!.unit
        let n = test["n"]!.phVal!.asInteger!
        let testInt = test["integer"]!.phVal!.asBool!
        if x != Double(Int(x)) || testInt == false {
            // nombres aléatoires décimaux entre 0 et x
            //var vals : [Double] = []
            let vals = Array(repeating: x, count: n).map({
                Double($0) * Double.random(in: 0...1)
                
            })
            return PhysValue(unit: unit, type: "double", values: vals)
        } else {
            // nombres alétaoires entiers de 1 à x
            var vals : [Int] = []
            (0..<n).forEach { i in
                vals.append(Int.random(in: 1...Int(x)))
            }
            return PhysValue(unit: unit, type: "int", values: vals)
        }
    }
    
    // fonctions numériques sans unité
    func xTrigofunc() -> PhysValue {
        let physVal = args[0].executeHierarchicScript()
        if physVal.isEmpty { return PhysValue() }
        return physVal.trigoFunction(op: op)
    }
    
    // logarithme en base quelconque
    func xLogab() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("a", type: "double", requested: true, limits: [">":0]),
            funcArgument("x", type: "double", requested: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let a = test["a"]!.phVal!
        let x = test["x"]!.phVal!
        let logx = x.trigoFunction(op: "Log")
        let loga = a.trigoFunction(op: "Log")
        return logx.binaryOp(op: "/", v2: loga)
    }
    
    // négation d'un booléen
    func xNot() -> PhysValue {
        let physVal = self.args[0].executeHierarchicScript()
        if physVal.isEmpty { return PhysValue() }
        if physVal.type != "bool" {return PhysValue(error:"arg of NOT schould be boolean")}
        return PhysValue(unit: Unit(), type: "bool", values: physVal.negated!)
    }
    
    // opérations n-aires
    func xAddmult() -> PhysValue {
        if args.count<2 { return PhysValue(error:"too few args in a sum or product") }
        var r = args[0].executeHierarchicScript()
        for i in 1...args.count-1 {
            let value2 = args[i].executeHierarchicScript()
            if r.type == "error" {return r }
            if value2.type == "error" {return value2 }
            r = r.binaryOp(op: op, v2: value2)
        }
        return r
    }
    
    // opérations binaires
    func xBinaryop() -> PhysValue {
        if args.count != 2 {return PhysValue(error:"not exactly two arguments in binary operation") }
        let value1 = args[0].executeHierarchicScript()
        if value1.isError {return value1 }
        let value2 = args[1].executeHierarchicScript()
        if value2.isError {return value2 }
        return value1.binaryOp(op: op, v2: value2)
    }
    
    
    // forçage de l'unité
    func xSetunit() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x", type: "double", requested: true),
            funcArgument("unit",type: "double", requested: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        if test["x"]!.phVal == nil { return errVal("syntax error")}
        if test["unit"]!.phVal == nil { return errVal("wrong unit")}
        if test["x"]!.phVal?.type != "double" { return errVal("x is not a double value")}
        let unit = test["unit"]!.phVal!.unit
        if test["x"]!.exp!.op == "_var" {
            let varName = test["x"]!.exp!.string!
            if theVariables[varName] != nil {
                theVariables[varName]!.unit = unit
                return theVariables[varName]!
            }
            return PhysValue()
        }
        let vals = test["x"]!.phVal!.asDoubles!.map({ $0 * unit.mult })
        return PhysValue(unit: unit, type: "double", values: vals)
    }
    
    
    // *******************
    // Calcul symbolique
    // *******************

    // calcul ou écriture d'une dérivée
    func xDeriv() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("f", type: "exp"),
            funcArgument("x", type: "exp", requested: false ),
            funcArgument("at", type: "double", requested: false),
            funcArgument("dx", type: "double", requested: false)
        ])
        
        if test["error"] != nil { return test["error"]!.phVal! }
        var fexp = test["f"]!.exp!
        if fexp.op == "_var" {
            // si f est une fonction...
            let fName = fexp.string!
            if theFunctions[fName] != nil { fexp = theFunctions[fName]!.args[1].copyExp() }
        }
        var x : HierarchicExp
        if test["x"]!.exp == nil {
            if fexp.containsVar("x") { x = HierarchicExp(withVar: "x") }
            if fexp.containsVar("y") { x = HierarchicExp(withVar: "y") }
            else {
                let listOfVars = fexp.listOfMyVars()
                if listOfVars.count == 0 { x = HierarchicExp(withVar: "x") }
                else { x = HierarchicExp(withVar: listOfVars.last!) }
            }
            self.args.insert(x, at: 1)
        } else {
            x = test["x"]!.exp!
            if x.op != "_var" { return errVal("Second argument of deriv should be a variable name")}
        }
        let varName = x.string!
        // calcul numérique de la dérivée en atx avec dx = dx
        var at : PhysValue
        if test["at"]!.phVal != nil {
            at = test["at"]!.phVal!
        } else if theVariables[varName] != nil {
            at = theVariables[varName]!
        } else {
            return PhysValue()
        }
        let dx : PhysValue = at.dup() // pour avoir les unités conformes !
        dx.values = test["dx"]!.phVal == nil ? [0.000001] : [test["dx"]!.phVal!.asDouble!]
        let dx2 = dx.binaryOp(op: "/", v2: PhysValue(doubleVal: 2)) // le demi dx pour faire x-dx/2 et x+dx/2
        let tempValx = theVariables[varName] // sauvegarde de la valeur de x éventuelle...
        theVariables[varName] = at.binaryOp(op: "+", v2: dx2)
        let f2 = fexp.executeHierarchicScript()
        theVariables[varName] = at.minus(dx2)
        let f1 = fexp.executeHierarchicScript()
        let df = f2.minus(f1)
        theVariables[varName] = tempValx
        let result = df.binaryOp(op: "/", v2: dx)
        return result
    }
    
    func xIntegral() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("f", type: "exp"),
            funcArgument("x", type: "exp", requested: false ),
            funcArgument("from", type: "exp", requested: false),
            funcArgument("to", type: "exp", requested: false),
            funcArgument("n", type: "int", requested: false, defVal: PhysValue(intVal: 10000)),
        ])
        
        if test["error"] != nil { return test["error"]!.phVal! }
        var fexp = test["f"]!.exp!
        if fexp.op == "_var" {
            // si f est une fonction utilisateur...
            let fName = fexp.string!
            if theFunctions[fName] != nil { fexp = theFunctions[fName]!.args[1].copyExp() }
        }
        var x : HierarchicExp
        if test["x"]!.exp == nil {
            if fexp.containsVar("x") { x = HierarchicExp(withVar: "x") }
            if fexp.containsVar("y") { x = HierarchicExp(withVar: "y") }
            else {
                let listOfVars = fexp.listOfMyVars()
                if listOfVars.count == 0 { x = HierarchicExp(withVar: "x") }
                else { x = HierarchicExp(withVar: listOfVars.last!) }
            }
            self.args.insert(x, at: 1)
        } else {
            x = test["x"]!.exp!
            if x.op != "_var" { return errVal("Second argument of deriv should be a variable name")}
        }
        let varName = x.string!
        
        // calcul numérique de l'intégrale
        let from = test["from"]!.exp != nil ? test["from"]!.exp!.executeHierarchicScript() : nil
        let to = test["to"]!.exp != nil ? test["to"]!.exp!.executeHierarchicScript() : nil
        let n = test["n"]!.phVal
        if from != nil || to != nil {
            if from == nil || to == nil || n == nil {
                return errVal("Missing argument 'from' , 'to' or 'n'")
            }
        } else {
            return PhysValue()
        }
        
        let tempValx = theVariables[varName] // sauvegarde de la valeur de x éventuelle...
        theVariables[varName] = from!
        var f = fexp.executeHierarchicScript()
        let dx = (to!.minus(from!)).div(n!)
        var result = f.binaryOp(op: "*", v2: theVariables[varName]!.binaryOp(op: "*", v2: PhysValue(doubleVal: 0)))
        for _ in 0..<n!.asInteger! {
            theVariables[varName] = theVariables[varName]!.plus(dx)
            let f2 = fexp.executeHierarchicScript()
            let fm = (f2.plus(f)).div(PhysValue(doubleVal: 2))
            result = result.binaryOp(op: "+", v2: fm.binaryOp(op: "*", v2: dx))
            f = f2
        }
        theVariables[varName] = tempValx
        return result
    }
    
    // *******************
    // Traitement de texte
    // *******************
    
    // transforme des nombres en chaînes...
    func xString() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x", requested: true),
            funcArgument("format",type: "string", requested: false)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x=test["x"]!.phVal!
        var strings: [String] = []
        if x.type == "double" {
            let vals = x.asDoubles!
            strings = vals.map({ String($0)})
        } else if x.type == "int" {
            let vals = x.asIntegers!
            strings = vals.map({ String($0)})
        } else if x.type == "bool" {
            let vals = x.asBools!
            strings = vals.map({ String($0 ? "TRUE" : "FALSE")})
        } else if x.type == "string" {
            strings = x.asStrings!
        } else {
            return errVal("argument x should be numbers or booleans")
        }
        return PhysValue(unit: Unit(), type: "string", values: strings)
    }
    
    // transforme un vecteur de nombres en caractères 1=A, 2=B, etc...
    func xAlpha() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("n",type: "int", requested: true, limits: [">":0,"<":27]),
            funcArgument("upper",type: "bool", defVal: PhysValue(boolVal: true)),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let nValues = test["n"]!.phVal!.asIntegers!
        let upper = test["upper"]!.phVal!.asBool!
        if upper {
            return PhysValue(unit: Unit(), type: "string",
                             values: nValues.map( { String(UnicodeScalar(UInt8(64 + $0))) }),
                             dim: test["n"]!.phVal!.dim)
        } else {
            return PhysValue(unit: Unit(), type: "string",
                             values: nValues.map( { String(UnicodeScalar(UInt8(96 + $0))) }),
                             dim: test["n"]!.phVal!.dim)
        }
    }
    
    // codes ascii ou unicode -> chaine(s) ou l'inverse
    func xAscii() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("string",type: "string", requested: true),
        ])
        if test["error"] == nil {
            let theString = test["string"]!.phVal!.asString!
            let theCodes = theString.compactMap( {Int($0.unicodeScalars.first!.value)} )
            return PhysValue(unit: Unit(), type: "int", values: theCodes, dim: [theCodes.count])
        } else {
            let test = testArguments(structure: [
                funcArgument("n",type: "int", requested: true, limits: [">":31,"<":256]),
                funcArgument("single", type: "bool", defVal: PhysValue(boolVal: false))
            ])
            if test["error"] != nil { return test["error"]!.phVal! }
            
            let nValues = test["n"]!.phVal!.asIntegers!
            let single = test["single"]!.phVal!.asBool!
            if single {
                let theString = nValues.reduce("") {(result, next) -> String in
                    return result + String(UnicodeScalar(UInt8(next)))
                }
                return PhysValue(string: theString)
            } else {
                let theStrings = nValues.map( { String(UnicodeScalar(UInt8($0))) })
                return PhysValue(unit: Unit(), type: "string", values: theStrings, dim: test["n"]!.phVal!.dim)
            }
        }
    }
    
    // longueur d'une chaine
    func xLength() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("string",type: "string", requested: true),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let theString = test["string"]!.phVal!.asString!
        return PhysValue(unit: Unit(), type: "int", values: [theString.count], dim: [1])
    }
    
    // extraction de n caractères (à gauche ou à droite) après omission évenuelle des 'drop' premiers (ou derniers)
    func xLeftright() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("string",type: "string", requested: true),
            funcArgument("n",type: "int", requested: true),
            funcArgument("drop",type: "int", defVal: PhysValue(intVal: 0),limits: ["≥":0]),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        var theString = test["string"]!.phVal!.asString!
        var n = test["n"]!.phVal!.asInteger!
        let drop = test["drop"]!.phVal!.asInteger!
        if drop > theString.count { return PhysValue(error: "You can't drop more characters than stringlength") }
        if drop + n > theString.count { n = theString.count - drop }
        if op == "left" {
            theString = String(theString.dropFirst(drop).prefix(n))
        } else {
            theString = String(theString.dropLast(drop).suffix(n))
        }
        return PhysValue(unit: Unit(), type: "string", values: [theString], dim: [1])
    }
    
    // remplace des sous-chaines...
    func xReplace() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("s",type: "string", requested: true),
            funcArgument("find",type: "string", requested: true),
            funcArgument("replace",type: "string", requested: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let s = test["s"]!.phVal!.asStrings!
        let f = test["find"]!.phVal!.asString!
        let r = test["replace"]!.phVal!.asString!
        let resvals = s.map({ $0.replacingOccurrences(of: f, with: r)})
        return PhysValue(unit: Unit(), type: "string", values: resvals)
    }
    
    // position d'une sous-chaine dans une chaine. Retourne -1 si inexistant
    func xPosition() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("substring",type: "string", requested: true),
            funcArgument("string",type: "string", requested: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let subString = test["substring"]!.phVal!.asString!
        let string = test["string"]!.phVal!.asString!
        let range = string.range(of: subString)
        if range == nil {
            return PhysValue(intVal: -1)
        } else {
            return PhysValue(intVal: string.distance(from: string.startIndex, to: range!.lowerBound))
        }
    }
    
    // Traite les arguments (expressions) comme des chaînes
    func xAsstrings() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x",type: "exp",repeating: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        var theStrings : [String] = []
        let n = test["x"]!.phVal!.asInteger!
        for k in 0..<n {
            theStrings.append(test["x\(k)"]!.exp!.stringExp())
        }
        return PhysValue(unit: Unit(), type: "string", values: theStrings, dim: [theStrings.count])
    }
    
    // Traite les arguments (chaines) comme des expressions
    func xAsexp() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x",type: "string",repeating: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        var theExps : [HierarchicExp] = []
        for n in 0..<test["x"]!.phVal!.asInteger! {
            theExps.append(test["x\(n)"]!.exp!)
        }
        return PhysValue(unit: Unit(), type: "exp", values: theExps, dim: [theExps.count])
    }
    
    // Affectation ou égalité
    func xEquation() -> PhysValue {
        if args.count != 2 { return PhysValue(error:"syntax error in affecting value to variable") }
        let arg0 = args[0]
        var testAffectation = (arg0.op == "_var") ? true : false

        if ["indexed", "#", "slice", "submatrix", "submat", "@" ].contains(arg0.op) && arg0.args[0].op == "_var" { testAffectation = true
        }
        
        if !testAffectation {
            let leftOp = args[0].op
            if !operatorsList.contains(leftOp) && !functionNames.contains(leftOp) {
                // définition d'une fonction
                let funcName = arg0.op
                // test de syntaxe membre gauche
                let funcArgs = (arg0).args
                for funcArg in funcArgs {
                    if funcArg.op != "_var" { return PhysValue() }
                    // il faut que les arguments soient des noms de vars.
                }
                mainDoc.theFunctions[funcName] = self
                return PhysValue(unit: Unit(num:false), type: "function_definition", values: [])
            }
            return PhysValue()
        } else {
            // affectation d'un calcul à une variable
            let returnValue = args[1].executeHierarchicScript()
            if returnValue.type == "error" { return returnValue }
            if returnValue.type == "" { return returnValue }
            if arg0.value != nil {
                if !(arg0.value!.unit).isNilUnit() {
                    returnValue.unit = arg0.value!.unit
                }
            }

            // affectation de valeurs à des parties d'une matrice, vecteur, liste...
            if ["indexed", "#", "slice", "submatrix", "submat", "@" ].contains(arg0.op) {
                let indexPhVal = arg0.xIndexesOfArray(getVal: false)
                if indexPhVal.type == "error" { return indexPhVal }
                let indexes = indexPhVal.asIntegers!
                if indexes.count < 1 {return PhysValue() }
                let varName = arg0.args[0].string!
                if varName.contains(".") {
                    // c'est une variable du simulateur
                    let components = theSim.varComponents(varExp: varName)
                    if components.pop == nil { return PhysValue(error:"wrong population name before '.'") }
                    if components.var == "" { return PhysValue(error:"no var name after '.' ??") }
                    if components.value == nil { return PhysValue(error:"variable should exist") }
                    if indexes.max()! >= components.value!.values.count { return PhysValue(error:"index out of range") }
                    let theVarValue = theSim.pops[components.pop!]!.vars[components.var]!
                    let result = theVarValue.replaceValues(indexes: indexes, newVals: returnValue.values)
                    theSim.pops[components.pop!]!.vars[components.var]! = result
                    
                } else {
                    if theVariables[varName] == nil {return PhysValue(error:"can't set indexed value of unexisting variable") }
                    if indexes.max()! >= theVariables[varName]!.values.count { return PhysValue(error:"index out of range") }
                    if theVariables[varName]!.type == "list" {
                        let result = theVariables[varName]!.replaceValues(indexes: indexes, newVals: [returnValue])
                        theVariables[varName] = result
                    } else {
                        if !theVariables[varName]!.unit.isIdentical(unit: returnValue.unit)  { return PhysValue(error: "unit does not conform")}
                        let result = theVariables[varName]!.replaceValues(indexes: indexes, newVals: returnValue.values)
                        theVariables[varName] = result
                    }
                }
                
            } else  {
                let varName = arg0.string!
                if varName.contains(".") {
                    // c'est une variable du simulateur
                    let components = theSim.varComponents(varExp: varName)
                    if components.pop == nil { return PhysValue(error:"wrong population name before '.'") }
                    theSim.setVarVal(popName: components.pop!, varName: components.var, theValue: returnValue)
                } else {
                    theVariables[varName] = returnValue
                }
                if !args[1].needsResult { return PhysValue() }
                return returnValue
            }
            return PhysValue(unit: Unit(num:false), type: "variable_definition", values: [])
        }
    }
    
    // effacement d'une variable
    func xDelete() -> PhysValue {
        if op == "clear" {
            //effacement de toutes les variables
            mainDoc.theVariables = [:]
            _ = dataLibrary.useLibrary(ifAuto: true) // chargement des données par défaut
            return PhysValue()
        }
        let test = testArguments(structure: [
            funcArgument("var", type: "exp", op: "_var" ,repeating: true)
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let nVars = test["var"]!.phVal!.asInteger!
        for n in 0..<nVars {
            let theExp = test["var\(n)"]!.exp
            let aVar = theExp!.string!
            theVariables[aVar] = nil
        }
        return PhysValue()
    }
    
    // utilisation d'un élément de la librairei
    func xUseLibElement() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("item", type : "exp", op: "_var", repeating: true )
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let nVars = test["item"]!.phVal!.asInteger!
        let result = PhysValue(unit: Unit(), type: "list", values: [])
        for n in 0..<nVars {
            let theExp = test["item\(n)"]!.exp
            let aVar = theExp!.string!
            let libitem = dataLibrary.getItem(named: aVar, type: "any")
            if libitem != nil {
                let r = libitem!.use()
                if r.isError { return r}
            }
            if theVariables[aVar] != nil {
                result.values.append(theVariables[aVar]!)
            } else {
                if libitem != nil {
                    var text = libitem!.script
                    text.removeAll(where: {$0=="\n"})
                    result.values.append(PhysValue(unit: Unit(), type: "label", values: [text]))
                }
            }
        }
        if nVars == 0 {return PhysValue() }
        return result

    }
    
    // Détermination du type d'un argument
    func xType() -> PhysValue {
        let test = testArguments(structure: [
            funcArgument("x"),
        ])
        if test["error"] != nil { return test["error"]!.phVal! }
        let x = test["x"]!.phVal!
        let theType = x.type
        let dim = x.dim
        if theType == "list" {
            return PhysValue(string: "list of \(dim[0]) elements")
        }
        if theType == "dataframe" {
            return PhysValue(string: "dataframe containing \(dim[0]) columns of \(x.names![1].count) rows")
        }
        if x.field != nil {
            if x.isVec {
                return PhysValue(string: "\(dim.count - 1) dimensional field of \(dim.last!) dim vectors")
            } else {
                return PhysValue(string: "\(dim.count) dimensional scalar field")
            }
        }
        if dim == [1] || dim == [0] {
            return PhysValue(string: "scalar of " + theType + " type")
        }
        if dim.count == 1 {
            return PhysValue(string: "vector or collection of \(dim[0]) " + theType + " elements")
        }
        if dim.count == 2 {
            return PhysValue(string: "\(dim[0]) x \(dim[1]) matrix of " + theType + " elements")
        }
        if dim.count > 2 {
            return PhysValue(string: "\(dim.count)-dimensional hypermatrix of " + theType + " elements")
        }
        return PhysValue(string: "unknown type ???")
    }
    
    
    // création d'un vecteur ou d'une liste
    func xVeclist() -> PhysValue {
        let n = args.count
        if n<1 {return PhysValue(error:"empty vector !") }
        // on le traite comme une liste au cas où l'un des args serait non scalaire ou de type ≠
        var phValues : [PhysValue] = []
        for arg in args {
            let value = arg.executeHierarchicScript()
            if value.type == "error" { return  value}
            if value.type == "" {
                phValues.append(PhysValue(unit: Unit(), type: "exp", values: [arg]))
            } else {
                phValues.append(value)
            }
        }
        // forçage de liste
        if op == "list" { return PhysValue(unit: Unit(), type: "list", values: phValues) }
        // un seul argument...
        if nArgs == 1 { return phValues[0]}
        // sinon, on essaye de faire un vecteur, et sinon une liste
        
        var returnPhVals = phValues[0].type == "list" ? phValues[0].values : [phValues[0]]
        var returnValues = phValues[0].values
        
        var theType = phValues[0].type
        var theUnit = theType == "double" ? phValues[0].unit : Unit()
        for i in 1..<nArgs {
            let value = phValues[i]
            if value.type == "error" {return value }
            if theType != value.type { theType = "list" }
            if theType == "double" {
                if theUnit.name == "" {
                    theUnit = value.unit
                    returnValues = returnValues.map {($0 as! Double) * theUnit.mult}
                } else if !value.unit.isNilUnit() && !value.unit.isIdentical(unit: theUnit) {
                    theType = "list"
                }
            }
            if value.type == "list" {
                returnPhVals.append(contentsOf: value.values)
            } else {
                returnPhVals.append(value)
            }
            returnValues.append(contentsOf: value.values)
        }
        if theType == "list" {
            return PhysValue(unit: Unit(), type: "list", values: returnPhVals)
        } else {
            return PhysValue(unit: theUnit, type: theType, values: returnValues)
        }
    }
    
    // séquence de nombres par a:b:c
    func xQuicksequence() -> PhysValue {
        if args.count<2 {return PhysValue(error:"too few arguments") }
        var defaultUnit = Unit(num: true) // l'unité de l'incrément
        
        let fromValue = args[0].executeHierarchicScript()
        if fromValue.type == "error" {return fromValue }
        if fromValue.type != "double" && fromValue.type != "int" {return PhysValue(error:"args must be numbers")}
        var fromNumber = fromValue.asDouble!
        let fromUnit = fromValue.unit
        if !fromValue.unit.isNilUnit() { defaultUnit = fromValue.unit }
        
        let toValue = args[1].executeHierarchicScript()
        if toValue.type == "error" {return toValue }
        if toValue.type != "double" && toValue.type != "int" {return PhysValue(error:"args must be numbers")}
        var toNumber = toValue.asDouble!
        if defaultUnit.isNilUnit() && !toValue.unit.isNilUnit() { defaultUnit = toValue.unit }
        let toUnit = toValue.unit
        if !toUnit.isNilUnit() && !fromUnit.isNilUnit() && !toUnit.isIdentical(unit: fromUnit) {
            return errVal("Incompatible units")
        }
        
        var stepValue : PhysValue
        var stepNumber : Double
        if args.count == 3 {
            stepValue = args[2].executeHierarchicScript()
            if stepValue.type == "error" {return stepValue }
            if stepValue.type != "double" && stepValue.type != "int" {return PhysValue(error:"args must be numbers")}
            stepNumber = stepValue.asDouble!
            if !stepValue.unit.isNilUnit() {
                if !defaultUnit.isNilUnit() {
                    if !stepValue.unit.isIdentical(unit: defaultUnit) {
                        return errVal("Incompatible units")
                    }
                }
                defaultUnit = stepValue.unit
            } else if !defaultUnit.isNilUnit() {
                stepNumber = stepNumber*defaultUnit.mult
            }
        } else {
            if !toUnit.isNilUnit() && !fromUnit.isNilUnit() {
                if toUnit.mult < fromUnit.mult { defaultUnit = toUnit}
            } else if !toUnit.isNilUnit() {
                defaultUnit = toUnit
            }
            stepValue = PhysValue(unit: defaultUnit, type: "double", values: [defaultUnit.mult])
            stepNumber = defaultUnit.mult
        }
                
        if !defaultUnit.isNilUnit() {
            if fromUnit.isNilUnit() {
                if !toUnit.isNilUnit() {
                    fromNumber = fromNumber*toUnit.mult
                } else {
                    fromNumber = fromNumber*defaultUnit.mult
                }
            }
            if toUnit.isNilUnit() {
                if !fromUnit.isNilUnit() {
                    toNumber = toNumber*fromUnit.mult
                } else {
                    toNumber = toNumber*defaultUnit.mult
                }
            }
        }
        
        //if (stepNumber > abs(toNumber-fromNumber)) {return PhysValue(error:"Step is too small")}

        if (toNumber-fromNumber)*stepNumber < 0 { stepNumber = -stepNumber }
        
        let nSteps = (toNumber-fromNumber)/stepNumber + 1
        let theArray = Array(0...Int(nSteps)-1).map{fromNumber + Double($0)*stepNumber}
        if  !fromUnit.isNilUnit() {
            return PhysValue(unit: fromUnit, type: "double", values: theArray)
        } else if !toUnit.isNilUnit() {
            return PhysValue(unit: toUnit, type: "double", values: theArray)
        }
        return PhysValue(unit: defaultUnit, type: "double", values: theArray)
    }
    
    // **************************
    // Une fonction utilisateur ?
    // **************************
    
    func xCalcuserfunc() -> PhysValue {
        if theFunctions[op] != nil {
            let theVars = (theFunctions[op]!).args[0].args
            if args.count != theVars.count {
                return PhysValue(error:"Wrong number of arguments")
            }
            // sauvegarde éventuelle des variables et calcul des nouvelles valeurs
            var savedVars = Dictionary<String,PhysValue>()
            var varNumber = 0
            for aVar in theVars {
                savedVars[aVar.string!] = theVariables[aVar.string!]
                theVariables[aVar.string!] = args[varNumber].executeHierarchicScript()
                varNumber += 1
            }
            // Exécution de la fonction
            let returnValue = ((theFunctions[op]!).args[1]).executeHierarchicScript()
            for aVar in theVars {
                theVariables[aVar.string!] = savedVars[aVar.string!]
            }
            if functionReturn.values.count > 0 {
                let r = functionReturn
                functionReturn = PhysValue()
                return r
            }
            return returnValue
        } else {
            return PhysValue() //errVal("Undefined function " + op)
        }
    }
}



// Calcul d'une variable quelconque (globale, world ou population)
func getVarVal(_ varName : String) -> PhysValue? {
    if varName.contains(".") {
        // c'est une variable du simulateur
        let components = theSim.varComponents(varExp: varName)
        if components.pop == nil { return PhysValue(error:"wrong population name before '.'") }
        if components.value == nil { return PhysValue(error:"wrong var name after '.'") }
        return(components.value!)
    } else {
        // c'est une variable ordinaire
        if varName == "" { return PhysValue(error:"variable without name") }
        if theVariables[varName] == nil {return PhysValue() }
        return(theVariables[varName]!.dup())
    }
}

// Gestion des couleurs
func rgbToNumber(red: Int, green: Int, blue: Int, alpha: Int) -> Int {
    return Int(red*1000000 + green*10000 + blue*100 + alpha)
}

func numberToRgb(c: Int) -> (red: Int, green: Int, blue: Int, alpha: Int) {
    let r = Int(c/1000000)
    let c2 = c - r * 1000000
    let g = Int(c2/10000)
    let c3 = c2 - g * 10000
    let b = Int(c3/100)
    let c4 = c3 - b * 100
    let a = Int(c4)
    return (red: r, green: g, blue : b, alpha: a)
}

func colorToNumber(c: NSColor) -> Int {
    let r = Int(c.redComponent * 100)
    let g = Int(c.greenComponent * 100)
    let b = Int(c.blueComponent * 100)
    let a = Int(c.alphaComponent * 100)
    return rgbToNumber(red: r, green: g, blue: b, alpha: a)
}

func numberToColor(cn: Int) -> NSColor {
    let c = numberToRgb(c: cn)
    let red = CGFloat(c.red/100)
    let green = CGFloat(c.green/100)
    let blue = CGFloat(c.blue/100)
    let alpha = CGFloat(c.alpha/100)
    return NSColor(cgColor: CGColor(red: red, green: green, blue: blue, alpha: alpha))!
}

func colorField(values: [Double], min: Double, max: Double, medVal: Double? = nil, start: NSColor, end: NSColor, medCol: NSColor? = nil) -> [NSColor] {
    let r0 = start.redComponent
    let g0 = start.greenComponent
    let b0 = start.blueComponent
    let a0 = start.alphaComponent
    let r1 = end.redComponent
    let g1 = end.greenComponent
    let b1 = end.blueComponent
    let a1 = end.alphaComponent
    if medVal != nil && medCol != nil {
        let r2 = medCol!.redComponent
        let g2 = medCol!.greenComponent
        let b2 = medCol!.blueComponent
        let a2 = medCol!.alphaComponent
        let dr1 = (r2-r0)/CGFloat(medVal!-min)
        let dg1 = (g2-g0)/CGFloat(medVal!-min)
        let db1 = (b2-b0)/CGFloat(medVal!-min)
        let da1 = (a2-a0)/CGFloat(medVal!-min)
        let dr2 = (r1-r2)/CGFloat(max-medVal!)
        let dg2 = (g1-g2)/CGFloat(max-medVal!)
        let db2 = (b1-b2)/CGFloat(max-medVal!)
        let da2 = (a1-a2)/CGFloat(max-medVal!)
        let dx = values.map { $0<min ? 0 : ($0>max ? CGFloat(max-min) : CGFloat($0 - min)) }
        let meddx = medVal! - min
        let fieldColor = dx.map { $0 < meddx ? NSColor(srgbRed: r0 + $0 * dr1, green: g0 + $0 * dg1, blue: b0 + $0 * db1, alpha: a0 + $0 * da1) : NSColor(srgbRed: r2 + ($0 - meddx) * dr2, green: g2 + ($0 - meddx) * dg2, blue: b2 + ($0 - meddx) * db2, alpha: a2 + ($0 - meddx) * da2) }
        return fieldColor

    } else {
        let dr = (r1-r0)/CGFloat(max-min)
        let dg = (g1-g0)/CGFloat(max-min)
        let db = (b1-b0)/CGFloat(max-min)
        let da = (a1-a0)/CGFloat(max-min)
        let dx = values.map { $0<min ? 0 : ($0>max ? CGFloat(max-min) : CGFloat($0 - min)) }
        let fieldColor = dx.map { NSColor(srgbRed: r0 + $0 * dr, green: g0 + $0 * dg, blue: b0 + $0 * db, alpha: a0 + $0 * da) }
        return fieldColor
    }
}
