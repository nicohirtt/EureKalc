//
//  unitsCreator.swift
//  calculator
//
//  Created by Nico on 23/10/14.
//  Copyright (c) 2014 Nico Hirtt. All rights reserved.
//

import Foundation


// ****************************************************
// Structures et fonctions pour la gestion des unités *
// ****************************************************

var fundamentalUnits = ["M","L","T","I","t","n","J"]
var fundamentalUnitsNames = ["M":"kg","L":"m","T":"s","I":"A","t":"K","n":"mol","J":"cd"]
var nullUnitPowers = ["M":0,"L":0,"T":0,"I":0,"t":0,"n":0,"J":0]
enum unitsMultiples: String { case y = "y", z = "z", a = "a", f = "f", p = "p", n = "n", µ = "µ", m = "m", c = "c", d = "d", da = "da", h = "h", k = "k", M = "M", G = "G", T = "T", P = "P", E = "E", Z = "Z", Y = "Y" }
var unitsMultiplesNames  : Dictionary<unitsMultiples,String> = [ .y:"y", .z:"z", .a:"a", .f:"f", .p:"p", .n:"n", .µ:"µ", .m:"m", .c:"c", .d:"d", .da:"da", .h:"h", .k:"k", .M:"M", .G:"G", .T:"T", .P:"P", .E:"E", .Z:"Z", .Y:"Y" ]
var unitsMultiplesMults  : Dictionary<unitsMultiples,Double>  = [ .y:1e-24, .z:1e-21, .a:1e-18, .f:1e-15, .p:1e-12, .n:1e-9, .µ:1e-6, .m:1e-3, .c:1e-2, .d:1e-1, .da:1e1, .h:1e2, .k:1e3, .M:1e6, .G:1e9, .T:1e12, .P:1e15, .E:1e18, .Z:1e21, .Y:1e24 ]
var unitsByName = Dictionary<String,Unit>()
var unitsByType = Dictionary<String, Array<Unit> >()
var unitsDefs : [[String]] = [] // le script de définition sous forme de array de lignes d'items

class Unit : NSObject, NSSecureCoding {
    
    var name : String = ""
    var powers : [String:Int]
    var mult : Double // le facteur par lequel il faut multiplier la valeur pour la transofrmer en unités de base (p. ex si mm -> 0.001 )
    var offset : Double // la valeur qu'il faut ensuite ajouter p.ex °C : mult = 1, offset = 273.15
     
