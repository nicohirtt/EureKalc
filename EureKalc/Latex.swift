//
//  Latex.swift
//  EureKalc
//
//  Created by Nico on 01/04/2023.
//  Copyright © 2023 Nico Hirtt. All rights reserved.
//

import Foundation

extension HierarchicExp {
    
    func toLatex() -> String {
        var resultat = ""
        let m = maxNumberValuesShown
        
        var connector : String = ""
        if self.draw?.settings?["connector"] != nil {
            connector = self.draw!.settings!["connector"] as! String
            var latexConnector : String
            switch(connector) {
            case "⇒" :  latexConnector = "\\Rightarrow "
            case "⇔" : latexConnector = "\\Leftrightarrow "
            default : latexConnector = "\\rightarrow "
            }
            if connector != "=" {
                resultat = latexConnector
            }
        }
        
        switch op {
            
        case "_grid" :
            let grid = (self as! HierGrid)
            if grid.isBaseGrid {
                resultat = "\\documentclass[11pt,a4paper,fleqn]{article} \n \\usepackage{amsmath} \n \\begin{document} \n"
                for r in 0..<grid.rows {
                    resultat = resultat + "\\begin{equation*} " + "\n" + grid.args[r].toLatex() + "\n" + "\\end{equation*} " + "\n"
                }
                resultat = resultat + "\\end{document}"
            } else if grid.islineGrid {
                for c in 0..<grid.cols {
                    resultat = resultat + grid.args[c].toLatex()
                    if c < grid.cols - 1 { resultat = resultat +  " \\qquad " }
                }
            } else {
                // cas d'une grille quelconque -> encore à traiter !
            }
        
        case "plot", "lineplot", "scatterplot", "histo" :
            resultat = "\\mathrm{Graphic}"
            
        case "table" :
            resultat = "\\mathrm{Table}"
            
        case "label" :
            resultat = "\\textrm{" + (args[0].value!.asString ?? "") + "}"


        case "_var" :
            var NomVar = self.string!
            if NomVar.hasSuffix("\\") {
                resultat = " \\vec{" + String(NomVar.removeLast()) + "} "
            } else if NomVar.hasSuffix("@") { // un jour on mettra ce suffixe ou un autre pour avoir du gras
                resultat =  " \\mathbf{" + String(NomVar.removeLast())  + "} "
            } else {
                resultat = NomVar
            }
        case "_val" :
            let Valeur = value!.asDouble
            if Valeur == nil {
                resultat = value!.asString ?? ""
            } else {
                resultat = "\\mathrm{" + value!.stringExp(units: false) + "}"
                if resultat.contains("e") {
                    resultat = resultat.replacingOccurrences(of: "e", with: "  x 10^{") + "}"
                }
                if !value!.unit.isNilUnit() {
                    let textUnit = value!.unit.name
                    var textUnit2 = ""
                    for (i,char) in textUnit.enumerated() {
                        textUnit2.append(char)
                        if i+1 >= textUnit.count {
                            textUnit2.append("}")
                        } else {
                            
                            if "-0123456789".contains(char) && !"-0123456789".contains(textUnit[i+1]) {
                                textUnit2.append("}")
                            } else if !"-0123456789".contains(char) && "-0123456789".contains(textUnit[i+1]) {
                                textUnit2.append("^{")
                            }
                        }
                    }
                    resultat.append(" \\; \\mathrm{" + textUnit + "}")
                }
            }
            
        case "=" :
            if connector != "=" {
                resultat = resultat +  "{" + args[0].toLatex() + "}={" + args[1].toLatex() + "}"
            } else {
                resultat = resultat +  "={" + args[1].toLatex() + "}"
            }
        case "," :
            resultat = resultat + "("
            if nArgs>0 {
                for (i,arg) in args.enumerated() {
                    if (i == m && nArgs > m) {
                        resultat = resultat + "..."
                    } else if nArgs <= m || i <= m || i > nArgs-m {
                        if i>0 { resultat.append(",") }
                        resultat.append(arg.toLatex())
                    }
                }
            }
            resultat.append(")")
        case "+" :
            resultat = resultat + "{" + args[0].toLatex() + "}"
            for (i,arg) in args.enumerated() {
                if i>0 {
                    if arg.op == "_minus" || arg.op == "-" {
                        resultat.append("-{" + arg.args[0].toLatex() + "}")
                    } else {
                        resultat.append("+{" + arg.toLatex() + "}")
                    }
                }
            }
            
        case "-", "_minus" :
            if ["+","-"].contains(args[0].op) {
                resultat = resultat + "-" + latexPar(args[0].toLatex())
            } else {
                resultat = resultat + "-{" + args[0].toLatex() + "}"
            }
            
        case "*":
            resultat = resultat + "{" + args[0].toLatex() + "}"
            for (i,arg) in args.enumerated() {
                if i>0 {
                    if arg.op == "+" {
                        resultat.append("\\cdot " + latexPar(arg.toLatex()))
                    } else {
                        resultat.append("\\cdot{" + arg.toLatex() + "}")
                    }
                }
            }
            
        case "/" :
            resultat = resultat + "\\displaystyle  \\frac{" + args[0].toLatex() + "}{" +  args[1].toLatex() + "}"
          
        case "^" :
            if ["+","-","*","^"].contains(args[0].op) {
                resultat = resultat + "{(" + args[0].toLatex() + ")}^{" + args[1].toLatex() + "}"
            } else if ["sin","cos","tan","asin","acos","atan"].contains(args[0].op) && args[1].op == "_val" {
                let argsin = args[0].args[0]
                if ["_var","_val"].contains(argsin.op) {
                    resultat = resultat + "\\" + args[0].op + "^" + args[1].toLatex() + "{" + argsin.toLatex() + "}"
                } else {
                    resultat = resultat + "\\" + args[0].op + "^" + args[1].toLatex() + latexPar(argsin.toLatex())
                }
            } else {
                resultat = resultat + args[0].toLatex() + "^{" + args[1].toLatex() + "}"
            }
            
        case "sqrt" :
            resultat = resultat + "\\sqrt{" + args[0].toLatex() + "}"
            
        case "sin","cos","tan","asin","acos","atan","ln" :
            let op2 = op.hasPrefix("a") ? "arc" + op.dropFirst() : op
            if ["+","-","/"].contains(args[0].op) {
                resultat = resultat + "\\" + op2 + " " + latexPar(args[0].toLatex())
            } else {
                resultat =  resultat + "\\" + op2 + "{" + args[0].toLatex() + "}"
            }
            
        case "exp" :
            resultat = resultat + "e^{" + args[0].toLatex() + "}"
            
        case "abs" :
            resultat = resultat + "\\left \\vert " + args[0].toLatex() + "\\right |"
            
        case "deriv" :
            if args[0].op == "_var" {
                resultat = resultat + "\\displaystyle \\frac { \\mathrm{d}" + args[0].toLatex() + "}{ \\mathrm{d} " + args[1].toLatex() + "}"
            } else {
                resultat = resultat + "\\displaystyle  \\frac { \\mathrm{d}" + "}{ \\mathrm{d}" + args[1].toLatex() + "}" + latexPar(args[0].toLatex())
            }
            
        case "Log" :
            if ["+","-","/"].contains(args[0].op) {
                resultat = resultat + "\\operatorname{Log} " + latexPar(args[0].toLatex())
            } else {
                resultat =  resultat + "\\operatorname{Log} " + "{" + args[0].toLatex() + "}"
            }
            
        case "log" :
            if ["+","-","/"].contains(args[0].op) {
                resultat = resultat + "\\operatorname{log}_" + args[0].toLatex() + " " + latexPar(args[1].toLatex())
            } else {
                resultat =  resultat + "\\operatorname{log}_" + args[0].toLatex() + "{" + args[1].toLatex() + "}"
            }
            
        case "•", "**", "***" :
            resultat = resultat + "{" + args[0].toLatex() + "}"
            let symb = op == "•" ? "\\centerdot " : (op == "**" ? "\\wedge " : "\\otimes ")
            for (i,arg) in args.enumerated() {
                if i>0 {
                    if arg.op == "+" {
                        resultat.append(symb + arg.toLatex() + "}")
                    } else {
                        resultat.append(symb + "{" + arg.toLatex() + "}")
                    }
                }
            }
            
        default :
            if nArgs>0 {
                for (i,arg) in args.enumerated() {
                    if i>1 { resultat.append(",") }
                    resultat.append(arg.toLatex())
                }
            }
            resultat = resultat + "\\mathrm{" + op + "}" + latexPar(resultat)
            
        }
        
        if self.result != nil {
            resultat = resultat + "=" +  result!.toLatex()
        }
        
        return resultat
    }
}

func latexPar(_ str : String) -> String {
    return ("\\left ( " + str + "\\right )")
}

