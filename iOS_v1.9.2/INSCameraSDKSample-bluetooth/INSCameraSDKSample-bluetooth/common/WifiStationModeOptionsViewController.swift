//
//  WifiStationModeOptionsViewController.swift
//  INSCameraSDKDemo
//
//  Created by insta360 on 2023/11/21.
//  Copyright © 2023 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK

class WifiStationModeOptionsViewController: FormViewController {

    let commandsManager = INSCameraManager.shared().commandManager;
    var bluttoothCommandsManager: INSCameraBasicCommands = INSCameraManager.shared().commandManager
    let scanIntervalRow = IntRow("Scan Interval (s)")
    let scanTimesRow = IntRow("Scan Times")
    // wifi 账号
    let wifiSsidRow = NameRow("wifi ssid")
    let wifiPasswordRow = NameRow("wifi password")
    // 绑定设备
    let bindSwitchRow = SwitchRow("Bind Set")
    
    init() {
        super.init(style: UITableView.Style.grouped)
    }
    
    init(commandsManager: INSCameraBasicCommands) {
        super.init(style: UITableView.Style.grouped)
        self.bluttoothCommandsManager = commandsManager
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Wifi Station Mode"
        
        setupForm()
        setupObservers()
    }
    
    func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraWifiScanListChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSetWifiConnectionNotification(_:)),
                                               name: .INSCameraCameraWifiStatus, object: nil)
    }
    
    func setupForm() {
        scanIntervalRow.title = scanIntervalRow.tag
        scanTimesRow.title = scanTimesRow.tag
        wifiSsidRow.title = wifiSsidRow.tag
        wifiPasswordRow.title = wifiPasswordRow.tag
        bindSwitchRow.title = bindSwitchRow.tag
        bindSwitchRow.value = false
        
        form +++ Section("Options")
            <<< scanIntervalRow
            <<< scanTimesRow
            <<< wifiSsidRow
            <<< wifiPasswordRow
            <<< bindSwitchRow
        
        +++ Section("Action")
            <<< ButtonRow("wifi scan info") {
                $0.title = $0.tag
            }.onCellSelection({ [weak self] (_, row) in
                guard let strongSelf = self else {
                    return
                }
                let params: INSGetWifiScanParams = INSGetWifiScanParams()
                params.interval = UInt32(strongSelf.scanIntervalRow.value ?? 1)
                params.count = UInt32(strongSelf.scanTimesRow.value ?? 1)
                strongSelf.commandsManager.getWifiScanInfo(with: params, completion: { error in
                    if let err = error {
                        self?.showAlert("失败", String.init(describing: err))
                    } else {
                        self?.showAlert("成功", "getWifiScanInfo")
                    }
                })
            })
            <<< ButtonRow("wifi connect check") {
                $0.title = $0.tag
            }.onCellSelection({ [weak self] (_, row) in
                guard let strongSelf = self else {
                    return
                }
                let wifiInfo: INSWifiConnectionInfo = INSWifiConnectionInfo()
                wifiInfo.ssid = strongSelf.wifiSsidRow.value ?? ""
                wifiInfo.password = strongSelf.wifiPasswordRow.value ?? ""
                let params: INSSetWifiConnectionInfo = INSSetWifiConnectionInfo()
                params.wifiConnectionInfo = wifiInfo
                strongSelf.commandsManager.setCameraWifiConnectionInfo(wifiInfo) { error in
                    
                }
            })
            <<< ButtonRow("wifi mode to AP") {
                $0.title = $0.tag
            }.onCellSelection({ [weak self] (_, row) in
                guard let strongSelf = self else {
                    return
                }
                let wifiMode: INSSetWifiMode = INSSetWifiMode()
                wifiMode.wifiMode = .AP
                strongSelf.bluttoothCommandsManager.setWifiModeWithParams(wifiMode) { error in
                    if let err = error {
                        self?.showAlert("失败", String.init(describing: err))
                    } else {
                        self?.showAlert("成功", "setWifiMode: AP")
                    }
                }
            })
            <<< ButtonRow("get cloud upload status") {
                $0.title = $0.tag
            }.onCellSelection({ [weak self] (_, row) in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.commandsManager.getCloudStorageUploadStatus { (error, uploadParams) in
                    if let err = error {
                        self?.showAlert("失败", String.init(describing: err))
                    } else {
                        if let params: INSCloudStorageUploadParams = uploadParams {
                            print("TT1: params:\(params.uploadStatus)")
                        }
                        self?.showAlert("成功", "getCloudStorageUploadStatus")
                    }
                }
            })
        
            <<< SwitchRow("cloud storage upload status") {
                $0.title = $0.tag
            }.onChange({ [weak self] row in
//                print("TT1: status:\(row.value)")
                guard let strongSelf = self else {
                    return
                }
                //INSCloudUploadStatus
                var uploadStatus: INSCloudUploadStatus = .idle
                if let value = row.value, value == true {
                    uploadStatus = .uploading
                }
                let params: INSCloudStorageUploadParams = INSCloudStorageUploadParams()
                params.uploadStatus = uploadStatus
                strongSelf.commandsManager.setCloudStorageUploadStatusWith(params, timeout: 5) { (error, result) in
                    if let err = error {
                        self?.showAlert("失败", String.init(describing: err))
                    } else {
                        self?.showAlert("成功", "setCloudStorageUploadStatus:\(uploadStatus)")
                    }
                }
            })
            <<< ButtonRow("get cloud bind status") {
                $0.title = $0.tag
            }.onCellSelection({ [weak self] (_, row) in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.commandsManager.getCloudStorageBindStatusInfo { error, bindParams in
                    if let err = error {
                        self?.showAlert("失败", String.init(describing: err))
                    } else {
                        if let params: INSCloudStorageBindParams = bindParams {
//                            print("TT1 params:\(params.bindStatus)")
                            switch params.bindStatus {
                            case .notBound:
                                print("TT1 当前设备未绑定")
                                self?.showAlert("成功", "getCloudBindStatus: 当前设备未绑定")
                            case .bound:
                                print("TT1 当前设备已绑定")
                                self?.showAlert("成功", "getCloudBindStatus: 当前设备已绑定")
                            default:
                                break
                            }
                        }
                    }
                }
            })
            <<< ButtonRow("cloud set bind device") {
                $0.title = $0.tag
            }.onCellSelection({ [weak self] (_, row) in
                guard let strongSelf = self else {
                    return
                }
                let params: INSCloudStorageBindParams = INSCloudStorageBindParams()
//                print("TT1 bindSwitch: \(strongSelf.bindSwitchRow.value)")
                params.bindStatus = .notBound
                if strongSelf.bindSwitchRow.value == true {
                    params.bindStatus = .bound
                }
                params.userName = "13751126802"
                params.serialNum = "INSWWYYNXXXXXX"
                params.token = "eyJhbGciOiJIUzI1NiJ9.eyJrZXlWZXJzaW9uIjoxMTksIm9wZW5JZCI6Im9LZDAwNHIzN0kzWGVBMXhpUWZFYXFOZjJ6TzgiLCJ0b2tlblZlcnNpb24iOjAsImVuY3J5cHQiOiJUWEk0YTJ0dFJVZDRjbkl6ZUVSSVVudFZNb0lvaUhucGNNOXFLbzVCdVljVDBwdmQyWVRaSVIxamdHd0plcWZrbGhEUy9jUTlhLzJSZ2RFMkVGUjdsNWc2dDNjYlN2dk1uUXl5eGx3VTBTeDVFc2EyWEpOaDdCaXNETERqYjZlUiIsImV4cCI6MTcxNjM0Nzk4OCwidGltZXN0YW1wIjoxNzAwNzk1OTg4NjI2fQ.bZvPGlJbr391WRBVIlQ5JJAqlMgA5gAmSkrybfNMX4w"
                
                strongSelf.commandsManager.setCloudStorageBindStatusInfoWith(params) { error, bindResp in
                    if let err = error {
//                        self?.showAlert("失败", String.init(describing: err))
                        return
                    }
                    if let bindParamResp: INSSetCloudStorageBindStatusResp = bindResp {
                        switch bindParamResp.result {
                        case .bindSuccess:
                            print("TT1 绑定/解绑成功")
                        case .bindFaild:
                            print("TT1 绑定/解绑失败")
                        @unknown default:
                            break
                        }
                    }
                }
            })
        <<< ButtonRow("set avilable wifi") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            guard let strongSelf = self else {
                return
            }
           
            let wifiInfo: INSWifiConnectionInfo = INSWifiConnectionInfo()
            wifiInfo.ssid = "AuthHotel"
            let params: INSSetWifiConnectionInfo = INSSetWifiConnectionInfo()
            params.wifiConnectionInfo = wifiInfo
            strongSelf.commandsManager.setAvailableWifiWithParams(wifiInfo) { error in
                if let error = error {
                    strongSelf.showAlert("失败", "开放式 wifi 下发给相机失败：\(error.localizedDescription)")
                } else {
                    strongSelf.showAlert("成功", "开放式 wifi 下发给相机成功")
                }
            }
        })
    }
    
    //MARK: - Notification Methods
    @objc func handleNotification(_ notification: Notification) -> Void {
        print(String(describing: notification.userInfo))
        if let mobile = notification.userInfo?["scanWifiList"] as? INSWifiScanInfoList {
            for info in mobile.wifiInfoArray {
                let wifiInfo = info as? INSWifiScanInfo
                print("TT1 ssid:\(wifiInfo?.ssid)")
                print("TT1 bssid:\(wifiInfo?.bssid)")
                print("TT1 =================================")
            }
        }
        self.showAlert(notification.name.rawValue, String(describing: notification.userInfo))
    }
    
    @objc func handleSetWifiConnectionNotification(_ notification: Notification) -> Void {
        if let result = notification.userInfo?["wifiConnectionResult"] as? INSCameraWifiConnectionResult {
            if let str = getResultTextFromCode(resultCode: result.wifiConnectionResult) {
                print("TT1 校验结果:\(str)")
                self.showAlert("校验结果", "\(str)")
            }
        }
    }
    
    private func getResultTextFromCode(resultCode: INSWifiConnectionResult) -> String? {
        var resultStr: String? = nil
        switch resultCode {
        case .success:
            resultStr = "成功"
        case .errorConnectFailed:
            resultStr = "无法连接路由器，可能是账号密码错误"
        case .timeout:
            resultStr = "已连接路由器，但无法ping通公网"
        default:
            resultStr = nil
        }
        return resultStr;
    }
}