    static var supportsSecureCoding: Bool = true
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.name, forKey: "name")
        aCoder.encode(self.powers, forKey: "powers")
        aCoder.encode(self.mult, forKey: "mult")
        aCoder.encode(self.offset, forKey: "offset")
    }
    
    required init?(coder aDecoder: NSCoder) {
        name = aDecoder.decodeObject(of: [NSString.self], forKey: "name") as! String
        powers = aDecoder.decodeObject(of: [NSDictionary.self, NSString.self, NSNumber.self], forKey: "powers") as! [String:Int]
        mult = aDecoder.decodeDouble(forKey: "mult")
        offset = aDecoder.decodeDouble(forKey: "offset")
    }
    
    override init() {
        // initialisation d'une unité numérique sans dimensions
        self.name = ""
        self.powers = nullUnitPowers
        self.mult = 1.0 // le facteur par lequel il faut multiplier la valeur pour la transofrmer en unités de base (p. ex si mm -> 0.001 )
        self.offset = 0.0 // la valeur qu'il faut ensuite ajouter p.ex °C : mult = 1, offset = 273.15
        super.init()
    }
  
    
    init(num: Bool) {
        // initialisation d'une unité numérique sans dimension (num = true) ou d'une unité vide (num = false)
        // => Unit(num=true) est donc identique à Unit()
        if num == true {
            self.powers = nullUnitPowers
        }
        else {
            self.powers = [:]
        }
        self.name = ""
        self.mult = 1.0 // le facteur par lequel il faut multiplier la valeur pour la transofrmer en unités de base (p. ex si mm -> 0.001 )
        self.offset = 0.0 // la valeur qu'il faut ensuite ajouter p.ex °C : mult = 1, offset = 273.15
        super.init()
    }
    
    init(name: String, powers : [String:Int], mult: Double, offset:Double) {
        // initialisation générale
        self.name = name
        self.powers = powers
        self.mult = mult
        self.offset = offset
        super.init()
    }
    
    init(unitExp: String) {
        // unitExp contient une chaine de type "<unité><nombre><unité><nombre>...". P.ex : "W1m-2"
        // Un "." derrière une lettre est interprété comme "1" (les autres "." sont sans effet)
        // Un "/" change le signe du premier nombre qui suit
        var mode = "name"
        var numString = ""
        var nameString = ""
        var divide = false
        var nextDivide = false
        self.powers = nullUnitPowers
        self.mult = 1.0
        self.offset = 0.0
        for car in (unitExp + ". ") {
            let c = String(car)
            if isDigit(c: c) || c=="-" {
                numString += c
                mode = "num"
            }
            else if mode == "num" && nameString != "" {
                // fin de lecture d'une unité et de sa puissance : on fait le traitement
                mode = "name"
                var newExp = (numString as NSString).integerValue
                numString = ""
                if divide==true {
                    newExp = -(newExp)
                    divide = false
                }
                if unitsByName[nameString] == nil {
                    self.powers = [String:Int]()
                }
                else {
                let newUnit = unitsByName[nameString]!
                nameString = ""
                let newPowers = multiplyUnitPowers(powers1: self.powers, exp1: 1, powers2: newUnit.powers, exp2: newExp)
                self.powers = newPowers
                self.mult = self.mult * pow(newUnit.mult,Double(newExp))
                self.offset = newUnit.offset
                if c == "/" || nextDivide == true {
                    divide = true
                    nextDivide = false
                    if c != "/" { nameString += c }
                }
                else if c != "." {
                    nameString += c
                }
                }
            }
                
            else if c=="." {
                if mode == "name" { numString = "1" }
                mode = "num"
            }
            else if c=="/" {
                if mode == "name" { numString = "1" }
                nextDivide = true
                mode = "num"
            }
            else {
                nameString += c
            }
        }
        self.name = unitExp
    }

    
    func powersString() -> String {
        // retourne les puissances de base soous forme de chaine "kg2m1s-1"
        var pString = ""
        for fUnit in fundamentalUnits {
            if powers[fUnit] != nil {
                if powers[fUnit]! != 0 {
                    pString = pString + fundamentalUnitsNames[fUnit]! + String(powers[fUnit]!)
                }
            }
        }
        return pString
    }
    
    func dup() -> Unit {
        let result = Unit()
        result.name = self.name
        result.powers = self.powers
        result.mult = self.mult
        result.offset = self.offset
        return result
    }
    
    func baseString() -> String {
        // retourne une unité sous la forme basique "kg2m3s-1"
        if self.powers.count == 0 { return "" }
        let theList = self.powers
        var theString = ""
        for fundamentalUnit in fundamentalUnits {
            let power = theList[fundamentalUnit]!
            if  power != 0 {
                theString += ( fundamentalUnitsNames[fundamentalUnit]! + "\(power)" )
            }
        }
        if theString == "" {theString = ""}
        return theString
    }
    
    // Vérifie si deux unités sont du même type
    func isIdentical(unit: Unit) -> Bool {
        if self.powers.count == 0 {
            if unit.powers.count == 0 { return true }
            else { return false }
        }
        if unit.powers.count == 0 { return false }
        for fundamentalUnit in fundamentalUnits {
            if self.powers[fundamentalUnit] != unit.powers[fundamentalUnit] { return false }
        }
        return true
    }
    
    func multiplyWith(unit:Unit, exp1:Int, exp2:Int) -> Unit {
        let power = multiplyUnitPowers(powers1: self.powers, exp1: exp1, powers2: unit.powers, exp2: exp2)
        let theUnit = Unit(name: "", powers: power, mult: 1.0, offset: 0.0)
        return theUnit.baseUnit()
    }
    
    func sqrt() -> Unit {
        var powers = self.powers
        for fundamentalUnit in fundamentalUnits {
            if (powers[fundamentalUnit] == nil ) {return Unit()}
            let power = powers[fundamentalUnit]!
            if (power % 2 == 0) {
                powers[fundamentalUnit] = power / 2
            }
            else {
                return Unit()
            }
        }
        return Unit(name: "", powers: powers, mult: 1.0, offset: 0.0).baseUnit()
    }
    
    func inverseUnit() -> Unit {
        var powers = self.powers
        for fundamentalUnit in fundamentalUnits {
            powers[fundamentalUnit] = -powers[fundamentalUnit]!
        }
        return Unit(name: "", powers: powers, mult: 1/self.mult, offset: 0.0).baseUnit()
    }
    
    func isBaseUnit() -> Bool {
        // s'il s'agit d'une unité SI de base (mult =1, offset = 0) comme m, s, J, W, m/s, etc
        if self.mult == 1.0 && self.offset == 0 {return true }
        return false
    }

    func isNilUnit() -> Bool {
        // une unit nulle (nil) non numérique
        if self.powers.count == 0 {return true }
        if self.powers == nullUnitPowers  {return true }
        return false
    }

    
    func isEmptyUnit() -> Bool {
        // unité numérique vide (toutes dimensions = 0)
        for (_,power) in self.powers {
            if power != 0 { return false }
        }
        return true
    }
    
    func baseUnit() -> Unit {
        let theString = self.baseString()
        if unitsByType[theString] == nil {
            let theBaseUnit = Unit()
            theBaseUnit.powers = self.powers
            theBaseUnit.mult = 1.0
            theBaseUnit.offset = 0.0
            theBaseUnit.name = theString
            return theBaseUnit
        }
        return (unitsByType[theString]!)[0]
    }

    func toSI(val: Double) -> Double {
        // tansforms the value (val) expressed in the receiver's unit to SI value
        return val*self.mult - self.offset
    }
    
    func fromSI(val: Double) -> Double {
        // transforms the (SI) value val into the receiver's unit
        return (val - self.offset)/self.mult
    }
    
    func unitDictionariesForGraph() -> (names:[String],mults:[String:Double],offsets:[String:Double]) {
        let thePowersString = self.baseString()
        let theUnitsList = unitsByType[thePowersString]
        var multDic = [String:Double]()
        var offDic = [String:Double]()
        var namesList = [String]()
        for aUnit in theUnitsList! {
            namesList.append(aUnit.name)
            multDic[aUnit.name] = aUnit.mult
            offDic[aUnit.name] = aUnit.offset
        }
        return (namesList,multDic,offDic)
    }
    
    func unitsOfSameType() -> [Unit] {
        let thePowersString = self.baseString()
        let theUnitsList = unitsByType[thePowersString]
        if theUnitsList == nil { return [Unit]() }
        return theUnitsList!
    }
    
    var similarUnitNames : [String] {
        let unitsList = unitsByType[baseString()]
        if unitsList == nil { return [self.name] }
        var list : [String] = []
        for aUnit in unitsList! {
            list.append(aUnit.name)
         }
        return list
    }
 }


