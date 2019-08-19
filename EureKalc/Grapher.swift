//
//  graphView.swift
//  Grapher
//
//  Created by Nico on 24/03/2019.
//  Copyright © 2019 Nico Hirtt. All rights reserved.
//

import Cocoa


// Cette classe définit un graphe de type "plot", "histo", "field" ou "vec"
// La fonction principale drawGraph(view: NSView) dessine le graphe dans une NSView
// Il faut commencer par définir au moins les variables type et frameRect
// et, selon le type, xyData ou barData et histoLabels ou fieldData

var graphDotTypes : [String] = ["","○","□","△","▽","+","x","●","■","▲","▼","◆"]


class Grapher: NSObject, NSSecureCoding {
    
    static var supportsSecureCoding: Bool = true
        
    // variables propres à chaque série tracée
    var xyData : [[PhysValue]]? // [[série de x,série de y,données extra]]. Les x doivent être de même unité
    var lineWidth : [CGFloat] = Array(repeating: 1, count: 10)
    var lineType : [Int] = [0,1,2,3,0,1,2,3,0,1,2,3] // tirets et pointillés...
    var lineColor : [NSColor] = [NSColor.systemGreen,NSColor.systemBlue,NSColor.systemGray,NSColor.systemRed,NSColor.systemYellow,NSColor.systemPink,NSColor.systemPink, NSColor.systemBrown, NSColor.systemTeal, NSColor.systemOrange]
    var dotType : [String] = Array(graphDotTypes.dropFirst())
    var dotSize : [CGFloat] = Array(repeating: 5, count: 10)
    var dotInterval : [Int] = Array(repeating: 0, count: 10)// 0 signifie aucun, 1 = tous, 2 = tous les 2, etc...
    var dotColor : [NSColor] = [NSColor.systemGreen,NSColor.systemBlue,NSColor.systemGray,NSColor.systemRed,NSColor.systemYellow,NSColor.systemPink,NSColor.systemPink, NSColor.systemBrown, NSColor.systemTeal, NSColor.systemOrange]
    var graphLegend : [String] = Array(repeating: "", count: 10) // le nom qui sera affiché dans la légende du graphe
    var useSecondYaxis : [Bool] = Array(repeating: false, count: 10)
    var valueLabels : [Bool] = Array(repeating: false, count: 10) // affichage des valeurs
    var histogram : [Bool] = Array(repeating: false, count: 10) // par défaut ce ne sont pas des histogrammes 0,1,2
    
    // Données supplémentaire éventuelles pour faire varier la couleur, ajouter des barres d'erreur, etc.
    // (String = "dotsize", "areaup", "areadown", "xerror","yerror","linewidth"..
    var extraData : [Int:[String:[Any]]] = [:] // n° type valeurs...

    // variables propres au graphe "histo"
    // (pour les couleurs et les lignes des colonnes on utilise lineColor, lineType, dotYpe, dotColor)
    var histoLabels : [String] = [] // les labels
    var barData : [[Double]]?
    var histoOrientation = "V" // ou "H"
    var histoStacked = false // empilement des histogrammes
    var histoS1 : CGFloat = -0.3 // espace entre deux colonnes (en multiple de la largeur des colonnes)
    var histoS2: CGFloat = 0.7 // espace entre deux séries de colonnes (idem)
    
    // variables propres aux graphes de type "field"
    var fields : [PhysValue]? // physvals contenant des champs ( 1 scal et plusieurs vec)
    var fieldType : [String]? // "color" ou "vector" (seulement des couleurs ou aussi des vecteurs [+ couleurs éventuelles si dim > 2]
    var fieldColors : [PhysValue]? // couleurs limites (min, max, min, max... pour chaque dim du champ vec)
    var fieldLimits : [PhysValue]? // valeurs limites du champ (min, max ou max de chaque composante => couleurs limites)
    var fieldVecSizes : [PhysValue]? = Array(repeating: PhysValue(doubleVal: 10), count: 10) // échelle des vecteurs pour les champs. Valeur donnant un vecteur maximal
    var fieldNames : [String]?
    
    // variables relatives au dessin des axes, cadres, etc [x, y, deuxième axe y ou z] des graphes "plot" et "field"
    var axes : [Bool] = [true,true] // faut-il dessiner les axes ?
    var axesMinMax : [PhysValue]? // une physval contenant min, max et unité pour chaque axe  (x, y, y sup ou z)
    var axesAuto : [Bool] = [false,false]
    var axesUnit : [Unit]? // unités des axes
    var axesLabsFormat : [String] = ["auto","auto"]
    var axesLabsDigits : [Bool] = [true,true]
    var axesLabsPrecision : [Int] = [3,3]
    var axesDivs : [Double] = [0.5,0.5]
    var axesSubDivs : [Int] = [4, 4]
    var axesArrows : [Bool] = [false,false]
    var axesTitles : [String] = ["?","?"]
    var axesPos : [String] = ["min","min"] // "min", "max", "0"
    var axesWidth : CGFloat = 1.0
    var axesFrame : Bool = true // dessin d'un cadre au lieu des axes
    var axesFill : Bool = false // remplissage
    var grids : [(main: Bool, sub: Bool)] = [(true, false),(true, false)] // affichage ou non de la grill principale et secondaire de chaque axe
    var gridsWidths : [(main: CGFloat, sub: CGFloat)] = [(0.5,0.2),(0.5,0.2)]
    var ticks : [(main: Bool, sub: Bool)] = [(true, false),(true, false)] // Dessin ou non des taquets
    var ticksSize : CGFloat = 4.0  // fraction de la taille du graphique ? Non !
    var tickLabels: [Bool] = [true,true] // affichage ou non des labels des taquets
    var labelSpace : CGFloat = 2
    
    // variables relatives au dessin général
    var frameRect : NSRect = NSRect()
    var mainFrame : Bool = true // Dessin d'un cadre extérieur
    var mainFrameFill : Bool = false // remplissage
    var mainFrameWidth : CGFloat = 0.2 // largeur du trait
    var mainTitle : String = "" // titre du graphique
    var legend : Bool = false
    var legendPos : String = "right" // "RT=right", "RB", "B"
    var legendOri : String = "C" // orientation légende R ou C (row, column)
    var legendNbr : Int = 0 // nombre de rangées ou colonnes - 0 pour auto
    var space : CGFloat = 10.0 // espace blanc en points
    var space2 : CGFloat = 15.0 // espace pour les titres
    
    var graphFonts : [ String : NSFont ] = ["maintitle" : NSFont.systemFont(ofSize: 14),
                                            "axeslabels" : NSFont.systemFont(ofSize: 12),
                                            "ticklabels" : NSFont.systemFont(ofSize: 10),
                                            "legend" : NSFont.systemFont(ofSize: 12) ]
    
    var graphColors : [ String : NSColor ] = ["axes": NSColor.lightGray,
                                              "axesfill" : NSColor(named: NSColor.Name("defaultGraphBkgnd"))!,
                                              "mainframe" : NSColor.black,
                                              "framefill": NSColor(named: NSColor.Name("defaultGraphBkgnd"))!,
                                              "maingrid" : NSColor.lightGray,
                                              "subgrid" : NSColor.lightGray,
                                              "maintitle": defaultTextColor,
                                              "axeslabels": defaultTextColor,
                                              "ticklabels": defaultTextColor,
                                              "legend": defaultTextColor]
    
    // variables qui ne peuvent être modifiées par l'utilisateur et ne sont pas sauvegardées
    var histoRects : [[NSRect]] = []
    var axesRect : NSRect = NSRect()
    var titleSize : NSSize = NSSize()
    var lastClickedElement : String = ""
    let lineTypes : [[CGFloat]] = [[],[2,2],[4,2],[5,3,2,3]] // tirets et pointillés...
    var needsResize = (false,false)
    var legendHeight: CGFloat = 0
    var legendWidth: CGFloat = 0
    
    // Encodage et décodage
    
