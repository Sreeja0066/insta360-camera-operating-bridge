//
//  CommonOptionsViewController.swift
//  INSCameraSDKSample-lite
//
//  Created by zeng bin on 9/30/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK

extension INSCameraStorageStatus {
    open override var description: String {
        switch self.cardState {
        case .invalidFormat:
            return "Invalid format"
        case .noCard:
            return "No card"
        case .noSpace:
            return "no space"
        case .writeProtectCard:
            return "write protect card"
        case .unknownError:
            return "unknown error"
        case .normal:
            return "\(freeSpace) B"
        default:
            return ""
        }
    }
}

extension INSCameraBatteryStatus {
    open override var description: String {
        switch self.powerType {
        case .adapter:
            return "charging"
        case .battery:
            return "\(Double(batteryLevel) / Double(batteryScale))"
        default:
            return ""
        }
    }
}

enum CommonOptionTypeName: String {
    case BatteryStatus = "Battery Status"
    case Mute = "Mute"
    case StorageState = "Storage State"
    case ChannelCountryCode = "Channel Country Code"
    case ChannelList = "Channel List"
}

class CommonOptionsViewController: FormViewController {
    let commandsManager = INSCameraManager.shared().commandManager
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Options"
        
        setupForm()
        fetchOptions()
        fetchChannelListOptions()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupForm() {
        
        let optionsSection = Section("Options")
        optionsSection.tag = optionsSection.header?.title
        
        optionsSection <<< LabelRow(CommonOptionTypeName.BatteryStatus.rawValue) {
                $0.title = $0.tag
            }
            <<< SwitchRow(CommonOptionTypeName.Mute.rawValue) {
                $0.title = $0.tag
                }.onChange({[weak self] (row) in
                    let options = INSCameraOptions()
                    options.mute = row.value ?? false
                    let types:[NSNumber] = [NSNumber(value: INSCameraOptionsType.mute.rawValue)]
                    self?.commandsManager.setOptions(options, forTypes:types, completion: { (err, types) in
                        if let err = err {
                            self?.showAlert(row.tag!, err.localizedDescription);
                            return
                        }
                    })
                })
            <<< LabelRow(CommonOptionTypeName.StorageState.rawValue) {
                $0.title = $0.tag
            }
        
        form +++ optionsSection
        

        let channelSection = Section("5G Channel Service")
        channelSection.tag = channelSection.header?.title
        channelSection <<< TextRow (CommonOptionTypeName.ChannelCountryCode.rawValue) {
            $0.title = $0.tag
        }
        <<< ButtonRow() {
            $0.title = "Apply Channel List"
            }.onCellSelection() {[weak self] _, row in
                self?.applyChannelListOptions()
            }
        <<< ButtonRow() {
            $0.title = "开启相机Wi-Fi"
        }.onCellSelection() {[weak self] _, row in
            
            self?.commandsManager.openCameraWifi(with: nil, channel: 0, completion: { (err) in
                if let err = err {
                    self?.showAlert("失败", String.init(describing: err))
                } else {
                    self?.showAlert("成功", "开启Wi-Fi")
                }
            })
        }
        <<< ButtonRow() {
            $0.title = "关闭相机Wi-Fi"
        }.onCellSelection() {[weak self] _, row in
            self?.commandsManager.closeCameraWifi(with: nil, completion: { (err) in
                if let err = err {
                    self?.showAlert("失败", String.init(describing: err))
                } else {
                    self?.showAlert("成功", "关闭Wi-Fi")
                }
            })
        }
        
        form +++ channelSection
        #if false
        let iperfSection = Section("Iperf Service")
        iperfSection.tag = iperfSection.header?.title
        
        iperfSection <<< ButtonRow() {
            $0.title = "Open Iperf Via TCP"
        }.onCellSelection() {[weak self] _, row in
            let option = INSOpenIperfOption(mode:.TCP)
            self?.commandsManager.openIperf(with: option, completion: { (err) in
                if let err = err {
                    print("\(row.title!) failed with error: \(err)")
                    self?.showAlert(row.title!, err.localizedDescription);
                    return
                }
                self?.showAlert(row.title!, "success");
            })
        }
        
        iperfSection <<< ButtonRow() {
            $0.title = "Open Iperf Via UDP"
        }.onCellSelection() {[weak self] _, row in
            let option = INSOpenIperfOption(mode:.UDP)
            self?.commandsManager.openIperf(with: option, completion: { (err) in
                if let err = err {
                    print("\(row.title!) failed with error: \(err)")
                    self?.showAlert(row.title!, err.localizedDescription);
                    return
                }
                self?.showAlert(row.title!, "success");
            })
        }
        
        iperfSection <<< ButtonRow() {
            $0.title = "Close Iperf"
        }.onCellSelection() {[weak self] _, row in
            self?.commandsManager.closeIperf(completion: { (err) in
                if let err = err {
                    print("\(row.title!) failed with error: \(err)")
                    self?.showAlert(row.title!, err.localizedDescription);
                    return
                }
                self?.showAlert(row.title!, "success");
            })
        }
        
        iperfSection <<< ButtonRow() {
            $0.title = "Iperf Average Data"
        }.onCellSelection() {[weak self] _, row in
            self?.commandsManager.getAverageIperf(completion: { (err, number) in
                if let mErr = err {
                    self?.showAlert(row.title!, (mErr.localizedDescription));
                    return
                }
                self?.showAlert(row.title!, "\(number)");
            })
        }
        
        form +++ iperfSection
        #endif
    }
    
