//
//  EquationView.swift
//  testCalc1
//
//  Created by Nico on 13/08/2019.
//  Copyright © 2019 Nico Hirtt. All rights reserved.
//

import Cocoa

var espace1: CGFloat = 3 // espace élémentaire entre éléments de l'expression
var espaceConnecteur : CGFloat = 10 // espace entre connecteur et expression
var defaulthMargin : CGFloat = 12 // demi esoace par défaut entre blocs
var defaultvMargin : CGFloat = 1  // demi esoace par défaut entre blocs
var defaultFrameMargin : CGFloat = 4 // espace par défaut pour l'encadrement
var margin : CGFloat = 10 // espace entre expression et cadre

let exponentSizeFactor : CGFloat = 0.75
var decimalFormatter = NumberFormatter()
var defaultFormatter = NumberFormatter()
var maxNumberValuesShown : Int = 10 // un nombre entier pair !

let theFontNames = ["Arial", "Avenir", "Baskerville", "Courier", "Euclid", "Garamond", "Helvetica", "Optima", "Palatino", "Times", "Verdana"]
var defaultFont : NSFont = NSFont(name: "Times", size: 14)!

var defaultTextColor : NSColor = NSColor(named: NSColor.Name("customTextColor"))!
var selectionColor : NSColor = NSColor(named: NSColor.Name("customSelectionColor"))!
var selectionBkgndColor : NSColor = NSColor(named: NSColor.Name("customSelectionBkgndColor"))!
var mouseColor : NSColor = NSColor(named: NSColor.Name("customMouseColor"))!
var defaultGraphBkgnd : NSColor = NSColor(named: NSColor.Name("defaultGraphBkgnd"))!

var varItalic = true // noms de variables en italique ?font
var varFontMask = varItalic ? NSFontTraitMask.italicFontMask : NSFontTraitMask.unitalicFontMask
var fontSize = 14
var defaultSettings : [String : Any] = [
    "textcolor":defaultTextColor,
    "font":defaultFont,
    "format": "auto",
    "digits": true,
    "precision": 4,
    "unit": Unit()
]
var controlOps = ["button","slider","popup","menu","hslider","cslider","stepper","vslider","image","imagebox","checkbox","table","text", "input","radiobuttons"]

var defaultNumberPrecision : Int = 4

// il est impératif que les entrées à deux caractères précèdent
var greekLetters : [String:String] = ["y":"υ","Y":"Υ","è":"η","et":"η","e":"ε","r":"ρ","th":"θ","t":"τ","i":"ι","o":"ο","a":"α","s":"σ","d":"δ","ph":"𝜑","f":"φ","g":"γ","h":"ħ","x":"ξ","kh":"χ","k":"κ","l":"λ","z":"ζ","ch":"χ","ps":"ψ","p":"π","w":"ω","b":"β","n":"ν","m":"μ","ET":"Η","E":"Ε","R":"Ρ","TH":"Θ","T":"Τ","I":"Ι","O":"Ο","A":"Α","S":"Σ","D":"Δ","F":"Φ","PH":"Φ","G":"Γ","X":"Ξ","KH":"Χ","K":"Κ","L":"Λ","Z":"Ζ","CH":"Χ","PS":"Ψ","P":"Π","W":"Ω","B":"Β","N":"Ν","M":"Μ"]


// La sous-classe de NSView qui permet d'afficher une (ou des) expression hiérarchique contenue(s) dans thePage
class EquationView: NSView {
    