    func encode(with aCoder: NSCoder) {
        if xyData != nil {aCoder.encode(xyData,forKey: "xyData")}
        aCoder.encode(lineWidth, forKey: "lineWidth")
        aCoder.encode(lineType, forKey: "lineType")
        aCoder.encode(lineColor, forKey: "lineColor")
        aCoder.encode(dotType, forKey: "dotType")
        aCoder.encode(dotSize, forKey: "dotSize")
        aCoder.encode(dotInterval, forKey: "dotInterval")
        aCoder.encode(dotColor, forKey: "dotColor")
        aCoder.encode(graphLegend, forKey: "graphLegend")
        aCoder.encode(useSecondYaxis, forKey: "useSecondYaxis")
        aCoder.encode(valueLabels, forKey: "valueLabels")
        aCoder.encode(histogram,forKey: "histogram")
        aCoder.encode(extraData, forKey: "extraData")
        aCoder.encode(histoLabels, forKey: "histoLabels")
        if barData != nil { aCoder.encode(barData, forKey: "barData") }
        aCoder.encode(histoOrientation, forKey: "histoOrientation")
        aCoder.encode(histoStacked, forKey: "histoStacked")
        aCoder.encode(histoS1, forKey: "histoS1")
        aCoder.encode(histoS2, forKey: "histoS2")
        if fields != nil { aCoder.encode(fields, forKey: "fields") }
        if fieldColors != nil { aCoder.encode(fieldColors, forKey: "fieldColors") }
        if fieldLimits != nil { aCoder.encode(fieldLimits, forKey: "fieldLimits") }
        if fieldVecSizes != nil { aCoder.encode(fieldVecSizes, forKey: "fieldVecSizes") }
        if fieldNames != nil { aCoder.encode(fieldNames, forKey: "fieldNames") }
        aCoder.encode(axes, forKey: "axes")
        if axesMinMax != nil { aCoder.encode(axesMinMax,forKey: "axesMinMax")}
        aCoder.encode(axesAuto, forKey: "axesAuto")
        if axesUnit != nil { aCoder.encode(axesUnit, forKey: "axesUnit") }
        aCoder.encode(axesLabsFormat, forKey: "axesLabsFormat")
        aCoder.encode(axesLabsDigits, forKey: "axesLabsDigits")
        aCoder.encode(axesLabsPrecision, forKey: "axesLabsPrecision")
        aCoder.encode(axesDivs, forKey: "axesDivs")
        aCoder.encode(axesSubDivs, forKey: "axesSubDivs")
        aCoder.encode(axesArrows, forKey: "axesArrows")
        aCoder.encode(axesTitles, forKey: "axesTitles")
        aCoder.encode(axesPos, forKey: "axesPos")
        aCoder.encode(axesWidth, forKey: "axesWidth")
        aCoder.encode(axesFrame, forKey: "axesFrame")
        aCoder.encode(axesFill, forKey: "axesFill")
        aCoder.encode([grids[0].main,grids[0].sub,grids[1].main,grids[1].sub], forKey: "grids")
        aCoder.encode([gridsWidths[0].main,gridsWidths[0].sub,gridsWidths[1].main,gridsWidths[1].sub], forKey: "gridsWidths")
        aCoder.encode([ticks[0].main,ticks[0].sub,ticks[1].main,ticks[1].sub], forKey: "ticks")
        aCoder.encode(ticksSize, forKey: "ticksSize")
        aCoder.encode(tickLabels, forKey: "tickLabels")
        aCoder.encode(labelSpace, forKey: "labelSpace")
        aCoder.encode(mainFrame, forKey: "mainFrame")
        aCoder.encode(mainFrameFill, forKey: "mainFrameFill")
        aCoder.encode(mainFrameWidth, forKey: "mainFrameWidth")
        aCoder.encode(mainTitle, forKey: "mainTitle")
        aCoder.encode(legend, forKey: "legend")
        aCoder.encode(legendPos, forKey: "legendPos")
        aCoder.encode(legendOri, forKey: "legendOri")
        aCoder.encode(legendNbr, forKey: "legendNbr")
        aCoder.encode(space, forKey: "space")
        aCoder.encode(frameRect, forKey: "frameRect")
        aCoder.encode(graphFonts, forKey: "graphFonts")
        aCoder.encode(graphColors, forKey: "graphColors")
    }
    
    
    required init?(coder: NSCoder) {
        xyData = coder.decodeObject(of: [NSArray.self, PhysValue.self], forKey: "xyData") as? [[PhysValue]]
        lineWidth = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "lineWidth") as! [CGFloat]
        lineType = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "lineType") as! [Int]
        lineColor = coder.decodeObject(of: [NSArray.self, NSColor.self], forKey: "lineColor") as! [NSColor]
        dotType = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "dotType") as! [String]
        dotSize = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "dotSize") as! [CGFloat]
        dotInterval = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "dotInterval") as! [Int]
        dotColor = coder.decodeObject(of: [NSArray.self, NSColor.self], forKey: "dotColor") as! [NSColor]
        graphLegend = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "graphLegend") as! [String]
        useSecondYaxis = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "useSecondYaxis") as! [Bool]
        valueLabels = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "valueLabels") as! [Bool]
        histogram = (coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "histogram") as? [Bool]) ??  Array(repeating: false, count: 10)
        extraData = coder.decodeObject(of: [NSArray.self, NSDictionary.self, NSColor.self, NSNumber.self, NSString.self], forKey: "extraData") as! [Int:[String:[Any]]]
        histoLabels = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "histoLabels") as! [String]
        barData = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "barData") as? [[Double]]
        histoOrientation = coder.decodeObject(of: [NSString.self], forKey: "histoOrientation") as! String
        histoStacked = coder.decodeBool(forKey: "histoStacked")
        histoS1 = coder.decodeObject(of: [NSNumber.self], forKey: "histoS1") as! CGFloat
        histoS2 = coder.decodeObject(of: [NSNumber.self], forKey: "histoS2") as! CGFloat
        fields = coder.decodeObject(of: [NSArray.self, PhysValue.self], forKey: "fields") as? [PhysValue]
        fieldColors = coder.decodeObject(of: [NSArray.self, PhysValue.self], forKey: "fieldColors") as? [PhysValue]
        fieldLimits = coder.decodeObject(of: [NSArray.self, PhysValue.self], forKey: "fieldLimits") as? [PhysValue]
        fieldVecSizes = coder.decodeObject(of: [NSArray.self, PhysValue.self], forKey: "fieldVecSizes") as? [PhysValue]
        fieldNames = coder.decodeObject(of: [NSArray.self,NSString.self], forKey: "fieldNames") as? [String]
        axes = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "axes") as! [Bool]
        axesMinMax = coder.decodeObject(of: [NSArray.self, PhysValue.self], forKey: "axesMinMax") as? [PhysValue]
        axesAuto = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "axesAuto") as? [Bool] ?? [false,false]
        axesUnit = coder.decodeObject(of: [NSArray.self, Unit.self], forKey: "axesUnit") as? [Unit]
        axesLabsFormat = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "axesLabsFormat") as? [String] ?? ["auto","auto"]
        axesLabsDigits = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "axesLabsDigits") as? [Bool] ?? [true,true]
        axesLabsPrecision = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "axesLabsPrecision") as? [Int] ?? [3,3]
        axesDivs = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "axesDivs") as! [Double]
        axesSubDivs = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "axesSubDivs") as! [Int]
        axesArrows = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "axesArrows") as! [Bool]
        axesTitles = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "axesTitles") as! [String]
        axesPos = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "axesPos") as! [String]
        axesWidth = coder.decodeObject(of: [NSNumber.self],forKey: "axesWidth") as! CGFloat
        axesFrame = coder.decodeBool(forKey: "axesFrame")
        axesFill = coder.decodeBool(forKey: "axesFill")
        let gridsArray = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "grids") as! [Bool]
        grids = [(gridsArray[0],gridsArray[1]),(gridsArray[2],gridsArray[3])]
        let gWidthArray = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "gridsWidths") as! [CGFloat]
        gridsWidths = [(gWidthArray[0],gWidthArray[1]),(gWidthArray[2],gWidthArray[3])]
        let ticksArray = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "ticks") as! [Bool]
        ticks = [(ticksArray[0],ticksArray[1]),(ticksArray[2],ticksArray[3])]
        ticksSize = coder.decodeObject(of: [NSNumber.self], forKey: "ticksSize") as! CGFloat
        tickLabels = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "tickLabels") as! [Bool]
        labelSpace = coder.decodeObject(of: [NSNumber.self], forKey: "labelSpace") as! CGFloat
        frameRect = coder.decodeRect(forKey: "frameRect")
        mainFrame = coder.decodeBool(forKey: "mainFrame")
        mainFrameFill = coder.decodeBool(forKey: "mainFrameFill")
        mainFrameWidth = coder.decodeObject(of: [NSNumber.self], forKey: "mainFrameWidth") as! CGFloat
        mainTitle = coder.decodeObject(of: [NSString.self], forKey: "mainTitle") as! String
        legend = coder.decodeBool(forKey: "legend")
        legendPos = coder.decodeObject(of: [NSString.self], forKey: "legendPos") as! String
        legendOri = coder.decodeObject(of: [NSString.self], forKey: "legendOri") as! String
        legendNbr = coder.decodeInteger(forKey: "legendNbr")
        space = coder.decodeObject(of: [NSNumber.self], forKey: "space") as! CGFloat
        graphFonts = coder.decodeObject(of: [NSFont.self, NSDictionary.self, NSString.self], forKey: "graphFonts") as! [String : NSFont]
        graphColors = coder.decodeObject(of: [NSColor.self, NSDictionary.self, NSString.self], forKey: "graphColors") as! [String : NSColor]
        if graphColors["legend"] == nil { graphColors["legend"] = defaultTextColor }
    }
    
    override init() { }
    
    // LA fonction principale : celle qui dessinne le graphique
    
    func drawGraph() {
        
        if (barData?.count ?? 0) == 0 { barData = nil } // temporaire pour éviter les bugs...
        
        // Si nécessaire recalcul automatique des limites d'axes
        var axesLimits : [(min:Double, max: Double)] = []
        if axesMinMax != nil {
            axesMinMax!.forEach({ oneLim in
                let limVals = oneLim.asDoubles!
                axesLimits.append((min: limVals[0], max: limVals[1]))
            })
        }
        // détermination des limites par défaut
        if axesMinMax == nil {  [0,1].forEach({ j in autoLimits(j: j) }) }
        
        if xyData != nil {
            for j in 0...1 {
                if axesAuto[j] {
                    var maxVal = -Double.greatestFiniteMagnitude
                    var minVal = Double.greatestFiniteMagnitude
                    for onePlot in xyData! {
                        minVal = min(minVal, onePlot[j].asDoubles!.min()!)
                        maxVal = max(maxVal, onePlot[j].asDoubles!.max()!)
                    }
                    
                    let limits = axesMinMax![j].asDoubles!
                    if minVal < limits[0] || maxVal > limits[1] || minVal > limits[0] + axesDivs[j] || maxVal < limits[1] - axesDivs[j] {
                        autoLimits(j: j)
                    }
                }
            }
            
        }
        
        // Dessin de la zone externe
        /*
        let theMainFrame = NSBezierPath(rect: frameRect)
        if mainFrameFill {
            graphColors["framefill"]!.setFill()
            theMainFrame.fill()
        }
        if mainFrame {
            graphColors["mainframe"]!.setStroke()
            theMainFrame.lineWidth = mainFrameWidth
            theMainFrame.stroke()
        }
        */
        
        //Dessin du titre
        var titleAttributes = [NSAttributedString.Key.font : graphFonts["maintitle"]!,
                               NSAttributedString.Key.foregroundColor: graphColors["maintitle"]!]
                
        titleSize = NSSize(width: 0, height: 0)
        if mainTitle != "" {
            titleSize = mainTitle.size(withAttributes: titleAttributes)
            mainTitle.draw(at:
                NSPoint(
                    x: frameRect.minX + CGFloat(frameRect.width / 2) - (titleSize.width / 2),
                    y: frameRect.maxY - space - titleSize.height
                ), withAttributes: titleAttributes)
        }
        

        // Génération des chaines formatées pour les labels de taquets
        let labelAttributes = [NSAttributedString.Key.font : graphFonts["ticklabels"]!,
                               NSAttributedString.Key.foregroundColor : graphColors["ticklabels"]!]
        let labelHeight = (("0" as NSString).size(withAttributes: labelAttributes)).height
        
        var xLabels : [String] = []
        var x = 0.0
        if barData != nil && histoOrientation == "V" { xLabels = histoLabels}
        else {
            x = axesLimits[0].min
            while x <= axesLimits[0].max {
                xLabels.append(tickLabel(x, j: 0))
                x = x + axesDivs[0]
            }
        }
        var maxLabelX : CGFloat = 0
        for lab in xLabels {
            maxLabelX = max(maxLabelX, ((lab as NSString).size(withAttributes: labelAttributes)).width)
        }
        
        var yLabels : [String] = []
        var y = 0.0
        if barData != nil && histoOrientation == "H" { yLabels = histoLabels }
        else {
            y = axesLimits[1].min
            while y <= axesLimits[1].max {
                yLabels.append(tickLabel(y, j: 1))
                y = y + axesDivs[1]
            }
        }
        var maxLabelY : CGFloat = 0
        for lab in yLabels {
            maxLabelY = max(maxLabelY, ((lab as NSString).size(withAttributes: labelAttributes)).width)
        }
        
        // Calcul des dimensions de la zone de graphique
        titleAttributes = [NSAttributedString.Key.font : graphFonts["axeslabels"]!,
                           NSAttributedString.Key.foregroundColor : graphColors["axeslabels"]! ]
        var x0 = max(space,labelSpace + (maxLabelX / 2)) + ticksSize + frameRect.minX
        if axesTitles[1] != "" {
            x0 = x0 + (axesTitles[1].size(withAttributes: titleAttributes)).height + space
        }
        if tickLabels[1] && axesPos[1] == "min" {
            x0 = x0 + maxLabelY + 2 * labelSpace
        }
        if barData != nil && histoOrientation == "H" {
            x0 = x0 + maxLabelY + 2 * labelSpace
        }
        var y0 = frameRect.minY + space + ticksSize
        if axesTitles[0] != "" {
            y0 = y0 + (axesTitles[0].size(withAttributes: titleAttributes)).height + space
        }
        if tickLabels[0] && axesPos[0] == "min" {
            y0 = y0 + labelHeight + 2 * labelSpace
        }
        if barData != nil && histoOrientation == "V" {
            y0 = y0 + labelHeight + 2 * labelSpace
        }
        var x1 = frameRect.maxX - max(space,labelSpace + (maxLabelX / 2))
        if tickLabels[1] && axesPos[1] == "max" {
            x1 = x1 - maxLabelY - 2 * labelSpace
        }
        var y1 = frameRect.maxY - space
        
        if mainTitle != "" {
            y1 = y1 - titleSize.height - space2
        }
        if tickLabels[0] && axesPos[0] == "max" {
            y1 = y1 - labelHeight - 2 * labelSpace
        }
        
        
        // Légende et correction de la zone graphique
        //var legendRect = NSRect()
        let legendAttributes = [NSAttributedString.Key.font : graphFonts["legend"]!,
                                NSAttributedString.Key.foregroundColor : graphColors["legend"]!]
        var legendWidth : CGFloat = 0
        var legendHeight : CGFloat = 0
        
        if legend && (xyData != nil || (barData?.count ?? 0) > 0)  {
            let w : CGFloat = 20
            let nLegends = xyData != nil ? xyData!.count : barData!.count
            if legendPos == "right" || legendPos == "RT" || legendPos == "RB" {
                legendHeight = space
                for n in 0...nLegends-1{
                    let aLegend = n < graphLegend.count ? graphLegend[n] : ""
                    let legendSize = aLegend.size(withAttributes: legendAttributes)
                    legendWidth = max(legendWidth, legendSize.width)
                    legendHeight = legendHeight + legendSize.height + space
                }
                var y = legendPos=="RB" ? y0 + legendHeight - 30 : y1 - 20
                for n in 0...nLegends-1 {
                    let aLegend = n < graphLegend.count ? graphLegend[n] : ""
                    let legendSize = aLegend.size(withAttributes: legendAttributes)
                    (aLegend as NSString).draw(at: NSPoint(x: x1 - w - space - legendWidth , y: y), withAttributes: legendAttributes)
                    drawLegend(n: n, p: NSPoint(x: x1 - w,y : y + legendSize.height / 2))
                    y = y - legendSize.height - space
                }
                x1 = x1 - w - legendWidth - space * 2
                legendHeight = 0 // pour ne pas déplacer le nim de l'axe x !
            } else if legendPos == "B" {
                for n in 0...nLegends-1{
                    let aLegend = n < graphLegend.count ? graphLegend[n] : ""
                    let legendSize = aLegend.size(withAttributes: legendAttributes)
                    legendHeight = max(legendHeight, legendSize.height)
                    legendWidth = legendWidth + legendSize.width + space * 3 + w
                }
                let y = frameRect.minY + space // y0 - 30
                var x = (x0 + x1)/2 - legendWidth/2
                for n in 0...nLegends-1 {
                    let aLegend = n < graphLegend.count ? graphLegend[n] : ""
                    let legendSize = aLegend.size(withAttributes: legendAttributes)
                    (aLegend as NSString).draw(at: NSPoint(x: x , y: y), withAttributes: legendAttributes)
                    drawLegend(n: n, p: NSPoint(x: x + legendSize.width + space,y : y + legendSize.height / 2))
                    x = x + space * 3 + legendSize.width + w
                }
                y0 = y0 + space + legendHeight
                legendHeight = legendHeight + 2 * space
            }
        }
        
        // Finalisation de la zone de graphique et position des axes
        axesRect = NSRect(x: x0, y: y0, width: x1-x0, height: y1-y0)
        var xAxis : CGFloat = 0
        if axesPos[0] == "max" { xAxis = axesRect.maxY }
        if axesPos[0] == "0" { xAxis = convert(0, n: 1) }
        if xAxis == 0 {xAxis = axesRect.minY }
        var yAxis : CGFloat = 0
        if axesPos[1] == "max" { yAxis = axesRect.maxX }
        if axesPos[1] == "0" { yAxis = convert(0, n: 0) }
        if yAxis == 0 {yAxis = axesRect.minX }
        
        // Affichage des titres d'axes
        if axesTitles[0] != "" {
            let title = axesUnit![0].name == "" ? axesTitles[0] : axesTitles[0] + " [" + axesUnit![0].name + "]"
            let size = title.size(withAttributes: titleAttributes)
            let posx = axesRect.midX - size.width / 2
            let posy = frameRect.minY + space + legendHeight
            (title as NSString).draw(at: NSPoint(x: posx, y: posy), withAttributes: titleAttributes)
        }
        if axesTitles[1] != "" {
            let title = axesUnit![1].name == "" ? axesTitles[1] : axesTitles[1] + " [" + axesUnit![1].name + "]"
            let size = title.size(withAttributes: titleAttributes)
            let posy = axesRect.midY - size.width / 2
            let posx = frameRect.minX + space
            let trans = NSAffineTransform()
            trans.rotate(byDegrees: 90)
            
            let context = NSGraphicsContext.current!.cgContext
            context.saveGState()
            trans.concat()
            let nx = posy
            let ny = -posx - size.height
            (title as NSString).draw(at: NSPoint(x: nx, y: ny), withAttributes: titleAttributes)
            context.restoreGState()
        }
        
        // Dessin du fond
        let theAxesFrame = NSBezierPath(rect: axesRect)
        if axesFill {
            graphColors["axesfill"]?.setFill()
            theAxesFrame.fill()
        }
        
        // Labels d'axes, taquets et grilles: axe X
        x = axesLimits[0].min
        while x <= axesLimits[0].max {
            let cx = convert(x, n: 0)
            // Dessin grille secondaire
            if grids[0].sub && axesSubDivs[0] > 1  {
                let subDiv = axesDivs[0] / Double(axesSubDivs[0])
                graphColors["subgrid"]!.setStroke()
                for k in 1...(axesSubDivs[0]-1) {
                    let ccx = convert(x + Double(k) * subDiv, n: 0)
                    let ligne = NSBezierPath()
                    ligne.lineWidth = gridsWidths[0].sub
                    ligne.move(to: CGPoint(x: ccx , y: axesRect.minY))
                    ligne.line(to: CGPoint(x: ccx , y: axesRect.maxY))
                    ligne.stroke()
                }
            }
            if x != 0 || axesPos[0] != "0" {
                // Dessin grille principale
                if grids[0].main {
                    graphColors["maingrid"]!.setStroke()
                    let ligne = NSBezierPath()
                    ligne.lineWidth = gridsWidths[0].main
                    ligne.move(to: CGPoint(x: cx , y: axesRect.minY))
                    ligne.line(to: CGPoint(x: cx , y: axesRect.maxY))
                    ligne.stroke()
                }
                
                // Dessin labels
                if tickLabels[0] {
                    let lab = tickLabel(x,j : 0) as NSString
                    let size = lab.size(withAttributes: labelAttributes)
                    let posx = cx - size.width / 2
                    if axesPos[0] == "max" {
                        lab.draw(at: CGPoint(x: posx, y :xAxis + ticksSize + labelSpace), withAttributes: labelAttributes)
                    } else {
                        lab.draw(at: CGPoint(x: posx, y :xAxis - ticksSize - labelSpace - size.height), withAttributes: labelAttributes)
                    }
                }
                // Dessin taquets
                if ticks[0].main {
                    let ligne = NSBezierPath()
                    ligne.move(to: CGPoint(x: cx , y: xAxis))
                    if axesPos[0] == "max" {
                        ligne.line(to: CGPoint(x: cx, y: xAxis + ticksSize))
                    } else {
                        ligne.line(to: CGPoint(x: cx, y: xAxis - ticksSize))
                    }
                    ligne.stroke()
                }
            }
            x = x + axesDivs[0]
        }
        
        // Labels d'axes, taquets et grilles: axe Y
        y = axesLimits[1].min
        while y <= axesLimits[1].max {
            let cy = convert(y, n: 1)
            if grids[1].sub && axesSubDivs[1] > 1 {
                let subDiv = axesDivs[1] / Double(axesSubDivs[1])
                graphColors["subgrid"]!.setStroke()
                for k in 1...(axesSubDivs[1]-1) {
                    let ccy = convert(y + Double(k) * subDiv, n: 1)
                    let ligne = NSBezierPath()
                    ligne.lineWidth = gridsWidths[1].sub
                    ligne.move(to: CGPoint(x: axesRect.minX , y: ccy))
                    ligne.line(to: CGPoint(x: axesRect.maxX , y: ccy))
                    ligne.stroke()
                }
            }
            if y != 0 || axesPos[1] != "0" {
                if tickLabels[1] {
                    let lab = tickLabel(y, j: 1) as NSString
                    let size = lab.size(withAttributes: labelAttributes)
                    let posy = cy - size.height / 2
                    if axesPos[1] == "max" {
                        lab.draw(at: CGPoint(x: yAxis + ticksSize + labelSpace, y :posy), withAttributes: labelAttributes)
                    } else {
                        lab.draw(at: CGPoint(x: yAxis - ticksSize - labelSpace - size.width, y :posy), withAttributes: labelAttributes)
                    }
                }
                if grids[1].main {
                    graphColors["maingrid"]!.setStroke()
                    let ligne = NSBezierPath()
                    ligne.lineWidth = gridsWidths[1].main
                    ligne.move(to: CGPoint(x: axesRect.minX , y: cy))
                    ligne.line(to: CGPoint(x: axesRect.maxX , y: cy))
                    ligne.stroke()
                }
                if ticks[1].main {
                    graphColors["axes"]!.setStroke()
                    let ligne = NSBezierPath()
                    ligne.move(to: CGPoint(x: yAxis , y: cy))
                    if axesPos[1] == "max" {
                        ligne.line(to: CGPoint(x: yAxis + ticksSize, y: cy))
                    } else {
                        ligne.line(to: CGPoint(x: yAxis - ticksSize, y: cy))
                    }
                    ligne.stroke()
                }
            }
            y = y + axesDivs[1]
        }
        
        // Dessin du cadre du graphique et des axes
        graphColors["axes"]!.setStroke()
        if axesFrame {
            theAxesFrame.lineWidth = axesWidth
            theAxesFrame.stroke()
        }
        if axes[0] {
            let xLine = NSBezierPath()
            xLine.lineWidth = axesWidth
            xLine.move(to: CGPoint(x: axesRect.minX, y: xAxis))
            xLine.line(to: CGPoint(x: axesRect.maxX, y: xAxis))
            xLine.stroke()
        }
        if axes[1] {
            let yLine = NSBezierPath()
            yLine.lineWidth = axesWidth
            yLine.move(to: CGPoint(x: yAxis, y: axesRect.minY))
            yLine.line(to: CGPoint(x: yAxis, y: axesRect.maxY))
            yLine.stroke()
        }
        
        
        // ******************************************
        // Dessin des tracés, barres, champs, etc...
        // ******************************************
        
        // Dessin des champs
        if fields != nil {
            // il faut détecter la résolution de l'écran pour éviter les effets de bords dans les champs scalaires
            let dpi = (NSScreen.main!.deviceDescription[NSDeviceDescriptionKey.resolution] as! NSSize).width / 72
            
            for (n,aField) in fields!.enumerated() {
                let nx = CGFloat(aField.dim[0])
                let dx = CGFloat(axisScale(n: 0) * aField.field!["dx"]!.asDouble!)
                let dy = CGFloat(axisScale(n: 1) * aField.field!["dx"]!.asDouble!)
                var ix : CGFloat = 1
                var iy: CGFloat = 1
                let origin = aField.field!["origin"]!.asDoubles!

                if !aField.isVec {
                    // champ scalaire
                    var fieldColor = Array(repeating: defaultTextColor, count: aField.nElems)
                    if fieldLimits?[n] != nil && fieldColors?[n] != nil {
                        let fldLims = fieldLimits![n].asDoubles!
                        let fldCols = fieldColors![n].asColors!
                        if fldCols.count == 3 && fldLims.count == 3 {
                            fieldColor = colorField(values: aField.asDoubles!, min: fldLims[0], max : fldLims[1], medVal: fldLims[2], start: fldCols[0], end: fldCols[1], medCol: fldCols[2])
                        } else if fldCols.count > 1 && fldLims.count > 1 {
                            fieldColor = colorField(values: aField.asDoubles!, min: fldLims[0], max : fldLims[1], start: fldCols[0], end: fldCols[1])
                        } else {
                            let vals = aField.asDoubles!
                            let min = vals.min() ?? 0
                            let max = vals.max() ?? 1
                            fieldColor = colorField(values: vals, min: min, max : max, medVal: (min+max)/2, start: NSColor.blue, end: NSColor.red, medCol: NSColor.yellow)
                        }
                    }
                    
                    let x0 = convert(origin[0], n: 0)
                    let y0 = convert(origin[1], n: 1)
                    var x = dpi * round(convert(origin[0], n: 0)/dpi)
                    var y = dpi * round(convert(origin[1], n: 1)/dpi)
         
                    for color in fieldColor {
                        let x2 = dpi * round((x0 + ix * dx)/dpi)
                        let y2 = dpi * round((y0 + iy * dy)/dpi)
                        let minx = (x >= axesRect.minX) ? x : axesRect.minX
                        let maxx = (x2 <= axesRect.maxX) ? x2 : axesRect.maxX
                        let miny = (y >= axesRect.minY) ? y : axesRect.minY
                        let maxy = (y2 <= axesRect.maxY) ? y2 : axesRect.maxY
                        if x2 >= axesRect.minX-1 && x <= axesRect.maxX+1 && y2 >= axesRect.minY-1 && y <= axesRect.maxY+1 {
                            let theLine = NSBezierPath(rect: NSRect(x: minx, y: miny, width: maxx-minx, height: maxy-miny))
                            color.set()
                            theLine.fill()
                        }
                        x = x2
                        ix = ix + 1
                        if ix > nx {
                            x = dpi * round(convert(origin[0], n: 0)/dpi)
                            ix = 1
                            iy = iy + 1
                            y = y2
                        }
                    }
                } else {
                    // champ vectoriel
                    // dessin d'un champ vectoriel
                    ix = 0
                    iy = 0
                    let fieldVx = aField.getComponentOfVecField(i: 0)!.asDoubles!
                    let fieldVy = aField.getComponentOfVecField(i: 1)!.asDoubles!
                    let theColor = fieldColors?[n] != nil ? fieldColors![n].asColors![0] : NSColor.gray
                    let x0 = convert(origin[0], n: 0) + dx/2
                    let y0 = convert(origin[1], n: 1) + dy/2
                    
                    let vecs = zip(fieldVx,fieldVy).map({ sqrt($0*$0+$1*$1) })
                    let maxvec = fieldLimits?[n] != nil ? abs(fieldLimits![n].asDoubles![1]) : vecs.max()!
                    let minvec = fieldLimits?[n] != nil ? abs(fieldLimits![n].asDoubles![0]) : vecs.min()!

                    if fieldVecSizes == nil {
                        let thePhVal = PhysValue(unit: Unit(), type: "double", values: [2,10])
                        fieldVecSizes = Array(repeating: thePhVal, count: 10)
                    }
                    if fieldVecSizes![n].asDoubles?.count == 1 {
                        fieldVecSizes![n].values.append(10)
                        fieldVecSizes![n].values[0]=2
                    }
                    let minvecsize = CGFloat(fieldVecSizes![n].asDoubles![0])
                    let maxvecsize = CGFloat(fieldVecSizes![n].asDoubles![1])
                    
                    var dvx : CGFloat = 0
                    var dvy : CGFloat = 0
                    let deltavec=maxvec-minvec
                    let deltasize=maxvecsize-minvecsize
                    vecs.enumerated().forEach({ (i,v) in
                        let vx = fieldVx[i]
                        let vy = fieldVy[i]
                        let x = x0 + CGFloat(ix) * dx
                        let y = y0 + CGFloat(iy) * dy
                        if x >= axesRect.minX && x <= axesRect.maxX && y >= axesRect.minY && y <= axesRect.maxY {
                            let  vecsize  = v < minvec ? minvecsize : (v > maxvec ? maxvecsize : minvecsize + (v-minvec)/deltavec*deltasize)
                            dvx = vecsize * CGFloat(vx)/v
                            dvy = vecsize * CGFloat(vy)/v
                            drawVector(x0: x-dvx/2, y0: y-dvy/2, vx: dvx, vy: dvy, color: theColor)
                            ix = ix + 1
                            if ix >= nx {
                                ix = 0
                                iy = iy + 1
                            }
                        }
                    })
                }
            }
        }
          
        
        //
        // Dessin des plots (ou de points et lignes sur un champ)
        if xyData != nil {
            let nGraphs = xyData!.count
            for n in 0...(nGraphs-1) {
                let xData = xyData![n][0].asDoubles!
                let yData = xyData![n][1].asDoubles!
                if lineWidth.count < nGraphs {lineWidth.append(lineWidth[0])}
                if lineColor.count < nGraphs {lineColor.append(lineColor[0])}
                if dotInterval.count < nGraphs {dotInterval.append(dotInterval[0])}
                if dotType.count < nGraphs {dotType.append(dotType[0])}
                if dotSize.count < nGraphs {dotSize.append(dotSize[0])}
                if lineType.count < nGraphs {lineType.append(lineType[0])}
                                
                // Dessin de la ligne
                var variableWidth = false
                var variableColor = false
                if extraData[n] != nil {
                    if extraData[n]!["linewidth"] != nil { variableWidth = true }
                    if extraData[n]!["linecolor"] != nil { variableColor = true }
                }
            
                if variableWidth || variableColor {
                    var x1 : CGFloat = 0
                    var y1 : CGFloat = 0
                    var outside = true
                    for (i,xVal) in xData.enumerated() {
                        let yVal = yData[i]
                        
                        let x = convert(xVal,n:0)
                        let y = convert(yVal,n:1)
                        if x>0 && y>0 {
                            if outside {
                                outside = false
                            } else {
                                let theLine = NSBezierPath()
                                if lineType[n] > 0 {
                                    let line = lineTypes[lineType[n]]
                                    theLine.setLineDash(line, count: line.count, phase: 1)
                                }
                                theLine.lineWidth = variableWidth ? extraData[n]!["linewidth"]![i] as! CGFloat : lineWidth[n]
                                if variableColor {
                                    (extraData[n]!["linecolor"]![i] as! NSColor).set()
                                } else {
                                    lineColor[n].set()
                                }
                                if theLine.lineWidth == 0 {
                                    NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0).set()
                                }
                                theLine.move(to: NSPoint(x: x1, y: y1))
                                theLine.line(to: NSPoint(x: x, y: y))
                                theLine.stroke()
                            }
                        } else {
                            outside = true
                        }
                        x1 = x
                        y1 = y
                    }
                
                } else if histogram[n] {
                    let theLine = NSBezierPath()
                    if lineType[n] > 0 {
                        let line = lineTypes[lineType[n]]
                        theLine.setLineDash(line, count: line.count, phase: 1)
                    }
                    theLine.lineWidth = lineWidth[n]
                    let yzero = max(0,convert(0, n: 1))
                    var lastx : CGFloat = 0
                    var lasty : CGFloat = 0
                    for (k,xVal) in xData.enumerated() {
                        let x = convert(xVal,n:0)
                        let y = (k >= yData.count) ? 0 : convert(yData[k],n:1)
                        if k > 0 {
                            theLine.appendRect(NSRect(x: lastx, y: yzero, width: x-lastx, height: lasty-yzero))
                        }
                        lastx = x
                        lasty = y
                    }
                    if dotType[n] != "" {
                        dotColor[n].set()
                        theLine.fill()
                    }
                    lineColor[n].set()
                    if theLine.lineWidth > 0 { theLine.stroke() }

                    
                    
                } else if lineWidth[n] > 0 {
                    let theLine = NSBezierPath()
                    if lineType[n] > 0 {
                        let line = lineTypes[lineType[n]]
                        theLine.setLineDash(line, count: line.count, phase: 1)
                    }
                    theLine.lineWidth = lineWidth[n]
                    lineColor[n].set()
                    var outside = true
                    for (i,xVal) in xData.enumerated() {
                        let x = convert(xVal,n:0)
                        let y = convert(yData[i],n:1)
                        if x>0 && y>0 {
                            if outside {
                                outside = false
                                theLine.move(to: NSPoint(x: x, y: y))
                            } else {
                                theLine.line(to: NSPoint(x: x, y: y))
                            }
                        } else {
                            outside = true
                        }
                    }
                    theLine.stroke()
                }
                
                // Dessin des dots
                if dotType[n] != ""  && !histogram[n] {
                    var dotCounter = dotInterval[n]
                    var ptsCounter = 0
                    
                    var theXSize = dotSize[n]
                    var theYSize = dotSize[n]
                    var theColor = dotColor[n]
                    
                    var variableSize : [CGFloat]? = nil
                    var xerror : [Double]? = nil
                    var yerror : [Double]? = nil
                    var dotColors : [NSColor] = []
                    
                    if extraData[n]?["dotsize"] != nil { variableSize = extraData[n]!["dotsize"]! as? [CGFloat] }
                    if extraData[n]?["xerror"] != nil { xerror = extraData[n]!["xerror"]! as? [Double] }
                    if extraData[n]?["yerror"] != nil { yerror = extraData[n]!["yerror"]! as? [Double] }
                    if extraData[n]?["dotcolor"] != nil { dotColors = extraData[n]!["dotcolor"]! as! [NSColor] }

                    for (i,xVal) in xData.enumerated() {
                        if dotCounter >= dotInterval[n] {
                            dotCounter = 0
                            let x = convert(xVal,n:0)
                            let y = convert(yData[i],n:1)
                            if x>0 && y>0 {
                              
                                if variableSize != nil {
                                    theXSize = (i < variableSize!.count) ? variableSize![i] : variableSize![0]
                                    theYSize = theXSize
                                }
                                if xerror != nil {
                                    theXSize = intervalConvert((i < xerror!.count) ?
                                                                xerror![i] : xerror![0] ,n: 0)
                                }
                                if yerror != nil {
                                    theYSize = intervalConvert((i < yerror!.count) ?
                                                                yerror![i] : xerror![0] ,n: 0)
                                }
                                theColor = (i < dotColors.count) ? dotColors[i] : dotColor[n]
                            
                            drawDot(x: x, y: y, type: dotType[n], width: theXSize, height: theYSize, color: theColor)
                            }
                        } else {
                            dotCounter = dotCounter + 1
                        }
                        ptsCounter = ptsCounter + 1
                    }
                }

            }
        }
        
        // Tracé d'un barplot
        if barData != nil {
            let nGraphs = barData!.count
            let nG = histoStacked ? CGFloat(0) : CGFloat(nGraphs)
            let nData = CGFloat(barData![0].count) // nombre de colonnes dans chaque graphe
            var largeur : CGFloat // distance entre les bords gauches de deux 1ères colonnes successives
            var lBarre : CGFloat // largeur d'une colonne
            
            if histoStacked {
                lBarre = (histoOrientation == "V" ? axesRect.width : axesRect.height ) / ( nData + nData * histoS2)
                largeur = lBarre * (1 + histoS2)
            } else {
                lBarre = (histoOrientation == "V" ? axesRect.width : axesRect.height ) / ( nData * nG + nData * (nG-1) * histoS1 + nData * histoS2)
                largeur = nG * lBarre + (nG-1) * lBarre * histoS1 + lBarre * histoS2
            }
            
            let mainMin = axesMinMax![histoOrientation == "V" ? 1 : 0].asDoubles![0]
            let mainMax = axesMinMax![histoOrientation == "V" ? 1 : 0].asDoubles![1]
            
            let theBottom = max(0.0,mainMin)
            let mainAxis = (histoOrientation == "V") ? 1 : 0
            var stackStart = Array(repeating: convert(theBottom, n: mainAxis), count: barData![0].count)
            var prevVals = Array(repeating: 0.0, count: barData![0].count)
            
            histoRects = []
            for n in 0...(nGraphs-1) {
                let theData = barData![n]
                if lineWidth.count < nGraphs {lineWidth.append(lineWidth[0])}
                if lineColor.count < nGraphs {lineColor.append(lineColor[0])}
                
                let theLine = NSBezierPath()
                theLine.lineWidth = lineWidth[n]
                lineColor[n].set()
                histoRects.append([])
                if histoOrientation == "V" {
                    var startx = histoStacked ?
                        axesRect.minX + lBarre * histoS2 / 2 :
                        axesRect.minX + CGFloat(n) * lBarre * (1+histoS1) + lBarre * histoS2 / 2
                    for (k,aValue) in theData.enumerated() {
                        let newVal = histoStacked ? aValue + prevVals[k] : aValue
                        prevVals[k] = newVal
                        let top = max(min(mainMax,newVal),mainMin)
                        let topConverted = convert(top, n: 1)
                        let height = topConverted -  stackStart[k]
                        let theRect = NSRect(x: startx, y: stackStart[k], width: lBarre, height: height)
                        theLine.appendRect(theRect)
                        histoRects[n].append(theRect)
                        if histoStacked { stackStart[k] = topConverted }
                        startx = startx + largeur
                    }
                } else {
                    var starty = histoStacked ?
                        axesRect.minY + lBarre * histoS2 / 2 :
                        axesRect.minY + CGFloat(n) * lBarre * (1+histoS1) + lBarre * histoS2 / 2
                    let zeroX = convert(0.0, n: 0)
                    for (k,aValue) in theData.enumerated()  {
                        let width = histoStacked ? max(0,convert(aValue,n: 0) - zeroX) : convert(aValue,n: 0) - zeroX
                        let theRect = NSRect(x: stackStart[k], y: starty, width: width, height: lBarre)
                        theLine.appendRect(theRect)
                        histoRects[n].append(theRect)
                        if histoStacked { stackStart[k] = stackStart[k] + width }
                        starty = starty  + largeur
                    }
                }

                if theLine.lineWidth > 0 { theLine.stroke() }
                theLine.fill()
            }
            // affichage des labels du barplot
            if histoOrientation == "V" {
                var startx = axesRect.minX + largeur/2
                for lab in histoLabels {
                    let size = lab.size(withAttributes: labelAttributes)
                    let posx = startx - size.width/2
                    if axesPos[0] == "max" {
                        lab.draw(at: CGPoint(x: posx, y :xAxis + ticksSize + labelSpace), withAttributes: labelAttributes)
                    } else {
                        lab.draw(at: CGPoint(x: posx, y :xAxis - ticksSize - labelSpace - size.height), withAttributes: labelAttributes)
                    }
                    startx = startx + largeur
                }
            } else {
                var starty = axesRect.minY + largeur/2
                for lab in histoLabels {
                    let size = lab.size(withAttributes: labelAttributes)
                    let posy = starty - size.height/2
                    if axesPos[1] == "max" {
                        lab.draw(at: CGPoint(x :yAxis + ticksSize + labelSpace, y: posy), withAttributes: labelAttributes)
                    } else {
                        lab.draw(at: CGPoint(x :yAxis - ticksSize - labelSpace - size.width,y: posy), withAttributes: labelAttributes)
                    }
                    starty = starty + largeur
                }
            }

        }
    }
    
    // détermine l'élément du graphe qui se trouve au point mouse
    func clickedElement(mouse: NSPoint) -> String {
        // détermination de l'élément cliqué
        if NSRect(x: axesRect.minX, y: axesRect.minY-10, width: axesRect.width,height: 12).contains(mouse) {
            return("x") // axe X
        }
        if NSRect(x: axesRect.minX, y: axesRect.minY-20, width: axesRect.width,height: 10).contains(mouse) {
            return("labx") // labels de l'axe x
        }
        if NSRect(x: axesRect.minX-10, y: axesRect.minY, width: 12, height: axesRect.height).contains(mouse) {
            return("y") // axe Y
        }
        if NSRect(x: axesRect.minX-20, y: axesRect.minY, width: 10, height: axesRect.height).contains(mouse) {
            return("laby") // labels de l'axe Y
        }
        if mainTitle != "" {
            if NSRect(x: frameRect.minX + CGFloat(frameRect.width / 2) - (titleSize.width / 2), y: frameRect.maxY - space2 - titleSize.height, width: titleSize.width, height: titleSize.height).contains(mouse) {
                return("title")
            }
        } else {
            if NSRect(x: axesRect.minX, y: axesRect.maxY, width: axesRect.width, height: space).contains(mouse) {
                return("title")
            }
        }
        if axesTitles[0] != "" {
            if NSRect(x: axesRect.minX, y: frameRect.minY + space + legendHeight, width: axesRect.width, height: CGFloat(15)).contains(mouse) {
                return("titlex")
            }
        } else {
            if NSRect(x: axesRect.minX, y: frameRect.minY, width: axesRect.width, height: space).contains(mouse) {
                return("titlex")
            }
        }
        if axesTitles[1] != "" {
            if NSRect(x: frameRect.minX + space, y: axesRect.minY, width: CGFloat(15), height: axesRect.height).contains(mouse) {
                return("titley")
            }
        } else {
            if NSRect(x: frameRect.minX, y: axesRect.minY, width: space, height: axesRect.height).contains(mouse) {
                return("titley")
            }
        }
        if xyData != nil {
            for (n,onePlot) in xyData!.enumerated() {
                if histogram[n] == true {
                    let thexVals = onePlot[0].asDoubles!
                    for (i,yVal) in onePlot[1].asDoubles!.enumerated() {
                        let x1 = convert(thexVals[i], n: 0)
                        let x2 = convert(thexVals[i+1], n: 0)
                        let y = convert(yVal, n: 1)
                        if x1>0 && x2>0 && y>0 {
                            if abs(y-mouse.y) < 5 && mouse.x >= x1 && mouse.x < x2 { return String(n)}
                        }
                    }
                } else {
                    if onePlot[0].values.count > 500 {
                        return String(n)
                    }
                    for (i,xVal) in onePlot[0].asDoubles!.enumerated() {
                        let yVal = onePlot[1].asDoubles![i]
                        let x = convert(xVal, n: 0)
                        let y = convert(yVal, n: 1)
                        if x>0 && y>0 {
                            let dis = abs(x-mouse.x) + abs(y-mouse.y)
                            if dis < 5 { return String(n)}
                        }
                    }
                }
            }
        } else if barData != nil {
            for n in 0...(barData!.count-1) {
                for k in 0...(barData![0].count-1) {
                    if histoRects.count == 0 { return "" }
                    if histoRects[n][k].contains(mouse) {
                        return String(n)
                    }
                }
            }
        }
        if axesRect.contains(mouse) { return "background"}
        return "graph"
    }
    
    // Dessin d'un point (dot) du graphe
    func drawDot(x: CGFloat, y: CGFloat, type: String, width: CGFloat, height: CGFloat, color: NSColor) {
        color.set()
        let theDotLine = NSBezierPath()
        switch type {
        case "○", "●" :
            theDotLine.appendOval(in: NSRect(x: x-width/2, y: y-height/2, width: width, height: height))
        case "□", "■" :
            theDotLine.appendRect(NSRect(x: x-width/2, y: y-height/2, width: width, height: height))
        case "△", "▲":
            theDotLine.move(to: NSPoint(x: x-width/2, y: y-height/3))
            theDotLine.line(to: NSPoint(x: x, y: y+height*2/3))
            theDotLine.line(to: NSPoint(x: x+width/2, y: y-height/3))
            theDotLine.line(to: NSPoint(x: x-width/2, y: y-height/3))
        case "▽", "▼":
            theDotLine.move(to: NSPoint(x: x-width/2, y: y+height/3))
            theDotLine.line(to: NSPoint(x: x, y: y-height*2/3))
            theDotLine.line(to: NSPoint(x: x+width/2, y: y+height/3))
            theDotLine.line(to: NSPoint(x: x-width/2, y: y+height/3))
        case "◇", "◆" :
            theDotLine.move(to: NSPoint(x: x - width/2, y: y))
            theDotLine.line(to: NSPoint(x: x, y: y - height/2))
            theDotLine.line(to: NSPoint(x: x + width/2, y: y))
            theDotLine.line(to: NSPoint(x: x, y: y + height/2))
            theDotLine.line(to: NSPoint(x: x-width/2, y: y))
        case "x" :
            theDotLine.move(to: NSPoint(x: x - width/2, y: y-height/2))
            theDotLine.line(to: NSPoint(x: x + width/2, y: y + height/2))
            theDotLine.move(to: NSPoint(x: x - width/2, y: y+height/2))
            theDotLine.line(to: NSPoint(x: x + width/2, y: y - height/2))
        default: // une croix
            theDotLine.move(to: NSPoint(x: x, y: y-height/2))
            theDotLine.line(to: NSPoint(x: x, y: y+height/2))
            theDotLine.move(to: NSPoint(x: x-width/2, y: y))
            theDotLine.line(to: NSPoint(x: x+width/2, y: y))
        }
        if ["●","■","▲","▼","◆"].contains(type) {
            theDotLine.fill()
        } else {
            theDotLine.stroke()
        }
    }
    
    // Convertit un intervalle d de l'axe n en intervalle CGFloat pour l'affichage
    func intervalConvert(_ d: Double, n: Int) -> CGFloat {
        var axesLimits : [(min:Double, max: Double)] = []
        if axesMinMax != nil {
            axesMinMax!.forEach({ oneLim in
                let limVals = oneLim.asDoubles!
                axesLimits.append((min: limVals[0], max: limVals[1]))
            })
        }
        let dx = d /  (axesLimits[n].max - axesLimits[n].min)
        if n == 0 {
            return CGFloat(dx) * axesRect.width
        } else {
            return CGFloat(dx) * axesRect.height
        }
    }
    
    // retourne les limites d'axe (en doubles)
    func axesLim(_ j:Int) -> (min: Double, max: Double) {
        if axesMinMax != nil {
            let lims = axesMinMax![j].asDoubles!
            return (min: lims[0], max: lims[1])
        }
        return (min:0, max: 1)
    }
        
    // spécifie les limite d'axe (en physvalues)
    func setPhvalLims(_ j: Int, min: PhysValue, max: PhysValue) {
        if axesMinMax == nil {
            let defaultLims = PhysValue(unit: Unit(), type: "double", values: [0,1])
            axesMinMax = [defaultLims,defaultLims.dup()]
        }
        axesMinMax![j] = min
        axesMinMax![j].addElement(max.asDouble!)
    }
    
    // modifie les valeurs limite (l'unité ne change pas !)
    func setDoubleLims(_ j: Int, min: Double, max: Double) {
        axesMinMax![j].values = [min,max]
    }
    
    // Convertit une coordonnée pour l'axe n (0 = x, 1 = y) (retourne 0 si hors limites)
    func convert(_ x: Double, n: Int) -> CGFloat {
        let dx = (x - axesLim(n).min) / (axesLim(n).max - axesLim(n).min)
        if dx < 0 || dx > 1 { return 0}
        if n == 0 {
            return axesRect.minX + CGFloat(dx) * axesRect.width
        } else {
            return axesRect.minY + CGFloat(dx) * axesRect.height
        }
    }
    
    // retourne l'échelle d'un axe : rapport entre espace écran et espace réel (points/unité fondamentale de l'axe)
    func axisScale(n: Int) -> Double {
        if n == 0 {
            return Double(axesRect.width)/(axesLim(n).max-axesLim(n).min)
        } else {
            return Double(axesRect.height)/(axesLim(n).max-axesLim(n).min)
        }
    }
    
    // Recherche de limites et subdivision automatiques pour la courbe n et l'axe j (inutilisé pour l'instant)
    func autoLimit(n: Int, j: Int, k: Int = 4) {
        var max : Double = -1e-99
        var min : Double = 1e99
        var unit : Unit = Unit()
        if barData != nil {
            max = barData![n].max()!
            min = barData![n].min()!
        } else if xyData != nil {
            let onePlot = xyData![n]
            min = onePlot[j].asDoubles!.min()!
            if histogram[n] { min = (min > 0) ? 0 : min }
            max = onePlot[j].asDoubles!.max()!
            if histogram[n] { max = (max < 0) ? 0 : max }
            unit = onePlot[j].unit
        }
        let auto = autoLimAndDivs(x1: min, x2: max, k: k)
        self.axesDivs[j] = auto.dx
        self.axesSubDivs[j] = Int(round(auto.dx/auto.ddx))
        self.axesMinMax![j] = PhysValue(unit: unit, type: "double", values: [auto.min,auto.max])
    }
    
    // Recherche de limites et subdivision automatiques pour l'axe j
    func autoLimits(j: Int, k: Int = 4) {
        var max : Double = -1e-99
        var min : Double = 1e99
        var unit : Unit = Unit()
        if barData != nil {
            if histoStacked {
                var stackedData = Array(repeating: 0.0, count: barData![0].count)
                for datan in barData! {
                    for (k,oneData) in datan.enumerated() {
                        stackedData[k] = stackedData[k] + oneData
                    }
                }
                max = stackedData.max()!
                min = stackedData.min()!
            } else {
                for datan in barData! {
                    let newMax = datan.max()!
                    max = newMax > max ? newMax : max
                    let newMin = datan.min()!
                    min = newMin < min ? newMin : min
                }
            }
            if min > 0 { min = 0 }
            if max < 0 { max = 0 }

        } else if xyData != nil {
            for (n,onePlot) in xyData!.enumerated() {
                let vals = onePlot[j].asDoubles!
                let nmin = vals.compactMap({ $0.isNaN || $0.isInfinite ? nil : $0 }).min()!
                let nmax = vals.compactMap({ $0.isNaN || $0.isInfinite ? nil : $0 }).max()!
                min = (min<nmin) ? min : nmin
                max = (max>nmax) ? max : nmax
                if histogram[n] {
                    min = (min > 0) ? 0 : min
                    max = (max < 0) ? 0 : max
                }
                unit = onePlot[j].unit
            }
        } else if fields != nil {
            for oneField in fields! {
                let origin = oneField.fieldOrigin!.asDoubles!
                let sizes = oneField.fieldSizes!.asDoubles!
                min = min < origin[j] ? min : origin[j]
                max = max > origin[j] + sizes[j] ? max : origin[j] + sizes[j]
            }
        }
        let mult = axesUnit![j].mult
        let auto = autoLimAndDivs(x1: min / mult, x2: max / mult, k: k)
        self.axesDivs[j] = auto.dx * mult
        self.axesSubDivs[j] = Int(round(auto.dx/auto.ddx))
        if self.axesMinMax == nil {
            self.axesMinMax = [PhysValue(),PhysValue()]
        }
        self.axesMinMax![j] = PhysValue(unit: unit, type: "double", values: [auto.min * mult,auto.max * mult])
    }
    
    
    func autoDivs(j: Int, k: Int = 4) {
        let mult = axesUnit![j].mult
        let auto = autoLimAndDivs(x1: axesLim(j).min / mult, x2: axesLim(j).max / mult, k: k)
        self.axesDivs[j] = auto.dx * mult
        self.axesSubDivs[j] = Int(round(auto.dx/auto.ddx))
        let unit = axesUnit?[j] ?? Unit()
        self.axesMinMax![j] = PhysValue(unit: unit, type: "double", values: [auto.min * mult,auto.max * mult])
    }
    
    func defaultHistoSettings(orientation : String = "V") {
                if orientation == "H" {
            self.tickLabels = [true,false]
            self.ticks = [(main:false,sub:false),(main:false,sub:false)]
            self.grids = [(main:true,sub:true),(main:false,sub:false)]
            self.lineColor = [NSColor.systemGreen,NSColor.systemGray]
            self.axesFrame = false
            self.axes = [false,false]
        } else {
            self.tickLabels = [false,true]
            self.ticks = [(main:false,sub:false),(main:false,sub:false)]
            self.grids = [(main:false,sub:false),(main:true,sub:true)]
            self.lineColor = [NSColor.systemGreen,NSColor.systemGray]
            self.axesFrame = false
            self.axes = [false,false]
        }
    }
    
    func addExtraData(n: Int = 0, dataType: String, data : [Any]) {
        if extraData[n] == nil {
            extraData[n] = [dataType: data]
        } else {
            extraData[n]![dataType] = data
        }
    }
    
    func removeExtraData(n: Int = 0, dataType: String) {
        if extraData[n] != nil {
            extraData[n]![dataType] = nil
        }
    }
    
    // fonction retournant le label d'un axe j pour la valeur x
    func tickLabel(_ dbVal: Double, j : Int) -> String {
        let x = axesUnit == nil ? dbVal : dbVal / axesUnit![j].mult
        var strVal = ""
        if axesLabsDigits[j] {
            decimalFormatter.usesSignificantDigits = true
            decimalFormatter.minimumSignificantDigits = 1
            decimalFormatter.maximumSignificantDigits = axesLabsPrecision[j]
        } else {
            decimalFormatter.usesSignificantDigits = false
            decimalFormatter.maximumFractionDigits = axesLabsPrecision[j]
        }
        if (axesLabsFormat[j] == "auto" && abs(x) > 0 && (abs(x) > 100000 || abs(x) < 0.00001))
                || axesLabsFormat[j] == "sci" {
            decimalFormatter.numberStyle = NumberFormatter.Style.scientific
            decimalFormatter.exponentSymbol = " e"
        } else {
            decimalFormatter.numberStyle = NumberFormatter.Style.decimal
        }
        strVal = decimalFormatter.string(from: x as NSNumber)!
        return strVal
    }
    
    // fonction permettant de dessiner l'élément n de la légende au point p
    func drawLegend(n: Int, p : NSPoint) {
        let w : CGFloat = 20
        let h : CGFloat = 12
        
        if barData != nil {
            let theLine = NSBezierPath()
            theLine.lineWidth = lineWidth[n]
            lineColor[n].set()
            let theRect = NSRect(x: p.x, y: p.y - h/2, width: w, height: h)
            theLine.appendRect(theRect)
            if theLine.lineWidth > 0 { theLine.stroke() }
            theLine.fill()
            
        } else {
            if lineWidth[n] > 0 {
                let theLine = NSBezierPath()
                if lineType[n] > 0 {
                    let line = lineTypes[lineType[n]]
                    theLine.setLineDash(line, count: line.count, phase: 1)
                }
                theLine.lineWidth = lineWidth[n]
                
                if histogram[n] {
                    theLine.appendRect(NSRect(x: p.x, y: p.y - h/2, width: w, height: h))
                    if dotType[n] != "" {
                        dotColor[n].set()
                        theLine.fill()
                    }
                } else {
                    theLine.move(to: NSPoint(x: p.x, y: p.y))
                    theLine.line(to: NSPoint(x: p.x+w, y: p.y))
                }
                lineColor[n].set()
                if theLine.lineWidth > 0 { theLine.stroke() }
            }
            
            if dotType[n] != ""  && !histogram[n] {
                var theXSize = dotSize[n]
                var theYSize = dotSize[n]
                var theColor = dotColor[n]
                
                var variableSize : [CGFloat]? = nil
                var xerror : [Double]? = nil
                var yerror : [Double]? = nil
                var dotColors : [NSColor] = []
                
                if extraData[n]?["dotsize"] != nil { variableSize = extraData[n]!["dotsize"]! as? [CGFloat] }
                if extraData[n]?["xerror"] != nil { xerror = extraData[n]!["xerror"]! as? [Double] }
                if extraData[n]?["yerror"] != nil { yerror = extraData[n]!["yerror"]! as? [Double] }
                if extraData[n]?["dotcolor"] != nil { dotColors = extraData[n]!["dotcolor"]! as! [NSColor] }
                
                if p.x>0 && p.y>0 {
                    if variableSize != nil {
                        theXSize = variableSize![0]
                        theYSize = theXSize
                    }
                    if xerror != nil {
                        theXSize = intervalConvert(xerror![0],n: 0)
                    }
                    if yerror != nil {
                        theYSize = intervalConvert(yerror![0] ,n: 0)
                    }
                    if dotColors.count > 0 {
                        theColor = dotColors[0]
                    } else {
                        theColor = dotColor[n]
                    }
                    drawDot(x: p.x + w/2, y: p.y, type: dotType[n], width: theXSize, height: theYSize, color: theColor)
                }
            }
        }
    }
}
    