    func fetchOptions() {
        let optionTypes = [
            NSNumber(value: INSCameraOptionsType.batteryStatus.rawValue),
            NSNumber(value: INSCameraOptionsType.mute.rawValue),
            NSNumber(value: INSCameraOptionsType.storageState.rawValue),
            ];
        
        commandsManager.getOptionsWithTypes(optionTypes) { (err, options, successTypes) in
            guard let options = options else {
                self.showAlert("get options", String(describing: err))
                return
            }
            
            self.rowBy(optionTypeName: .BatteryStatus)?.value = options.batteryStatus?.description;
            
            self.rowBy(optionTypeName: .StorageState)?.value = options.storageStatus?.description;
            self.rowBy(optionTypeName: .Mute)?.value = options.mute;
            
            self.form.sectionBy(tag: "Options")?.reload()
        }
    }
    
    func fetchChannelListOptions() {
        let optionTypes = [
            NSNumber(value: INSCameraOptionsType.wifiChannelList.rawValue),
            ];
        
        commandsManager.getOptionsWithTypes(optionTypes) { (err, options, successTypes) in
            guard let options = options else {
                self.showAlert("get channel list", String(describing: err))
                return
            }
            
            let countryCode  = options.wifiChannelList.countryCode
            self.rowBy(optionTypeName: .ChannelCountryCode)?.value = countryCode
            /*
            let listData = options.wifiChannelList.channelListData
            let listArray = [UInt8](listData)
            let listString = String(describing: listArray)
            self.rowBy(optionTypeName: .ChannelList)?.value = listString
            */
            self.form.sectionBy(tag: "5G Channel Service")?.reload()
        }
    }
    
    func applyChannelListOptions() {
        let optionTypes = [
            NSNumber(value: INSCameraOptionsType.wifiChannelList.rawValue),
            ];
        let options = INSCameraOptions();
        
        let countryCode = form.rowBy(tag: CommonOptionTypeName.ChannelCountryCode.rawValue)?.baseValue
        /*
        let listString = form.rowBy(tag: CommonOptionTypeName.ChannelList.rawValue)?.baseValue as! String
        let trimString = listString.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: ["[","]"])
        let listArray = trimString.components(separatedBy: [","])
        var list:[UInt8] = []
        for listItem in listArray {
            list.append(UInt8(listItem)!)
        }
        let listData = NSData(bytes: list, length: list.count)
        */
        
        options.wifiChannelList = INSCameraWifiChannelList(countryCode: countryCode as! String)
        commandsManager.setOptions(options, forTypes: optionTypes) { (err, successTypes) in
            if let err = err {
                self.showAlert("set channel list", err.localizedDescription);
                return
            }
            self.showAlert("set channel list", "success");
        }
    }
    
    func rowBy<T>(optionTypeName: CommonOptionTypeName) -> Eureka.RowOf<T>? where T : Equatable {
        return form.rowBy(tag: optionTypeName.rawValue)
    }
}
