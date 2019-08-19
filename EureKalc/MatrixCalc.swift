//
//  MatrixCalc.swift
//  EureKalc
//
//  Created by Nico on 01/10/2022.
//  Copyright © 2022 Nico Hirtt. All rights reserved.
//

import Foundation

var coordinatesForNumber : [[Int]:[[Int]]] = [:] // table mémorisant le lien entre numéro d'un élément et ses coordonnées dans une n-matrice de dimensions données (= key du dictionnaire). Ne pas appeler directement. Utiliser getAllCoords ou get CoordsForElement qui utilisent ce dictionnaire ou le créent si nécessaire.
var dimProducts : [[Int] : [Int]] = [:] // table mémorisant les produits successifs des dimensions pour une n-matrice de dimensions données. Ne pas utiliser directement. Utiliser getDimProds.

var neighboursForDim : [Int : [[Int]]] = [1 : [[-1],[0],[1]]]
var neighbours2ForDim : [Int: [[Int]]] = [1 : [[0],[1]]]



// retourne les coordonnées du n-ème élément d'une n-matrice
// utilise la table coordinatesForNumber si elle existe, mais ne la crée pas
func coordsFromIndex(dim: [Int], n: Int) -> [Int] {
    if coordinatesForNumber[dim] != nil { return coordinatesForNumber[dim]![n] }
    var main = n
    var result : [Int] = []
    for k in (0..<dim.count).reversed() {
        let divider = dim.prefix(k).reduce(1,*)
        let (q,r) = main.quotientAndRemainder(dividingBy: divider)
        main = r
        result.append(q)
    }
    return result.reversed()
}

// le contraire : retourne le numéro de l'élément de coordonnées donné (pour un champ scalaire !)
// sans contrôle !!
func indexFromCoords(dim: [Int], coord: [Int]) -> Int {
    if dim.count != coord.count { return (-1) }
    let testDims : [Bool] = coord.enumerated().map {
        if $1 < 0 { return false }
        if $1 >= dim[$0] { return false }
        return true
    }
    if testDims.contains(false) { return (-1) }
    let dimProds = getDimProds(dim: dim)
    let n = (0..<dim.count).reduce(0) {$0 + dimProds[$1] * coord[$1]}
    if n < 0 || n >= dim.reduce(1,*) { return (-1) }
    return n
}

// construit si nécessaire la table mémorisant les sous-produits successifs des premières dimensions
// ex si dim = [3, 5, 2] => les produits = [1,3,15]
func getDimProds(dim: [Int]) -> [Int] {
    if dimProducts[dim] != nil { return dimProducts[dim]! }
    let theProds : [Int] = (0..<dim.count).map {
        return dim.prefix($0).reduce(1,*)
    }
    dimProducts[dim] = theProds
    return theProds
}

// construit (si nécessaire) une table de relation numéro-indices propre aux dimensions dim
func getAllCoordsIndexes(dim : [Int]) -> [[Int]] {
    if coordinatesForNumber[dim] != nil { return coordinatesForNumber[dim]! }
    let N = dim.reduce(1,*)
    let coordIndexes : [[Int]] = (0..<N).map { coordsFromIndex(dim: dim, n: $0) }
    coordinatesForNumber[dim] = coordIndexes
    return coordIndexes
}

// retourne les coordonnées relatives des voisins dans un champ de ndims dimensions
func getNeighboursCoords(ndims: Int) -> [[Int]] {
    if neighboursForDim[ndims] != nil { return neighboursForDim[ndims]! }
    if ndims == 1 { return [[-1],[0],[1]] }
    let prev = getNeighboursCoords(ndims: ndims - 1)
    var result : [[Int]] = []
    [-1,0,1].forEach({ i in
        result.append(contentsOf: prev.map({ [i] + $0 }))
    })
    return result
}

// idem pour le cas d'un champ décalé de dx/2 (moins de voisins !)
func getNeighbours2Coords(ndims: Int) -> [[Int]] {
    if neighbours2ForDim[ndims] != nil { return neighbours2ForDim[ndims]! }
    if ndims == 1 { return [[0],[1]] }
    let prev = getNeighbours2Coords(ndims: ndims - 1)
    var result : [[Int]] = []
    [0,1].forEach({ i in
        result.append(contentsOf: prev.map({ [i] + $0 }))
    })
    return result
}