// Cette sous-classe de NSView peut afficher plusieurs graphes de la classe Grapher
class graphView: NSView {
    var theGraphs : [Grapher] = []
    var layout : (r: Int, c: Int) = (0,2) // nombre de rangs ou de colonnes imposé (ou libre si 0)
   
    override func draw(_ dirtyRect: NSRect) {
        //var context = NSGraphicsContext()
        
        super.draw(dirtyRect)
        NSEraseRect(self.bounds)
        
        var nr = layout.r
        var nc = layout.c
        if nr == 1 { nc = theGraphs.count }
        if nc == 1 { nr = theGraphs.count }
        if nr > 1 { nc = 1 + (theGraphs.count - 1) / nr
        } else if nc > 1 { nr = 1 + (theGraphs.count - 1) / nc }
        var gh : CGFloat = 1
        var gw : CGFloat = 1
        if nr > 0 && nc > 0 {
            gh = 1 / CGFloat(nr)
            gw = 1 / CGFloat(nc)
        }
        var ic : CGFloat = 0
        var ir : CGFloat = CGFloat(nr - 1)
        for aGraph in theGraphs {
            if nc > 0 && nr > 0 {
                aGraph.frameRect = NSRect(
                    x: bounds.minX + ic * gw * bounds.width,
                    y: bounds.minY + ir * gh * bounds.height,
                    width: gw * bounds.width,
                    height: gh * bounds.height
                )
            }
            aGraph.drawGraph()
            if ic < CGFloat(nc-1) {
                ic = ic + 1
            } else {
                ic = 0
                ir = ir - 1
            }
        }
    }
}

