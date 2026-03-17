//
//  RootViewController+Sections.swift
//  INSCameraSDKSample-lite
//
//  Created by zeng bin on 9/29/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import Foundation
import Eureka
import INSCameraSDK

extension RootViewController {
    var actionsSection: Section {
        let section = Section("Actions")
        section <<< ButtonRow("Connect Wi-Fi Mode") { row in
            row.title = row.tag;
        }.onCellSelection({ [unowned self] (_, row) in
            print("Connect Wi-Fi Mode")
            if INSCameraManager.socket().cameraState == .connected {
                self.showAlert("Tip", "Camera is already connect")
            } else {
                INSCameraManager.socket().setup()
            }
        })
        <<< ButtonRow("Disconnect Wi-Fi Mode") { row in
            row.title = row.tag;
        }.onCellSelection({ (_, row) in
            print("Disconnect Wi-Fi Mode")
            if INSCameraManager.socket().cameraState == .connected || INSCameraManager.socket().cameraState == .found {
                INSCameraManager.socket().shutdown()
            }
        })
        <<< ButtonRow("Bluetooth") {
            $0.title = $0.tag
            $0.presentationMode = .show(controllerProvider: .callback() {
                BluetoothViewController()
            }, onDismiss: nil);
        }

        <<< ButtonRow("Record new") { row in
            row.title = row.tag;
            row.presentationMode = .show(controllerProvider: .callback() {
                CameraConfigByJsonController()
            }, onDismiss: nil);
        }
        
        <<< ButtonRow("For internal testing​​") { row in
            row.title = row.tag;
            row.presentationMode = .show(controllerProvider: .callback() {
                DemoTestViewController()
            }, onDismiss: nil);
        }
        
        <<< ButtonRow("AV Output​​") { row in
            row.title = row.tag;
            row.presentationMode = .show(controllerProvider: .callback() {
                AVOutputViewController()
            }, onDismiss: nil);
        }
        return section
    }
    
    var mediasSection: Section {
        let section = Section("Medias")
        section
        <<< ButtonRow("Player") { row in
            row.title = row.tag;
            row.presentationMode = .show(controllerProvider: .callback() {
                PlayerViewController()
            }, onDismiss: nil);
        }
        <<< ButtonRow("Camera Resource List") { row in
            row.title = row.tag
            row.presentationMode = .show(controllerProvider: .callback() {
                RemoteMediaViewController()
            }, onDismiss: nil);
        }
        return section
    }
    
    var CameraInfoSection: Section{
        let section = Section("Camera")
        section
        
        <<< ButtonRow("Camera Setting") { row in
            row.title = row.tag;
            row.presentationMode = .show(controllerProvider: .callback() {
                CameraSettingViewController()
            }, onDismiss: nil);
        }
        
        <<< LabelRow("Wi-FI") { row in
            row.title = row.tag
        }
        <<< LabelRow("Wi-FI Passward") { row in
            row.title = row.tag
        }
        
        <<< LabelRow("Battery") { row in
            row.title = row.tag
        }
        <<< LabelRow("SD Card Status") { row in
            row.title = row.tag
        }
        
        <<< LabelRow("SD Total Space") { row in
            row.title = row.tag
        }
        
        <<< LabelRow("SD Free Space") { row in
            row.title = row.tag
        }
        
        <<< LabelRow("Activate Time") { row in
            row.title = row.tag
        }
        
  
        return section
    }
    
    func updateCameraInfo(){
        if INSCameraManager.socket().cameraState != .connected {
            return
        }
        
        let optionTypes = [
            NSNumber(value: INSCameraOptionsType.batteryStatus.rawValue),
            NSNumber(value: INSCameraOptionsType.storageState.rawValue),
            NSNumber(value: INSCameraOptionsType.activateTime.rawValue),
            NSNumber(value: INSCameraOptionsType.wifiInfo.rawValue),
            ];
        INSCameraManager.shared().commandManager.getOptionsWithTypes(optionTypes) { (err, options, successTypes) in
            guard let options = options else {
//                self.showAlert("get options====", String(describing: err))
                return
            }
            var sdCardStatus = "error"
            switch options.storageStatus?.cardState {
            case .normal:
                sdCardStatus = "Normal"
                break
            case .noCard:
                sdCardStatus = "NoCard"
                break
            case .noSpace:
                sdCardStatus = "NoSpace"
                break
            case .invalidFormat:
                sdCardStatus = "INvalid Format"
                break
            case .writeProtectCard:
                sdCardStatus = "Write Protect Card"
                break
            case .unknownError:
                sdCardStatus = "UnknownError"
                break
            default:
                sdCardStatus = "Status Error"
            }
            
            // 激活时间
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let date = Date(timeIntervalSince1970: Double(options.activateTime / 1000))
            
            // WIFI信息
            if let batteryRow = self.form.rowBy(tag: "Battery") as? LabelRow {
                batteryRow.value = "\(String(describing: options.batteryStatus!.batteryLevel))"
                batteryRow.updateCell() // 刷新 UI
            }

            if let sdCardStatusRow = self.form.rowBy(tag: "SD Card Status") as? LabelRow {
                sdCardStatusRow.value = sdCardStatus
                sdCardStatusRow.updateCell() // 刷新 UI
            }

            if let sdTotalSpaceRow = self.form.rowBy(tag: "SD Total Space") as? LabelRow {
                let totalSpaceGB = Double(options.storageStatus!.totalSpace) / Double(1024 * 1024 * 1024)
                sdTotalSpaceRow.value = String(format: "%.2fG", totalSpaceGB) // 保留两位小数
                sdTotalSpaceRow.updateCell() // 刷新 UI
            }

            if let sdFreeSpaceRow = self.form.rowBy(tag: "SD Free Space") as? LabelRow {
                let freeSpaceGB = Double(options.storageStatus!.freeSpace) / Double(1024 * 1024 * 1024)
                sdFreeSpaceRow.value = String(format: "%.2fG", freeSpaceGB) // 保留两位小数
                sdFreeSpaceRow.updateCell() // 刷新 UI
            }
            if let activateTimeRow = self.form.rowBy(tag: "Activate Time") as? LabelRow {
                activateTimeRow.value = formatter.string(from: date)
                activateTimeRow.updateCell() // 刷新 UI
            }

            if let wifiSSIDRow = self.form.rowBy(tag: "Wi-FI") as? LabelRow {
                wifiSSIDRow.value = options.wifiInfo?.ssid
                wifiSSIDRow.updateCell() // 刷新 UI
            }

            if let wifiPasswordRow = self.form.rowBy(tag: "Wi-FI Passward") as? LabelRow {
                wifiPasswordRow.value = options.wifiInfo?.password
                wifiPasswordRow.updateCell() // 刷新 UI
            }
        }
    }
    
}