    var thePage = HierarchicExp()
    var trackingArea : NSTrackingArea?
    var isMainView : Bool = false
    

    
    override func updateTrackingAreas() {
        if trackingArea != nil {
            self.removeTrackingArea(trackingArea!)
        }
        let options : NSTrackingArea.Options =
            [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options,
                                      owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }
    

    override var acceptsFirstResponder: Bool {
        return true
    }
        
    override func keyDown(with event: NSEvent) {
        mainCtrl.manageKeyEvent(event: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        mainCtrl.manageMouseMoved(event: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        if self == mainCtrl.theEquationView {
            mainCtrl.manageMouseDown(event: event)
        } else if self == mathTabCtrl.panelEquationView {
            mathTabCtrl.manageMouseDown(event: event)
        } else {
            print("another view ??")
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        mainCtrl.manageMouseDragged(event: event)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        thePage.setOrigin(NSPoint(x: margin, y: self.bounds.height - margin) )
        if isMainView {
            drawPage(thePage) // provisoirement...
            let theViewScale = theMainDoc!.viewScale
            let width = max(thePage.draw!.size.width + 20,self.superview!.bounds.width)/theViewScale
            let height = max(thePage.draw!.size.height + 30,self.superview!.bounds.height)/theViewScale
            self.frame.size = NSSize(width: width, height: height)
        } else {
            decimalFormatter = defaultFormatter.copy() as! NumberFormatter
            calcOrDraw(thePage, drawIt: false, settings: defaultSettings)
            defaultTextColor.set()
            calcOrDraw(thePage, drawIt: true, settings: defaultSettings)
        }
    }
    
    // convertit les coordonnées fenêtre en coordonnées d/Volumes/DD4To/Backups.backupdb/iMac Pro (2)/2022-09-08-162529/Macintosh HD - Données/Users/nicohirtt/Downloads/Nouveau dossier contenant des élémentsu view
    func getViewPoint(winPoint : NSPoint) -> NSPoint {
        let vPoint = self.convert(winPoint, from: mainCtrl.windowView)
        return vPoint
    }
    
}



// cherche l'expression hiérarchique la plus basse contenant le point atPoint. nil si c'est rien ou la page
func getEquation(atPoint: NSPoint, inExp: HierarchicExp) -> HierarchicExp? {
    if inExp.theRect == nil { return nil }
    if inExp.theRect!.contains(atPoint) || inExp.op == "_page"  {
        for arg in inExp.args {
            let t = getEquation(atPoint: atPoint, inExp: arg)
            if t != nil  { return t! }
        }
        if inExp.result != nil {
            let t = getEquation(atPoint: atPoint, inExp: inExp.result!)
            if t != nil { return t! }
        }
        if inExp.op == "_page" {return nil}
        return inExp
    }
    return nil
}

// Dessin d'une page
func drawPage(_ thePage: HierarchicExp) {
      
       
    // Et on commence l'affichage
    varFontMask = varItalic ? NSFontTraitMask.italicFontMask : NSFontTraitMask.unitalicFontMask
    decimalFormatter = defaultFormatter.copy() as! NumberFormatter
    let settings = thePage.drawSettings ?? [:]

    // On calcule d'abord toutes les dimensions...
    calcOrDraw(thePage, drawIt: false, settings: settings)
    
    // ...et puis on dessine
    defaultTextColor.set()
    calcOrDraw(thePage,drawIt: true, settings: settings)
    
    // Dessin du fond de la sélection
    if selectedEquation != nil && mainCtrl.selectionHighlite {
        let inset : CGFloat = controlOps.contains(selectedEquation!.op) ? 0 : -4
        if selectedEquation!.theRect == nil {return}
        let theRect =  selectedEquation!.isAncestor ? selectedEquation!.theRect!.insetBy(dx: inset, dy: inset) : selectedEquation!.theRect!
        if selectedEquation!.isScalable {
            let resizeDot = NSBezierPath(rect: selectedEquation!.resizingDotRect!)
            selectionColor.setFill()
            resizeDot.fill()
        }
        let cadre = NSBezierPath(rect: theRect)
        if selectedEquation!.op == "_edit" {
            if selectedEquation!.string == "" {
                NSColor.textColor.setFill()
            } else {
                return
            }
        } else {
            selectionBkgndColor.setFill()
        }
        if selectedEquation!.view == nil && !["plot", "lineplot", "scatterplot", "histogram", "barplot"].contains(selectedEquation!.op) {
            cadre.fill()
        }
        selectionColor.set()
        cadre.stroke()

    }
    if mainCtrl.multiSelection.count > 0 {
        var x0 : CGFloat = mainCtrl.theEquationView.frame.height
        var y0 : CGFloat = mainCtrl.theEquationView.frame.width
        var x1 : CGFloat = 0
        var y1 : CGFloat = 0
        mainCtrl.multiSelection.forEach({ hexp in
            if hexp.theRect != nil {
                let r = hexp.theRect!
                x0 = min(x0,r.minX)
                x1 = max(x1,r.maxX)
                y0 = min(y0,r.minY)
                y1 = max(y1,r.maxY)
            }
        })
        let theRect = NSRect(x: x0, y: y0, width: x1-x0, height: y1-y0)
        let cadre = NSBezierPath(rect: theRect)
        selectionColor.setFill()
        cadre.fill()
    }

    // opérations sous la souris
    let mouseEquation = mainCtrl.mouseEquation
    if mouseEquation != nil {
        // Dessin du cadre de l'équation sous la souris
        if mouseEquation != nil && mainCtrl.mouseTimer.isValid && mainCtrl.mouseHighlite {
            if !["plot","lineplot","scatterplot"].contains(mouseEquation!.op) {
                let inset : CGFloat = controlOps.contains(mouseEquation!.op) ? 0 : -4
                let theRect =  mainCtrl.mouseEquation!.isAncestor ? mainCtrl.mouseEquation!.theRect?.insetBy(dx: inset, dy: inset) : mainCtrl.mouseEquation!.theRect
                let cadre = NSBezierPath(rect: theRect!)
                mouseColor.set()
                cadre.stroke()
            }
        }
        // désactivation d'un contrôle si la touche ctrl est enfoncée
        if controlOps.contains(mouseEquation!.op) && mouseEquation!.view != nil {
            switch mouseEquation!.op {
            case "text":
                (mouseEquation!.view as! NSTextView).isHidden = NSEvent.modifierFlags.contains(.option)
            case "table":
                (mouseEquation!.view as! ekTableScrollView).isHidden = NSEvent.modifierFlags.contains(.option)
            default:
                (mouseEquation!.view as! NSControl).isEnabled = !NSEvent.modifierFlags.contains(.option)

            }
        }
    }
      
    // Dessin des limites de zone d'impression
    if showPageLimits {
        let paperSize = NSPrintInfo.shared.paperSize
        let theWidth = (paperSize.width - 20)/theMainDoc!.printScale - 10
        let theHeight = (paperSize.height - 20)/theMainDoc!.printScale - 10
        let Vline = NSBezierPath()
        Vline.move(to: NSPoint(x: theWidth, y: mainCtrl.theEquationView.frame.height * theMainDoc!.viewScale))
        Vline.line(to: NSPoint(x: theWidth, y: 0))
        var theyPos = mainCtrl.theEquationView.frame.height * theMainDoc!.viewScale - theHeight
        while theyPos > 0 {
            Vline.move(to: NSPoint(x: 0, y: theyPos))
            Vline.line(to: NSPoint(x: theWidth, y: theyPos))
            theyPos = theyPos - theHeight
        }
        NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.5).set()
        Vline.stroke()
    }
    
    return
    
}


// Calcule les dimensions (size et offset) d'une équation (ou la dessine si drawIt = true)
func calcOrDraw(_ hierExp: HierarchicExp, drawIt: Bool, settings: [String:Any]) {
    
    var op = hierExp.op
    if op == "" { return }
    
    var newSettings = settings
    
    if hierExp.father == nil {
        hierExp.resetFathers()
    }
    
    if hierExp.draw == nil {
        hierExp.draw = HierDraw()
        if op.hasPrefix("_UI") {
            let theDraw = HierDraw()
            theDraw.settings = ["framewidth":1, "framefillcolor":NSColor.darkGray]
            hierExp.draw = theDraw
        }
        hierExp.draw!.eqnPosition = nil
    }
    
    var font =  settings["font"] as! NSFont
    if hierExp.font != nil {
        font = hierExp.font!
        newSettings["font"] = font
    }
    espace1 = font.pointSize * 3 / 14
    var textColor = settings["textcolor"] as! NSColor
    if hierExp.textColor != nil {
        textColor = hierExp.textColor!
        newSettings["textcolor"] = textColor
    }
    let textAttributes = [NSAttributedString.Key.font : font,
                          NSAttributedString.Key.foregroundColor: textColor]
    var frameMargin : CGFloat = defaultFrameMargin
    var origin = hierExp.origin // le coin supérieur gauche de l'expression - l'axe y va de bas en haut !!
    var theSize: NSSize = NSSize(width: 0, height: 0) // dimension de l'expression, cadre compris
    var innerSize : NSSize = NSSize(width: 0, height: 0) // dimension de l'expression, sans cadre
    var theTop : CGFloat = 0   // distance entre ligne de base et sommet du rectangle (ou du cadre éventuel)
    var theBottom : CGFloat = 0 // idem en bas
    var theWidth : CGFloat = 0 // avec les cadres et connecteurs
    var theHeight : CGFloat =  0
    var innerWidth : CGFloat = 0 // sans les cadres et connecteurs
    var innerHeight : CGFloat = 0
    var calcHeight : CGFloat = 0 // hauteur sans tenir compte du résultat
    var calcOffset : CGFloat = 0
    
    var parWidth : CGFloat = 0 // largeur des parenthèses
    var omitLeftMember : Bool = false
    
    // connectorOffset et eqnPosition ne contiennent de valeurs que si la colonne du grid est de type "equation" (et si connecteur pour le premier cas)
    if !drawIt {
        hierExp.draw!.connectorOffset = nil
        hierExp.draw!.eqnPosition = nil
    }
    
    if drawIt {
        theSize = hierExp.size
        innerSize = hierExp.innerSize
        theTop = hierExp.offset
        theWidth = theSize.width
        theHeight = theSize.height
        theBottom = theSize.height - theTop
        innerWidth = innerSize.width
        innerHeight = innerSize.height
        calcHeight = hierExp.draw!.calcHeight
        calcOffset = hierExp.draw!.calcOffset
        var frameW = theWidth // le cadre
        if op == "_hblock" { innerWidth = theWidth }

        // Dessin du connecteur, du cadre et du fond
        if hierExp.drawSettingForKey(key: "connector") != nil {
            let theConnector = hierExp.drawSettingForKey(key: "connector") as! String
            if theConnector == "=" && hierExp.op == "=" { omitLeftMember = true }
            let opSize = (theConnector as NSString).size(withAttributes: textAttributes)
            let basey = origin.y - theTop
            theConnector.draw(at: NSPoint(x: origin.x, y: basey - opSize.height * 1/3), withAttributes: textAttributes)
            
            var espace : CGFloat
            if hierExp.draw!.connectorOffset != nil { // cas particulier des grid de type "equation"
                espace = espaceConnecteur + hierExp.draw!.connectorOffset! + opSize.width
            } else if hierExp.father!.op == "_grid" && ((hierExp.father! as? HierGrid)?.rows == 1) {
                espace = espaceConnecteur + 2*(hierExp.father! as! HierGrid).hMargin
            } else {
                espace = espaceConnecteur
            }
            origin.x = origin.x + opSize.width + espace
            frameW = theWidth - espace
 
         } else if hierExp.draw!.eqnPosition != nil {
             origin.x = origin.x + (hierExp.draw?.connectorOffset ?? 0)
            frameW = theWidth - hierExp.draw!.eqnPosition!
        }
        
        // Dessin du fond
        if hierExp.drawSettingForKey(key: "framefillcolor") != nil {
            let x1 = origin.x
            let y2 = origin.y - theHeight
            (hierExp.drawSettingForKey(key: "framefillcolor") as! NSColor).setFill()
            NSBezierPath.fill(NSRect(origin: NSPoint(x: x1, y: y2), size: NSSize(width: frameW, height: theHeight)))
        }
        // Dessin du cadre et ajustement des tailles
        if hierExp.drawSettingForKey(key: "framewidth") != nil && hierExp.op != "_grid" {
            let x1 = origin.x
            let y2 = origin.y - theHeight
            NSBezierPath.defaultLineWidth = CGFloat( hierExp.drawSettingForKey(key: "framewidth") as! Int)
            defaultTextColor.set()
            if hierExp.drawSettingForKey(key: "framecolor") != nil {
                (hierExp.drawSettingForKey(key: "framecolor") as! NSColor).set()
            }
            NSBezierPath.stroke(NSRect(origin: NSPoint(x: x1, y: y2), size: NSSize(width: frameW, height: theHeight)))
            
            NSBezierPath.defaultLineWidth = 1
            defaultTextColor.set()
            frameMargin = hierExp.drawSettingForKey(key: "framemargin") as? CGFloat ?? defaultFrameMargin
            theTop = theTop - frameMargin
            theBottom = theBottom - frameMargin
            origin.x = origin.x + frameMargin // où on va inscrire le contenu
            origin.y = origin.y - frameMargin
        } else if hierExp.op != "_grid" {
            frameMargin = 0
/*
            frameMargin = hierExp.drawSettingForKey(key: "framemargin") as? CGFloat ?? 0
            theTop = theTop - frameMargin
            theBottom = theBottom - frameMargin
            origin.x = origin.x + frameMargin // où on va inscrire le contenu
            origin.y = origin.y - frameMargin
 */
        } else {
            frameMargin = 0
        }
        
        if calcOffset < theTop {
            origin.y = origin.y + calcOffset - theTop
        }
    } else {
        if hierExp.drawSettingForKey(key: "connector") != nil {
            let theConnector = hierExp.drawSettingForKey(key: "connector") as! String
            if theConnector == "=" && hierExp.op == "=" { omitLeftMember = true }
        }

    }
    
    var thePoint = origin // coordonnées variables du point de dessin
    //var thisWidth : CGFloat = 0 // largeur interne de l'élément en cours de calcul
    
    // Dessin des parenthèses ouvrantes
    if drawIt {
        var parType = ""
        if hierExp.drawSettingForKey(key: "leftpar") != nil {
            parType = hierExp.drawSettingForKey(key: "leftpar") as! String
        }
        if hierExp.draw!.pars {parType = "("}
        if hierExp.father != nil {
            if hierExp.father!.op == "@" && hierExp.argInFather == 1 { parType = "{" }
        }
        if parType != "" {
            parWidth = drawParenthesis(at: thePoint, height: innerHeight, close: false, type: parType, drawIt: drawIt, settings: newSettings)

            thePoint.x = thePoint.x + parWidth + espace1
        }
    }
    
    // initialisation éventuelle des views de contrôles
    if controlOps.contains(op) {
        if hierExp.view == nil {
            // si on vient d'ouvrir le document
            let r = hierExp.executeHierarchicScript()
            // s'il y a une erreur, on ne crée pas le view !
            if r.type == "error" {
                op = "error : " + op
            }
        }
    }
    
    if omitLeftMember { op = "_omitLeftMember"}
    
    // Aiguillage principal
    var passe : Bool = false
    if op == "transpose" && hierExp.nArgs == 1 { op = "transexp" }
    switch op {
        
    case "text" : // bloc de texte
        if passe { fallthrough }
        if hierExp.result == nil { // sinon, c'est une erreur de syntaxe !
            if !hierExp.isError {
                let theTextView = hierExp.view as! NSTextView
                // si on a changé de page
                if hierExp.view!.superview == nil { mainCtrl.theEquationView.subviews.append(theTextView)}
                if !drawIt {
                    hierExp.viewSize = theTextView.frame.size
                    innerWidth = theTextView.frame.width+2
                    let height = theTextView.frame.height+2
                    theTop = height/2
                    theBottom = height/2
                } else {
                    let theTextView = hierExp.view as! NSTextView
                    theTextView.frame.origin = NSPoint(x: origin.x+1, y: origin.y - theTextView.frame.height - 1)
                    thePoint.x = thePoint.x + hierExp.innerSize.width
                }
            }
        }

    case "table" :
        if passe { fallthrough }
        if hierExp.result == nil { // sinon, c'est une erreur de syntaxe !
            if !hierExp.isError {
                let theTable = hierExp.view as! ekTableScrollView
                if hierExp.view!.superview == nil { mainCtrl.theEquationView.subviews.append(theTable)}
                if !drawIt {
                    hierExp.viewSize = theTable.frame.size
                    innerWidth = theTable.frame.width+2
                    let height = theTable.frame.height+2
                    theTop = height/2
                    theBottom = height/2
                } else {
                    theTable.frame.origin = NSPoint(x: origin.x+1, y: origin.y - theTable.frame.height - 1)
                    thePoint.x = thePoint.x + hierExp.innerSize.width
                    theTable.theTable.reloadData()
                }
            }
        }
    
    case "button", "checkbox", "popup", "menu" :
        if passe { fallthrough }
        if hierExp.result == nil { // sinon, c'est une erreur de syntaxe !
            if !hierExp.isError {
                let theButton = hierExp.view as! NSButton
                if hierExp.view!.superview == nil { mainCtrl.theEquationView.subviews.append(theButton)}
                if !drawIt {
                    hierExp.viewSize = theButton.frame.size
                    innerWidth = theButton.frame.width+2
                    let height = theButton.frame.height+2
                    theTop = height/2
                    theBottom = height/2
                } else {
                    theButton.frame.origin = NSPoint(x: origin.x+1, y: origin.y - theButton.frame.height - 1)
                    thePoint.x = thePoint.x + hierExp.innerSize.width
                    if op == "checkbox" {
                        let variable = hierExp.getArg(name: "var", n: 0)?.string ?? "?"
                        if theVariables[variable]?.asBool == nil {
                            theVariables[variable] = PhysValue(boolVal: false)
                        }
                        setBtnState(theButton, set: theVariables[variable]!.asBool!)
                    }
                }
            }
        }
    
    case "input" :
        if passe { fallthrough }
        if !hierExp.isError {
            let thefield = hierExp.view as! NSTextField
            if hierExp.view!.superview == nil {
                mainCtrl.theEquationView.subviews.append(thefield)
            }
            let varName = hierExp.getArg(name: "var", n: 0)?.string ?? "?"
            let label = hierExp.getArg(name: "label", n: 6)?.value?.asString ?? varName
            let labelSize = sizeOfText(label, settings: newSettings)
            if !drawIt {
                hierExp.viewSize = thefield.frame.size
                innerWidth = labelSize.width + espace1 + thefield.frame.width + 2
                let height = thefield.frame.height+2
                theTop = height/2
                theBottom = height/2
            } else {
                (label as NSString).draw(at: NSPoint(x: thePoint.x, y: origin.y - thefield.frame.height / 2 - labelSize.height/2), withAttributes: textAttributes)
                thefield.frame.origin = NSPoint(x: origin.x + 1 + labelSize.width + espace1, y: origin.y - thefield.frame.height - 1)
                thePoint.x = thePoint.x + hierExp.innerSize.width
            }
        }

    
    case "slider", "hslider", "vslider", "cslider"  :
        if passe { fallthrough }
        if !hierExp.isError {
            let theSlider = hierExp.view as! NSSlider
            if hierExp.view!.superview == nil {
                mainCtrl.theEquationView.subviews.append(theSlider)
            }
            let varName = hierExp.getArg(name: "var", n: 0)?.string ?? "?"
            let label = hierExp.getArg(name: "label", n: 6)?.value?.asString ?? varName
            let labelSize = sizeOfText(label, settings: newSettings)
            if !drawIt {
                hierExp.viewSize = theSlider.frame.size
                innerWidth = labelSize.width + espace1 + theSlider.frame.width + 2
                let height = theSlider.frame.height+2
                theTop = height/2
                theBottom = height/2
            } else {
                (label as NSString).draw(at: NSPoint(x: thePoint.x, y: origin.y - theSlider.frame.height / 2 - labelSize.height/2), withAttributes: textAttributes)
                theSlider.frame.origin = NSPoint(x: origin.x + 1 + labelSize.width + espace1, y: origin.y - theSlider.frame.height - 1)
                thePoint.x = thePoint.x + hierExp.innerSize.width
            }
        }
    
    case "stepper"  :
        if passe { fallthrough }
        if !hierExp.isError {
            let theStepper = hierExp.view as! NSStepper
            let stepperSize = theStepper.frame.size
            if hierExp.view!.superview == nil {
                mainCtrl.theEquationView.subviews.append(theStepper)
            }
            let varName = hierExp.getArg(name: "var", n: 0)?.string ?? "?"
            let label = hierExp.getArg(name: "label", n: 6)?.value?.asString ?? varName
            let labelSize = sizeOfText(label, settings: newSettings)
            if !drawIt {
                hierExp.viewSize = stepperSize
                innerWidth = labelSize.width + espace1 + stepperSize.width + 2
                let height = stepperSize.height+2
                theTop = height/2
                theBottom = height/2
            } else {
                label.draw(at: NSPoint(x: thePoint.x, y: origin.y - stepperSize.height / 2 - labelSize.height/2), withAttributes: textAttributes)
                theStepper.frame.origin = NSPoint(x: origin.x + 1 + labelSize.width + espace1, y: origin.y - stepperSize.height - 1)
                thePoint.x = thePoint.x + hierExp.innerSize.width
                theStepper.doubleValue = theVariables[varName]?.asDouble ?? theStepper.minValue
            }
        }
    
        
    case "image", "imagebox" :
        if passe { fallthrough }
        if hierExp.result == nil { // sinon, c'est une erreur de syntaxe !
            if !hierExp.isError {
                // si on vient d'ouvrir le document
                var theImageView = NSImageView()
                if hierExp.view != nil {
                    theImageView = hierExp.view as! NSImageView
                    if hierExp.view!.superview == nil { mainCtrl.theEquationView.subviews.append(theImageView)}
                }
                // si on a changé de page
                if !drawIt {
                    innerWidth = theImageView.frame.width+2
                    let height = theImageView.frame.height+2
                    theTop = height/2
                    theBottom = height/2
                } else {
                    theImageView.frame.origin = NSPoint(x: origin.x+1, y: origin.y - theImageView.frame.height - 1)
                    thePoint.x = thePoint.x + hierExp.innerSize.width
                    hierExp.image = theImageView.image
                }
            }
        }
        
        
    case "_page" :
        if passe { fallthrough }
        (hierExp.args)[0].setOrigin( hierExp.origin ) // Le premier bloc est au sommet à gauche...
        for arg in hierExp.args {
            calcOrDraw(arg, drawIt: drawIt, settings: newSettings)
            theTop = max(theTop,origin.y-arg.origin.y + arg.size.height)
            theWidth = max(theWidth,arg.draw!.size.width)
        }
        theBottom = 0
    
    case "_grid" :
        if passe { fallthrough }
        let theGrid : HierGrid = hierExp as! HierGrid
        let nCols = theGrid.cols
        let nRows = theGrid.rows
        theGrid.testGrid()
    
        if hierExp.nArgs == 0 { return }
        
        if !drawIt {
            theGrid.rowOffsets = Array(repeating: 0, count: nRows)
            hierExp.args.forEach({ arg in
                calcOrDraw(arg, drawIt: false, settings: newSettings)
            })
            // largeur de chaque colonne
            var maxColWidth : CGFloat = 0 // plus grande colonne si gridWidths = "equal"
            (0..<nCols).forEach({ col in
                var colWidth : CGFloat = 0
                // alignement sur l'égalité des équations dans une colonne de grid
                if theGrid.hAligns[col] == "equation" {
                    var leftWidth : CGFloat = 0 // espace maximal à gacuhe de l'égalité
                    var rightWidth : CGFloat = 0 // espace maximal à droite
                    // calcul de ces deux espaces (la valeur eqnPosition de chaque élément est calculée dans la phase !draw)
                    (0..<nRows).forEach({ row in
                        let n = row * nCols + col
                        let totalWidth = hierExp.args[n].size.width //- espaceConnecteur
                        if hierExp.args[n].op == "=" {
                            leftWidth = max(leftWidth, hierExp.args[n].draw!.eqnPosition ?? leftWidth)
                            rightWidth = max(rightWidth, totalWidth-leftWidth)
                        } else {
                            rightWidth = max(rightWidth, totalWidth)
                        }
                    })
                    colWidth = leftWidth + rightWidth + 2 * theGrid.hMargin
                    // 2e passage pour ajuster les dimensions
                    (0..<nRows).forEach({ row in
                        let n = row * nCols + col
                        hierExp.args[n].draw!.connectorOffset = leftWidth - (hierExp.args[n].draw!.eqnPosition ?? 0)
                        hierExp.args[n].draw!.size.width = leftWidth + rightWidth
                    })
                     
                } else {
                    (0..<nRows).forEach({ row in
                        let n = row * nCols + col
                        colWidth = max(colWidth, hierExp.args[n].size.width + 2 * theGrid.hMargin)
                        hierExp.args[n].draw!.eqnPosition = nil
                    })
                }
                maxColWidth = max(maxColWidth,colWidth)
                if theGrid.gridWidth == "fit"  { theGrid.colWidths[col] = colWidth }
            })
            if theGrid.gridWidth == "equal" {
                theGrid.colWidths = Array(repeating: maxColWidth, count: nCols)
            }
            if theGrid.islineGrid && !theGrid.showGrid && theGrid.hAligns[0] == "left"{
                theGrid.colWidths[0] = theGrid.colWidths[0] - theGrid.hMargin
                theGrid.colWidths[nCols-1] = theGrid.colWidths[nCols-1] - theGrid.hMargin
            }
            if theGrid.isBaseGrid && !theGrid.showGrid {
                theGrid.colWidths[0] = theGrid.colWidths[0] - theGrid.hMargin
                theGrid.colWidths[nCols-1] = theGrid.colWidths[nCols-1] - theGrid.hMargin
            }
            innerWidth = theGrid.colWidths.reduce(0, { x, y in x + y })
            // hauteur de chaque rang
            var maxRowHeight : CGFloat = 0 // le plus haut rang
            var rowBottoms: [CGFloat] = []
            (0..<nRows).forEach({ row in
                var rowHeight : CGFloat = 0
                var rowsTop : CGFloat = 0
                var rowsBottom: CGFloat = 0
                (0..<nCols).forEach({ col in
                    let n = row * nCols + col
                    let arg = hierExp.args[n]
                    rowHeight = max(rowHeight, arg.size.height + 2 * theGrid.vMargin)
                    rowsTop = max(rowsTop ,arg.offset)
                    rowsBottom = max(rowsBottom , arg.size.height - arg.offset)
                })
                if theGrid.vAligns[row] == "baseline" {
                    rowHeight = rowsTop + rowsBottom +  2 * theGrid.vMargin }
                maxRowHeight = max(maxRowHeight,rowHeight)
                if theGrid.gridHeight == "fit" { theGrid.rowHeights[row] = rowHeight }
                theGrid.rowOffsets[row] = rowsTop
                rowBottoms.append(rowsBottom)
            })
            if theGrid.gridHeight == "equal" {
                theGrid.rowHeights = Array(repeating: maxRowHeight, count: nRows)
                (0..<nRows).forEach({ row in
                    theGrid.rowOffsets[row] = theGrid.rowOffsets[row] * theGrid.rowHeights[row] / (theGrid.rowOffsets[row] + rowBottoms[row] + 2 * theGrid.vMargin)
                })
            }
            theHeight = theGrid.rowHeights.reduce(0, { x, y in x + y })
            
            if nRows == 1 && theGrid.vAligns[0] == "baseline" {
                theTop = theGrid.rowOffsets[0]
                theBottom = theHeight - theTop
            } else {
                theTop = theHeight / 2
                theBottom = theHeight / 2
            }
            
        } else {
            var theDrawPoint = thePoint
            
            var x0 = thePoint.x
            (0..<nCols).forEach({ col in
                var y0 = thePoint.y
                (0..<nRows).forEach({ row in
                    let n = row * nCols + col
                    let arg = hierExp.args[n]
                    
                    switch theGrid.vAligns[row] {
                    case "top" :
                        theDrawPoint.y = y0 - theGrid.vMargin
                    case "bottom" :
                        theDrawPoint.y = y0 - theGrid.rowHeights[row] + arg.size.height + theGrid.vMargin
                    default :
                        theDrawPoint.y = y0 - theGrid.vMargin - theGrid.rowOffsets[row] + arg.offset
                    }
                    
                    switch theGrid.hAligns[col] {
                    case "right" :
                        theDrawPoint.x = x0 + theGrid.colWidths[col] - arg.size.width - theGrid.hMargin
                    case "center" :
                        theDrawPoint.x = x0 + (theGrid.colWidths[col] - arg.size.width) / 2
                    //case "equation" :
                    //    theDrawPoint.x = x0 + theGrid.eqnPositions![col] - hierExp.args[n].draw!.eqnPosition!
                    default :
                        if theGrid.islineGrid && !theGrid.showGrid && theGrid.hAligns[0] == "left" && col == 0 {
                            theDrawPoint.x = x0
                        } else {
                            theDrawPoint.x = x0 + theGrid.hMargin
                        }
                        if theGrid.isBaseGrid && !theGrid.showGrid {
                            theDrawPoint.x = x0
                        }
                    }
                    
                    arg.setOrigin( theDrawPoint )
                    calcOrDraw(arg, drawIt: true, settings: newSettings)
                    if theGrid.hAligns[col] == "equation" {
                        arg.setOrigin(NSPoint(x: x0 , y: theDrawPoint.y ))
                    }
                    y0 = y0 - theGrid.rowHeights[row]

                })
                x0 = x0 + theGrid.colWidths[col]

            
            /*
            var y0 = thePoint.y // la position supérieure du rang
            (0..<nRows).forEach({ row in
                var x0 = thePoint.x
                (0..<nCols).forEach({ col in
                    let n = row * nCols + col
                    let arg = hierExp.args[n]
                    
                    switch theGrid.vAligns[row] {
                    case "top" :
                        theDrawPoint.y = y0 - theGrid.vMargin
                    case "bottom" :
                        theDrawPoint.y = y0 - theGrid.rowHeights[row] + arg.size.height + theGrid.vMargin
                    default :
                        theDrawPoint.y = y0 - theGrid.vMargin - theGrid.rowOffsets[row] + arg.offset
                    }
                    
                    switch theGrid.hAligns[col] {
                    case "right" :
                        theDrawPoint.x = x0 + theGrid.colWidths[col] - arg.size.width - theGrid.hMargin
                    case "center" :
                        theDrawPoint.x = x0 + (theGrid.colWidths[col] - arg.size.width) / 2
                    default :
                        if theGrid.islineGrid && !theGrid.showGrid && theGrid.hAligns[0] == "left" && col == 0 {
                            theDrawPoint.x = x0
                        } else {
                            theDrawPoint.x = x0 + theGrid.hMargin
                        }
                        if theGrid.isBaseGrid && !theGrid.showGrid {
                            theDrawPoint.x = x0
                        }
                    }
                    
                    arg.setOrigin( theDrawPoint )
                    calcOrDraw(arg, drawIt: true, settings: newSettings)
                    x0 = x0 + theGrid.colWidths[col]
                })
                y0 = y0 - theGrid.rowHeights[row]
                */
                
            })
            if theGrid.showGrid == true {
                NSBezierPath.defaultLineWidth = CGFloat( hierExp.drawSettingForKey(key: "framewidth") as! Int)
                defaultTextColor.set()
                if hierExp.drawSettingForKey(key: "framecolor") != nil {
                    (hierExp.drawSettingForKey(key: "framecolor") as! NSColor).set()
                }
                // dessin du cadre extérieur
                NSBezierPath.stroke(NSRect(origin: NSPoint(x: thePoint.x, y: origin.y-theHeight), size: NSSize(width: innerWidth, height: theHeight)))
                // dessin de la grille
                var y0 = origin.y
                (0..<nRows-1).forEach({ row in
                    y0 = y0 - theGrid.rowHeights[row]
                    NSBezierPath.strokeLine(from: NSPoint(x: thePoint.x, y: y0), to: NSPoint(x: thePoint.x + innerWidth, y: y0))
                })
                var x0 = thePoint.x
                (0..<nCols-1).forEach({ col in
                    x0 = x0 + theGrid.colWidths[col]
                    NSBezierPath.strokeLine(from: NSPoint(x: x0, y: origin.y), to: NSPoint(x: x0, y: origin.y - theHeight))
                })
                NSBezierPath.defaultLineWidth = 1
                defaultTextColor.set()
            } else if mainCtrl.showGrids == true {
                NSBezierPath.defaultLineWidth = 0.5
                NSColor.lightGray.set()
                // dessin du cadre extérieur
                NSBezierPath.stroke(NSRect(origin: NSPoint(x: thePoint.x, y: origin.y-theHeight), size: NSSize(width: innerWidth, height: theHeight)))
                // dessin de la grille
                var y0 = origin.y
                (0..<nRows-1).forEach({ row in
                    y0 = y0 - theGrid.rowHeights[row]
                    NSBezierPath.strokeLine(from: NSPoint(x: thePoint.x, y: y0), to: NSPoint(x: thePoint.x + innerWidth, y: y0))
                })
                var x0 = thePoint.x
                (0..<nCols-1).forEach({ col in
                    x0 = x0 + theGrid.colWidths[col]
                    NSBezierPath.strokeLine(from: NSPoint(x: x0, y: origin.y), to: NSPoint(x: x0, y: origin.y - theHeight))
                })
                NSBezierPath.defaultLineWidth = 1
                defaultTextColor.set()
            }
            thePoint.x = thePoint.x + hierExp.innerSize.width
        }
    
    
    case "plot", "lineplot", "scatterplot", "barplot", "histogram", "histo"  :
        if hierExp.result != nil {
            calcOrDrawText(hierExp.stringExp(), hierExp: hierExp, drawIt: drawIt, settings: newSettings)
            innerWidth = hierExp.size.width
            theHeight = hierExp.size.height
            theTop = hierExp.offset
            theBottom = theHeight - theTop
            if drawIt {thePoint.x = thePoint.x + hierExp.innerSize.width}
        } else {
            let theGraph = hierExp.graph
            if theGraph == nil { return }
            if !drawIt {
                let graphRect = theGraph!.frameRect
                theTop = graphRect.size.height/2
                theBottom = graphRect.size.height/2
                innerHeight = theTop
                innerWidth = graphRect.size.width
            } else {
                hierExp.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y))
                var graphRect = theGraph!.frameRect
                graphRect.origin.x = thePoint.x
                graphRect.origin.y = thePoint.y - theGraph!.frameRect.height
                theGraph!.frameRect = graphRect
                theGraph!.drawGraph()
            }
        }
    
    case "_edit" :
        if passe { fallthrough }
        let text = hierExp.string ?? " "
        hierExp.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y))
        calcOrDrawText(text, hierExp: hierExp, drawIt: drawIt, settings: newSettings)
        innerWidth = hierExp.size.width
        theHeight = hierExp.size.height
        theTop = hierExp.offset
        theBottom = theHeight - theTop
        if drawIt {
            // dessin du point d'insertion
            
            if hierExp == mainCtrl.selectedEquation {
                let theRect = hierExp.theRect
                let cadre = NSBezierPath(rect: theRect!.insetBy(dx: 1, dy: 0))
                //mouseColor.setFill()
                //cadre.fill()
                mouseColor.set()
                cadre.stroke()
            }
            
            thePoint.x = thePoint.x + hierExp.innerSize.width
        }

        
    case "_val" :
        if passe { fallthrough }
        // test pour voir si on est dans le cas a+(-b) qu'on écrit a-b => le "-" a déjà été écrit !
        let testSum = (hierExp.father!.op == "+" && hierExp.argInFather > 0)
        let phVal = hierExp.value!
        let tempOrigin = hierExp.origin
        hierExp.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y))
        if testSum && phVal.values.count == 1 && (phVal.asDouble ?? 1) < 0 {
            let minPhVal = PhysValue(unit: phVal.unit, type: phVal.type, values: [-(phVal.asDouble!)], dim: [1], field: nil)
            calcOrDrawVal(minPhVal, hierExp : hierExp, drawIt: drawIt, settings: newSettings)

        } else {
            calcOrDrawVal(phVal, hierExp : hierExp, drawIt: drawIt, settings: newSettings)
        }
        hierExp.setOrigin(tempOrigin)
        innerWidth = hierExp.innerSize.width
        theHeight = hierExp.size.height
        theTop = hierExp.offset
        theBottom = theHeight - theTop
        if drawIt {thePoint.x = thePoint.x + hierExp.innerSize.width}
            
    case "label", "_err" :
        if passe { fallthrough }
        let text = hierExp.args[0].value?.asString ?? ""
        hierExp.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y))
        calcOrDrawText(text, hierExp: hierExp, drawIt: drawIt, settings: newSettings)
        innerWidth = hierExp.size.width
        theHeight = hierExp.size.height
        theTop = hierExp.offset
        theBottom = theHeight - theTop
        if drawIt {thePoint.x = thePoint.x + hierExp.innerSize.width}
        
    case "_var" :
        var italic = varItalic
        if passe { fallthrough }
        
        var varName = hierExp.string!
        if varName == "" {
            hierExp.string = "varname"
            varName = "varname"
        }
        // Détection d'un \ à la fin : vecteur
        var vector = false
        if varName.hasSuffix("\\") {
            vector = true
            varName.removeLast()
        }
        // Détection d'un "&"
        var bold = false
        if varName.contains("&") {
            bold = true
            varName = varName.replacingOccurrences(of: "&", with: "")
            italic = false
        }
        // s'il y a un (seul) chiffre à la fin, on ajoute "_" pour l'écrire en indice
        if varName.last!.isNumber && !varName.contains("_") {
            varName = varName.dropLast(1) + "_" + String(varName.last!)
        }
        
        let tempOrigin = hierExp.origin
        hierExp.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y))
        // détection d'une lettre grecque en début (un peu compliqué à cause des codes à deux caractères)
        if varName.hasPrefix("\\") {
            let sortedLetters = greekLetters.keys.sorted { $0.count > $1.count }
            sortedLetters.forEach({ lCode in
                let gLetter = greekLetters[lCode]!
                if varName.hasPrefix("\\" + lCode) {
                    varName = varName.replacingOccurrences(of: "\\" + lCode, with: gLetter)
                    italic = false
                }
            })
        }
        
        var varSettings = italic ?
            drawSettings( old: newSettings, new: ["trait": NSFontTraitMask.italicFontMask]) : newSettings
        if bold {
            varSettings =  drawSettings( old: newSettings, new: ["trait": NSFontTraitMask.boldFontMask])
        }

    
        
        // détection d'un indice
        if varName.contains("_") {
            let expSettings = drawSettings(old: varSettings, new: ["resize" : exponentSizeFactor])

            let splitted = varName.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: true)
            varName = String(splitted[0])
            let index = String(splitted[1])
            if !drawIt {
                let size1 = sizeOfText(varName, settings: varSettings)
                let size2 = sizeOfText(index, settings: expSettings)
                innerWidth = size1.width + size2.width
                theTop = size1.height * 2/3
                if vector { theTop = theTop + 2 * espace1 }
                theBottom = size1.height * 1/3 + size2.height/2
            } else {
                let size1 = sizeOfText(varName, settings: settings)
                let size2 = sizeOfText(index, settings: expSettings)
                if vector {
                    calcOrDrawVector(varName, hierExp: hierExp , drawIt: drawIt, settings: varSettings)
                    hierExp.setOrigin(NSPoint(x: thePoint.x + size1.width, y: thePoint.y - size1.height + size2.height/2 - 2 * espace1)) // position de l'index !
                } else {
                    calcOrDrawText(varName, hierExp: hierExp , drawIt: drawIt, settings: varSettings)
                    hierExp.setOrigin(NSPoint(x: thePoint.x + size1.width, y: thePoint.y - size1.height + size2.height/2)) // position de l'index !
                }
                calcOrDrawText(index, hierExp: hierExp , drawIt: drawIt, settings: expSettings)
                hierExp.setOrigin(tempOrigin)
                hierExp.setSize(NSSize(width: theWidth, height: theHeight))
                hierExp.setOffset(theTop)
                thePoint.x = thePoint.x + hierExp.innerSize.width
            }
            
        // variable ordinaire...
        } else {
            if vector {
                calcOrDrawVector(varName.replacingOccurrences(of: "\\", with: ""), hierExp: hierExp , drawIt: drawIt, settings: varSettings)
            } else {
                calcOrDrawText(varName, hierExp: hierExp , drawIt: drawIt, settings: varSettings)
            }
            hierExp.setOrigin(tempOrigin)
            if !drawIt {
                innerWidth = hierExp.size.width
                theHeight = hierExp.size.height
                theTop = hierExp.offset
                theBottom = theHeight - theTop
            } else {
                hierExp.setSize(NSSize(width: theWidth, height: theHeight))
                hierExp.setOffset(theTop)
                thePoint.x = thePoint.x + hierExp.innerSize.width
            }
        }

        
    case "#" :
        // élément d'un vecteur déterminé par son indice
        if passe { fallthrough }
        let expSettings = drawSettings(old: newSettings, new: ["resize" : exponentSizeFactor])
        
        let tempOrigin = hierExp.origin
        hierExp.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y))
        
        if !drawIt  {
            let arg1 = hierExp.args[0]
            let op1 = arg1.op
            if operatorsList.contains(op1) {
                arg1.setPars( true)
            } else {
                arg1.setPars( false)
            }
            let arg2 = hierExp.args[1]
            calcOrDraw(arg1, drawIt: false, settings: newSettings)
            calcOrDraw(arg2, drawIt: false, settings: expSettings)
            theTop = arg1.offset
            theBottom = arg1.size.height - arg1.offset + arg2.size.height/2
            innerWidth = arg1.size.width + arg2.size.width + arg1.size.height / 6
        } else {
            let arg1 = hierExp.args[0]
            let arg2 = hierExp.args[1]
            
            arg1.setOrigin( NSPoint(x: thePoint.x, y: hierExp.origin.y))
            arg2.setOrigin(NSPoint(x: thePoint.x + arg1.size.width + arg1.size.height / 6, y: hierExp.origin.y - arg1.size.height + arg2.size.height/2))
            
            calcOrDraw(arg1, drawIt: true, settings: newSettings)
            calcOrDraw(arg2, drawIt: true, settings: expSettings)
            
            hierExp.setOrigin(tempOrigin)
            hierExp.setSize(NSSize(width: theWidth, height: theHeight))
            hierExp.setOffset(theTop)
            thePoint.x = thePoint.x + hierExp.innerSize.width
        }

    case "_omitLeftMember" :
        if passe { fallthrough }
        let arg = hierExp.args[1]
        arg.setOrigin( thePoint )
        calcOrDraw( arg, drawIt: drawIt, settings: newSettings)
        theTop = arg.offset
        theBottom = arg.size.height - theTop
        innerWidth = arg.size.width
        
        
        
    case "==","<=","≤",">=","≥","<",">","!=","≠","=",",",":","+","*","•","**","***","@","∈", "%" :
        if passe { fallthrough }
        let opS = (op == ",") ? listSep : opSymb[(operatorsList.firstIndex(of: op)! as Int)]
        let opSize = (opS as NSString).size(withAttributes: textAttributes)
        if op == "," {hierExp.setPars(true)}
        if !drawIt {
            var c : Int = 0
            var previousOp = ""
            for arg in hierExp.args {
                let subOp = arg.op
                // On ajoute le "+" si nécessaire
                if c>0 {
                    if op == "+" && arg.op == "_minus" {
                        innerWidth = innerWidth + ("-" as NSString).size(withAttributes: textAttributes).width + espace1 * 3
                    } else if op == "+" && arg.op == "_val" {
                        if (arg.value!.asDouble ?? 1) < 0 {
                            innerWidth = innerWidth + ("-" as NSString).size(withAttributes: textAttributes).width + espace1 * 2
                        } else {
                            innerWidth = innerWidth + opSize.width + espace1 * 2
                        }
                    } else if op == "*" && previousOp == "_val" && arg.op != "_val" {
                        innerWidth = innerWidth + espace1 * 3/2
                    } else if op == "=" {
                        hierExp.draw!.eqnPosition = innerWidth + espace1
                        innerWidth = innerWidth + opSize.width + espace1 * 2
                    } else {
                        innerWidth = innerWidth + opSize.width + espace1 * 2
                    }
                }
                // on vérifie s'il faut des parenthèses
                arg.setPars( false )
                if operatorsList.contains(subOp) {
                    if (operatorsList.firstIndex(of: subOp)! as Int) < (operatorsList.firstIndex(of: op)! as Int) {
                        arg.setPars( true )
                    }
                }
                // On calcule les différents arguments
                calcOrDraw(arg, drawIt: false, settings: newSettings)
                let argSize = arg.size
                let argOffset = arg.offset
                innerWidth = innerWidth + argSize.width
                theTop = max(theTop , argOffset)
                theBottom = max(theBottom, argSize.height - argOffset)
                previousOp = arg.op
                c = c+1

            }
            
        } else {
            let basey = hierExp.origin.y - hierExp.offset
            var c : Int = 0
            var previousOp = ""
            for arg in hierExp.args {
                // On dessine le "+" si nécessaire
                if c>0 {
                    thePoint.x = thePoint.x + espace1
                    // test du cas spécial a+(-b) qui s'écrit a-b
                    if op == "+" && arg.op == "_minus" && c>0 {
                        thePoint.x = thePoint.x + espace1*0.5
                        ("-" as NSString).draw(at: NSPoint(x: thePoint.x, y: basey - opSize.height * 1/3), withAttributes: textAttributes)
                        thePoint.x = thePoint.x + opSize.width
                        thePoint.x = thePoint.x + espace1*0.5
                    } else if op == "+" && arg.op == "_val" {
                        if (arg.value!.asDouble ?? 1) < 0 {
                            ("-" as NSString).draw(at: NSPoint(x: thePoint.x, y: basey - opSize.height * 1/3), withAttributes: textAttributes)
                            thePoint.x = thePoint.x + opSize.width
                        } else {
                            (opS as NSString).draw(at: NSPoint(x: thePoint.x, y: basey - opSize.height * 1/3), withAttributes: textAttributes)
                            thePoint.x = thePoint.x + opSize.width + espace1
                        }
                    } else if op == "*" && previousOp == "_val" && arg.op != "_val" {
                        thePoint.x = thePoint.x + espace1/2
                    } else {
                        (opS as NSString).draw(at: NSPoint(x: thePoint.x, y: basey - opSize.height * 1/3), withAttributes: textAttributes)
                        thePoint.x = thePoint.x + opSize.width + espace1
                    }
                }
                c=c+1
                // on dessine l'argument
                arg.setOrigin( NSPoint(x: thePoint.x, y: basey + arg.offset) )
                calcOrDraw(arg, drawIt: true, settings: newSettings)
                thePoint.x = thePoint.x + arg.size.width
                previousOp = arg.op
            }
        }
    
    case "_setunit" :
        if passe { fallthrough }
        let arg1 = hierExp.getArg(name: "x", n: 0) ?? HierarchicExp(withText: "?")
        if arg1.op != "," && arg1.op != "_var" { arg1.setPars(true) }
        let arg2 = hierExp.getArg(name: "unit", n: 1) ?? HierarchicExp(withPhysVal: PhysValue(doubleVal: 0))
        let unitString = "[" + hierExp.args[1].value!.unit.name + "]"

        if !drawIt {
            // On calcule les différents arguments
            calcOrDraw(arg1, drawIt: false, settings: newSettings)
            let width1 = arg1.size.width
            let width2 = sizeOfText(unitString, settings: newSettings).width
            innerWidth = width1 + espace1 + width2
            theHeight = arg1.size.height
            theTop = arg1.offset
            theBottom = theHeight - theTop
        } else {
            arg1.setOrigin( NSPoint(x: thePoint.x, y: thePoint.y))
            calcOrDraw(arg1, drawIt: true, settings: newSettings)
            arg2.setOrigin( NSPoint(x: thePoint.x + arg1.size.width + espace1, y: thePoint.y))
            calcOrDrawText(unitString, hierExp: arg2, drawIt: true, settings: newSettings)
            thePoint.x = thePoint.x + innerWidth
        }
        
    case "/" :
        if passe { fallthrough }
        if hierExp.drawSettingForKey(key: "smalldiv") == nil {
            // si c'est un exposant -> petite division
            if hierExp.father!.op == "^" && hierExp.argInFather == 1 {
                hierExp.setSetting(key: "smalldiv", value: true)
            } else {
                hierExp.setSetting(key: "smalldiv", value: false)
            }
        }
        let arg1 = hierExp.args[0]
        let arg2 = hierExp.args[1]
        if hierExp.drawSettingForKey(key: "smalldiv") as! Bool == true {
            if !drawIt {
                // On calcule les différents arguments
                calcOrDraw(arg1, drawIt: false, settings: newSettings)
                calcOrDraw(arg2, drawIt: false, settings: newSettings)
                let barwidth = (arg1.size.height+arg2.size.height)/5
                innerWidth = arg1.size.width+arg2.size.width+barwidth
                theTop = arg1.size.height/2
                theBottom = arg2.size.height
            } else {
                let basey = origin.y - calcOffset + arg2.size.height/4
                let barwidth = (arg1.size.height+arg2.size.height)/5
                arg1.setOrigin( NSPoint(x: thePoint.x, y: thePoint.y ))
                arg2.setOrigin( NSPoint(x: thePoint.x + arg1.size.width + barwidth, y: basey))
                calcOrDraw(arg1, drawIt: true, settings: newSettings)
                calcOrDraw(arg2, drawIt: true, settings: newSettings)
                let divLine = NSBezierPath()
                divLine.move(to: NSPoint(x: thePoint.x + arg1.size.width-barwidth/4, y: basey - arg2.size.height*0.8
                                        ))
                divLine.line(to: NSPoint(x: thePoint.x + arg1.size.width + barwidth*3/4, y: basey))
                divLine.lineWidth = 1
                divLine.stroke()
                thePoint.x = thePoint.x + innerWidth
            }
        } else {
            if !drawIt {
                // On calcule les différents arguments
                calcOrDraw(arg1, drawIt: false, settings: newSettings)
                calcOrDraw(arg2, drawIt: false, settings: newSettings)
                let width1 = arg1.size.width
                let width2 = arg2.size.width
                innerWidth = max(width1,width2)
                theTop = arg1.size.height
                theBottom = arg2.size.height
            } else {
                let basey = origin.y - calcOffset
                arg1.setOrigin( NSPoint(x: thePoint.x + innerWidth / 2 - arg1.size.width / 2, y: thePoint.y))
                arg2.setOrigin( NSPoint(x: thePoint.x + innerWidth / 2 - arg2.size.width / 2, y: basey))
                calcOrDraw(arg1, drawIt: true, settings: newSettings)
                calcOrDraw(arg2, drawIt: true, settings: newSettings)
                let divLine = NSBezierPath()
                divLine.move(to: NSPoint(x: thePoint.x, y: basey))
                divLine.line(to: NSPoint(x: thePoint.x + innerWidth, y: basey))
                divLine.lineWidth = 1
                divLine.stroke()
                thePoint.x = thePoint.x + innerWidth
            }
        }
        
    case "deriv", "derivative" :
        passe = hierExp.result?.isError ?? false
        if passe { fallthrough }
        let expSettings = drawSettings(old: newSettings, new: ["resize" : exponentSizeFactor])
        let arg1 = hierExp.getArg(name: "f", n: 0) ?? HierarchicExp(withText: "?")
        let arg2 = hierExp.getArg(name: "x", n: 1) ?? HierarchicExp(withText: "?")
        let arg3 = hierExp.getArg(name: "at", n: 2) // la valeur pour laquelle on calcule f'(x)
           
        if arg1.op == "_var" {
            // type df/dx
            let dSize = ("d" as NSString).size(withAttributes: textAttributes)
            let dWidth = dSize.width + espace1/2
            if !drawIt {
                calcOrDraw(arg1, drawIt: false, settings: newSettings)
                calcOrDraw(arg2, drawIt: false, settings: newSettings)
                if arg3 != nil {
                    arg3!.setPars(true)
                    calcOrDraw(arg3!, drawIt: false, settings: newSettings)
                }
                let width1 = dWidth + arg1.size.width
                let width2 = dWidth + arg2.size.width
                let width3 = arg3 != nil ? arg3!.size.width + espace1 : 0
                innerWidth = max(width1,width2) + width3
                theTop = arg1.size.height + espace1
                theBottom = arg2.size.height + espace1
            } else {
                let basey = origin.y - calcOffset
                let width1 = dWidth + arg1.size.width
                let width2 = dWidth + arg2.size.width
                innerWidth = max(width1,width2)
                ("d" as NSString).draw(at: NSPoint(x: thePoint.x + innerWidth / 2 - arg1.size.width / 2 - dWidth / 2, y: thePoint.y - dSize.height), withAttributes: textAttributes)
                ("d" as NSString).draw(at: NSPoint(x: thePoint.x + innerWidth / 2 - arg2.size.width / 2 - dWidth / 2, y: basey - espace1 - dSize.height), withAttributes: textAttributes)
                   arg1.setOrigin( NSPoint(x: thePoint.x + innerWidth / 2 - arg1.size.width / 2 + dWidth / 2, y: thePoint.y))
                arg2.setOrigin( NSPoint(x: thePoint.x + innerWidth / 2 - arg2.size.width / 2 + dWidth / 2, y: basey - espace1))
                let fName = arg1.string!
                if theFunctions[fName] != nil {
                    calcOrDrawText(arg1.string!, hierExp: arg1, drawIt: true, settings: newSettings)
                } else {
                    calcOrDraw(arg1, drawIt: true, settings: newSettings)
                }
                calcOrDraw(arg2, drawIt: true, settings: newSettings)
                let divLine = NSBezierPath()
                divLine.move(to: NSPoint(x: thePoint.x, y: basey))
                divLine.line(to: NSPoint(x: thePoint.x + innerWidth, y: basey))
                divLine.lineWidth = 1
                divLine.stroke()
                thePoint.x = thePoint.x + innerWidth
                if arg3 != nil {
                    arg3!.setOrigin( NSPoint(x: thePoint.x + espace1, y: basey + arg3!.size.height / 2))
                    calcOrDraw(arg3!, drawIt: true, settings: newSettings)
                    innerWidth = innerWidth + arg3!.size.width
                    thePoint.x = thePoint.x + arg3!.size.width
                }
            }
        } else {
            // type d/dx(expression)
            let dSize = ("d" as NSString).size(withAttributes: textAttributes)
            let dWidth = dSize.width + espace1/2
            let varSize = arg3 != nil ? sizeOfText(arg2.string! + "=", settings: expSettings).width : 0
            if !drawIt {
                calcOrDraw(arg1, drawIt: false, settings: newSettings)
                calcOrDraw(arg2, drawIt: false, settings: newSettings)
                if arg3 != nil {
                    calcOrDraw(arg3!, drawIt: false, settings: expSettings)
                }
                let width1 = arg1.size.width
                let width2 = dWidth + arg2.size.width
                let width3 = arg3 != nil ? varSize + arg3!.size.width + espace1 : 0
                innerWidth = width1 + width2  +  2 * drawParenthesis(at: thePoint, height: calcHeight, close: false, type: "(", drawIt: false, settings: newSettings) + 4 * espace1 + width3
                theTop = dSize.height + espace1
                theBottom = arg2.size.height + espace1
                if theTop + theBottom < arg1.size.height {
                    theTop = arg1.offset
                    theBottom = arg1.size.height - theTop
                }
            } else {
                let basey = origin.y - calcOffset
                let width2 = dWidth + arg2.size.width
                let width3 = arg3 != nil ? arg3!.size.width + varSize : 0
                ("d" as NSString).draw(at: NSPoint(x: thePoint.x + width2 / 2 - dWidth / 2, y: basey + espace1), withAttributes: textAttributes)
                ("d" as NSString).draw(at: NSPoint(x: thePoint.x + width2 / 2 - arg2.size.width / 2 - dWidth / 2, y: basey - espace1 - dSize.height), withAttributes: textAttributes)
                arg2.setOrigin( NSPoint(x: thePoint.x + width2 / 2 - arg2.size.width / 2 + dWidth / 2, y: basey - espace1))
                calcOrDraw(arg2, drawIt: true, settings: newSettings)
                let divLine = NSBezierPath()
                divLine.move(to: NSPoint(x: thePoint.x, y: basey))
                divLine.line(to: NSPoint(x: thePoint.x + width2, y: basey))
                divLine.lineWidth = 1
                divLine.stroke()
      
                parWidth = drawParenthesis(at: NSPoint(x: thePoint.x + espace1 + width2, y: basey + arg1.offset), height: arg1.size.height, close: false, type: "(", drawIt: true, settings: newSettings)
                arg1.setOrigin( NSPoint(x: thePoint.x + width2 + 2 * espace1 + parWidth, y: basey + arg1.offset))
                calcOrDraw(arg1, drawIt: true, settings: newSettings)
                _ = drawParenthesis(at: NSPoint(x: thePoint.x + width2 + 3 * espace1 + arg1.size.width + espace1, y: basey + arg1.offset), height: arg1.size.height, close: true, type: "(", drawIt: true, settings: newSettings)
                thePoint.x = thePoint.x + innerWidth

                if arg3 != nil {
                    arg3!.setOrigin(NSPoint(x: thePoint.x - width3, y: basey - arg1.offset + arg3!.size.height - espace1))
                    calcOrDrawText(arg2.string! + "=", hierExp: arg3!, drawIt: true, settings: expSettings)
                    arg3!.setOrigin(NSPoint(x: thePoint.x - width3 + varSize, y: basey - arg1.offset + arg3!.size.height - espace1))
                    calcOrDraw(arg3!, drawIt: true, settings: expSettings)
                }

            }
        }
    
    case "integral", "integ" :
        passe = hierExp.result?.isError ?? false
        if passe { fallthrough }
        let expSettings = drawSettings(old: newSettings, new: ["resize" : exponentSizeFactor])

        let arg1 = hierExp.getArg(name: "f", n: 0) ?? HierarchicExp(withText: "?") // l'expression à dériver
        if arg1.op == "+" { arg1.setPars( true ) }
        let arg2 = hierExp.getArg(name: "x", n: 1) ?? HierarchicExp(withText: "?")// la variable de dérivation x
        let arg3 = hierExp.getArg(name: "from", n: 2)
        let arg4 = hierExp.getArg(name: "to", n: 3)
        let intsymb = "∫"
        let intFontName = "Euclid Symbol"
        let intFonts : [String:(size:CGFloat, xoffset: CGFloat, yoffset: CGFloat)] = [
            "Euclid Symbol":(0.8,1.0,1.0),
            "Apple SD Gothic Neo Thin":(0.8,1.0,1.0),
            "Helvetica Neue Thin":(0.8,1.0,1.0)  ,
            "Helvetica Neue UltraLight":(0.8,1.0,1.0) ,
            "Avenir Next Ultra Light Italic":(0.8,1.0,1.0)
        ]
        let intSizeFactor = intFonts[intFontName]!.size
        let intxoffset = intFonts[intFontName]!.xoffset
        let intyoffset = intFonts[intFontName]!.yoffset
        
        var intSettings = newSettings
        intSettings["font"] = NSFont(name: intFontName, size: 12)

        if !drawIt {
            calcOrDraw(arg1, drawIt: false, settings: newSettings)
            calcOrDraw(arg2, drawIt: false, settings: newSettings)
            theTop = arg1.offset + 2 * espace1
            theBottom = arg1.size.height - arg1.offset + 2 * espace1
            if arg3 != nil {
                calcOrDraw(arg3!, drawIt: false, settings: expSettings)
                calcOrDraw(arg4!, drawIt: false, settings: expSettings)
                theTop = theTop + arg4!.size.height
                theBottom = theBottom + arg3!.size.height
            }
            intSettings["font"] = NSFont(name: intFontName, size: (theTop + theBottom) * intSizeFactor)
            let intSize = sizeOfText(intsymb, settings: intSettings)
            
            innerWidth = intSize.width + espace1 + arg1.size.width + sizeOfText(" d", settings: newSettings).width + arg2.size.width
          
        } else {
            intSettings["font"] = NSFont(name: intFontName, size: (theTop + theBottom) * intSizeFactor)
            let intAttString = attStringForString(intsymb, settings: intSettings)
            intAttString.draw(at: NSPoint(x: thePoint.x, y: thePoint.y - (theTop + theBottom)*intyoffset))
            
            thePoint.x = thePoint.x + intAttString.size().width * intxoffset
            if arg3 != nil {
                arg4!.setOrigin(NSPoint(x: thePoint.x + 4 * espace1, y: thePoint.y))
                calcOrDraw(arg4!, drawIt: true, settings: expSettings)
                arg3!.setOrigin(NSPoint(x: thePoint.x - 2 * espace1, y: thePoint.y - hierExp.size.height + arg3!.size.height))
                calcOrDraw(arg3!, drawIt: true, settings: expSettings)
                thePoint.x = thePoint.x + espace1
                //arg1.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y - 2 * espace1 - arg4!.size.height))
                arg1.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y - theTop + arg1.offset))

            } else {
                thePoint.x = thePoint.x + espace1
                arg1.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y - 2 * espace1))
            }
            calcOrDraw(arg1, drawIt: true, settings: newSettings)

            thePoint.x = thePoint.x + arg1.size.width
            arg2.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y - theTop + arg2.offset))
            let dAttString = attStringForString(" d", settings: newSettings)
            calcOrDrawAttstring(dAttString, hierExp: arg2, drawIt: true)
            
            thePoint.x = thePoint.x+dAttString.size().width
            arg2.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y - theTop + arg2.offset))
            calcOrDraw(arg2, drawIt: true, settings: newSettings)
            
            thePoint.x = thePoint.x + arg2.size.width
        }
        
    case "^", "transexp" :
        if passe { fallthrough }
        let expSettings = drawSettings(old: newSettings, new: ["resize" : exponentSizeFactor])

        let arg1 = hierExp.args[0]
        let arg2 = (op == "transexp") ? HierarchicExp(withText: "𝒯") : hierExp.args[1]

        if !drawIt  {
            let op1 = arg1.op
            if operatorsList.contains(op1) && op1 != "#" {
                arg1.setPars( true)
            } else {
                arg1.setPars( false)
            }
            calcOrDraw(arg1, drawIt: false, settings: newSettings)
            calcOrDraw(arg2, drawIt: false, settings: expSettings)
            theTop = arg1.offset + arg2.size.height / 2 - espace1
            theBottom = arg1.size.height - arg1.offset
            innerWidth = arg1.size.width + arg2.size.width + arg1.size.height / 6
        } else {
            let basey = hierExp.origin.y - hierExp.offset
            arg1.setOrigin( NSPoint(x: thePoint.x, y: basey + arg1.offset))
            arg2.setOrigin(NSPoint(x: thePoint.x + arg1.size.width + arg1.size.height / 6, y: thePoint.y))
            calcOrDraw(arg1, drawIt: true, settings: newSettings)
            calcOrDraw(arg2, drawIt: true, settings: expSettings)
            thePoint.x = thePoint.x + innerWidth
        }
    
    case "exp" :
        if passe { fallthrough }
        let expSettings = drawSettings(old: newSettings, new: ["resize" : exponentSizeFactor])

        let opSize = ("e" as NSString).size(withAttributes: textAttributes)
        let arg1 = hierExp.args[0]
        if drawIt == false {
            calcOrDraw(arg1, drawIt: false, settings: expSettings)
            theTop = arg1.size.height + opSize.height * 1/4
            theBottom = opSize.height * 1/3
            innerWidth = opSize.width  + arg1.size.width + espace1
        } else {
            ("e" as NSString).draw(at: NSPoint(x: thePoint.x, y: thePoint.y - hierExp.size.height), withAttributes: textAttributes)
            arg1.setOrigin( NSPoint(x: thePoint.x + opSize.width + espace1, y: thePoint.y))
            calcOrDraw(arg1, drawIt: true, settings: expSettings)
            thePoint.x = thePoint.x + innerWidth
        }
        
    case "log" :
        if passe { fallthrough }
        let expSettings = drawSettings(old: newSettings, new: ["resize" : exponentSizeFactor])
        
        let opSize = ("log" as NSString).size(withAttributes: textAttributes)
        var pars = true
        let arg1 = hierExp.getArg(name: "a", n: 0) ?? HierarchicExp(withText: "?")
        let arg2 = hierExp.getArg(name: "x", n: 1) ?? HierarchicExp(withText: "?")
        if arg2.op == "_var" || arg2.op == "_val" { pars = false }
        
        if drawIt == false {
            innerWidth = opSize.width + espace1
            if pars { arg2.setPars( true) }
            calcOrDraw(arg1, drawIt: false, settings: expSettings)
            calcOrDraw(arg2, drawIt: false, settings: newSettings)
            theTop = arg2.offset
            theBottom = arg2.size.height + arg1.size.height / 2 - arg2.offset
            innerWidth = innerWidth + arg1.size.width + arg2.size.width + espace1
            
        } else {
            let basey = hierExp.origin.y - hierExp.offset
            let opSize = ("log" as NSString).size(withAttributes: textAttributes)
            (op as NSString).draw(at: NSPoint(x: thePoint.x, y: basey - opSize.height * 1/3), withAttributes: textAttributes)
            let startx = thePoint.x + opSize.width + espace1
            if pars { arg2.setPars( true) }
            arg1.setOrigin( NSPoint(x: startx, y: basey + opSize.height * 1/2 - arg1.offset))
            arg2.setOrigin(NSPoint(x: startx + espace1 + arg1.size.width, y: thePoint.y))
            calcOrDraw(arg1, drawIt: true, settings: expSettings)
            calcOrDraw(arg2, drawIt: true, settings: newSettings)
            thePoint.x = thePoint.x + innerWidth
        }
        
    case "_minus":
        if passe { fallthrough }
        let opSize = ("-" as NSString).size(withAttributes: textAttributes)
        let arg = hierExp.args[0]
        // test pour voir si on est dans le cas a+(-b) qu'on écrit a-b => le "-" a déjà été écrit !
        var testSum = false
        if hierExp.father!.op == "+" && hierExp.argInFather > 0 {
            testSum = true
        }
        if drawIt == false {
            calcOrDraw(arg, drawIt: false, settings: newSettings)
            if testSum {
                innerWidth = arg.size.width
            } else {
                innerWidth = opSize.width + espace1 + arg.size.width
            }
            theTop = max(theTop , arg.offset)
            theBottom = max(theBottom, arg.size.height - arg.offset)
            if ["==","<=",">=","<",">","!=","=",":","+","-"].contains(arg.op) {
                innerWidth = innerWidth +  2 * drawParenthesis(at: thePoint, height: theHeight, close: false, drawIt: false, settings: newSettings)
            }
        } else {
            let basey = hierExp.origin.y - hierExp.offset
            let opSize = ("-" as NSString).size(withAttributes: textAttributes)
            if !testSum {
                ("-" as NSString).draw(at: NSPoint(x: thePoint.x, y: basey - opSize.height * 1/3), withAttributes: textAttributes)
                thePoint.x = thePoint.x + opSize.width + espace1
            }
            if ["==","<=",">=","<",">","!=","=",":","+","-"].contains(arg.op) {
                let parWidth = drawParenthesis(at: NSPoint(x: thePoint.x, y: thePoint.y), height: theHeight, close: false, drawIt: true, settings: newSettings)
                thePoint.x = thePoint.x + parWidth
            }
            arg.setOrigin(NSPoint(x: thePoint.x, y: basey + arg.offset))
            calcOrDraw(arg, drawIt: true, settings: newSettings)
            thePoint.x = thePoint.x + arg.size.width
            if ["==","<=",">=","<",">","!=","=",":","+","-"].contains(arg.op) {
                _ = drawParenthesis(at: NSPoint(x: thePoint.x, y: thePoint.y), height: theHeight, close: true, drawIt: true, settings: newSettings)
            }
        }
        
    case "sqrt":
        if passe { fallthrough }
        if drawIt == false {
            let arg = hierExp.args[0]
            arg.setPars(false)
            calcOrDraw(arg, drawIt: false, settings: newSettings)
            theTop  = arg.offset + espace1
            theBottom = arg.size.height - arg.offset
            theHeight = theTop + theBottom
            innerWidth = arg.size.width + max(10 , theHeight / 4) + 2 * espace1
        } else {
            let sqrtWidth = max(10 , calcHeight / 4)
            let basey = hierExp.origin.y - hierExp.offset
            let arg = hierExp.args[0]
            arg.setOrigin(NSPoint(x: thePoint.x + sqrtWidth + espace1 , y: thePoint.y - espace1 ))
            calcOrDraw(arg, drawIt: true, settings: newSettings)
            let sqrtLine = NSBezierPath()
            sqrtLine.move(to: NSPoint(x: thePoint.x, y: basey))
            sqrtLine.line(to: NSPoint(x: thePoint.x + sqrtWidth/4, y: basey + calcOffset/4))
            sqrtLine.line(to: NSPoint(x: thePoint.x + sqrtWidth/2, y: thePoint.y - calcHeight + espace1))
            sqrtLine.line(to: NSPoint(x: thePoint.x + sqrtWidth, y: thePoint.y - espace1 ))
            sqrtLine.line(to: NSPoint(x: thePoint.x + innerWidth, y: thePoint.y - espace1))
            sqrtLine.line(to: NSPoint(x: thePoint.x + innerWidth, y: thePoint.y - 2*espace1))
            sqrtLine.lineWidth = 1
            sqrtLine.stroke()
            thePoint.x = thePoint.x + innerWidth
        }
        
    case "mean":
        if passe { fallthrough }
        if drawIt == false {
            let arg = hierExp.args[0]
            calcOrDraw(arg, drawIt: false, settings: newSettings)
            theTop  = arg.offset + espace1 / 2
            theBottom = arg.size.height - arg.offset
            theHeight = theTop + theBottom
            innerWidth = arg.size.width
        } else {
            let arg = hierExp.args[0]
            arg.setOrigin(NSPoint(x: thePoint.x , y: thePoint.y - espace1 / 2 ))
            calcOrDraw(arg, drawIt: true, settings: newSettings)
            let theLine = NSBezierPath()
            theLine.move(to: NSPoint(x: thePoint.x, y: thePoint.y))
            theLine.line(to: NSPoint(x: thePoint.x + innerWidth, y: thePoint.y))
            theLine.lineWidth = 1
            theLine.stroke()
            thePoint.x = thePoint.x + innerWidth
        }
        
        
    case "sum":
        if passe { fallthrough }
        let arg = hierExp.args[0]
        var iVar : HierarchicExp? = nil
        var indexes: HierarchicExp? = nil
        let expSettings = drawSettings(old: newSettings, new: ["resize" : exponentSizeFactor])
        let indexFontSize = (expSettings["font"] as! NSFont).pointSize

        var bottomXtra: CGFloat = 2.0
        var topXtra : CGFloat = 2.0
        var fromExp = HierarchicExp()
        var toExp = HierarchicExp()
        if hierExp.nArgs == 3 {
            iVar = hierExp.args[1]
            indexes = hierExp.args[2]
            if iVar!.op == "_var" {
                bottomXtra = indexFontSize + espace1
                if indexes!.op == ":" && indexes!.nArgs == 2 {
                    topXtra = indexFontSize + espace1
                    fromExp = HierarchicExp(withOp: "=", args: [iVar!, indexes!.args[0]])
                    toExp = indexes!.args[1]
                } else {
                    fromExp = HierarchicExp(withOp: "∈", args: [iVar!, indexes!])
                }
            }
        }
        if drawIt == false {
            calcOrDraw(arg, drawIt: false, settings: newSettings)
            theTop  = arg.offset + topXtra
            theBottom = arg.size.height - arg.offset + bottomXtra
            theHeight = theTop + theBottom
            let sumHeight = theHeight - topXtra - bottomXtra
            let sumWidth = sumHeight * 2 / 3
            innerWidth = arg.size.width + sumWidth * 1.3
            if hierExp.nArgs == 3 {
                calcOrDraw(fromExp, drawIt: false, settings: expSettings)
                if fromExp.size.width > sumWidth {
                    innerWidth = innerWidth + (fromExp.size.width - sumWidth)/2
                }
            }

        } else {
            let sumHeight = theHeight - topXtra - bottomXtra
            let sumWidth = sumHeight * 2 / 3
            var startx = thePoint.x
            if hierExp.nArgs == 3 {
                calcOrDraw(fromExp, drawIt: false, settings: expSettings)
                if fromExp.size.width > sumWidth {
                    startx = startx + (fromExp.size.width - sumWidth)/2
                }
            }
            arg.setOrigin(NSPoint(x: startx + sumWidth * 1.3 ,
                                  y: thePoint.y - topXtra - sumHeight/2 + arg.size.height/2  ))
            calcOrDraw(arg, drawIt: true, settings: newSettings)
            if hierExp.nArgs == 3 {
                fromExp.setOrigin(NSPoint(x: startx + sumWidth / 2 - fromExp.size.width / 2, y: thePoint.y - theHeight + indexFontSize))
                calcOrDraw(fromExp, drawIt: true, settings: expSettings)
                if indexes!.op == ":" && indexes!.nArgs == 2 {
                    calcOrDraw(toExp, drawIt: false, settings: expSettings)
                    toExp.setOrigin(NSPoint(x: startx + sumWidth / 2 - toExp.size.width / 2, y: thePoint.y))
                    calcOrDraw(toExp, drawIt: true, settings: expSettings)
                }
            }
            let sumLine = NSBezierPath()
            sumLine.move(to: NSPoint(x: startx + sumWidth, y: thePoint.y  - theHeight + bottomXtra + sumHeight/10))
            sumLine.line(to: NSPoint(x: startx + sumWidth, y: thePoint.y  - theHeight + bottomXtra))
            sumLine.line(to: NSPoint(x: startx , y: thePoint.y  - theHeight + bottomXtra))
            sumLine.line(to: NSPoint(x: startx + sumWidth/2, y: thePoint.y - topXtra - sumHeight/2))
            sumLine.line(to: NSPoint(x: startx, y: thePoint.y - topXtra))
            sumLine.line(to: NSPoint(x: startx + sumWidth, y: thePoint.y - topXtra))
            sumLine.line(to: NSPoint(x: startx + sumWidth, y: thePoint.y - topXtra - sumHeight/10))
            sumLine.lineWidth = 1
            sumLine.stroke()
            thePoint.x = thePoint.x + innerWidth
        }
        
    default : // c'est une fonction...
        var fop = op
        if op == "grad" {fop = "∇"}
        var opSize = (fop as NSString).size(withAttributes: textAttributes)
        let commaSize = ("," as NSString).size(withAttributes: textAttributes)
        var pars = true
        var parType = "("
        if op == "abs" {
            parType = "|"
            opSize = NSSize(width: 0, height: 0)
        } else if op == "norm" {
            parType = "||"
            opSize = NSSize(width: 0, height: 0)
        }
        if ["sin","cos","tan","exp","ln","Log","atan","asin","acos","grad"].contains(op) {
            if hierExp.nArgs == 1 {
                if hierExp.args[0].op == "_var" || hierExp.args[0].op == "_val" {
                    pars = false
                }
            }
        }
        
        if hierExp.nArgs == 0 {
            let text = op + "( )"
            hierExp.setOrigin(NSPoint(x: thePoint.x, y: thePoint.y))
            calcOrDrawText(text, hierExp: hierExp, drawIt: drawIt, settings: newSettings)
            innerWidth = hierExp.size.width
            theHeight = hierExp.size.height
            theTop = hierExp.offset
            theBottom = theHeight - theTop
            if drawIt {thePoint.x = thePoint.x + hierExp.innerSize.width}
       
        } else {
            
            if drawIt == false {
                innerWidth = opSize.width + espace1
                var c : Int = 0
                for arg in hierExp.args {
                    // On ajoute le "," si nécessaire
                    if c>0 { theWidth = theWidth + commaSize.width + espace1 * 2 }
                    c = c+1
                    // On calcule les différents arguments
                    calcOrDraw(arg, drawIt: false, settings: newSettings)
                    innerWidth = innerWidth + arg.size.width
                    theTop = max(theTop , arg.offset)
                    theBottom = max(theBottom, arg.size.height - arg.offset)
                }
                let argsCalcHeight = theTop + theBottom
                if pars {
                    innerWidth = innerWidth +  2 * drawParenthesis(at: thePoint, height: argsCalcHeight, close: false, type: parType, drawIt: false, settings: newSettings) + espace1
                }
                
            } else {
                let basey = hierExp.origin.y - hierExp.offset
                //let opSize = (op as NSString).size(withAttributes: textAttributes)
                if op != "abs" && op != "norm" {
                    (fop as NSString).draw(at: NSPoint(x: thePoint.x, y: basey - opSize.height * 1/3), withAttributes: textAttributes)
                }
                
                thePoint.x = thePoint.x + opSize.width + espace1
                var parWidth : CGFloat = 0
                
                if pars {
                    parWidth = drawParenthesis(at: NSPoint(x: thePoint.x - 1, y: basey + calcOffset), height: calcHeight, close: false, type: parType, drawIt: true, settings: newSettings)
                }
                thePoint.x = thePoint.x + parWidth
                var c : Int = 0
                for arg in hierExp.args {
                    // On dessine le "," si nécessaire
                    if c>0 {
                        thePoint.x = thePoint.x + espace1
                        ("," as NSString).draw(at: NSPoint(x: thePoint.x, y: basey - opSize.height * 1/3), withAttributes: textAttributes)
                        thePoint.x = thePoint.x + commaSize.width + espace1
                    }
                    c=c+1
                    // on dessine l'argument
                    arg.setOrigin(NSPoint(x: thePoint.x, y: basey + arg.offset))
                    calcOrDraw(arg, drawIt: true, settings: newSettings)
                    thePoint.x = thePoint.x + arg.size.width
                }
                if pars {
                    _ = drawParenthesis(at: NSPoint(x: thePoint.x + 1, y: basey + calcOffset), height: calcHeight, close: true, type: parType, drawIt: true, settings: newSettings)
                }
            }
        }
    }

    // Dessin des parenthèses fermantes
    if drawIt {
        var parType = ""
        if hierExp.drawSettingForKey(key: "rightpar") != nil { parType = hierExp.drawSettingForKey(key: "rightpar") as! String}
        if hierExp.draw!.pars {parType = "("}
        if hierExp.father != nil {
            if hierExp.father!.op == "@" && hierExp.argInFather == 1 { parType = "{" }
        }
        if parType != "" {
            parWidth = drawParenthesis(at: NSPoint(x: thePoint.x + espace1, y: origin.y), height: innerHeight, close: true, type: parType, drawIt: drawIt, settings: newSettings)
            thePoint.x = thePoint.x + parWidth + espace1
        }
    }

    // Ecriture du résultat
    if drawIt && hierExp.result != nil && hierExp.drawSettingForKey(key: "hideresult") as? Bool? != true {
        let res = hierExp.result!
        let opS = " → "
        let opSize = (opS as NSString).size(withAttributes: textAttributes)
        var basey = thePoint.y - hierExp.offset
        if calcOffset < theTop { basey = thePoint.y - calcOffset }
        thePoint.x = thePoint.x + espace1
        (opS as NSString).draw(at: NSPoint(x: thePoint.x, y: basey - opSize.height * 1/3 ), withAttributes: textAttributes)
        thePoint.x = thePoint.x + opSize.width + espace1
        res.setOrigin( NSPoint(x: thePoint.x, y: basey + res.offset) )
        calcOrDraw(res, drawIt: true, settings: newSettings)
        thePoint.x = thePoint.x + res.size.width
    }

    
    // finalisation des caluls préliminaires
    if !drawIt {
        
        theWidth = theWidth + innerWidth
        innerHeight = theTop + theBottom
        
        // parenthèses ouvrantes
        var parType = ""
        if hierExp.drawSettingForKey(key: "leftpar") != nil {
            parType = hierExp.drawSettingForKey(key: "leftpar") as! String
        }
        if hierExp.draw!.pars { parType = "(" }
        if hierExp.father != nil {
            if hierExp.father!.op == "@" && hierExp.argInFather == 1 { parType = "{" }
        }
        if parType != "" {
            parWidth = drawParenthesis(at: thePoint, height: innerHeight, close: false, type: parType, drawIt: drawIt, settings: newSettings)
            theWidth = theWidth + espace1 + parWidth
        }
        
        // parenthèses fermantes
        parType = ""
        if hierExp.drawSettingForKey(key: "rightpar") != nil {
            parType = hierExp.drawSettingForKey(key: "rightpar") as! String
        }
        if hierExp.draw!.pars {parType = "("}
        if hierExp.father != nil {
            if hierExp.father!.op == "@" && hierExp.argInFather == 1 { parType = "{" }
        }
        if parType != "" {
            parWidth = drawParenthesis(at: NSPoint(x: thePoint.x + espace1, y: origin.y), height: innerHeight, close: true, type: parType, drawIt: drawIt, settings: newSettings)
            theWidth = theWidth + 2 * parWidth + espace1
        }
        
        // Calcul des dimensions du résultat
        hierExp.draw!.calcHeight = theTop + theBottom
        hierExp.draw!.calcOffset = theTop
        if hierExp.result != nil && hierExp.drawSettingForKey(key: "hideresult") as? Bool? != true {
            let res = hierExp.result!
            let opS = " → "
            let opSize = (opS as NSString).size(withAttributes: textAttributes)
            theWidth = theWidth + opSize.width + espace1 * 2
            calcOrDraw(res, drawIt: false, settings: newSettings)
            let argSize = res.size
            let argOffset = res.offset
            theWidth = theWidth + argSize.width
            theTop = max(theTop , argOffset)
            theBottom = max(theBottom, argSize.height - argOffset)
        }
    
                
        // Ajustement des tailles pour le cadre
        //hierExp.drawSettingForKey(key: "framewidth") != nil &&
        if  hierExp.drawSettingForKey(key: "framewidth") != nil && hierExp.op != "_grid"  {
            theWidth = theWidth + frameMargin * 2
            theTop = theTop + frameMargin
            theBottom = theBottom + frameMargin
        }
        
        // ajustement connecteur
        if hierExp.drawSettingForKey(key: "connector") != nil  {
            let theConnector = hierExp.drawSettingForKey(key: "connector") as! String
            let opSize = (theConnector as NSString).size(withAttributes: textAttributes)
            if hierExp.father!.op == "_grid" {
                theWidth = theWidth + opSize.width + 2*(hierExp.father! as! HierGrid).hMargin  + espaceConnecteur
            } else {
                theWidth = theWidth + opSize.width + espaceConnecteur
            }
          }
        
        theHeight = theTop + theBottom
        theSize = NSSize(width: theWidth, height: theHeight )
        innerSize = NSSize(width: innerWidth, height: innerHeight)
        hierExp.setSize(theSize)
        hierExp.setOffset(theTop)
        hierExp.setInnerSize(innerSize)
    }
    
}

