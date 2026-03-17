//
//  FlatEditorViewController.swift
//  INSCameraSDKDemo
//
//  Created by zeng bin on 9/27/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK
import INSCoreMedia

class FlatEditorViewController: FormViewController {
    var flatPanoOutput: INSCameraFlatPanoOutput?
    
    let beautifyFilters = [
        INSFilterType.typeNull,
        INSFilterType.typeBeautify1,
        INSFilterType.typeBeautify2,
        INSFilterType.typeBeautify3,
        INSFilterType.typeBeautify4,
        INSFilterType.typeBeautify5
    ]
    
    let filters = [
        INSFilterType.typeNull,
        INSFilterType.typeGray,
        INSFilterType.typeSketch
    ]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Live Editor"
        
        setupForm()
    }
    
    func setupForm() {
        guard let flatPanoOutput = flatPanoOutput else {
            return
        }
        
        form +++ Section()
            <<< SwitchRow("Stabilization") {
                $0.title = $0.tag
                $0.value = flatPanoOutput.enableGyroStabilization
            }.onChange({[unowned self] (row) in
                self.flatPanoOutput?.enableGyroStabilization = row.value!
            })
            <<< SwitchRow("Remove Purple") {
                $0.title = $0.tag
                $0.value = flatPanoOutput.removePurple
            }.onChange({[unowned self] (row) in
                self.flatPanoOutput?.removePurple = row.value!
            })
            <<< ActionSheetRow<String>("Filters") {
                $0.title = $0.tag
                $0.options = ["NULL", "Gray", "Sketch"]
                let index = filters.firstIndex(of: flatPanoOutput.filter) ?? 0
                $0.value = $0.options![index];
            }.onChange({[unowned self] (row) in
                let index = row.options!.firstIndex(of: row.value!) ?? 0
                self.flatPanoOutput?.filter = self.filters[index]
            })
            <<< ActionSheetRow<Int>("Beautify Filters") {
                $0.title = $0.tag
                $0.options = [0, 1, 2, 3, 4, 5]
                let index = beautifyFilters.firstIndex(of: flatPanoOutput.beautifyFilter) ?? 0
                $0.value = $0.options![index];
            }.onChange({[unowned self] (row) in
                self.flatPanoOutput?.beautifyFilter = self.beautifyFilters[row.value ?? 0]
            })
    }
}
