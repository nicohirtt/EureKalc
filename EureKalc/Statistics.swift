//
//  statistics.swift
//
//
//  Created by Nico on 13/07/14.
//  Copyright (c) 2014 Nico Hirtt. All rights reserved.
//

import Foundation
import Accelerate



func statsNormalDis(min:Double, max: Double, mean:Double, sd: Double, n:Int) -> Array<Double> {
    // retourne une liste (array) de valeurs selon une distribution normale centrée en "mean"
    // seules des valeurs comprises entre min et max son retournées
    // si min >= max alors il n'y a pas de limite à la distribution
    var resultat = [Double]() // ceci sera le résultat en ordre aléatoire
    var x = 0.0
    var r1 = 0.0
    var r2 = 0.0
    for _ in 1...n {
        r1 = drand48()
        r2 = drand48()
        x = mean + sd*sqrt(-2*log(r1))*sin(2 * pi * r2)
        while (max > min) && (x < min || x > max) {
            r1 = drand48()
            r2 = drand48()
            x = mean + sd*sqrt(-2*log(r1))*sin(2 * pi * r2)
        }
        resultat.append(x)
    }
    return resultat
}

func statsUniformDis(min: Double, max: Double, n:Int) -> [Double] {
    let d = max - min
    return Array(repeating: 1.0, count: n).map { $0 * drand48() * d + min}
}


func statsUniformClasses(min: Double, max: Double, nc:Int) -> [Double] {
    let size =  (max-min)/Double(nc)
    var classes : [Double] = [min]
    for i in (1...nc) {
        classes.append(min + Double(i) * size)
    }
    return classes
}

func statsMiddleOfClasses(_ classes: [Double]) -> [Double] {
    var middles : [Double] = []
    for i in 0...classes.count-2 {
        middles.append((classes[i+1]+classes[i])/2)
    }
    return middles
}
    
func statsMeansByClasses(liste: [Double], classes: [Double]) -> Array<Double> {
    var means : [Double] = []
    for i in 0...classes.count-2 {
        let elements = statsElementsOfClass(liste: liste, classes: classes, classNumber: i)
        means.append(statsMean(elements))
    }
    return means
}

func statsByClasses(liste: [Double], classes: [Double], calc: String = "freq", w: [Double]? = nil) -> [Double] {
    let nc = classes.count - 1 // nombre de classe
    let N = liste.count // nombre total d'éléments
    let sortedList = liste.sorted()
    var resultat : [Double] = []
    let sumw = (w ==  nil) ? Double(N) : vDSP.sum(w!)
    for i in 1...nc {
        let limInf = sortedList.firstIndex(where: {$0 >= classes[i-1]}) ?? 0
        let limSup = (i==nc) ?
            sortedList.lastIndex(where: {$0 <= classes[i]}) ?? N-1 :
            sortedList.lastIndex(where: {$0 < classes[i]}) ?? N-1

        let n = Double(limSup-limInf+1)
        if limSup < limInf {
            if calc == "freq" || calc == "rfreq" || calc == "dens" {
                resultat.append(0)
            } else {
                resultat.append(Double.nan)
            }
        } else if calc == "freq" {
            let f = (w == nil) ? n : vDSP.sum(w![limInf ... limSup])
            resultat.append(f)
        } else if calc == "rfreq" {
            let f = (w == nil) ? n/Double(N) : vDSP.sum(w![limInf ... limSup])/sumw
            resultat.append(f)
        } else if calc == "dens" {
            resultat.append(Double(limSup-limInf)/Double(N)/(classes[i]-classes[i-1]))
        } else if calc == "sum" {
            let sum = (w == nil) ?
                vDSP.sum(sortedList[limInf ... limSup]) :
                vDSP.sum(vDSP.multiply(sortedList[limInf ... limSup], w![limInf ... limSup]))
            resultat.append(sum)
        } else if calc == "median" {
            if w == nil {
                let middle = limInf + (limSup - limInf).quotientAndRemainder(dividingBy: 2).quotient
                resultat.append(sortedList[middle])
            } else {
                let median = statsMedian(Array(sortedList[limInf ... limSup]),w: Array(w![limInf ... limSup]))
                resultat.append(median)
            }
        } else if calc == "mean" {
            let mean = (w == nil) ?
            vDSP.sum(sortedList[limInf ... limSup]) / Double(sortedList[limInf ... limSup].count) :
            vDSP.sum(vDSP.multiply(sortedList[limInf ... limSup], w![limInf ... limSup]))/vDSP.sum(w![limInf ... limSup])
            resultat.append(mean)
        } else if calc == "var" || calc == "std" {
            let theSlice = Array(sortedList[limInf ... limSup])
            let ecarts = (w == nil) ?
            vDSP.add(statsMean(theSlice,w:nil),theSlice) :
            vDSP.add(statsMean(theSlice,w: Array(w![limInf ... limSup])),theSlice)
            let ecartsquad = vDSP.multiply(ecarts,ecarts)
            let variance = (w == nil) ?
            vDSP.sum(ecartsquad) / n :
            vDSP.sum(vDSP.multiply(ecartsquad, w![limInf ... limSup]))/vDSP.sum(w![limInf ... limSup])
            if calc == "var" { resultat.append(variance ) }
            else { resultat.append( sqrt(variance) )} // écart type
        }
    }
    return resultat
}

