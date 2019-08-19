//
//  Populations.swift
//
//  Created by Nico on 17/08/2019.
//

import Cocoa

var worldScriptNames = ["INIT", "END_INIT","VIEW", "LOOP", "END_LOOP"]
var popScriptNames = ["INIT", "MEMBERS_INIT","END_INIT","LOOP","MECHANICS","MEMBERS_LOOP", "END_LOOP"]

class Simulation: NSObject, NSSecureCoding {

    var pops : [String : Population] = [:]
    var vars : [String : PhysValue] = [
        "t": PhysValue(numExp: "0[s]"),
        "dt":PhysValue(doubleVal: 0), // si 0 => temps réel !
        "dim":PhysValue(intVal: 0),
        "min":PhysValue(unit: Unit(unitExp: "m1"), type: "double", values: [-Double.infinity]),
        "max":PhysValue(unit: Unit(unitExp: "m1"), type: "double", values: [Double.infinity]),
        "leftBorder":PhysValue(string: ""),
        "rightBorder":PhysValue(string: ""),
        "loop" : PhysValue(intVal: 0)
        ]  // variables globales du monde
    var scripts : [String : HierarchicExp] = [:] // scripts globaux du monde
    var oldScripts : [String : HierarchicExp] = [:] // où on mémorise les scripts désactivés (par erreur?)
    // la première valeur est l'intervalle du timer (ou 0 si temps réel), la deuxième est la pause, la troisième le temps actuel.
    var scriptPop : String = "world" // population of the current script context (for .var expressions)
    var lastPop : String = "" // last used population (for ..var expressions)
    var scriptMember : Int?
    var timer : Timer = Timer()
    var running : Bool = false // état de la simulation
    var pause : Double = 0 // temps avant une pause (si 0, pas de pause)
    var viewInterval = 1 // nombre d'itérations par affichage de view ( 0 = 1)
    var pauseCounter : Double = 0 // compteur interne pour les pauses
    var viewCounter : Int = 0
    var simSpeed : Double = 0.001 // l'intervalle  du timer en secondes
    var realTime = NSDate()
    var realSpeed : Double = 0
    var ctrlTimeUnit : Unit?
    
    var dt: Double = 0.001
    
    override init() {

    }
    
    var t: Double {
        get { vars["t"]!.asDouble!}
        set(x) { vars["t"]!.values[0] = x}
    }
    
    var min: [Double] {
        get { vars["min"]!.values as! [Double]}
        set(x) { vars["min"]!.values = x}
    }
    
    var max: [Double] {
        get { vars["max"]!.values as! [Double]}
        set(x) { vars["max"]!.values = x}
    }
    
    var sizeUnit : Unit {
        get { vars["min"]!.unit}
    }
    
    var loop: Int {
        get { vars["loop"]!.values[0] as! Int}
        set(x) { vars["loop"]!.values[0] = x}
    }
    
    var dim: Int {
        get { vars["dim"]!.values[0] as! Int}
        set(x) { vars["dim"]!.values[0] = x}
    }
    
    var leftBorder: [String] {
        get { vars["leftBorder"]!.values as! [String]}
        set(x) { vars["leftBorder"]!.values = x}
    }
    
    var rightBorder: [String] {
        get { vars["rightBorder"]!.values as! [String]}
        set(x) { vars["rightBorder"]!.values = x}
    }
    
    
    // Encodage et décodage
    