// Ecriture d'une unité


// Ecriture ou calcul d'un texte
func calcOrDrawText(_ text: String, hierExp : HierarchicExp, drawIt: Bool, settings: [String:Any] ) {
    let font = settings["font"] as! NSFont
    let textColor = settings["textcolor"] as! NSColor
    let textAttributes = [NSAttributedString.Key.font : font,
                          NSAttributedString.Key.foregroundColor: textColor]
    let theSize = (text as NSString).size(withAttributes: textAttributes)
    if drawIt {
        let atPoint = hierExp.origin
        (text as NSString).draw(at: NSPoint(x: atPoint.x,
                                            y: atPoint.y - theSize.height),
                                withAttributes: textAttributes)
    } else {
        let theTop = theSize.height * 2/3
        hierExp.setSize(theSize)
        hierExp.setOffset(theTop)
        hierExp.setInnerSize(theSize)
    }
}

func calcOrDrawAttstring(_ attString : NSAttributedString, hierExp: HierarchicExp, drawIt: Bool) {
    let theSize = attString.size()
    if drawIt {
        let atPoint = hierExp.origin
        attString.draw(at: NSPoint(x: atPoint.x, y: atPoint.y - theSize.height))
    } else {
        let theTop = theSize.height * 2/3
        //hierExp.setInnerSize(theSize)
        hierExp.setSize(theSize)
        hierExp.setOffset(theTop)
        hierExp.setInnerSize(theSize)
    }
}

