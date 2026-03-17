//
//  PhotographyOptionsViewController.swift
//  INSCameraSDK
//
//  Created by zeng bin on 6/5/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK


class PhotographyOptionItem<RowT: BaseRow> {
    let name: String
    var row: RowT
    let optionType: INSPhotographyOptionsType
    
    init(name: String, type: INSPhotographyOptionsType) {
        self.name = name
        self.optionType = type;
        row = RowT(tag: name)
        row.title = name
    }
    
    func sendCommand(commandManager: INSCameraBasicCommands, options: INSPhotographyOptions, functionMode: INSCameraFunctionMode, vc: UIViewController?) {
        let optionTypes = [NSNumber(value: optionType.rawValue)];
        commandManager.setPhotographyOptions(options, for: functionMode, types: optionTypes) {[weak vc] (err, successTypes) in
            if let vc = vc {
                if let err = err {
                    vc.showAlert(self.name, "\(err)")
                } else {
                    vc.showAlert(self.name, "SUCCESS")
                }
            }
        }
    }
}

class BoolValueItem: PhotographyOptionItem<SwitchRow> {
    init(name: String, type: INSPhotographyOptionsType, value: Bool) {
        super.init(name: name, type: type)
        row.value = value
    }
}

class IntValueItem: PhotographyOptionItem<IntRow> {
    init(name: String, type: INSPhotographyOptionsType, value: Int) {
        super.init(name: name, type: type)
        row.value = value
    }
}

class StringValueItem: PhotographyOptionItem<LabelRow> {
    init(name: String, type: INSPhotographyOptionsType, value: String) {
        super.init(name: name, type: type)
        row.value = value
    }
}

class IntOptionsItem: PhotographyOptionItem<ActionSheetRow<Int>> {
    init(name: String, type: INSPhotographyOptionsType, index: Int, options: [Int]) {
        super.init(name: name, type: type)
        row.value = options[index]
        row.options = options
    }
}

class StringOptionsItem: PhotographyOptionItem<ActionSheetRow<String>> {
    init(name: String, type: INSPhotographyOptionsType, index: Int, options: [String]) {
        super.init(name: name, type: type)
        row.value = options[index]
        row.options = options
    }
}


class PhotographyOptionsViewController: FormViewController {
    var functionMode: INSCameraFunctionMode = INSCameraFunctionMode.init(functionMode: 0)
    
    let channel = IntValueItem(name: "Channel", type: .channel, value: 0)
    let brightness = IntValueItem(name: "Brightness", type: .brightness, value: 0)
    let contrast = IntValueItem(name: "Contrast", type: .contrast, value: 0)
    let saturation = IntValueItem(name: "Saturation", type: .saturation, value: 0)
    let hue = IntOptionsItem(name: "HUE", type: .HUE, index: 0, options: Array(-15...15))
    let sharpness = IntOptionsItem(name: "Sharpness", type: .sharpness, index: 4, options: Array(0...6))
    let exposureValue = IntOptionsItem(name: "EV", type: .exposureBias, index: 0, options: Array(-8...8))
    
    let stillExposureProgram = StringOptionsItem(name: "Still Exposure Mode", type: .stillExposureOptions, index: 0, options: ["Auto", "ISO priority", "Shutter priority", "Manual"])
    
    let videoExposureProgram = StringOptionsItem(name: "Video Exposure Mode", type: .videoExposureOptions, index: 0, options: ["Auto", "ISO priority", "Shutter priority", "Manual"])
    
    let aeMeterMode = StringOptionsItem(name: "AE Meter", type: .aeMeterMode, index: 0, options: ["Normal", "Manual"])
    let aeManualMeterWeights = IntValueItem(name: "Meter Weights", type: .aeManualMeterWeights, value: 0)
    let whiteBalance = StringOptionsItem(name: "White Balance", type: .whiteBalance, index: 0, options: ["Auto", "2700K", "4000K", "5000K", "6500K", "7500K"])
    let flicker = StringOptionsItem(name: "Flicker", type: .flicker, index: 0, options: ["Auto", "60 hz", "50 hz"])
    let evIndex = IntValueItem(name: "EV Index", type: .evIndex, value: 0)
    