    static var supportsSecureCoding: Bool = true
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(pops, forKey: "pops")
        aCoder.encode(vars, forKey: "vars")
        aCoder.encode(scripts, forKey: "scripts")
        aCoder.encode(running, forKey: "running")
        aCoder.encode(pause, forKey: "pause")
        aCoder.encode(pauseCounter, forKey: "pauseCounter")
        aCoder.encode(simSpeed, forKey: "simSpeed")
    }
    
    required init?(coder: NSCoder) {
        pops = coder.decodeObject(of: [NSDictionary.self, Population.self, NSString.self], forKey: "pops") as! [String : Population]
        vars = coder.decodeObject(of: [NSDictionary.self, PhysValue.self, NSString.self], forKey: "vars") as! [String : PhysValue]
        scripts = coder.decodeObject(of: [NSDictionary.self, HierarchicExp.self, NSString.self], forKey: "scripts") as! [String : HierarchicExp]
        for aScriptName in scripts.keys {
            let aScript = scripts[aScriptName]
            aScript!.resetFathers()
            scripts[aScriptName] = aScript
        }
 
        running = coder.decodeBool(forKey: "running") 
        pause = coder.decodeDouble(forKey: "pause")
        pauseCounter = coder.decodeDouble(forKey: "pauseCounter")
        simSpeed = coder.decodeDouble(forKey: "simSpeed")
    }
    
    // tente d'exécuter un script donné s'il existe, sinon retourne VRAI !!!
    func runScriptIfExists(pop: String, name: String) -> Bool {
        if pop == "world" {
            if scripts.keys.contains(name) {
                return runScriptForSim(theScript: scripts[name]!, name: "world." + name)
            } else { return false }
        } else {
            if pops[pop]!.scripts.keys.contains(name){
                if name.hasPrefix("MEMBER") {
                    for member in 0...pops[pop]!.id.count-1 {
                        scriptMember = member
                        if runScriptForSim(theScript: pops[pop]!.scripts[name]!, name : pop + "." + name + "[\(member)]") { return true }
                    }
                    scriptMember = nil
                    return false
                } else {
                    return runScriptForSim(theScript: pops[pop]!.scripts[name]!, name: pop + "." + name)
                }
            }  else { return false }
        }
    }
    
    // Affichage
    func showView() {
        let name = worldScriptNames[2]
        if scripts.keys.contains(name) {
            if runScriptIfExists(pop: "world", name: worldScriptNames[2]) { return }
        } else {
            let result = mainCtrl.page!.executeHierarchicScript()
            if result.type == "error" { mainCtrl.printToConsole(result.asString!)}
        }
        mainCtrl.theEquationView.needsDisplay = true

    }
    
    // Initilisation du monde et des populations
    func initiate() {
        timer.invalidate()
        scriptPop = "world"
        scriptMember = nil
        t = 0.0
        loop = 0
        dt = vars["dt"]?.asDouble ?? 0.001
        pauseCounter = 0
        mainCtrl.pauseRunBtn.state = NSControl.StateValue.off
        if ctrlTimeUnit == nil {
            mainCtrl.simIterationsLbl.integerValue = loop
        } else {
            mainCtrl.simIterationsLbl.integerValue = Int(t/ctrlTimeUnit!.mult)
        }
                
        // initilisation du monde
        if runScriptIfExists(pop: "world", name: worldScriptNames[0]) { return }
                
        // boucle d'initialisation des populations
        for popName in pops.keys {
            scriptPop = popName

            // script d'initialisation de chaque population (création des membres)
            if runScriptIfExists(pop: popName, name: popScriptNames[0]) { return }
            
            // boucle(membres)
            if runScriptIfExists(pop: popName, name: popScriptNames[1]) { return }

            // post-initialisation de chaque population
            if runScriptIfExists(pop: popName, name: popScriptNames[2]) { return }
            
            // Calcul de la grille
            pops[popName]!.calcGrid()
                
        }
        //return
        
        // script END_INIT global
        scriptPop = "world"
        if runScriptIfExists(pop: "world", name: worldScriptNames[1]) { return }
                
        // Affichage initial du résultat
        showView()
        viewCounter = 1

    }
    

    // Exécution d'un cycle pour le monde et ses populations
    func loopSim() {
        
        // Un cycle du monde
        scriptPop = "world"
        scriptMember = nil
        if runScriptIfExists(pop: "world", name: worldScriptNames[3]) { return }

        // Un cycle des populations
        for (popName,pop) in pops {
            scriptPop = popName
            
            // script beforeloop de chaque population
            if runScriptIfExists(pop: popName, name: popScriptNames[3]) { return }
            
            // mécanique
            if pop.meca != "" && pop.meca != "p"  {
                
                if runScriptIfExists(pop: popName, name: popScriptNames[4]) { return }
                
                // gestion des bords
                let de = (vars["borderEnergy"] != nil) ? sqrt(vars["borderEnergy"]!.asDouble!/100):1
                for d in 0...dim-1 {
                    let c = ["x","y","z"][d]
                    // détection des débordements
                    let mi = min[d]
                    let ma = max[d]
                    let w = ma-mi
                                        
                    var x = pop.vars[c]!.values as! [Double]

                    if mi > -Double.infinity {
                        let outLeft = x.indices.filter({ x[$0] < mi }) // indices des éléments sortis à gauche
                        if outLeft.count > 0 {
                            switch leftBorder[d] {
                            case "cycle" :
                                for i in outLeft {
                                    x[i] = x[i] + Double(1 + Int((mi-x[i])/w)) * w
                                }
                                
                            case "bounce" :
                                let mi2 = mi + mi
                                var v = pop.vars["v"+c]!.values as! [Double]
                                for i in outLeft {
                                    x[i] = mi2 - x[i]
                                    v[i] = -v[i]*de
                                }
                                pop.vars["v"+c]!.values = v
                            case "stop" :
                                var v = pop.vars["v"+c]!.values as! [Double]
                                for i in outLeft {
                                    x[i] = mi
                                    v[i] = 0
                                }
                                pop.vars["v"+c]!.values = v
                            case "delete" :
                                for i in outLeft {
                                    pop.removeElement(n: i)
                                }
                                x = pop.vars[c]!.values as! [Double]
                            default :
                                for i in outLeft {
                                    x[i] = x[i] + w
                                }
                            }
                        }
                        
                    }
                    if ma < Double.infinity {
                        let outRight = x.indices.filter({ x[$0] > ma }) // indices des éléments sortis à gauche
                        if outRight.count > 0 {
                            switch rightBorder[d] {
                            case "cycle" :
                                for i in outRight {
                                    x[i] = x[i] - Double(1 + Int((x[i]-ma)/w)) * w

                                    //x[i] = x[i] - w
                                }
                            case "bounce" :
                                let ma2 = ma + ma
                                var v = pop.vars["v"+c]!.values as! [Double]
                                for i in outRight {
                                    x[i] = ma2 - x[i]
                                    v[i] = -v[i]*de
                                }
                                pop.vars["v"+c]!.values = v
                            case "stop" :
                                var v = pop.vars["v"+c]!.values as! [Double]
                                for i in outRight {
                                    x[i] = ma
                                    v[i] = 0
                                }
                                pop.vars["v"+c]!.values = v
                            case "delete" :
                                for i in outRight {
                                    pop.removeElement(n: i)
                                }
                            default :
                                print("c'est quoi ça ???")
                            }
                        }
                    }
                    pop.vars[c]!.values = x
                }
                
                // peuplement de la grille
                //pop.calcGrid()
            }
        
            
            // boucle(membres) : script memberloop pour chaque membre
            if runScriptIfExists(pop: popName, name: popScriptNames[5]) { return }
            
            // script boucle final de chaque population
            if runScriptIfExists(pop: popName, name: popScriptNames[6]) { return }

            // calcul de la grille
            pop.calcGrid()

            
        }
        // fin boucle (populations)
        scriptMember = nil
        if runScriptIfExists(pop: "world", name: worldScriptNames[4]) { return }
        
        // script VIEW
        if viewInterval < 2 {
            showView()
        } else if viewCounter == viewInterval {
            showView()
            viewCounter = 1
        } else {
            viewCounter = viewCounter + 1
        }
        
        // et on finit par le timer...
        if vars["dt"]!.asDouble == 0 {
            dt = NSDate().timeIntervalSince(realTime as Date)
            vars["dt"]!.values = [dt]
        }
        t = t + dt
        loop = loop + 1
        if ctrlTimeUnit == nil {
            mainCtrl.simIterationsLbl.integerValue = loop
        } else {
            mainCtrl.simIterationsLbl.integerValue = Int(t/ctrlTimeUnit!.mult)
        }
        if pause > 0 {
            pauseCounter = pauseCounter + 1
            if pauseCounter >= pause {
                pauseCounter = 0
                stopSim()
                viewCounter = 1
            }
        }
        
        realSpeed = (-(realTime.timeIntervalSinceNow)+realSpeed*5)/6
        realTime = NSDate()
        mainCtrl.simSpeedFld.stringValue = "\(1 + Int(realSpeed*1000)) ms"
    }
    
    // retourne vrai s'il y a une erreur
    func runScriptForSim(theScript: HierarchicExp, name: String) -> Bool {
        theMainDoc!.currentScript = name
        let test = theScript.executeHierarchicScript()
        if test.type == "error" {
            stopSim(withError: test.asString!)
            return true
        }
        theMainDoc!.currentScriptLine = ""
        return false
    }
    
    
    func stopSim(withError: String = "") {
        if withError != "" {
            mainCtrl.printToConsole("error: [" + withError
                                    + "] in script: [" + theMainDoc!.currentScript
                                    + "] at line: [" + theMainDoc!.currentScriptLine
                                    + "]")
        }
        timer.invalidate()
        mainCtrl.pauseRunBtn.state = NSControl.StateValue.off
        running = false
        pauseCounter = 0
    }
    
    func startSim() {
        timer.invalidate() //si jamais le timer tournait déjà...
        running = true
        mainCtrl.pauseRunBtn.state = NSControl.StateValue.on
        realTime = NSDate()
        timer = Timer.scheduledTimer(withTimeInterval: simSpeed, repeats: true, block: { _ in self.loopSim() })
        ctrlTimeUnit = mainCtrl.timerUnit
    }
    
    func stepSim() {
        pause = 1
        startSim()
    }
    
    func resetSimSpeed() {
        timer.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: simSpeed, repeats: true, block: { _ in self.loopSim() })
    }
    
    // teste si une population existe
    func hasPop(_ popname: String) -> Bool {
        if Array(pops.keys).contains(popname) { return true }
        return false
    }
    
    func hasVars(_ varname: String) -> Bool {
        if Array(vars.keys).contains(varname) { return true }
        return false
    }
    
    // retourne les composants d'une expression du type <population>.<variable> ainsi que la valeur
    func varComponents(varExp: String) -> (pop: String?, var: String, value: PhysValue?) {
        var popName : String
        var varName : String
        if varExp.hasPrefix("..") {
            if lastPop == "" { popName = "world" }
            else { popName = lastPop }
            varName = String(varExp.dropFirst(2))
        } else if varExp.hasPrefix(".") {
            if scriptPop == "" { popName = "world"}
            else { popName = scriptPop }
            varName = String(varExp.dropFirst())
        } else {
            let splitted = varExp.split(separator: ".")
            popName = String(splitted[0])
            if splitted.count == 1 {
                varName = "id"
            } else {
                varName = String(splitted[1])
            }
        }
        if popName == "world" || popName == "timer" || popName == "sim" {
            if vars[varName] == nil {
                return ("world",varName,nil)            }
            return ("world",varName,vars[varName]!.dup())
        }
        if !self.hasPop(popName) { return (nil,varName,nil)}
        if varName == "id" || varName == "Id" {
            return(popName,varName,PhysValue(unit: Unit(), type: "int", values: pops[popName]!.id))
        }
        if !pops[popName]!.hasVar(varName) {
            if vars[varName] != nil { return ("world",varName,vars[varName]!.dup()) }
            return (popName,varName,nil)
        }
        lastPop = popName
        return(popName,varName,pops[popName]!.vars[varName]!.dup())
    }
    
    // affecte une valeur à une variable, en la recyclant si nécessaire (mais sans contrôle !)
    func setVarVal(popName: String, varName: String, theValue: PhysValue) {
        if popName == "World" || popName == "world" {
            vars[varName] = theValue
        } else {
            pops[popName]!.vars[varName] = theValue
        }
    }
    
    // modifie une sous-valeur d'une variable
    func setVarSubVal(popName: String, varName: String, theValue: Any, item: Int) {
        if popName == "World" || popName == "world" {
            vars[varName]!.values[item] = theValue
        } else {
            pops[popName]!.vars[varName]?.values[item] = theValue
        }
    }
}