func sizeOfText(_ text: String, settings: [String:Any] ) -> NSSize {
    let font = settings["font"] as! NSFont
    let textColor = settings["textcolor"] as! NSColor
    let textAttributes = [NSAttributedString.Key.font : font,
                          NSAttributedString.Key.foregroundColor: textColor]
    let theSize = (text as NSString).size(withAttributes: textAttributes)
    return theSize
}

func attStringForString(_ text: String, settings: [String:Any] ) -> NSAttributedString {
    let font = settings["font"] as! NSFont
    let textColor = settings["textcolor"] as! NSColor
    let textAttributes = [NSAttributedString.Key.font : font,
                          NSAttributedString.Key.foregroundColor: textColor]
    return NSAttributedString(string: text , attributes: textAttributes)
}

func attributesForSettings(settings: [String:Any]) -> [NSAttributedString.Key : Any] {
    let font = settings["font"] as! NSFont
    let textColor = settings["textcolor"] as! NSColor
    let textAttributes = [NSAttributedString.Key.font : font,
                          NSAttributedString.Key.foregroundColor: textColor]
    return textAttributes
}

// Dessin d'un vecteur (texte surmonté d'une flèche)
func calcOrDrawVector(_ text: String, hierExp : HierarchicExp, drawIt: Bool, settings: [String:Any] ) {
    if !drawIt {
        calcOrDrawText(text, hierExp: hierExp, drawIt: false, settings: settings)
        let theTop = hierExp.offset + 2 * espace1
        hierExp.setOffset(theTop)
        let theSize = NSSize(width: hierExp.size.width, height: hierExp.size.height + 2 * espace1)
        hierExp.setSize(theSize)
        hierExp.setInnerSize(theSize)
    } else {
        let atPoint = hierExp.origin
        let arrowLine = NSBezierPath()
        arrowLine.move(to: NSPoint(x: atPoint.x, y: atPoint.y - espace1))
        arrowLine.line(to: NSPoint(x: atPoint.x + hierExp.innerSize.width, y: atPoint.y - espace1))
        arrowLine.line(to: NSPoint(x: atPoint.x + hierExp.innerSize.width - espace1, y: atPoint.y))
        arrowLine.move(to: NSPoint(x: atPoint.x + hierExp.innerSize.width, y: atPoint.y - espace1))
        arrowLine.line(to: NSPoint(x: atPoint.x + hierExp.innerSize.width - espace1, y: atPoint.y - 2 * espace1))
        arrowLine.lineWidth = 1
        arrowLine.stroke()
        hierExp.setOrigin( NSPoint(x: atPoint.x, y: atPoint.y - 2*espace1) )
        calcOrDrawText(text, hierExp: hierExp, drawIt: true, settings: settings)
    }
}

