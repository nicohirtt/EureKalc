//
//  TabControllers.swift
//  EureKalc
//
//  Created by Nico on 29/09/2019.
//  Copyright © 2019 Nico Hirtt. All rights reserved.
//

import Cocoa

//var tabsCtrl : TabButtonsController = TabButtonsController()
var activeTab : String = "layout"

// Gestion générale des panneaux de contrôle

class TabButtonsController: NSViewController {
    
    @IBOutlet var layoutBtn: NSButton!
    @IBOutlet var mathBtn: NSButton!
    @IBOutlet var graphBtn: NSButton!
    @IBOutlet var simBtn: NSButton!
    @IBOutlet var varsBtn: NSButton!
    
    override var representedObject: Any? {
           didSet {
           // Update the view, if already loaded.
           }
       }
       
     override func viewDidLoad() {
        super.viewDidLoad()
        mainDoc.tabsCtrl = self
     }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }

    @IBAction func activateLayoutTab(_ sender: Any) {
        btnStatesOff()
        layoutBtn.state = NSControl.StateValue.on
        hideTabViews(except: mainCtrl.layoutTab)
        layoutTabCtrl.updatePanel()
        activeTab = "layout"
    }
    
    @IBAction func activateMathTab(_ sender: Any) {
        btnStatesOff()
        mathBtn.state = NSControl.StateValue.on
        hideTabViews(except: mainCtrl.mathTab)
        mathTabCtrl.updatePanel()
        activeTab = "math"
    }
    
    @IBAction func activateGraphTab(_ sender: Any) {
        btnStatesOff()
        graphBtn.state = NSControl.StateValue.on
        hideTabViews(except: mainCtrl.graphTab)
        graphTabCtrl.updatePanel()
        activeTab = "graph"
    }
    
    
    @IBAction func activateSimTab(_ sender: Any) {
        btnStatesOff()
        simBtn.state = NSControl.StateValue.on
        hideTabViews(except: mainCtrl.simTab)
        //simTabCtrl.updatePanel()
        activeTab = "sim"
    }
    
    @IBAction func activateVarsTab(_ sender: Any) {
        btnStatesOff()
        varsBtn.state = NSControl.StateValue.on
        hideTabViews(except: mainCtrl.varsTab)
        activeTab = "vars"
        //mainDoc.varsTabCtrl?.reloadItems()
    }
    
    
    func btnStatesOff() {
        layoutBtn.state = NSControl.StateValue.off
        mathBtn.state = NSControl.StateValue.off
        graphBtn.state = NSControl.StateValue.off
        simBtn.state = NSControl.StateValue.off
        varsBtn.state = NSControl.StateValue.off
    }
    
    func hideTabViews(except : NSView) {
        let theTabs = mainCtrl.layoutTab.superview!.subviews
        for aTab in theTabs {
            if aTab == except || aTab == mainCtrl.tabButtonsView {
                aTab.isHidden = false
            } else {
                aTab.isHidden = true
            }
        }
    }
    
    func updateActivetab() {
        switch activeTab {
        case "graph" : activateGraphTab(self)
        case "math" : activateMathTab(self)
        case "sim" : activateSimTab(self)
        case "vars" : activateVarsTab(self)
        default : activateLayoutTab(self)
        }
    }
    
}


// place un panneau dans un tabview et retourne la position y du prochain panneau
func placePanel(panel: NSBox, at : CGFloat) -> CGFloat {
    let x : CGFloat = -4
    let s : CGFloat = 4
    let y = at - panel.frame.height + s
    panel.setFrameOrigin(NSPoint(x: x, y: y))
    panel.isHidden = false
    return y
}