// classe définissant une population
class Population: NSObject , NSSecureCoding {
    var id : [Int] = [] // l'identifiant de chaque élément
    var meca : String = "" // "p"osition, "v"itesse, "a"ccélération, "f"orces (et masses)
    var borders : String = "bounce" // comportement des élements sur les bords du monde (s'il y a lieu) : "delete", "bounce", "stop"
    var fieldGrid : PhysValue? // subdivisions grille (en m) pour la recherche rapide des voisins ou champs
    var vars : [String : PhysValue] = [:]
    var scripts : [String : HierarchicExp] = [:]
    var oldScripts : [String : HierarchicExp] = [:] // où on mémorise les scripts désactivés (par erreur?)
    var links : [String:String] = [:] // population : variable. P.ex la ppopulation "eleves"" contient le lien ["ecole","ecoles"]
    // indiquant que la variable "ecole" de la pop "eleves" contient l'id d'un élément de "ecoles".
    var fields : [PhysValue]?
    var gridDims : [Int]? // dimensions de la grille éventuelle
    var gridEls : [[Int]]? // numéros des individus dans chaque case de la grille
    override init() {
    }
        
    static var supportsSecureCoding: Bool = true
     
    func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: "id")
        aCoder.encode(meca, forKey: "meca")
        aCoder.encode(borders, forKey: "borders")
        if fieldGrid != nil { aCoder.encode(fieldGrid,forKey: "fieldGrid")}
        if gridDims != nil { aCoder.encode(gridDims,forKey: "gridDims")}
        if gridEls != nil { aCoder.encode(gridEls,forKey: "gridEls")}
        aCoder.encode(vars, forKey: "vars")
        aCoder.encode(scripts, forKey: "scripts")
        aCoder.encode(links, forKey: "links")
    }
     
     required init?(coder: NSCoder) {
         id = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "id") as! [Int]
         meca = coder.decodeObject(of: [NSString.self], forKey: "meca") as! String
        borders = coder.decodeObject(of: [NSString.self], forKey: "borders") as! String
        fieldGrid = coder.decodeObject(of: [PhysValue.self], forKey: "fieldGrid") as? PhysValue
         gridDims = coder.decodeObject(of: [NSArray.self, PhysValue.self, NSNumber.self], forKey: "gridDims") as? [Int]
         gridEls = coder.decodeObject(of: [NSArray.self, PhysValue.self, NSNumber.self], forKey: "gridEls") as? [[Int]]
        vars = coder.decodeObject(of: [NSDictionary.self, PhysValue.self,NSString.self], forKey: "vars") as! [String : PhysValue]
        scripts = coder.decodeObject(of: [NSDictionary.self, HierarchicExp.self, PhysValue.self, NSString.self], forKey: "scripts") as! [String : HierarchicExp]
         for aScriptName in scripts.keys {
             let aScript = scripts[aScriptName]
             aScript!.resetFathers()
             scripts[aScriptName] = aScript
         }
        links = coder.decodeObject(of: [NSDictionary.self, NSString.self], forKey: "links") as! [String : String]
        // petite routine temporaire pour assurer la conformité avec les premières versions
        for sName in scripts.keys {
            let s = scripts[sName]
            scripts[sName] = nil
            switch sName {
            case "beforeinit" : scripts["START_INIT"] = s
            case "memberinit" : scripts["MEMBER_INIT"] = s
            case "afterinit" : scripts["END_INIT"] = s
            case "beforeloop" : scripts["START_LOOP"] = s
            case "meca" : scripts["MECHANICS"] = s
            case "memberloop" : scripts["MEMBERS_LOOP"] = s
            case "afterloop" : scripts["END_LOOP"] = s
            default : scripts[sName] = s
            }
        }
     }
    
    // ajoute n éléments à une population
    func addElements(n : Int) {
        // création des variables (si id.count = 0) ou ajout de valeurs
        if id.count == 0 {
            create(n: n)
            return
        }
        for (_,theVar) in vars {
            let newValues = Array(repeating: theVar.values[0], count: n)
            theVar.values.append(contentsOf: newValues)
        }
        // mise à jour des identifiants
        var maxId = 0
        if id.count > 0 { maxId = id.max()! }
        id.append(contentsOf: maxId+1...maxId+n)
    }
    
    // crée une population en repartant de zéro
    func create(n: Int) {
        id = Array(0...n-1)
        for (_,theVar) in vars {
            var v : [Any]
            if theVar.values.count == 0 {
                switch theVar.type {
                case "string" : v = Array(repeating: "", count: n)
                case "int" : v = Array(repeating: 0, count: n)
                case "bool" : v = Array(repeating: true, count: n)
                case "color" : v = Array(repeating: NSColor.white, count: n)
                default : v = Array(repeating: 0.0, count: n)
                }
            } else {
                v = Array(repeating: theVar.values[0], count: n)
            }
            theVar.values = v
        }
    }
    
    // teste si une population existe
    func hasVar(_ varname: String) -> Bool {
        if Array(vars.keys).contains(varname) { return true }
        return false
    }
    
    // supprime un élément
    func removeElement(n: Int) {
        if id.count > 0 && n < id.count {
            for (_,theVar) in vars {
                if theVar.values.count == id.count {
                    theVar.values.remove(at: n)
                }
            }
            id.remove(at: n)
        }
    }
    
    // retourne les numéros des éléments dont var égale val
    func getElements(varName: String, value: PhysValue) -> [Int] {
        let values = vars[varName]!.asDoubles
        if values == nil { return [] }
        let testValue = value.asDouble
        if testValue == nil { return [] }
        let r = values!.enumerated().compactMap({ ($1 == testValue!) ? $0 : nil })
        return r
    }
    
    // calcule la grille gridEls de la population
    // attribue d'abord des coordonnées gc[] à chaque individu
    // puis classe les individus dans les gridEls
    func calcGrid() {
        if fieldGrid == nil { return }
        let min = theSim.vars["min"]!
        let max = theSim.vars["max"]!
        gridDims = (max.binaryOp(op: "+", v2: min.numericFunction(op: "_minus"))).binaryOp(op: "/", v2: fieldGrid!).asIntegers!
        let N = gridDims!.reduce(1, { x, y in x*y })
        gridEls = Array(repeating: [], count: N)
        let dxv = fieldGrid!.asDouble!
        let minv = theSim.vars["min"]!.asDoubles!
        let worldDims = theSim.vars["dim"]!.asInteger!
        let dimProds = getDimProds(dim: gridDims!)

        var coords : [[Double]] = []
        (0..<worldDims).forEach({ d in
            let c = ["x","y","z"][d]
            let v = vars[c]?.asDoubles
            if v == nil { return }
            if v!.count != id.count { return }
            coords.append(v!)
        })
        if coords.count == 0 { return }
        var gridCells : [Int] = []
        (0..<id.count).forEach({ el in
            var gc : [Int] = Array(repeating: 0, count: worldDims)
            var errorTest = false
            (0..<worldDims).forEach({ d in
                let x = coords[d][el]
                if x.isNaN { errorTest = true }
                else { gc[d] = Int(trunc((x - minv[d])/dxv)) }
            })
            if errorTest {
                theSim.stopSim(withError: "Undefined x,y coordinates element")
                return
            }
            let n = (0..<worldDims).reduce(0) {$0 + dimProds[$1] * gc[$1]}
            if n>=0 && n<N {
                gridEls![n].append(el)
                gridCells.append(n)
            } else {
                gridCells.append(-1)
            }
        })
        vars["grid"] = PhysValue(unit: Unit(), type: "int", values: gridCells)
    }
}