// Ecriture ou calcul d'une physVal scalaire ou vectorielle
func calcOrDrawVal(_ phVal: PhysValue, hierExp : HierarchicExp, drawIt: Bool, settings: [String:Any]) {
    let nDims = phVal.dim.count
    if nDims == 2 {
        // affichage d'une matrice 2D... pas trop grande !
        let nrows = phVal.dim[1]
        let ncols = phVal.dim[0]
        if nrows > 10 || ncols > 10 {
            let r = min(10,nrows)
            let c = min(10,ncols)
            let coorArray = [ (0..<c).indices.map { $0 }, (0..<r).indices.map { $0 }]
            var newPhVal = phVal.subMatrix(coords: coorArray)
            let lastCol = newPhVal.coordArrayToIndexes(coords: [[c-1],coorArray[1]])
            let lastRow = newPhVal.coordArrayToIndexes(coords: [coorArray[0],[r-1]])
            newPhVal = newPhVal.replaceValues(indexes: lastCol, newVals: ["..."])
            newPhVal = newPhVal.replaceValues(indexes: lastRow, newVals: ["..."])
            calcOrDrawMatrix(newPhVal, hierExp: hierExp, drawIt: drawIt, settings: settings)
            return
        } else {
            calcOrDrawMatrix(phVal, hierExp: hierExp, drawIt: drawIt, settings: settings)
            return
        }
    } else if nDims == 3 {
        let dims = phVal.dim
        var dim = phVal.dim.count - 1
        if hierExp.draw?.settings?["hypermatview"] == nil {
            hierExp.setSetting(key: "hypermatview", value: [dim,0])
        }
        let hypermatsetting = hierExp.draw!.settings!["hypermatview"] as! [Int]
        dim = hypermatsetting[0]
        let index = hypermatsetting[1]

        var coordArray : [[Int]] = Array(repeating: [-1], count: dims.count)
        coordArray[dim] = [index]
        let slice = phVal.subMatrix(coords: coordArray).reduceDims()
        calcOrDrawMatrix(slice, hierExp: hierExp, drawIt: drawIt, settings: settings, is3D: true)
        return
    } else if nDims > 3 {
        calcOrDrawText("🧊", hierExp: hierExp, drawIt: drawIt, settings: settings)
        return
    }
    // Ce n'est pas une matrice, ni un vecteur...
    let font = settings["font"] as! NSFont
    let textColor = settings["textcolor"] as! NSColor
    let textAttributes = [NSAttributedString.Key.font : font,
                           NSAttributedString.Key.foregroundColor: textColor]
    let attString = NSMutableAttributedString()
    if phVal.type == "dataframe" {
        attString.append(NSAttributedString(string: "Use table(..) to dispay dataframes", attributes: textAttributes))
        calcOrDrawAttstring(attString, hierExp: hierExp, drawIt: drawIt)
        return
    }
    
    let nvals = phVal.values.count
    if nvals > 1 {attString.append(NSAttributedString(string: "(", attributes: textAttributes))}
    let vecLength = hierExp.drawSettingForKey(key: "vecLength") as? Int ?? maxNumberValuesShown
    let list = (phVal.type == "list")
    


    if nvals <= vecLength {
        for n in 0...nvals-1 {
            attString.append(oneValToString(phVal, n: n, hierExp : hierExp, settings: settings, list: list))
            if n < nvals-1 {
                attString.append(NSAttributedString(string: " " + listSep + " ", attributes: textAttributes))
            }
        }
    } else {
        for n in 1...vecLength / 2 {
            attString.append(oneValToString(phVal, n: n-1, hierExp : hierExp, settings: settings, list: list))
            if n < vecLength/2 {
                attString.append(NSAttributedString(string: " " + listSep + " ", attributes: textAttributes))
            }
        }
        attString.append(NSAttributedString(string: " … ", attributes: textAttributes))
        for n in nvals-vecLength/2+1...nvals {
            attString.append(oneValToString(phVal, n: n-1, hierExp : hierExp, settings: settings, list: list))
            if n < nvals {
                attString.append(NSAttributedString(string: " " + listSep + " ", attributes: textAttributes))
            }
        }
        
    }
    if nvals > 1 {attString.append(NSAttributedString(string: ")", attributes: textAttributes))}
    
    // Ecriture de l'unité
    if phVal.unit.name != "" { attString.append(attStringForUnit(phVal.unit, attributes: textAttributes)) }
    calcOrDrawAttstring(attString, hierExp: hierExp, drawIt: drawIt)
}