func statsGetDiscreteClasses(theType: String, liste: [Any]) -> [Any] {
    if theType == "string" {
        let sortedvals = (liste as! [String]).sorted()
        let v : [String] = sortedvals.enumerated().compactMap({
            if $0 == 0 { return $1 }
            else if $1 != sortedvals[$0-1] { return $1 }
            else { return nil }
        })
        return v
    } else if theType == "double"  {
        let sortedvals = (liste as! [Double]).sorted()
        let v : [Double] = sortedvals.enumerated().compactMap({
            if $0 == 0 { return $1 }
            else if $1 != sortedvals[$0-1] { return $1 }
            else { return nil }
        })
        return v
    } else if theType == "int"  {
        let sortedvals = (liste as! [Int]).sorted()
        let v : [Int] = sortedvals.enumerated().compactMap({
            if $0 == 0 { return $1 }
            else if $1 != sortedvals[$0-1] { return $1 }
            else { return nil }
        })
        return v
    } else if theType == "bool"  {
        return [true,false]
    }
    return []
}

func statsByDiscreteClasses(theType: String, liste: [Any], classes: [Any], calc: String = "freq") -> [Double] {
    let N = liste.count
    var resultat : [Double] = []
    for c in classes {
        var r : Int
        switch theType {
        case "bool" : r = (liste as! [Bool]).filter({$0 == c as! Bool}).count
        case "int" : r = (liste as! [Int]).filter({$0 == c as! Int}).count
        case "string" : r = (liste as! [String]).filter({$0 == c as! String}).count
        default : r = (liste as! [Double]).filter({$0 == c as! Double}).count
        }
        
        if calc == "rfreq" {
            resultat.append(Double(r)/Double(N))
        } else {
            resultat.append(Double(r))
        }
    }
    return resultat
}

func statsIsInClass(value: Double, classes:Array<Double>, classNumber:Int) -> Bool {
    // teste si une valeur est dans la classe classNumber d'une classification donnée
    if (value > classes[classNumber]) && (value <= classes[classNumber+1]) { return true }
    return false
}

func statsIndexesOfClass(liste: Array<Double>, classes: Array<Double>, classNumber: Int) -> Array<Int> {
    // retourne la liste des indexes d'éléments dans une liste
    // qui correspondent à une certaine classe d'un classement
    var resultat = Array<Int>()
    for i in 0...liste.count-1 {
        if statsIsInClass(value: liste[i],classes: classes,classNumber: classNumber)==true {
            resultat.append(i)
        }
    }
    return resultat
}

func statsSubList(liste:Array<Double>, indexes: Array<Int>) -> Array<Double> {
    // retourne une sous-liste d'éléments sur base d'une liste d'indices
    return (0...indexes.count-1).map({ liste[indexes[$0]] })
}

func statsElementsOfClass(liste: Array<Double>, classes: Array<Double>, classNumber: Int) -> Array<Double> {
    // retourne les éléments appartenant à une classe
    let indexes = statsIndexesOfClass(liste: liste, classes: classes, classNumber: classNumber)
    return statsSubList(liste: liste, indexes: indexes)
}