/*

{<population>} retourne les numéros d'ordre des éléments de population
{<population>.<variable>} retourne les valeurs de cette variable (sous la forme d'une Physval vectorielle)
{<population>.<variable1>.<variable2>} idem avec une variable liée dans une population 2
{<population1>..<population2>.<variable>} idem

{<population>.id} retourne les numéros d'id des éléments de population
<vecteur>.[Int] retourne les élements du vecteur d'indices compris dans [Int]
<vecteur>.[Bool] retourne les élements du vecteur d'indices TRUE
{<population>[Int]} retourne les numéros des éléments dont l'id est dans [Int] et dans le même ordre
{<population>[Int].variable} retourne les valeurs de variable des éléments dont l'id est dans [Int]

 
Exemple de scripts avec une population "Ecoles" et une population "Eleves" (ayant entre autres une variable "ecole" liée à "Ecoles")
 
 {Eleves} retourn les numéros 1 à n des élèves (équivalent à (1:n)
 {Eleves.age} retourne une PhysVal contenant tous les âges des élèves
 {Eleves.age}[n] idem pour l'élève n°n
 {Eleves.age}[selection] idem pour tous les élèves de la sélection ([Int])
 {Eleves.Ecole} retourne une physval contenant les numéros id des écoles dans l'ordre des élèves (on suppose uen
 {Eleves.Ecole}[n] le numéro de l'école du n-ième élève
 {Ecoles.taille}[{Eleves.Ecole}[n]] la taille de l'école du nième élève - identique à {Eleves.ecole.taille}[n]
 {Eleves.ecole.id}[n] retourne le numéro d'id de l'école de l'élève n°n
 {Ecoles.taille}[{Ecole.id} == 237 ] Taille de l'école dont l'id = 237
 {Eleves.age} > 15 retourne une physval booléenne indiquant quels élèves ont plus de 15 ans
 
 {Eleves.age} = 16 met tous les ages à 16
 N =  count({Eleves.id}) nombre d'élèves
 {Eleves.age} = normdis(N,0,1,-1,5) + 16   distribution quasi-normale d'âges de moyenne 16 (entre 15 et 21)
 mean({Eleves.age}) moyenne des âges
 
*/