// attributed string pour une unité
func attStringForUnit(_ unit : Unit, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
    let attString = NSMutableAttributedString()
    var expAttrib = attributes
    let textFont = attributes[NSAttributedString.Key.font]! as! NSFont
    let expFont = NSFont(name: textFont.fontName, size: textFont.pointSize * 0.8)
    expAttrib[NSAttributedString.Key.baselineOffset] = NSNumber(floatLiteral: 4)
    expAttrib[NSAttributedString.Key.font] = expFont
    
    attString.append(NSAttributedString(string: " [", attributes: attributes))
    var acceptOne = false
    for char in unit.name {
        if char.isNumber || char == "-" {
            if char == "-" {
                acceptOne = true
                attString.append(NSAttributedString(string: String(char), attributes: expAttrib))
            }
            else if char != "1" || acceptOne {
                attString.append(NSAttributedString(string: String(char) + " ", attributes: expAttrib))
            } else {
                attString.append(NSAttributedString(string: " ", attributes: expAttrib))
            }
        } else {
            acceptOne = false
            attString.append(NSAttributedString(string: String(char), attributes: attributes))
        }
    }
    attString.append(NSAttributedString(string: "]", attributes: attributes))
    return attString
}

// dessin d'une matrice
func calcOrDrawMatrix(_ phVal: PhysValue, hierExp : HierarchicExp, drawIt: Bool, settings: [String:Any],is3D : Bool = false) {
    
    let color : NSColor? = is3D ? NSColor.blue : nil
    let font = settings["font"] as! NSFont
    let textColor = settings["textcolor"] as! NSColor
    let textAttributes = [NSAttributedString.Key.font : font,
                           NSAttributedString.Key.foregroundColor: textColor]
    
    if phVal.dim.count != 2 { return }
    let nrows = phVal.dim[1]
    let ncols = phVal.dim[0]
    var maxWidth : CGFloat = 0
    var maxHeight : CGFloat = 0
    if !drawIt {
        var n = 0
        for _ in 0...nrows-1 {
            for _ in 0...ncols-1 {
                let attString = phVal.values[n] as? String == nil ?
                    oneValToString(phVal, n: n, hierExp : hierExp, settings: settings) :
                    NSAttributedString(string: phVal.values[n] as! String, attributes: textAttributes)
                let textSize = attString.size()
                if maxWidth < textSize.width { maxWidth = textSize.width}
                if maxHeight < textSize.height { maxHeight = textSize.height}
                n = n + 1
            }
        }
        let theHeight = maxHeight * CGFloat(nrows)
        let parwidth = drawParenthesis(at: hierExp.origin, height: theHeight, close: false, type: "[", drawIt: false, settings: settings)
        var theWidth = (maxWidth + 2 * espace1) * CGFloat(ncols) + 2 * parwidth + 2 * espace1
        if phVal.unit.name != "" {
            theWidth = theWidth + sizeOfText(" [" + phVal.unit.name + "]", settings: settings).width
        }
        let theTop = theHeight/2
        let theSize = NSSize(width: theWidth, height: theHeight )
        hierExp.setSize(theSize)
        hierExp.setInnerSize(theSize)
        hierExp.setOffset(theTop)

    } else {
        var n = 0
        let font = settings["font"] as! NSFont
         let textColor = settings["textcolor"] as! NSColor
         let textAttributes = [NSAttributedString.Key.font : font,
                               NSAttributedString.Key.foregroundColor: textColor]
        var atPoint = hierExp.origin
        let parwidth = drawParenthesis(at: atPoint, height: hierExp.size.height, close: false, type: "[", drawIt: true, settings: settings, color: color)
        var theWidth = hierExp.size.width
        if phVal.unit.name != "" {
            theWidth = theWidth - sizeOfText(" [" + phVal.unit.name + "]", settings: settings).width
        }
        maxWidth = (theWidth - 2 * parwidth - 2 * espace1) / CGFloat(ncols)
        maxHeight = hierExp.size.height / CGFloat(nrows)
        atPoint.x = atPoint.x + parwidth
        for row in 0...nrows-1 {
            for col in 0...ncols-1 {
                let attString = phVal.values[n] as? String == nil ?
                    oneValToString(phVal, n: n, hierExp : hierExp, settings: settings) :
                    NSAttributedString(string: phVal.values[n] as! String, attributes: textAttributes)
                let textSize = attString.size()
                attString.draw(at: NSPoint(x: atPoint.x + CGFloat(col+1) * maxWidth - textSize.width,
                                                      y: atPoint.y - CGFloat(row+1) * maxHeight))
                n = n + 1
            }
        }
        atPoint.x = hierExp.origin.x + theWidth - parwidth
        _ = drawParenthesis(at: atPoint, height: hierExp.size.height, close: true, type: "[", drawIt: true, settings: settings, color: color)
        if phVal.unit.name != "" {
            let unitString = " [" + phVal.unit.name + "]"
            (unitString as NSString).draw(at: NSPoint(x: atPoint.x + parwidth,
                                                      y: atPoint.y - hierExp.offset - sizeOfText(" [" + phVal.unit.name + "]", settings: settings).height/3 ),
                                          withAttributes: textAttributes)
        }
    }

}