    let stillISO = IntOptionsItem(name: "Still ISO", type: .stillExposureOptions, index: 0, options: [0, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600])
    let stillShutterSpeedN = IntValueItem(name: "Still Shutter Speed n", type: .stillExposureOptions, value: 1)
    let stillShutterSpeedD = IntValueItem(name: "Still Shutter Speed d", type: .stillExposureOptions, value: 1)
    
    let videoISO = IntOptionsItem(name: "Video ISO", type: .videoExposureOptions, index: 0, options: [0, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600])
    let videoShutterSpeedN = IntValueItem(name: "Video Shutter Speed n", type: .videoExposureOptions, value: 1)
    let videoShutterSpeedD = IntValueItem(name: "Video Shutter Speed d", type: .videoExposureOptions, value: 1)
    
    var commandManager: INSCameraBasicCommands!
    
    
    let autoModeVideoParamISO = IntValueItem(name: "Audo Video ISO", type: .autoModeVideoParam, value: 0)
    let autoModeVideoParamShutter = StringValueItem(name: "Audo Video Shutter", type: .autoModeVideoParam, value: "1/1")
    let autoModeStillParamISO = IntValueItem(name: "Audo Still ISO", type: .autoModeStillParam, value: 0)
    let autoModeStillParamShutter = StringValueItem(name: "Audo Still Shutter", type: .autoModeStillParam, value: "1/1")
    
    let videoGamma = StringOptionsItem(name: "Video Gamma", type: .videoGamma, index: 0, options: ["NORMAL", "LOG"])
    
    let mctf = BoolValueItem(name: "MCTF", type: .MCTF, value: false)
    let sportMode = BoolValueItem(name: "Sport Mode", type: .sportMode, value: false)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Photography Options"

        setupForm()
        
        let types = [INSPhotographyOptionsType.evIndex.rawValue as NSNumber,
                     INSPhotographyOptionsType.autoModeVideoParam.rawValue as NSNumber,
                     INSPhotographyOptionsType.autoModeStillParam.rawValue as NSNumber,
                     INSPhotographyOptionsType.channel.rawValue as NSNumber,
                     INSPhotographyOptionsType.brightness.rawValue as NSNumber,
                     INSPhotographyOptionsType.contrast.rawValue as NSNumber,
                     INSPhotographyOptionsType.saturation.rawValue as NSNumber,
                     INSPhotographyOptionsType.HUE.rawValue as NSNumber,
                     INSPhotographyOptionsType.sharpness.rawValue as NSNumber,
                     INSPhotographyOptionsType.exposureBias.rawValue as NSNumber,
                     INSPhotographyOptionsType.whiteBalance.rawValue as NSNumber,
                     INSPhotographyOptionsType.flicker.rawValue as NSNumber,
                     INSPhotographyOptionsType.videoGamma.rawValue as NSNumber,
                     INSPhotographyOptionsType.stillExposureOptions.rawValue as NSNumber,
                     INSPhotographyOptionsType.videoExposureOptions.rawValue as NSNumber,
                     INSPhotographyOptionsType.MCTF.rawValue as NSNumber,
                     INSPhotographyOptionsType.sportMode.rawValue as NSNumber,
                     ]
        commandManager.getPhotographyOptions(with: functionMode, types: types) {[weak self] (err, options, _) in
            guard err == nil else {
                self?.showAlert("Get Photogtaphy Options", "\(err!)")
                return
            }
            
            guard let options = options else {
                self?.showAlert("Get Photogtaphy Options successfully with empty response", "")
                return
            }
            
            self?.evIndex.row.value = Int(options.evIndex)
            if let autoModeStillParam = options.autoModeStillParam {
                self?.autoModeStillParamISO.row.value = Int(autoModeStillParam.iso)
                let ssp = "\(autoModeStillParam.shutterSpeed.value)/\(autoModeStillParam.shutterSpeed.timescale)"
                self?.autoModeStillParamShutter.row.value = ssp
            }
            if let autoModeVideoParam = options.autoModeVideoParam {
                self?.autoModeVideoParamISO.row.value = Int(autoModeVideoParam.iso)
                let vsp = "\(autoModeVideoParam.shutterSpeed.value)/\(autoModeVideoParam.shutterSpeed.timescale)"
                self?.autoModeVideoParamShutter.row.value = vsp
            }
            self?.channel.row.value = Int(options.channel)
            self?.brightness.row.value = Int(options.brightness)
            self?.contrast.row.value = Int(options.contrast)
            self?.saturation.row.value = Int(options.saturation)
            self?.hue.row.value = Int(options.hue)
            self?.sharpness.row.value = Int(options.sharpness)
            self?.exposureValue.row.value = Int(options.exposureBias)
            self?.whiteBalance.row.value = self!.whiteBalance.row.options![Int(options.whiteBalance.rawValue)]
            self?.flicker.row.value = self!.flicker.row.options![Int(options.flicker.rawValue)]
            self?.videoGamma.row.value = self!.videoGamma.row.options![Int(options.videoGamma)]
            
            if let videoExposure = options.videoExposure {
                self?.videoExposureProgram.row.value = self?.videoExposureProgram.row.options![Int(videoExposure.program)]
                self?.videoISO.row.value = Int(videoExposure.iso)
                self?.videoShutterSpeedD.row.value = Int(videoExposure.shutterSpeed.value)
                self?.videoShutterSpeedN.row.value = Int(videoExposure.shutterSpeed.timescale)
            }
            if let stillExposure = options.stillExposure {
                self?.stillExposureProgram.row.value = self?.stillExposureProgram.row.options![Int(stillExposure.program)]
                self?.stillISO.row.value = Int(stillExposure.iso)
                self?.stillShutterSpeedD.row.value = Int(stillExposure.shutterSpeed.value)
                self?.stillShutterSpeedN.row.value = Int(stillExposure.shutterSpeed.timescale)
            }
            
            self?.mctf.row.value = options.enableMCTF
            self?.sportMode.row.value = options.enableSportMode
            
            self?.form.sectionBy(tag: "get")?.reload()
            self?.form.sectionBy(tag: "set")?.reload()
            
            self?.handleChanges()
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        print("PhotographyOptionsViewController deinit")
    }