func multiplyUnitPowers(powers1 : Dictionary<String,Int>, exp1 : Int, powers2 : Dictionary<String,Int>, exp2 : Int) -> Dictionary <String,Int> {
    // multiplie deux puissances d'unités en les multipliqant par exp1 ou exp2 (donc additionne leurs puissances)
    // pour une division, il suffit de prendre exp2 négatif
    var result = nullUnitPowers
    for fundamentalUnit in fundamentalUnits {
        var p1 = 0
        if powers1[fundamentalUnit] != nil { p1 = powers1[fundamentalUnit]! }
        var p2 = 0
        if powers2[fundamentalUnit] != nil { p2 = powers2[fundamentalUnit]! }
        let power = exp1*p1 + exp2*p2
        result[fundamentalUnit] = power
    }
    return result
}

func unitConversion(value : Double, oldUnit : Unit, newUnit : Unit) -> Double {
    // convertit une grandeur numérique d'une unité dans une autre
    let baseValue = (value + oldUnit.offset)*oldUnit.mult
    return baseValue/newUnit.mult - newUnit.offset
}


func createUnits(name: String, powStr : String, mult : Double, offset: Double, multiples : Array<unitsMultiples>) -> Unit {
    // crée une série d'unités à lettir de la liste ci-dessus
    let newUnit = Unit(name : name, powers : unitPowersFromBaseString(theString: powStr), mult : mult , offset : offset)
    addUnitToLists(unit: newUnit)
    for multiple in multiples {
        let theMult = unitsMultiplesMults[multiple as unitsMultiples]! * newUnit.mult
        let theName = unitsMultiplesNames[multiple]! + newUnit.name
        let thePowers = newUnit.powers
        addUnitToLists(unit: Unit(name: theName, powers: thePowers, mult: theMult , offset: 0.0))
    }
    return newUnit // retourne la première unité créée
}

func unitPowersFromBaseString(theString : String) -> Dictionary<String,Int> {
    // transforme une unité sous forme "kg2m3s-1" en dictionnaire de puissance d'unité (Unit.powers)
    var thePowers = nullUnitPowers
    for fundamentalUnit in fundamentalUnits {
        let separatedArray = (theString as NSString).components(separatedBy: fundamentalUnitsNames[fundamentalUnit]!)
        if separatedArray.count == 2 {
            let power = (separatedArray[1] as NSString).integerValue
            thePowers[fundamentalUnit] = power
        }
    }
    return thePowers
}

func addUnitToLists(unit : Unit) {
    // ajoute une unité aux deux listes
    let theName = unit.name
    let thePowersString = unit.baseString()
    var theList = Array<Unit>()
    unitsByName[theName] = unit
    if unitsByType[thePowersString] == nil {
        theList.append(unit)
        unitsByType[thePowersString] = theList
    }
    else {
        theList = unitsByType[thePowersString]!
        theList.append(unit)
        unitsByType[thePowersString] = theList
    }
}

