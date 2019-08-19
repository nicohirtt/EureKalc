//
//  ValueAndUnits.swift
//  calculator
//
//  Created by Nico on 22/10/14.
//  Copyright (c) 2014 Nico Hirtt. All rights reserved.
//

import Cocoa
import Accelerate


// Classe  ¨physValue pour la gestion des grandeurs (scalaires, vectorielles, avec ou sans unités)

var maxValuesInResultString = 10

var trueVal = PhysValue(boolVal : true)
var falseVal = PhysValue(boolVal : false)
func errVal(_ err: String) -> PhysValue { return PhysValue(error: err)}
func dbVal(_ db: Double, unit : Unit = Unit() ) -> PhysValue { return PhysValue(unit: unit, type: "double", values: [db])}

class PhysValue : NSObject, NSSecureCoding {
    
    var unit : Unit = Unit()
    var type : String = "double" // "double","int","string","bool","exp","list","color","dataframe", "error"
    var values : [Any] = [] // la(les) valeur(s) dans l'unité fondamentale (!)
    var dim : [Int] = [1] // [1] pour un scalaire, [n] pour un vecteur, [n,m] pour champ 2D, etc...
    var names : [[String]]? = nil // les noms pour les dataframes : [[noms de colonnes],[noms de rangs]]
    var field : [String:PhysValue]? = nil // keys = "origin" et "dx" et "vec" (bool)
    