// Cette procédure retourne des limites min et max et une (sub)division plausible (de ±k valeurs) pour un axe allant (au moins) de x1 à x2
func autoLimAndDivs(x1: Double, x2: Double, k: Int = 4) -> (min: Double, max: Double, dx: Double, ddx: Double) {
    var max = x2
    var min = x1
    if min > max {
        min = x2
        max = x1
    }
    if min == max && min > 0 { min = 0 }
    if min == max && min < 0 { max = 0 }
    if min == 0 && max == 0 {
        min = -1
        max = 1
    }
    let cible = (max-min)/Double(k) // valeur cible de l'intervalle
    let ordre = log10(cible) // ordre de grandeur du dx
    var dx = pow(10.0,Double(round(ordre))) // une valeur plausible en puissance de 10
    var ecart = abs(10*dx - cible)
    let ms : [Double] = [10, 5, 2.5, 2, 1, 0.5, 0.25, 0.2, 0.1]
    let sms: [Double] = [0.2,1,0.5,0.5,0.2,0.1,0.05,0.05,0.02]
    var best = 0
    for n in 1...8  {
        if abs(ms[n]*dx - cible) < ecart {
            ecart = abs(ms[n] * dx - cible)
            best = n
        }
    }
    let ddx = dx * sms[best]
    dx = dx * ms[best]
    
    if min < 0 {
        let test = -dx * trunc(abs(min)/dx)
        if test <= min { min = test }
        else { min = -dx * (trunc(abs(min)/dx) + 1) }
    } else {
        min = dx * trunc(abs(min)/dx)
    }
    if max < 0 {
        max = -dx * trunc(abs(max)/dx)
    } else {
        let test = dx * trunc(abs(max)/dx)
        if test >= max { max = test }
        else { max = dx * (trunc(abs(max)/dx) + 1) }
    }
    return (min: min, max: max, dx: dx, ddx: ddx)
 }


func drawVector(x0: CGFloat, y0: CGFloat, vx: CGFloat, vy: CGFloat, color: NSColor) {
    let v = sqrt(vx*vx+vy*vy)
    if v == 0 { return }
    let dx = 2*vx/v
    let dy = 2*vy/v
    let x1 = x0 + vx - dx
    let y1 = y0 + vy - dy
    let theLine = NSBezierPath()
    theLine.move(to: NSPoint(x: x0, y: y0))
    theLine.line(to: NSPoint(x: x1 + dx, y: y1 + dy ))
    theLine.line(to: NSPoint(x: x1 + dy, y: y1 - dx))
    theLine.move(to: NSPoint(x: x1 + dx, y: y1 + dy ))
    theLine.line(to: NSPoint(x: x1 - dy, y: y1 + dx))

    color.setStroke()
    theLine.lineWidth = 1.0
    theLine.stroke()
}