func statsNtiles(_ liste: Array<Double>, n : Int, all : Bool = true, w: [Double]? = nil) -> Array<Double> {
    // Calcule les n-tiles d'une distribution continue
    let N = liste.count
    let sortedList = liste.sorted()
    var resultat : [Double] = []
    if all { resultat.append(sortedList[0]) }
    if w == nil {
        resultat.append(contentsOf: (1..<n).map({ sortedList[N/n*$0-1] }))
    } else {
        let indexes = Array(0..<N).sorted{ liste[$0] < liste[$1] }
        let sortedw = indexes.map({ w![$0] })
        // on commence par construire la séquence des poids cumulés
        var cumw : [Double] = []
        sortedw.enumerated().forEach({ cumw.append($0 == 0 ? $1 : $1 + cumw[$0-1])})
        let qSize = (cumw.last!)/Double(n)
        for i in 1..<n {
            let q = cumw.firstIndex(where: {$0 >= (Double(i) * qSize) } ) ?? n-1
            resultat.append(sortedList[q])
        }
    }
    if all { resultat.append(sortedList.last!) }
    return resultat
}

func statsMean(_ liste : Array<Double>, w: [Double]? = nil) -> Double {
    // Calcule la moyenne d'une liste de valeurs
    if w == nil {
        return vDSP.sum(liste)/Double(liste.count)
    } else {
        return vDSP.sum(vDSP.multiply(liste, w!))/vDSP.sum(w!)
    }
}

func statsMedian(_ liste: [Double], w: [Double]? = nil) -> Double {
    if w == nil {
        let n = liste.count.quotientAndRemainder(dividingBy: 2).quotient
        return liste.sorted()[n]
    } else {
        let s = statsNtiles(liste, n: 2, w: w!)
        return s[1]
    }
}

func statsSum(_ liste: Array<Double>, w: [Double]? = nil) -> Double {
    // Calcule la somme d'une liste de valeurs
    if w == nil {
        return vDSP.sum(liste)
    } else {
        return vDSP.sum(vDSP.multiply(liste, w!))
    }
}

// Calcule le produit des éléments d'une liste
func statsProd(_ liste: [Double]) -> Double {
    return liste.reduce(1,*)
}

func statsProd(_ liste: [Int]) -> Int {
    return liste.reduce(1,*)
}

func statsNorm(_ liste: Array<Double>) -> Double {
    // Calcule la norme d'un vecteur
    return sqrt(vDSP.sumOfSquares(liste))
}

func statsVariance(_ liste: Array<Double>, w: [Double]? = nil) -> Double {
    // Calcule la variance d'une liste de valeurs
    let ecarts = vDSP.add(-statsMean(liste,w: w),liste)
    let ecartsquad = vDSP.multiply(ecarts,ecarts)
    let result = statsMean(ecartsquad,w: w)
    return result
}

func statsCovariance(x: Array<Double>, y: Array<Double>) -> Double {
    // Calcule la covariance de deux listes
    return  vDSP.sum(vDSP.multiply(vDSP.add(-vDSP.mean(x), x), vDSP.add(-vDSP.mean(y), y)))/Double(x.count)
}

func statsRSquare(x: Array<Double>, y: Array<Double>) -> Double {
    // Calcule le coefficient de détermination de deux listes
    let cov = statsCovariance(x: x,y: y)
    return cov*cov/(statsVariance(x)*statsVariance(y))
}

func statsRegression(x: Array<Double>, y: Array<Double>, typeCoeff: Int) -> (r2:Double,coeff:Double) {
    // Calcule le coefficient de détermination et la pente d'une régression linéaire de deux listes (liste 2 = variable indépendante)
    // type coeff : 0 = régression verticale, 1 = régression horizontale, autres = moyenne géométrique des deux (pour approcher la régression orthogonale...)
    let cov = statsCovariance(x: x, y: y)
    let var2 = statsVariance(x)
    let var1 = statsVariance(y)
    var coeff = 0.0
    switch typeCoeff {
        case 0:
            coeff = cov/var2
        case 1:
            coeff = var1/cov
        default:
            coeff = sqrt(var1/var2)
    }
    let r2 = cov*cov/(var1*var2)
    return (r2:r2,coeff:coeff)
}