    static var supportsSecureCoding: Bool = true
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.unit, forKey: "unit")
        aCoder.encode(self.type, forKey: "type")
        aCoder.encode(self.values, forKey: "values")
        aCoder.encode(self.dim, forKey: "dim")
        if let names = names {aCoder.encode(names, forKey: "names")}
        if let field = field {aCoder.encode(field, forKey: "field")}
    }

    required init?(coder: NSCoder) {
        unit = coder.decodeObject(of: [Unit.self], forKey: "unit") as! Unit
        type = coder.decodeObject(of: [NSString.self], forKey: "type") as! String
        values = coder.decodeObject(of: [NSArray.self, PhysValue.self, HierarchicExp.self, NSColor.self, NSString.self, NSNumber.self], forKey: "values") as! [Any]
        dim = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "dim") as! [Int]
        names = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "names") as? [[String]]
        field = coder.decodeObject(of: [NSDictionary.self, PhysValue.self, NSString.self], forKey: "field") as? [String:PhysValue]
    }
    
    // retourne une valeur "nulle" (= vide), p.ex pour une variable sans valeur.
    
    override init() {
        unit = Unit(num: false)
        type = ""
        values = []
        dim = [0]
        field = nil
        super.init()
    }
    
    // Création d'une PhysVal avec des valeurs données et (éventuellement) des dimensions données
    init(unit:Unit, type:String, values: [Any], dim: [Int] = [1], field: [String : PhysValue]? = nil) {
        self.unit = unit
        self.type = type
        self.values = values
        if dim.count == 1 {
            self.dim = [values.count]
        } else {
            self.dim = dim
            let n = dim.reduce(1,*)
            if values.count != n {
                self.type = "error"
                self.values = ["number of elements does not fit dimensions"]
                self.unit = Unit()
            }
        }
        self.field = field
        super.init()
    }
    
    // Création d'une PhysVal d'erreur
    init(error: String) {
        type = "error"
        values = [error]
        super.init()
    }
    
    init(doubleVal : Double) {
        self.unit = Unit(num: true)
        self.type = "double"
        self.values = [doubleVal]
        self.dim = [1]
        super.init()
    }
    
    init(boolVal : Bool) {
        unit = Unit(num: false)
        type = "bool"
        values = [boolVal]
        self.dim = [1]
        super.init()
    }
    
    init(intVal : Int) {
        unit = Unit(num: false)
        type = "int"
        values = [intVal]
        self.dim = [1]
        super.init()
    }
    
    init(string : String) {
        unit = Unit(num: false)
        type = "string"
        values = [string]
        self.dim = [1]
        super.init()
    }
    
    init(color: NSColor) {
        unit = Unit(num: false)
        type = "color"
        values = [color]
        self.dim = [1]
        super.init()
    }
    
    init(exp: HierarchicExp) {
        unit = Unit(num: false)
        type = "exp"
        values = [exp]
        self.dim = [1]
        super.init()
    }

    // Crée un champ de valeurs (double) de dimensions données
    init(dim: [Int], fill: Double = 0.0, values : [Double] = [] ) {
        self.unit = Unit(num: true)
        self.type = "double"
        self.dim = dim
        var n = 1
        for k in 0...dim.count-1 {
            n = n * dim[k]
        }
        if values.count != n {
            self.values = Array(repeating: fill, count: n)
        } else {
            self.values = values
        }
    }
    
    // Crée une physval contenant une liste d'indices entiers
    init(indexes : [Int]) {
        self.dim = [indexes.count]
        self.type = "int"
        self.values = indexes
    }
    
    // crée une valeur  PhysValue depuis une chaine représentant un nombre genre 4.3[kg/s]
    init(numExp : String, dim: [Int] = [1]) {
        self.type = "double"
        let splittedString = numExp.components(separatedBy: "[")
        if splittedString.count == 1 {
            // il n'y a pas d'unité
            if numExp == "∞" { self.values = [Double.infinity]}
            else if numExp == "-∞" { self.values = [-Double.infinity]}
            else {
                let numExp2 = (numExp.contains(",") && decimalSep == ",") ?
                    numExp.replacingOccurrences(of: ",", with: ".") : numExp
                self.values = [(numExp2 as NSString).doubleValue]
            }
            self.unit = Unit(num:true)
        }
        else {
            var theValue = 0.0
            if splittedString[0] == "∞" { theValue = Double.infinity}
            else if splittedString[0] == "-∞" { theValue = -Double.infinity}
            else { theValue = (splittedString[0] as NSString).doubleValue}
            let theUnitString = (splittedString[1].components(separatedBy: "]"))[0]
            let theUnit = Unit(unitExp:theUnitString)
            theValue = unitConversion(value: theValue, oldUnit: theUnit, newUnit: theUnit.baseUnit())
            self.values = [theValue]
            self.unit = theUnit
            self.type = "double"
        }
        if dim.count > 1 {
            let n = dim.reduce(1,*)
            self.values = Array(repeating: self.values[0], count: n)
        } else if dim[0] > 1 {
            self.values = Array(repeating: self.values[0], count: dim[0])
        }
        self.dim = dim
    }
    
    init(physval: PhysValue) {
        unit = physval.unit
        type = physval.type
        values = physval.values
        dim = physval.dim
        field = physval.field
    }
    
    // produit des dimensions
    var dimProds : Int {
        return dim.reduce(1,*)
    }
    
    // force la composante "vec" d'un champ
    func setVec(_ vec: Bool = true) {
        if field == nil {
            field = ["vec" : PhysValue(boolVal: vec)]
        } else {
            field!["vec"] = PhysValue(boolVal: vec)
        }
    }
    
    func setFieldValue(key : String, phv : PhysValue) {
        if field == nil {
            field = [key : phv]
        } else {
            field![key] = phv
        }
    }
    
    var isEmpty : Bool {
        if type == "" && values.count == 0 { return true }
        return false
    }
    
    var isNumber : Bool {
        if type == "int" || type == "double" { return true}
        return false
    }
    
    var isInteger : Bool {
        if !isNumber { return false }
        let db = asDouble!
        if floor(db) == db { return true }
        return false
    }
    
    var isBool : Bool {
        if type == "bool" { return true}
        return false
    }
    
    var isError : Bool {
        if type == "error" { return true }
        return false
    }
    
    var isVec : Bool {
        if field == nil { return false }
        if field!["vec"] == nil { return false }
        return field!["vec"]!.asBool!
    }
    
    var isField : Bool {
        if field == nil { return false}
        return true
    }
    
    var fieldOrigin : PhysValue? {
        if field != nil {
            return field!["origin"]
        }
        return nil
    }
    
    var fieldDx : PhysValue? {
        if field != nil {
            return field!["dx"]
        }
        return nil
    }
    
    var fieldSizes : PhysValue? {
        if field != nil {
            let dx = field!["dx"]!.asDouble!
            let sizeVals = dim.enumerated().map({ (j,d) in
                dx * Double(d)
            })
            return PhysValue(unit: field!["dx"]!.unit, type: "double", values: sizeVals)
        }
        return nil
    }
    
    func isString() -> Bool {
        if type != "string" { return false }
        if values.count != 1 { return false }
        if values[0] is String { return true }
        return false
    }
    
    func isStrings() -> Bool {
        if type != "string" { return false }
        if values[0] is String { return true }
        return false
    }
    
    
    func isEmptyString() -> Bool {
        if self.isString() {
            if values[0] as! String == "" { return true}
        }
        return false
    }
    
    
    // Retourne la/les valeur(s) dans l'unité spécifiée (uniquement pour les valeurs doubles)
    
    var valuesInUnit : [Double] {
        let vals = self.asDoubles!
        if unit.isNilUnit() {
            return vals
        }
        return vals.map { $0 / unit.mult + unit.offset }
    }
 
    
    // Retourne la valeur dans l'unité (uniquement pour les scalaires
    var valueInUnit : Double {
        return (self.asDouble! / unit.mult + unit.offset)
    }
    
    // Retourne la valeur (supposée scalaire) en chaîne (on suppose le type String)
    
    var asString : String? {
        if values.count < 1 || (type != "string" && type != "error") { return nil }
        return values[0] as? String
    }
    
    var asStrings : [String]? {
        if type == "string" { return values as? [String] }
        if (type == "double" || type == "int") { return values.map{ ($0 is Int) ? String($0 as! Int): String($0 as! Double) } }
        return nil
    }

    
    var asDouble : Double? {
        if type != "double" && type != "int" { return nil }
        if values[0] is Int { return(Double(values[0] as! Int))}
        return values[0] as? Double
    }
    
    var asDoubles : [Double]? {
        if type != "double" && type != "int" { return nil }
        return values.map{ ($0 is Int) ? Double($0 as! Int) : $0 as? Double ?? Double.nan }
    }
    
    // On suppose que physval est un scalaire double
    func getDouble(n : Int) -> Double {
        return values[n] is Int ? Double(values[n] as! Int) : values[n] as! Double
    }
    
    var asInteger : Int? {
        if type != "double" && type != "int" { return nil }
        if values[0] is Int { return values[0] as? Int }
        if values[0] is Double { return Int(values[0] as! Double) }
        return nil
    }
    
    var asIntegers : [Int]? {
        if type != "double" && type != "int" { return nil }
        if values.count == 0 { return [] }
        let r = values.map({
            if $0 is Int { return $0 as! Int }
            else if $0 is Double { return Int($0 as! Double) }
            return 0
        })
        return r
        /*
        if values[0] is Int {
            let test = values as? [Int]
            return values as? [Int]
        } else if values[0] is Double {
            let asDoub = values as! [Double]
            return(asDoub.map { Int($0)} )
        } else {
            let asDoub = values as? [Double]
            if asDoub == nil {
                return nil
            }
            return(asDoub!.map { Int($0)} )
        }
        //return nil
         */
    }
    
    var asBool : Bool? {
        if values.count == 0 || type != "bool" { return nil }
        return values[0] as? Bool
    }
    
    var asBools : [Bool]? {
        if type != "bool" { return nil }
        return(values as! [Bool])
    }
    
    var asColor : NSColor? {
        if type != "color" { return nil }
        return(values[0] as! NSColor)
    }
    
    var asColors : [NSColor]? {
        if type != "color" { return nil }
        return(values as! [NSColor])
    }

    // transforme une physval quelconque en liste
    var asList : PhysValue {
        if type == "list" { return self }
        let result = PhysValue(unit: Unit(), type: self.type, values: [])
        for n in 0..<values.count {
            result.values.append(self.physValn(n: n))
        }
        return result
    }
    
    var negated: [Bool]?  {
        if type != "bool" { return nil}
        return values.map { !($0 as! Bool)}
    }
    

    
    // Duplique une valeur Physval
    func dup() -> PhysValue {
        let result = PhysValue()
        result.unit = self.unit.dup()
        result.type = self.type
        if type == "list" {
            result.values = []
            for v in self.values {
                if v is PhysValue {
                    result.values.append((v as! PhysValue).dup())
                } else if v is HierarchicExp {
                    result.values.append((v as! HierarchicExp).copyExp())
                } else {
                    result.values.append(v)
                }
            }
        } else if type == "exp" {
            result.values = []
            for v in self.values {
                result.values.append((v as! HierarchicExp).copyExp())
            }
        } else {
            result.values = self.values
        }
        result.dim = self.dim
        result.names = self.names
        if self.field == nil { result.field = nil }
        else {
            var r : [String:PhysValue] = [:]
            for k in field!.keys {
                r[k] = field![k]!.dup()
            }
            result.field = r
        }
        return result
    }

    
    // Ajoute un élément (Any) à une physVal
    func addElement(_ newVal: Any) {
        if dim.count != 1 { return }
        dim[0] = dim[0] + 1
        self.values.append(newVal)
    }
    
    // Ajoute un array d'éléments à une physval
    func addElements(_ newVals: [Any]) {
        if dim.count != 1 { return }
        dim[0] = dim[0] + newVals.count
        (self.values).append(contentsOf: newVals)
    }
    
    // Remplace les valeurs par d'autres (en conservant la dim)
    func setValues(_ val2: PhysValue) {
        if val2.values.count == 1 {
            let doubVal = val2.values[0] as! Double
            values = Array(repeating: doubVal, count: self.values.count)
        } else {
            values = val2.values
        }
    }
    
    // retourne une physval de même type, mais vide
    func emptyCopy() -> PhysValue {
        let result = PhysValue()
        result.unit = self.unit.dup()
        result.type = self.type
        result.values = []
        result.dim = [0]
        result.field = self.field
        return result
    }
    
    // retourne une physval contenant seulement les valeurs min et max non NaN et non infini
    func limits() -> PhysValue {
        let dbVals = (self.asDoubles!).compactMap({ ($0.isNaN || $0.isInfinite ? nil : $0)})
        if dbVals.count == 0 { return PhysValue(unit: self.unit, type: "double", values: [0,0]) }
        if dbVals.count == 1 {
            let r = self.dup()
            let v = r.values[0]
            r.values = [v,v]
            return r
        }
        let result = PhysValue()
        result.unit = self.unit.dup()
        result.type = self.type
        result.values = [dbVals.min()!,dbVals.max()!]
        result.dim = [2]
        return result
    }
    
    func dims() -> [Int] {
        if dim.count > 1 {return dim}
        dim = [values.count]
        return dim
    }
    
    
    // ************************************************
    // gestion des indices et coordonnées de n-matrices
    // ************************************************
    
    // dimension d'un champ (réduit à l'essentiel si vecteur)
    var fieldDim : [Int] {
        return isVec ? dim.dropLast() : dim
    }
    
    // nombre d'éléments (ou nombre de vecteurs pour un champ vectoriel)
    var nElems : Int {
        return fieldDim.reduce( 1, { x, y in x*y })
    }
    
    // n-ième élément des valeurs
    func getValueNumber(n : Int) -> Any? {
        if n < self.values.count && n >= 0 { return values[n] }
        return nil
    }
    
    // élément matriciels de coordonnées coord=(i,j,k,...)
    func getMatValueWithIndexes(coord: [Int]) -> Any? {
        let n = indexFromCoords(coord: coord)
        if n == nil { return nil }
        if n! < 0 || n! > values.count - 1 { return nil }
        return getValueNumber(n: n!)
    }
    
    // valeur d'un champ vectoriel au point d'indices (i,j,k)'
    func getVecFieldValWithIndexes(coord: [Int]) -> [Double]? {
        var values: [Double] = []
        let vecDim = self.dim.last!
        for i in 0..<vecDim {
            var vCoord = coord
            vCoord.append(i)
            let val = self.getMatValueWithIndexes(coord:vCoord)
            if val as? Double == nil {return nil}
            values.append(val as! Double)
        }
        return values
    }
    
    // test si un point est contenu dans un champ donné
    func fieldContains(point: PhysValue) -> Bool {
        let dims = isVec ? dim.dropLast() : dim // les dimensions du champ initial (scalaire)
        let origin = self.fieldOrigin!.asDoubles!
        let sizes = self.fieldSizes!.asDoubles!
        let coords = point.asDoubles!
        for i in 0..<dims.count {
            if coords[i] < origin[i] { return false }
            if coords[i] > origin[i] + sizes[i] { return false }
        }
        return true
    }
    
    // valeur d'un champ au point de coord=(x,y,z...) SANS TEST DE VALIDITE DU POINT
    func getFieldValWithCoord(coord: PhysValue, extra: Bool = false) -> PhysValue? {
        if !self.isField { return nil }
        let coordVals = coord.asDoubles
        if coordVals == nil { return nil}
        let origin = self.fieldOrigin!.asDoubles!
        let dx = self.fieldDx!.asDouble!
        let fDim = self.isVec ? self.dim.count - 1 : self.dim.count
        if coordVals!.count != fDim { return nil}
        var mCoord: [Int] = []
        if !extra {
            for i in 0..<fDim {
                let c = Int(((coordVals![i] - origin[i])/dx).rounded())
                if c<0 || c >= self.dim[i] { return nil }
                mCoord.append(c)
            }
            if self.isVec {
                let vector = getVecFieldValWithIndexes(coord: mCoord)
                return vector == nil ? nil : PhysValue(unit: self.unit, type: "double", values: vector!)
            } else {
                let val = self.getMatValueWithIndexes(coord:mCoord)
                return val == nil ? nil : PhysValue(unit: self.unit, type: "double", values: [val!])
            }
        } else {
            if !self.isVec {
                if fDim == 1 {
                    let cx1 = Int(((coordVals![0] - origin[0])/dx - 0/5).rounded())
                    let dx1 = coordVals![0] - origin[0] - dx*Double(cx1)
                    let v1 = (self.getMatValueWithIndexes(coord:[cx1]) as! Double)*(dx-dx1)
                    let v2 = (self.getMatValueWithIndexes(coord:[cx1+1]) as! Double)*dx1
                    let v=(v1+v2)/dx
                    return PhysValue(unit: self.unit, type: "double", values: [v],dim: [1])
                } else if fDim == 2 {
                    let cx1 = Int(((coordVals![0] - origin[0])/dx - 0/5).rounded())
                    let dx1 = coordVals![0] - origin[0] - dx*Double(cx1)
                    let cy1 = Int(((coordVals![1] - origin[1])/dx - 0.5).rounded())
                    let dy1 = coordVals![1] - origin[1] - dx*Double(cy1)
                    let v1 = (self.getMatValueWithIndexes(coord:[cx1,cy1]) as! Double)*(dx-dx1)*(dx-dy1)
                    let v2 = (self.getMatValueWithIndexes(coord:[cx1,cy1+1]) as! Double)*(dx-dx1)*dy1
                    let v3 = (self.getMatValueWithIndexes(coord:[cx1+1,cy1]) as! Double)*dx1*(dx-dy1)
                    let v4 = (self.getMatValueWithIndexes(coord:[cx1+1,cy1+1]) as! Double)*dx1*dy1
                    let v=(v1+v2+v3+v4)/(dx*dx)
                    return PhysValue(unit: self.unit, type: "double", values: [v], dim: [1])
                } else if fDim == 3 {
                    let cx1 = Int(((coordVals![0] - origin[0])/dx - 0/5).rounded())
                    let dx1 = coordVals![0] - origin[0] - dx*Double(cx1)
                    let cy1 = Int(((coordVals![1] - origin[1])/dx - 0.5).rounded())
                    let dy1 = coordVals![1] - origin[1] - dx*Double(cy1)
                    let cz1 = Int(((coordVals![2] - origin[2])/dx - 0.5).rounded())
                    let dz1 = coordVals![2] - origin[2] - dx*Double(cz1)
                    
                    let v1 = (self.getMatValueWithIndexes(coord:[cx1,cy1,cz1]) as! Double)*(dx-dx1)*(dx-dy1)*(dx-dz1)
                    let v2 = (self.getMatValueWithIndexes(coord:[cx1,cy1,cz1+1]) as! Double)*(dx-dx1)*(dx-dy1)*dz1
                    let v3 = (self.getMatValueWithIndexes(coord:[cx1,cy1+1,cz1]) as! Double)*(dx-dx1)*dy1*(dx-dz1)
                    let v4 = (self.getMatValueWithIndexes(coord:[cx1,cy1+1,cz1+1]) as! Double)*(dx-dx1)*dy1*dz1
                    let v5 = (self.getMatValueWithIndexes(coord:[cx1+1,cy1,cz1]) as! Double)*dx1*(dx-dy1)*(dx-dz1)
                    let v6 = (self.getMatValueWithIndexes(coord:[cx1+1,cy1,cz1+1]) as! Double)*dx1*(dx-dy1)*dz1
                    let v7 = (self.getMatValueWithIndexes(coord:[cx1+1,cy1+1,cz1]) as! Double)*dx1*dy1*(dx-dz1)
                    let v8 = (self.getMatValueWithIndexes(coord:[cx1+1,cy1+1,cz1+1]) as! Double)*dx1*dy1*dz1
                    let v=(v1+v2+v3+v4+v5+v6+v7+v8)/(dx*dx*dx)
                    return PhysValue(unit: self.unit, type: "double", values: [v], dim: [1])
                }
            } else {
                
                if fDim == 1 {
                    let cx1 = Int(((coordVals![0] - origin[0])/dx - 0/5).rounded())
                    let dx1 = coordVals![0] - origin[0] - dx*Double(cx1)
                    let v1 = (self.getVecFieldValWithIndexes(coord:[cx1])!).map({ $0*(dx-dx1) })
                    let v2 = (self.getVecFieldValWithIndexes(coord:[cx1+1])!).map({ $0*dx1 })
                    let v=zip(v1,v2).map({ ($0+$1)/dx })
                    return PhysValue(unit: self.unit, type: "double", values: v,dim: [1])
                } else if fDim == 2 {
                    let cx1 = Int(((coordVals![0] - origin[0])/dx - 0/5).rounded())
                    let dx1 = coordVals![0] - origin[0] - dx*Double(cx1)
                    let cy1 = Int(((coordVals![1] - origin[1])/dx - 0.5).rounded())
                    let dy1 = coordVals![1] - origin[1] - dx*Double(cy1)
                    let v1 = (self.getVecFieldValWithIndexes(coord:[cx1,cy1])!).map({ $0*(dx-dx1)*(dx-dy1) })
                    let v2 = (self.getVecFieldValWithIndexes(coord:[cx1,cy1+1])!).map({ $0*(dx-dx1)*dy1 })
                    let v3 = (self.getVecFieldValWithIndexes(coord:[cx1+1,cy1])!).map({ $0*dx1*(dx-dy1) })
                    let v4 = (self.getVecFieldValWithIndexes(coord:[cx1+1,cy1+1])!).map({ $0*dx1*dy1 })
                    let dx2=dx*dx
                    let v = zip(zip(v1,v2).map({ $0+$1 }),zip(v3,v4).map({ $0+$1 })).map({ ($0+$1)/dx2})
                    return PhysValue(unit: self.unit, type: "double", values: v, dim: [1])
                } else if fDim == 3 {
                    
                    let cx1 = Int(((coordVals![0] - origin[0])/dx - 0/5).rounded())
                    let dx1 = coordVals![0] - origin[0] - dx*Double(cx1)
                    let cy1 = Int(((coordVals![1] - origin[1])/dx - 0.5).rounded())
                    let dy1 = coordVals![1] - origin[1] - dx*Double(cy1)
                    let cz1 = Int(((coordVals![2] - origin[2])/dx - 0.5).rounded())
                    let dz1 = coordVals![2] - origin[2] - dx*Double(cz1)
                    let v1 = (self.getVecFieldValWithIndexes(coord:[cx1,cy1,cz1])!).map({ $0*(dx-dx1)*(dx-dy1)*(dx-dz1) })
                    let v2 = (self.getVecFieldValWithIndexes(coord:[cx1,cy1,cz1+1])!).map({ $0*(dx-dx1)*(dx-dy1)*dz1 })
                    let v3 = (self.getVecFieldValWithIndexes(coord:[cx1,cy1+1,cz1])!).map({ $0*(dx-dx1)*dy1*(dx-dz1) })
                    let v4 = (self.getVecFieldValWithIndexes(coord:[cx1,cy1+1,cz1+1])!).map({ $0*(dx-dx1)*dy1*dz1 })
                    let v5 = (self.getVecFieldValWithIndexes(coord:[cx1+1,cy1,cz1])!).map({ $0*dx1*(dx-dy1)*(dx-dz1) })
                    let v6 = (self.getVecFieldValWithIndexes(coord:[cx1+1,cy1,cz1+1])!).map({ $0*dx1*(dx-dy1)*dz1 })
                    let v7 = (self.getVecFieldValWithIndexes(coord:[cx1+1,cy1+1,cz1])!).map({ $0*dx1*dy1*(dx-dz1) })
                    let v8 = (self.getVecFieldValWithIndexes(coord:[cx1+1,cy1+1,cz1+1])!).map({ $0*dx1*dy1*dz1 })
                    let va=zip(zip(v1,v2).map({ $0+$1 }),zip(v3,v4).map({ $0+$1 })).map({ $0+$1 })
                    let vb=zip(zip(v5,v6).map({ $0+$1 }),zip(v7,v8).map({ $0+$1 })).map({ $0+$1 })
                    let dx3=dx*dx*dx
                    let v = zip(va,vb).map({ ($0+$1)/dx3 })
                    return PhysValue(unit: self.unit, type: "double", values: v, dim: [1])
                }
            }
            return nil
        }
    }
    
    // incrémente l'élément de coord=(x,y,z) supposé entier et sans contrôle !
    func incrementValWithCoord(coord:[Int]) {
        let n = indexFromCoords(coord: coord)
        values[n!] = 1 + (values[n!] as! Int)
    }

    // retourne une physval contenant les i-èmes coordonnées d'un champ vectoriel (i=0 => x, i=1 => y, etc...) => champ scalaire
    func getComponentOfVecField(i: Int) -> PhysValue? {
        if field == nil { return nil }
        if !isVec { return self.dup() }
        let values0 = asDoubles
        if values0 == nil { return nil }
        let dims0 : [Int] = Array(dim.dropLast())
        let n0 = dims0.reduce(1, *)
        let values1 : [Double] = Array(values0![n0 * i ..< n0 * i + n0])
        let r = PhysValue(unit: unit, type: "double", values: values1, dim: dims0, field: field)
        r.setVec(false)
        return r
    }

    // retourne le numéro de l'élément d'indices c dans une n-matrice
    func indexFromCoords(coord : [Int]) -> Int? {
        if self.dim.count != coord.count { return nil }
        let testDims : [Bool] = coord.enumerated().map {
            if $1 < 0 { return false }
            if $1 >= dim[$0] { return false }
            return true
        }
        if testDims.contains(false) { return nil }
        let dimProds = getDimProds(dim: dim)
        let n = (0..<dim.count).reduce(0) {$0 + dimProds[$1] * coord[$1]}
        if n < 0 || n >= values.count { return nil }
        return n
    }
    
    
    /// dédouble un champ  en extrapolant les valeurs (ne vérifie pas si self est bien un champ !!)
    func doubleField() -> PhysValue {
        let dims0 = isVec ? dim.dropLast() : dim // les dimensions du champ initial (scalaire)
        let nDims = isVec ? dim.count - 1 : dim.count
        let dims1 = dims0.map{ $0 * 2 }
        let rDim = isVec ? dims1 + [nDims] : dims1
              
        var newValues : [Double] = []

        if isVec {
            let nVecDims = dim.last!
            for nv in 0..<nVecDims {
                let scalField = self.getComponentOfVecField(i: nv)
                let doubScalField = scalField!.doubleField()
                newValues.append(contentsOf: doubScalField.asDoubles!)
            }
            
        } else {
            let values0 = asDoubles!
            let coords0 = getAllCoordsIndexes(dim: dims0)
            let n0 = dims0.reduce(1, *)
            let n1 = dims1.reduce(1, *)
            newValues = Array(repeating: 0, count: n1)
            let dimProds1 = getDimProds(dim: dims1)
            
            let G = self.gradiant()
            let Gvals = G.asDoubles!
            let dx = field!["dx"]!.asDouble!/4

            coords0.enumerated().forEach({ i0, c0 in
                var newCoords : [[Int]] = [c0.map({ $0 * 2 })]
                (0..<nDims).forEach({ d in
                    let newCoords2 = newCoords
                    var new = newCoords[0]
                    newCoords2.forEach({ old in
                        new = old
                        new[d] = old[d] + 1
                        newCoords.append(new)
                    })
                })
                newCoords.forEach({ c1 in
                    let i1 = (0..<nDims).reduce(0) {$0 + dimProds1[$1] * c1[$1]}
                    newValues[i1] = values0[i0]
                    (0..<nDims).forEach({ d in
                        newValues[i1] = newValues[i1] + ( c1[d] > 2*c0[d] ? Gvals[i0 + d * n0]*dx : -Gvals[i0 + d * n0]*dx)
                    })
                })
            })
        }
        let result = PhysValue(unit: unit, type: "double", values: newValues, dim: rDim, field: self.field)
        let dx1 = field!["dx"]!.dup()
        dx1.values = [(dx1.asDouble!)/2]
        result.setFieldValue(key: "dx", phv: dx1)
        result.setFieldValue(key: "origin", phv: self.fieldOrigin!)

        return result
    }
    
    // réduit un champ en ne conservant qu'une valeur sur deux dans chaque dim
    func reduceField() -> PhysValue {
        let dims0 = isVec ? dim.dropLast() : dim // les dimensions du champ initial
        let nDims = isVec ? dim.count - 1 : dim.count
        let dims1 = dims0.map{ ($0 + 1) / 2 }
        let resultDims = isVec ? dims1 + [nDims] : dims1
        let nVecDims = isVec ? nDims : 1
        var resultVals : [Double] = []
        
        for vecDim in (0..<nVecDims) {
            let component = getComponentOfVecField(i: vecDim)
            let vals = component!.asDoubles!
            let coords = getAllCoordsIndexes(dim: component!.dim)
            let newVals : [Double] = vals.enumerated().compactMap({ i,v in
                let c = coords[i]
                if c.allSatisfy({ $0 % 2 == 0 }) { return v } // si toutes les coordonnées sont paires, on garde la valeur
                else { return nil }
            })
            resultVals.append(contentsOf: newVals)
        }
        //result.values = newVals
        let result = PhysValue(unit: unit, type: type, values: resultVals, dim: resultDims, field: field)
        let dx1 = field!["dx"]!
        dx1.values = [(dx1.asDouble!) * 2]
        result.setFieldValue(key: "dx", phv: dx1)
        result.setFieldValue(key: "origin", phv: self.fieldOrigin!)
        return result
    }
    
    // adoucit un champ
    func smoothField(keep: Bool) -> PhysValue {
        let dims = isVec ? dim.dropLast() : dim // les dimensions du champ initial (scalaire)
        let n = self.values.count
        let nDims = isVec ? dim.count - 1 : dim.count
        var resultVals : [Double] = []
        if isVec {
            let nVecDims = dim.last!
            for nv in 0..<nVecDims {
                let scalField = self.getComponentOfVecField(i: nv)
                let doubScalField = scalField!.smoothField(keep: keep)
                resultVals.append(contentsOf: doubScalField.asDoubles!)
            }
        } else {
            let coords = getAllCoordsIndexes(dim: dims)
            let values = asDoubles!
              let fac = 1/pow(3.0,Double(nDims))
            resultVals = Array(repeating: 0, count: n)
            for (i0,c0) in coords.enumerated() {
                let v0 = values[i0]
                var cneighb : [[Int]] = [c0]
                var cnewneighb : [[Int]] = [c0]
                
                (0..<nDims).forEach({ d in
                    cnewneighb = cneighb
                    cneighb.forEach({ c in
                        var cante = c
                        cante[d] = c[d] == 0 ? c[d] : c[d] - 1
                        var cpost = c
                        cpost[d] = c[d] == dims[d] - 1 ? c[d] : c[d] + 1
                        cnewneighb.append(cpost)
                        cnewneighb.append(cante)
                    })
                    cneighb = cnewneighb
                    
                })
                
                let dv = cneighb.reduce(0.0, { r , c in r + (self.getMatValueWithIndexes(coord: c) as! Double) } )
                resultVals[i0] = v0 * (1 - fac) + fac * dv
            }
            if keep {
                let min = values.min()!
                let max = values.max()!
                let nmin = resultVals.min()!
                let nmax = resultVals.max()!
                let d0 = max-min
                let d1 = nmax-nmin
                let f = d0/d1
                resultVals = resultVals.map({ ($0 - nmin)*f + min})
            }
        }
        let result = self.dup()
        result.values = resultVals
        //if isVec {result.setVec(true) }
        return result
    }
    
    // self est supposé être un champ scalaire. Retourne le gradiant de ce champ
    // si coord est omis, retourne le champ complet, sinon le gradiant au point donné
    func gradiant(coord: [Int]? = nil) -> PhysValue {
        let xVals = self.asDoubles!
        let dims = self.dim
        let nDims = dims.count // nombre de dimensions (1, 2 ,3...)
        // coordonnées du ou des points à calculer
        let coords = coord != nil ? [coord!] : getAllCoordsIndexes(dim: dims)
        let n = dims.reduce(1, *) // nombre d'éléments'
        var resultVals : [Double] = Array(repeating: 0, count: n * nDims)
        let vDims = dims + [nDims] // puisque ce sont des vecteurs de dimension nDims
        
        coords.enumerated().forEach( {i, c in
            // on parcourt toutes les dimensions
            (0..<nDims).forEach({ d in
                var cNext = c
                var cPrev = c
                cNext[d] = cNext[d] + 1
                cPrev[d] = cPrev[d] - 1
                let iSelf = EureKalc.indexFromCoords(dim: dims, coord: c)
                if cNext[d] < dims[d] && cPrev[d] > -1  {
                    let iNext = EureKalc.indexFromCoords(dim: dims, coord: cNext)
                    let iPrev = EureKalc.indexFromCoords(dim: dims, coord: cPrev)
                    resultVals[i + n*d] = (xVals[iNext] - xVals[iPrev])/2
                } else if cNext[d] < dims[d] {
                    let iNext = EureKalc.indexFromCoords(dim: dims, coord: cNext)
                    resultVals[i + n*d] = xVals[iNext] - xVals[iSelf]
                } else if cPrev[d] > -1 {
                    let iPrev = EureKalc.indexFromCoords(dim: dims, coord: cPrev)
                    resultVals[i + n*d] = xVals[iSelf] - xVals[iPrev]
                }
            })
        })
        
        var result = PhysValue(unit: self.unit, type: self.type, values: resultVals, dim: vDims, field: self.field)
        result.setVec(true) // un champ vectoriel
        result = result.binaryOp(op: "/", v2: self.field!["dx"]!)
        return result
    }

    // Retourne une Physval comportant l'unique élément numéro n
    func physValn(n: Int) -> PhysValue {
        if n < 0 || n > self.values.count - 1 { return PhysValue( error: "wrong index")}
        if self.type == "list" { return (self.values[n] as! PhysValue).dup() }
        return PhysValue(unit: self.unit, type: self.type, values: [self.values[n]], dim: [1])
    }
    
    func last() -> PhysValue {
        let n = self.values.count
        return physValn(n: n)
    }
    
    func first() -> PhysValue {
        return physValn(n: 0)
    }
    
    // retourne une Physval contenant les éléments correspondant à indexes
    func subPhysVal(indexes: [Int], newDim : [Int]? = nil ) -> PhysValue {
        if indexes.count == 0 { return PhysValue() }
        if indexes.min()! < 0 || indexes.max()! > values.count-1 { return PhysValue(error: "wrong index") }
        let vals = indexes.map{ values[$0] }
        return PhysValue(unit: unit, type: type, values: vals, dim: newDim ?? [indexes.count], field: field)
    }
    
    // remplace les valeurs d'indices indexes par celles fournies (en recyclant si nécessaire)
    func replaceValues(indexes: [Int], newVals: [Any]) -> PhysValue {
        let result = self.dup()
        var k : Int = 0
        for index in indexes {
            if k >= newVals.count { k = 0 }
            result.values[index] = newVals[k]
            k = k + 1
        }
        return result
    }
    

    // ******************************************
      
    func stringExp(units: Bool, prec: Int = 5) -> String {
        // retourne une représentation de la valeur sous forme de chaîne
        var result = ""
        if values.count > 1 { result += "(" }
        var first = true
        let baseUnit = unit.baseUnit()
        let count = values.count
        var n = 1
        let max = Int(maxValuesInResultString/2)
        var dots = false
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 1
        formatter.maximumSignificantDigits = prec
        formatter.decimalSeparator = decimalSep
        formatter.hasThousandSeparators = false
        
        for baseValue in values {
            if (count < maxValuesInResultString) || n < max || n > count - max  {
                if first == false { result += " " + listSep + " " }
                first = false
                if type == "double" {
                    let dbVal = EureKalc.asDouble(baseValue) ?? Double.nan
                    if dbVal == Double.infinity { result = "∞" }
                    else if (dbVal) == -Double.infinity { result = "-∞"}
                    else {
                        let value = NSNumber(value: unitConversion(value: dbVal, oldUnit: baseUnit, newUnit: unit))
                        if (abs(Double(truncating: value)) > 100000 || (abs(Double(truncating: value)) < 0.00001 && dbVal != 0.0)) {
                            formatter.numberStyle = NumberFormatter.Style.scientific
                            formatter.exponentSymbol = "e"
                        } else {
                            formatter.numberStyle = NumberFormatter.Style.decimal
                        }
                        result +=  formatter.string(from: value)! //String(format: "%.\(prec)g", value)
                    }
                } else if type == "int" {
                    let value = unitConversion(value: EureKalc.asDouble(baseValue)!, oldUnit: baseUnit, newUnit: unit)
        
                    result += String(value)
                } else if type == "bool" {
                    if (baseValue as! Bool) == true {
                        result += "TRUE"
                    }
                    else {
                        result += "FALSE"
                    }
                }
                else if  type == "string" || type == "error" || type == "label" {
                    result += baseValue as! String
                } else if type == "list" {
                    result += (baseValue as! PhysValue).stringExp(units: units)
                } else if type == "dataframe" {
                    return "[dataframe]"
                } else if type == "exp" {
                    result += (baseValue as! HierarchicExp).stringExp()
                } else {
                    return "unknown error in expression !"
                }
            }
            else if dots == false {
                result += " ... "
                dots = true
            }
            n = n + 1
        }

        if values.count > 1 { result += ")" }
        if units == true && unit.powers.count > 0 && unit.name != "" {
            result += "["
            result += unit.name
            result += "]"
        }
        return result
    }
    
   
    
    // vérifie si deux physvals sont identiques
    func isIdentical(_ val : PhysValue) -> Bool {
        if !unit.isIdentical(unit: val.unit) { return false }
        if type != val.type { return false }
        if dim != val.dim { return false }
        if values.count != val.values.count { return false}
        for n in 0 ... values.count-1 {
            switch type {
            case "double", "int" : if self.asDoubles![n] != val.asDoubles![n] { return false }
            case "bool" : if values[n] as! Bool != val.values[n] as! Bool { return false }
            case "string" :  if values[n] as! String != val.values[n] as! String { return false }
            case "exp" : if values[n] as! HierarchicExp != val.values[n] as! HierarchicExp { return false }
            default : return false
            }
        }
        return true
    }
    
    
    // opérations mathématiques courantes (ajouter au fur et à mesure des besoins...)
    func plus(_ x : PhysValue) -> PhysValue {
        return self.binaryOp(op: "+", v2: x)
    }
    
    func minus(_ x : PhysValue) -> PhysValue {
        return self.binaryOp(op: "+", v2: x.numericFunction(op: "_minus"))
    }
    
    func mult(_ x : PhysValue) -> PhysValue {
        return self.binaryOp(op: "*", v2: x)
    }
    
    func div(_ x : PhysValue) -> PhysValue {
        return self.binaryOp(op: "/", v2: x)
    }
    
    func int() -> PhysValue {
        return self.numericFunction(op: "int")
    }
    
    func round() -> PhysValue {
        return self.numericFunction(op: "round")
    }
    
    func Log() -> PhysValue {
        return self.trigoFunction(op: "Log")
    }
    
    // exécution d'une opération binaire avec une autre physval
    func binaryOp(op: String, v2: PhysValue) -> PhysValue {
        let n1 = self.values.count
        let n2 = v2.values.count
        if n1 != n2 && n1 != 1 && n2 != 1 { return PhysValue(error:"incompatible dimensions") }
        let resDim = n1 == 1 ? v2.dim : self.dim
        let resField = n1 == 1 ? v2.field : self.field
        var vals1 = self.values
        var vals2 = v2.values
        var resultValues : [Any] = []
        var theType = ""
        var theUnit = Unit()
        
        if self.isNumber && v2.isNumber {
            // opérations binaires sur des doubles ou des entiers
            theType = "double"
            vals1 = self.asDoubles!
            vals2 = v2.asDoubles!
            
            switch op {
            case "+" :
                if n2 == 1 {resultValues = vDSP.add( vals2[0] as! Double, vals1 as! [Double]) }
                else if n1 == 1 { resultValues = vDSP.add( vals1[0] as! Double, vals2 as! [Double])  }
                else {resultValues = vDSP.add( vals1 as! [Double], vals2 as! [Double])  }
                theUnit = self.unit
            case "*" :
                if n2 == 1 {resultValues = vDSP.multiply( vals2[0] as! Double, vals1 as! [Double]) }
                else if n1 == 1 { resultValues = vDSP.multiply( vals1[0] as! Double, vals2 as! [Double])  }
                else {resultValues = vDSP.multiply( vals1 as! [Double], vals2 as! [Double])  }
                let thePowers = multiplyUnitPowers(powers1: self.unit.powers, exp1: 1, powers2: v2.unit.powers, exp2: 1)
                theUnit.powers = thePowers
                theUnit = theUnit.baseUnit()
            case "/" :
                if n2 == 1 {resultValues = vDSP.divide( vals1 as! [Double], vals2[0] as! Double) }
                else if n1 == 1 { resultValues = vDSP.divide( vals1[0] as! Double, vals2 as! [Double])  }
                else {resultValues = vDSP.divide( vals1 as! [Double], vals2 as! [Double])  }
                let thePowers = multiplyUnitPowers(powers1: self.unit.powers, exp1: 1, powers2: v2.unit.powers, exp2: -1)
                theUnit.powers = thePowers
                theUnit = theUnit.baseUnit()
            case "%" :
                if n2 == 1 {
                    let d = v2.asInteger!
                    resultValues = self.asIntegers!.map { Double($0 % d) }
                }
                else if n1 == 1 {
                    let d = self.asInteger!
                    resultValues = v2.asIntegers!.map {Double(d % $0)}
                }
                else {resultValues = zip(self.asIntegers!, v2.asIntegers!).map {Double($0.0 % $0.1)} }
                let thePowers = multiplyUnitPowers(powers1: self.unit.powers, exp1: 1, powers2: v2.unit.powers, exp2: -1)
                theUnit.powers = thePowers
                theUnit = theUnit.baseUnit()
                theType = "int"
            case "^" :
                if n2 == 1 { resultValues = vals1.map {pow(($0 as! Double) , (vals2[0] as! Double))} }
                else if n1 == 1 { resultValues = vals2.map {pow((vals1[0] as! Double) , ($0 as! Double))} }
                else {resultValues = vForce.pow(bases: vals1 as! [Double] , exponents:vals2 as! [Double]) }
                let thePowers = multiplyUnitPowers(powers1: self.unit.powers, exp1: Int(vals2[0] as! Double), powers2: nullUnitPowers, exp2: 1)
                theUnit.powers = thePowers
                theUnit = theUnit.baseUnit()
            case "==" :
                if n2 == 1 { resultValues = vals1.map {($0 as! Double) == (vals2[0] as! Double)} }
                else if n1 == 1 { resultValues = vals1.map { (vals1[0] as! Double) == ($0 as! Double)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Double) == ($0.1 as! Double)} }
                theUnit = Unit()
                theType = "bool"
            case "≤" :
                if n2 == 1 { resultValues = vals1.map {($0 as! Double) <= (vals2[0] as! Double)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! Double) <= ($0 as! Double)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Double) <= ($0.1 as! Double)} }
                theUnit = Unit()
                theType = "bool"
            case "≥" :
                if n2 == 1 { resultValues = vals1.map {($0 as! Double) >= (vals2[0] as! Double)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! Double) >= ($0 as! Double)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Double) >= ($0.1 as! Double)} }
                theUnit = Unit()
                theType = "bool"
            case "<" :
                if n2 == 1 { resultValues = vals1.map {($0 as! Double) < (vals2[0] as! Double)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! Double) < ($0 as! Double)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Double) < ($0.1 as! Double)} }
                theUnit = Unit()
                theType = "bool"
            case ">" :
                if n2 == 1 { resultValues = vals1.map {($0 as! Double) > (vals2[0] as! Double)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! Double) > ($0 as! Double)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Double) > ($0.1 as! Double)} }
                theUnit = Unit()
                theType = "bool"
            case "≠" :
                if n2 == 1 { resultValues = vals1.map {($0 as! Double) != (vals2[0] as! Double)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! Double) != ($0 as! Double)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Double) != ($0.1 as! Double)} }
                theUnit = Unit()
                theType = "bool"
            case "•" :
                if n2 != n1 { return errVal("vectors of scalar product have different dimensions")}
                resultValues = [vDSP.sum(vDSP.multiply(vals1 as! [Double], vals2 as! [Double]))]
                let thePowers = multiplyUnitPowers(powers1: self.unit.powers, exp1: 1, powers2: v2.unit.powers, exp2: 1)
                theUnit.powers = thePowers
                theUnit = theUnit.baseUnit()
            case "**" :
                if n1 != 3 || n2 != 3 { return errVal("Vector product operates only on 3D vectors")}
                let r0 = (vals1[1] as! Double) * (vals2[2] as! Double) - (vals1[2] as! Double) * (vals2[1] as! Double)
                let r1 = (vals1[2]  as! Double) * (vals2[0] as! Double) - (vals1[0] as! Double) * (vals2[2] as! Double)
                let r2 = (vals1[0] as! Double) * (vals2[1] as! Double) - (vals1[1] as! Double) * (vals2[0] as! Double)
                resultValues = [r0,r1,r2]
                let thePowers = multiplyUnitPowers(powers1: self.unit.powers, exp1: 1, powers2: v2.unit.powers, exp2: 1)
                theUnit.powers = thePowers
                theUnit = theUnit.baseUnit()
            default :
                return PhysValue(error: "unknown binary operator")
            }
            if theType == "int" { resultValues = resultValues.map{Int($0 as! Double)} }
            
            
        } else if type == "string" || v2.type == "string" {
            if type == "int" { vals1 = vals1.map({String($0 as! Int)})}
            if type == "double" { vals1 = vals1.map({ String(Int($0 as! Double)) })}
            if type == "bool" { vals1 = vals1.map({String($0 as! Bool ? "TRUE" : "FALSE")})}
            if v2.type == "int" { vals2 = vals2.map({String($0 as! Int)})}
            if v2.type == "double" { vals2 = vals2.map({String(Int($0 as! Double)) })}
            if v2.type == "bool" { vals2 = vals2.map({String($0 as! Bool ? "TRUE" : "FALSE")})}
       
            // opérations binaires sur des chaines de caractères
            switch op {
            case "+" :
                if n2 == 1 { resultValues  = vals1.map {($0 as! String) +  (vals2[0] as! String)} }
                else if n1 == 1 { resultValues = vals2.map {(vals1[0] as! String) + ($0 as! String)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! String) + ($0.1 as! String)} }
                theType = "string"
            case "==" :
                if n2 == 1 { resultValues = vals1.map {($0 as! String) == (vals2[0] as! String)} }
                else if n1 == 1 { resultValues = vals1.map { (vals1[0] as! String) == ($0 as! String)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! String) == ($0.1 as! String)} }
                theType = "bool"
            case "≤" :
                if n2 == 1 { resultValues = vals1.map {($0 as! String) <= (vals2[0] as! String)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! String) <= ($0 as! String)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! String) <= ($0.1 as! String)} }
                theType = "bool"
            case "≥" :
                if n2 == 1 { resultValues = vals1.map {($0 as! String) >= (vals2[0] as! String)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! String) >= ($0 as! String)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! String) >= ($0.1 as! String)} }
                theType = "bool"
            case "<" :
                if n2 == 1 { resultValues = vals1.map {($0 as! String) < (vals2[0] as! String)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! String) < ($0 as! String)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! String) < ($0.1 as! String)} }
                theType = "bool"
            case ">" :
                if n2 == 1 { resultValues = vals1.map {($0 as! String) > (vals2[0] as! String)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! String) > ($0 as! String)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! String) > ($0.1 as! String)} }
                theType = "bool"
            case "≠" :
                if n2 == 1 { resultValues = vals1.map {($0 as! String) != (vals2[0] as! String)} }
                else if n1 == 1 { resultValues = vals1.map {(vals1[0] as! String) != ($0 as! String)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! String) != ($0.1 as! String)} }
                theType = "bool"
            default :
                return PhysValue(error: op + " is not a string operator")
            }
            
        } else  if type == "bool" && v2.type == "bool" {
            switch op {
            case "OR", "+" :
                if n2 == 1 { resultValues  = vals1.map {($0 as! Bool) ||  (vals2[0] as! Bool)} }
                else if n1 == 1 { resultValues = vals2.map {(vals1[0] as! Bool) || ($0 as! Bool)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Bool) || ($0.1 as! Bool)} }
                
            case "==" :
                if n2 == 1 { resultValues  = vals1.map {($0 as! Bool) == (vals2[0] as! Bool)} }
                else if n1 == 1 { resultValues = vals2.map {(vals1[0] as! Bool) == ($0 as! Bool)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Bool) == ($0.1 as! Bool)} }
                
            case "AND", "*" :
                if n2 == 1 { resultValues  = vals1.map {($0 as! Bool) &&  (vals2[0] as! Bool)} }
                else if n1 == 1 { resultValues = vals2.map {(vals1[0] as! Bool) && ($0 as! Bool)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Bool) && ($0.1 as! Bool)} }
                
            case "!=" :
                if n2 == 1 { resultValues  = vals1.map {($0 as! Bool) !=  (vals2[0] as! Bool)} }
                else if n1 == 1 { resultValues = vals2.map {(vals1[0] as! Bool) != ($0 as! Bool)} }
                else {resultValues = zip(vals1, vals2).map {($0.0 as! Bool) != ($0.1 as! Bool)} }
                
            default :
                return PhysValue(error: "unknown bool operator")
            }
            theType = "bool"
        }
        
        return PhysValue(unit: theUnit, type: theType, values : resultValues, dim: resDim, field: resField)

    }
    
    func numericFunction(op: String) -> PhysValue {
        // numeric functions with one argument
        if type == "" { return PhysValue() }
        if op == "_minus" && type == "bool" { return PhysValue(boolVal: !(self.asBool!)) }
        if !self.isNumber {return PhysValue(error:"value is not a number ") }
        switch op {
            case "_minus" :
                let doubleValues = self.asDoubles!.map { -($0) }
                return PhysValue(unit: unit, type: "double", values: doubleValues, dim: dim, field:field)
            case "sqrt" :
                let doubleValues = vForce.sqrt(self.asDoubles!)
                return PhysValue(unit: unit.sqrt(), type: "double", values: doubleValues, dim: dim, field: field)
            case "abs" :
                let doubleValues = self.asDoubles!.map { abs($0) }
                return PhysValue(unit: unit, type: "double", values: doubleValues, dim: dim, field:field)
            case "int" :
                let intValues = self.asDoubles!.map { Int($0) }
                return PhysValue(unit: unit, type: "int", values: intValues, dim: dim, field: field)
            case "round" :
                let intValues = self.asDoubles!.map { Int(0.5 + $0) }
                return PhysValue(unit: unit, type: "int", values: intValues, dim: dim, field: self.field)
            case "ceiling" :
                let intValues = self.asDoubles!.map { Int($0 + 0.999999999999999999999999999) }
                return PhysValue(unit: unit, type: "int", values: intValues, dim: dim, field: field)
            case "bool" :
                let boolValues = self.asDoubles!.map { $0 > 0 }
                return PhysValue(unit: Unit(), type: "bool", values: boolValues, dim: dim, field:field)
            default :
                return PhysValue(unit: unit, type: "double", values: values, field: field)
        }
    }
    
    func trigoFunction(op: String) -> PhysValue {
        // trigonometric functions and other functions without unit
        if unit.isEmptyUnit() == false { return PhysValue(error:op + " function applies only on numbers without physical dimension") }
        if type != "double" {return PhysValue(error:"value is not of type 'double' ") }
        let x = values as! [Double]
        var resultValues : [Double]
        switch op {
        case "sin" : resultValues = vForce.sin(x)
        case "cos" : resultValues = vForce.cos(x)
        case "tan" : resultValues = vForce.tan(x)
        case "cot" : resultValues = vForce.reciprocal(vForce.tan(x))
        case "sinh" : resultValues = vForce.sinh(x)
        case "cosh" : resultValues = vForce.cosh(x)
        case "tanh" : resultValues = vForce.tanh(x)
        case "coth" : resultValues = vForce.reciprocal(vForce.tanh(x))
        case "exp" : resultValues = vForce.exp(x)
        case "ln" : resultValues = vForce.log(x)
        case "Log" : resultValues = vForce.log10(x)
        case "atan" : resultValues = vForce.atan(x)
        case "asin" : resultValues = vForce.asin(x)
        case "acos" : resultValues = vForce.acos(x)
        case "acot" : resultValues = vForce.atan(vForce.reciprocal(x))
        default : resultValues = vForce.reciprocal(x)
        }
        return PhysValue(unit: Unit(), type: "double", values: resultValues, dim: self.dim, field: field)
        
    }
    
    // Exécution d'une physval de type "exp"
    func execute() -> PhysValue {
        var result = PhysValue()
        if self.type != "exp" { return result }
        for anExp in values as! [HierarchicExp] {
            result = anExp.calcIfNamed()
            if result.type == "error" { return result }
        }
        return result
    }
        
}

func valuesInBaseUnit(values : NSArray, unit: Unit) -> NSArray {
    // convertit les valeurs d'une grandeur physique en unités SI de base
    var newValues = Array<Double>()
    let mult = unit.mult
    let offset = unit.offset
    for val : Any in values {
        let newVal = (val as! Double)*mult + offset
        newValues.append(newVal)
    }
    return newValues as NSArray
}