// représentation de la n-ième composante de phVal sous forme de chaîne formatée
func oneValToString(_ phVal: PhysValue, n: Int, hierExp : HierarchicExp, settings: [String:Any], list: Bool = false, noQuotes: Bool = false) -> NSAttributedString {
    let val = phVal.values[n]
    let font = settings["font"] as! NSFont
    
    let textColor = settings["textcolor"] as! NSColor
    var textAttributes = [NSAttributedString.Key.font : font,
                           NSAttributedString.Key.foregroundColor: textColor]

    var strVal = ""
    switch phVal.type {
    case "double" :
        let unit = (settings["unit"] as? Unit) ?? phVal.unit
        let dVal = (asDouble(val) ?? Double.nan) / unit.mult - unit.offset
        let newFormatter = NumberFormatter()
        newFormatter.decimalSeparator = decimalSep
        let format = (settings["format"] as? String) ?? ((hierExp.drawSettingForKey(key: "format") as? String) ?? "auto")
        if (format == "auto" && abs(dVal) > 0 && (abs(dVal) > 100000 || abs(dVal) < 0.00001)) || format == "sci" {
            newFormatter.numberStyle = NumberFormatter.Style.scientific
            newFormatter.exponentSymbol = " e"
        } else {
            newFormatter.numberStyle = NumberFormatter.Style.decimal

        }
        
        let digits = (settings["digits"] as? Bool) ?? ((hierExp.drawSettingForKey(key: "digits") as? Bool) ?? defaultFormatter.usesSignificantDigits)
        var precision = (settings["precision"] as? Int) ?? (hierExp.drawSettingForKey(key: "precision") as? Int)
        
        if digits {
            newFormatter.usesSignificantDigits = true
            newFormatter.minimumSignificantDigits = 1
            newFormatter.maximumSignificantDigits = (precision ?? defaultFormatter.maximumSignificantDigits)
        } else {
            if newFormatter.numberStyle == NumberFormatter.Style.scientific && precision != nil {
                precision = precision! + 1
            }
            newFormatter.usesSignificantDigits = false
            newFormatter.minimumFractionDigits = precision ?? defaultFormatter.minimumFractionDigits
            newFormatter.maximumFractionDigits = precision ??  defaultFormatter.maximumFractionDigits
        }
        strVal = newFormatter.string(from: dVal as NSNumber)!
        if strVal.contains("e") {
            let splitted = strVal.split(separator: "e")
            var expAttrib = textAttributes
            var tenAttrib = textAttributes
            let expFont = NSFont(name: font.fontName, size: font.pointSize * 0.8)
            let tenFont = NSFont(name: font.fontName, size: font.pointSize * 0.8)
            expAttrib[NSAttributedString.Key.baselineOffset] = NSNumber(floatLiteral: 4)
            expAttrib[NSAttributedString.Key.font] = expFont
            tenAttrib[NSAttributedString.Key.font] = tenFont
            
            let attString = NSMutableAttributedString(string: String(splitted[0]), attributes: textAttributes)
            attString.append(NSAttributedString(string: " x ", attributes: tenAttrib))
            attString.append(NSAttributedString(string: "10", attributes: textAttributes))
            attString.append(NSAttributedString(string: String(splitted[1]), attributes: expAttrib))
            return attString
        }
    case "int" :
        if let intVal = val as? Int { strVal = String(intVal) }
        else if let doubVal = val as? Double { strVal = String(doubVal)}
        else if let boolVal = val as? Bool { strVal = String(boolVal)}
        else if val is NSColor { strVal = "color ?" }
        else { strVal = val as! String }
    case "bool" : strVal = (String(val as? Bool ?? false)).uppercased()
    case "dataframe" : strVal = "dataframe" // (val as! PhysValue).stringExp(units: true)
    case "list":
        let attString = NSMutableAttributedString()
        
        if  (val as! PhysValue).values.count > 1  && list {
            attString.append(NSAttributedString(string: "("))
        }
        
        attString.append(oneValToString(val as! PhysValue, n: 0, hierExp: hierExp, settings: settings, list: true))
        let unit = (val as! PhysValue).unit
        if !(unit.isNilUnit()) {
            attString.append(NSAttributedString(string: " "))
            attString.append(attStringForUnit(unit, attributes: textAttributes))
        }
        
        if (val as! PhysValue).values.count > 1  && list {
            attString.append(NSAttributedString(string: "...)"))
        }
    
        return attString
    case "color" :
        let color = val as! NSColor
        let font = NSFont(name: "Helvetica", size: 18)!
        let colorAttributes: [NSAttributedString.Key : Any] =
            [NSAttributedString.Key.foregroundColor: color,
             NSAttributedString.Key.font: font]
        return NSAttributedString(string: "◼︎", attributes: colorAttributes)
    case "exp" :
        strVal = (val as! HierarchicExp).stringExp()
    case "label" :
        strVal = val as! String
    case "error" :
        textAttributes[NSAttributedString.Key.foregroundColor] = NSColor(named: NSColor.Name("errorColor"))
        strVal = val as! String
        return NSAttributedString(string: strVal, attributes: textAttributes)
    default :
        strVal = noQuotes ? (val as? String ?? "") : "'" + (val as? String ?? "") + "'"
    }
    let attString = NSAttributedString(string: strVal, attributes: textAttributes)
    return attString
}