    func setupForm() {
        
        form +++ Section("get")
            <<< evIndex.row
            <<< autoModeStillParamISO.row
            <<< autoModeStillParamShutter.row
            <<< autoModeVideoParamISO.row
            <<< autoModeVideoParamShutter.row
        +++ Section("set")
            <<< channel.row
            <<< brightness.row
            <<< contrast.row
            <<< saturation.row
            <<< hue.row
            <<< sharpness.row
            <<< exposureValue.row
            <<< stillExposureProgram.row
            <<< stillISO.row
            <<< stillShutterSpeedD.row
            <<< stillShutterSpeedN.row
            <<< videoExposureProgram.row
            <<< videoISO.row
            <<< videoShutterSpeedD.row
            <<< videoShutterSpeedN.row
            <<< aeMeterMode.row
            <<< aeManualMeterWeights.row
            <<< whiteBalance.row
            <<< flicker.row
            <<< videoGamma.row
            <<< mctf.row
            <<< sportMode.row
    }
    
    func handleChanges() {
        let options = INSPhotographyOptions()
        hue.row.onChange {[unowned self] (row) in
            options.hue = Int32(row.value!)
            self.hue.sendCommand(commandManager: self.commandManager, options: options, functionMode: self.functionMode, vc: self)
        }
        
        sharpness.row.onChange {[unowned self] (row) in
            options.sharpness = UInt32(row.value!)
            self.sharpness.sendCommand(commandManager: self.commandManager, options: options, functionMode: self.functionMode, vc: self)
        }
        
        stillExposureProgram.row.onChange {[unowned self] (_) in
            let stillExposureOptions = INSCameraExposureOptions();
            stillExposureOptions.program = UInt8(self.stillExposureProgram.row.options!.index(of: self.stillExposureProgram.row.value!)!)
            
            let iso = UInt(self.stillISO.row.value!)
            var d = Int32(self.stillShutterSpeedN.row.value!)
            if d == 0 { d = 1 }
            let shutterSpeed = CMTime(value: Int64(self.stillShutterSpeedD.row.value!),
                                      timescale: d)
            stillExposureOptions.iso = iso;
            stillExposureOptions.shutterSpeed = shutterSpeed;
            
            options.stillExposure = stillExposureOptions;
            let types = [NSNumber(value: INSPhotographyOptionsType.stillExposureOptions.rawValue)];
            self.commandManager.setPhotographyOptions(options, for: self.functionMode, types: types, completion: {[weak self] (err, successTypes) in
                if let err = err {
                    self?.showAlert("Set Photogtaphy Options", "\(err)")
                } else {
                    self?.showAlert("Set Photogtaphy Options", "SUCCESS")
                }
            })
        }
        videoExposureProgram.row.onChange {[unowned self] (_) in
            let videoExposureOptions = INSCameraExposureOptions();
            videoExposureOptions.program = UInt8(self.videoExposureProgram.row.options!.index(of: self.videoExposureProgram.row.value!)!)
            
            let iso = UInt(self.videoISO.row.value!)
            var d = Int32(self.videoShutterSpeedN.row.value!)
            if d == 0 { d = 1 }
            let shutterSpeed = CMTime(value: Int64(self.stillShutterSpeedD.row.value!),
                                      timescale: d)
            videoExposureOptions.iso = iso;
            videoExposureOptions.shutterSpeed = shutterSpeed;
            
            options.videoExposure = videoExposureOptions;
            let types = [NSNumber(value: INSPhotographyOptionsType.videoExposureOptions.rawValue)];
            self.commandManager.setPhotographyOptions(options, for: self.functionMode, types: types, completion: {[weak self] (err, successTypes) in
                if let err = err {
                    self?.showAlert("Set Photogtaphy Options", "\(err)")
                } else {
                    self?.showAlert("Set Photogtaphy Options", "SUCCESS")
                }
            })
        }
        
        sharpness.row.onChange {[unowned self] (row) in
            let options = INSPhotographyOptions()
            options.sharpness = UInt32(row.value!)
            self.sharpness.sendCommand(commandManager: self.commandManager, options: options, functionMode: self.functionMode, vc: self)
        }
        exposureValue.row.onChange {[unowned self] (row) in
            let options = INSPhotographyOptions()
            options.exposureBias = Float(row.value!)
            self.exposureValue.sendCommand(commandManager: self.commandManager, options: options, functionMode: self.functionMode, vc: self)
        }
        whiteBalance.row.onChange {[unowned self] (row) in
            let options = INSPhotographyOptions()
            options.whiteBalance = INSCameraWhiteBalance.init(rawValue: UInt16(row.options!.index(of: row.value!)!))!
            self.whiteBalance.sendCommand(commandManager: self.commandManager, options: options, functionMode: self.functionMode, vc: self)
        }
        flicker.row.onChange {[unowned self] (row) in
            let options = INSPhotographyOptions()
            options.flicker = INSCameraFlicker.init(rawValue: UInt16(row.options!.index(of: row.value!)!))!
            self.flicker.sendCommand(commandManager: self.commandManager, options: options, functionMode: self.functionMode, vc: self)
        }
        videoGamma.row.onChange {[unowned self] (row) in
            let options = INSPhotographyOptions()
            options.videoGamma = UInt8(row.options!.index(of: row.value!)!)
            self.videoGamma.sendCommand(commandManager: self.commandManager, options: options, functionMode: self.functionMode, vc: self)
        }
        mctf.row.onChange {[unowned self] (row) in
            let options = INSPhotographyOptions()
            options.enableMCTF = row.value!
            self.mctf.sendCommand(commandManager: self.commandManager,
                                  options: options,
                                  functionMode: self.functionMode,
                                  vc: self)
        }
        sportMode.row.onChange {[unowned self] (row) in
            let options = INSPhotographyOptions()
            options.enableSportMode = row.value!
            self.sportMode.sendCommand(commandManager: self.commandManager,
                                       options: options,
                                       functionMode: self.functionMode,
                                       vc: self)
        }
    }
    
    override func textInputDidEndEditing<T>(_ textInput: UITextInput, cell: Cell<T>) {
        guard let tag = cell.row.tag else {
            return
        }
        
        
        let options = INSPhotographyOptions()
        
        switch tag {
        case channel.name:
            options.channel = UInt32(cell.row.value as! Int)
            self.channel.sendCommand(commandManager: commandManager, options: options, functionMode: functionMode, vc: self)
        case brightness.name:
            options.brightness = Int32(cell.row.value as! Int)
            self.brightness.sendCommand(commandManager: commandManager, options: options, functionMode: functionMode, vc: self)
        case contrast.name:
            options.contrast = UInt32(cell.row.value as! Int)
            self.contrast.sendCommand(commandManager: commandManager, options: options, functionMode: functionMode, vc: self)
        case saturation.name:
            options.saturation = UInt32(cell.row.value as! Int)
            self.saturation.sendCommand(commandManager: commandManager, options: options, functionMode: functionMode, vc: self)
        default:
            return
        }
    }
}