// décale les élements d'une matrice de dimensions dim de dx (dx a la même dimension que dim de matrice)
func shiftMatrix(m: [Any], dim: [Int], dx: [Int]) -> [Any] {
    var r = m
    m.enumerated().forEach{(n,val) in
        let c = coordsFromIndex(dim: dim, n: n)
        let newc = c.enumerated().map{(i,co) in
            let t = (co + dx[i])%dim[i]
            return t<0 ? t + dim[i] : t
        }
        let newn = indexFromCoords(dim: dim, coord: newc)
        r[newn] = val
    }
    return r
}

// gestion des matrices physval
extension PhysValue {
    
    func is2Dnumeric() -> Bool {
        if type != "double" { return false }
        if dim.count != 2 { return false }
        return true
    }
    
    func isSquareMatrix() -> Bool {
        if dim.count != 2 { return false }
        if dim[0] != dim[1] { return false }
        return true
    }
    
    // transposée d'une matrice
    func transpose(p : [Int]? = nil ) -> PhysValue {
        let n = dim.count
        let N = values.count
        var perm = Array(1..<n)
        perm.append(0)
        let newDim = (0..<n).map({ dim[perm[$0]]})
        let vals = asDoubles!
        var newVals = vals
        if p != nil {
            var test = true
            perm.forEach({
                if !p!.contains($0) { test = false }
            })
            if !test || p!.count != n { return errVal("wrong indexes permutation")}
            perm = p!
        }
        (0..<N).forEach({ i in
            let c1 = coordsFromIndex(dim: dim, n: i)
            let c2 = (0..<n).map({ c1[perm[$0]]})
            let j = EureKalc.indexFromCoords(dim: newDim, coord: c2)
            newVals[j] = vals[i]
        })
        let r = self.dup()
        r.values = newVals
        r.dim = newDim
        return r
    }
    
    // Fonction récursive pour le calcul de déterminant
    func determinant() -> PhysValue {
        if !isSquareMatrix() || type != "double" {
            return errVal("arg should be a 2D double square matrix")
        }
        let v = asDoubles!
        let n = dim[0]
        if n == 1 { return physValn(n: 0)}
        let r = physValn(n: 0).binaryOp(op: "^", v2: PhysValue(intVal: n))
        r.dim = [1]
        var rv : Double = 0
        if n == 2 {
            rv = v[0]*v[3]-v[1]*v[2]
        } else {
            let c2 = Array(1..<n)
            var s : Double = 1
            for i in 0..<n {
                let cell = getMatValueWithIndexes(coord: [i,0]) as! Double
                var c1 = Array(0..<n)
                c1.remove(at: i)
                let m2 = subMatrix(coords: [c1,c2])
                let subDet = m2.determinant()
                rv = rv + s * cell * subDet.asDouble!
                s = -s
            }
        }
        r.values = [rv]
        return r
    }
    
    
    
    // transforme un array de coordonnées en indices
    // exemple d'array de coords : list((0,1,2),-1,5) = col 0, 1 et 2 de toutes les lignes du plan 5
    func coordArrayToIndexes(coords: [[Int]]) -> [Int] {
        let coordsByIndex = getAllCoordsIndexes(dim: dim)
        let indexes : [Int] = coordsByIndex.enumerated().compactMap {
            for k in 0...dim.count-1 {
                if !coords[k].contains($1[k]) && coords[k] != [-1] { return nil }
            }
            return $0
        }
        return indexes
    }
    
    // calcule les dimensions de la physval correspondant à l'array de coords
    func dimsForCoordArray(coords: [[Int]]) -> [Int] {
        let newDim :[Int] = coords.enumerated().map {
            if $1 == [-1] { return dim[$0] }
            return $1.count
        }
        return newDim
    }
    
    // retourne une physVal contenant les éléments correspondant à l'array de coordonnées
    func subMatrix(coords : [[Int]]) -> PhysValue {
        let indexes = coordArrayToIndexes(coords: coords)
        let newDims = dimsForCoordArray(coords: coords)
        return subPhysVal(indexes: indexes,newDim: newDims)
    }


    func reduceDims() -> PhysValue {
        if dim.count < 2 { return self }
        var newDim : [Int] = []
        for d in self.dim {
            if d > 1 { newDim.append(d)}
        }
        self.dim = newDim
        return self
    }
}