// écriture de parenthèses ou calcul de leur largeur
func drawParenthesis(at: NSPoint, height: CGFloat, close: Bool, type: String = "(", drawIt : Bool, settings: [String:Any], color: NSColor? = nil ) -> CGFloat {
    
    let textColor = color ?? settings["textcolor"] as! NSColor
    textColor.setStroke()
    
    // grandes parenthèses
    let width = min(15,max(height/10,2.5))
    var par = type
    if close {
        switch par {
        case "{", "}": par = "}"
        case "[", "]": par = "]"
        case "|": par = "|"
        case "||": par = "||"
        default : par = ")"
        }
    }
    if drawIt {
        let parLine = NSBezierPath()
        switch par {
        case "(" :
            parLine.move(to: NSPoint(x: at.x + width, y: at.y))
            parLine.curve(to: NSPoint(x: at.x + width , y: at.y - height),
                          controlPoint1:NSPoint(x: at.x, y: at.y - height / 10),
                          controlPoint2: NSPoint(x: at.x , y: at.y - 9 * height / 10))
        case ")" :
            parLine.move(to: NSPoint(x: at.x, y: at.y))
            parLine.curve(to: NSPoint(x: at.x , y: at.y - height),
                          controlPoint1:NSPoint(x: at.x + width , y: at.y - height / 10),
                          controlPoint2: NSPoint(x: at.x + width  , y: at.y - 9 * height / 10))
        case "[" :
            parLine.move(to: NSPoint(x: at.x + width, y: at.y))
            parLine.line(to: NSPoint(x: at.x, y: at.y))
            parLine.line(to: NSPoint(x: at.x, y: at.y - height))
            parLine.line(to: NSPoint(x: at.x + width, y: at.y - height))
        case "]" :
            parLine.move(to: NSPoint(x: at.x, y: at.y))
            parLine.line(to: NSPoint(x: at.x + width , y: at.y))
            parLine.line(to: NSPoint(x: at.x + width, y: at.y - height))
            parLine.line(to: NSPoint(x: at.x , y: at.y - height))
        case "{" :
            parLine.move(to: NSPoint(x: at.x + width, y: at.y))
            parLine.curve(to: NSPoint(x: at.x , y: at.y - height/2),
                          controlPoint1:NSPoint(x: at.x, y: at.y - height / 10),
                          controlPoint2: NSPoint(x: at.x + width , y: at.y - height / 2 + height / 10))
            parLine.move(to: NSPoint(x: at.x + width, y: at.y-height))
            parLine.curve(to: NSPoint(x: at.x , y: at.y - height/2),
                          controlPoint1:NSPoint(x: at.x, y: at.y - 9 * height / 10),
                          controlPoint2: NSPoint(x: at.x + width , y: at.y - height / 2 - height / 10))
        case "}" :
            parLine.move(to: NSPoint(x: at.x, y: at.y))
            parLine.curve(to: NSPoint(x: at.x + width , y: at.y - height/2),
                          controlPoint1:NSPoint(x: at.x + width, y: at.y - height / 10),
                          controlPoint2: NSPoint(x: at.x , y: at.y - height / 2 + height / 10))
            parLine.move(to: NSPoint(x: at.x, y: at.y-height))
            parLine.curve(to: NSPoint(x: at.x + width , y: at.y - height/2),
                          controlPoint1:NSPoint(x: at.x + width, y: at.y - 9 * height / 10),
                          controlPoint2: NSPoint(x: at.x , y: at.y - height / 2 - height / 10))
        case "||" :
            if close {
                parLine.move(to: NSPoint(x: at.x + width * 1.8 , y: at.y))
                parLine.line(to: NSPoint(x: at.x + width * 1.8 , y: at.y - height))
                parLine.move(to: NSPoint(x: at.x + width * 0.8, y: at.y))
                parLine.line(to: NSPoint(x: at.x + width * 0.8, y: at.y - height))
            } else {
                parLine.move(to: NSPoint(x: at.x - width * 0.8, y: at.y))
                parLine.line(to: NSPoint(x: at.x - width * 0.8, y: at.y - height))
                parLine.move(to: NSPoint(x: at.x + width * 0.2, y: at.y))
                parLine.line(to: NSPoint(x: at.x + width * 0.2, y: at.y - height))
            }
        default :
            if close {
                parLine.move(to: NSPoint(x: at.x + width, y: at.y))
                parLine.line(to: NSPoint(x: at.x + width, y: at.y - height))
            } else {
                parLine.move(to: NSPoint(x: at.x, y: at.y))
                parLine.line(to: NSPoint(x: at.x, y: at.y - height))
            }
        }
        parLine.lineWidth = 1
        parLine.stroke()
    }
    return width
    
}

func mergeDics(_ d1: [String:Any], _ d2: [String:Any]) -> [String:Any] {
    return d1.merging(d2) { (_, new) in new }
}

