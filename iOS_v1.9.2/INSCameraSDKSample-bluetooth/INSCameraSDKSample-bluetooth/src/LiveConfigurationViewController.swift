//
//  LiveConfigurationViewController.swift
//  INSCameraSDK
//
//  Created by zeng bin on 4/25/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK
import INSCoreMedia


let bitRates:[Int] = [1, 2, 3, 4, 5, 6]

class LiveConfigurationViewController: FormViewController, AVConfigProtocol {
    var avConfigSection: Section?
    
    var bitRate = bitRates[1]
    var serverURL = URL(string: "rtmp://192.168.42.2/live/")
    var room = "room"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Live Configuration"

        setupForm()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupForm() {
        avConfigSection = setupConfigSection()
        
        form +++ avConfigSection!
            <<< ActionSheetRow<Int>("Bit Rate") {
                $0.title = "\($0.tag!): (mps)"
                $0.value = bitRate
                $0.options = bitRates
            }.onChange({[unowned self] (row) in
                self.bitRate = row.value!
                return
            })
            <<< URLRow("URL") {
                $0.title = $0.tag
                $0.value = serverURL
            }.onChange() {[unowned self] row in
                self.serverURL = row.value
            }
            <<< TextRow("Room") {
                $0.title = $0.tag
                $0.value = room
            }.onChange() {[unowned self] row in
                self.room = row.value!
            }
    }
}
