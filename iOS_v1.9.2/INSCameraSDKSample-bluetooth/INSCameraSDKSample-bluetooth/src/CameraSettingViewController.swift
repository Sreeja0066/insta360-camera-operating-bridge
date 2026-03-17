//
//  CameraSetting.swift
//  INSCameraSDKSample-bluetooth
//
//  Created by dml on 2025/3/11.
//  Copyright © 2025 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK
import INSCoreMedia
import Foundation


class CameraSettingViewController: FormViewController{
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupForm()
        addNotification()
    }
    
    private func addNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(storageFileStatusChanged(noti:)), name: .INSCameraDataExportStatus, object: nil)
    }
    @objc private func storageFileStatusChanged(noti: Notification) {
        guard let userInfo = noti.userInfo, let trackState = userInfo["trackStatus"] as? INSFileTrackState else {
            return
        }
        
        let outputUrl = NSURL()
        
//        let resourceURI = "https://example.com/path/to/resource.zip"

        // 本地文件路径
        let tmpPath = NSHomeDirectory() + "/Documents/resource.tar"
        let localFileURL = URL(fileURLWithPath: tmpPath)
        
        INSCameraManager.shared().commandManager.fetchResource(withURI: trackState.uri!, toLocalFile: localFileURL) {
            progress in
            if let progress = progress {
                print("下载进度: \(progress.fractionCompleted * 100)%")
            }
        } completion: { error in
            // 完成回调
            if let error = error {
                print("下载失败: \(error.localizedDescription)")
            } else {
                print("下载成功，文件保存到: \(localFileURL.path)")
            }
        }

        

        
    }
    
    func setupForm() {
        form +++ Section("Camera Setting")
        
        <<< ButtonRow("Erase SD Card"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            INSCameraManager.shared().commandManager.eraseSDCard(with: INSStorageType.SD, completion: {error in
                if let error = error {
                    self?.showAlert("Erase SD Card Failed!", String.init(describing: error))
                } else {
                    self?.showAlert("Erase", " SD Card SUCCESS!")
                }
            })

        })
        
        <<< ButtonRow("Camera Activate") { row in
            row.title = row.tag;
        }.onCellSelection() { [weak self] _, row in
            
            guard let serialNumber = INSCameraManager.shared().currentCamera?.serialNumber else {
                self?.showAlert("提示", "请先连接相机")
                return
            }
            let commandManager = INSCameraManager.shared().commandManager
            
            INSCameraActivateManager.setAppid("mmrdyydxlj0e0rwb", secret: "ynjy0l7v0ody9d36jbzlf74dfhvlrn5p")
            
            INSCameraActivateManager.share().activateCamera(withSerial: serialNumber, commandManager: commandManager) { deviceInfo, error in
                if let activateError = error {
                    self?.showAlert("Activate to \(serialNumber)", String(describing: activateError))
                } else {
                    let deviceType = deviceInfo?["deviceType"] ?? ""
                    let serialNumber = deviceInfo?["serial"] ?? ""
                    self?.showAlert("Activate to success", "deviceType: \(deviceType), serial: \(serialNumber)")
                }
            }
        }
        
        <<< ButtonRow() {
            $0.title = "Close Camera"
        }.onCellSelection() {_, row in
            if INSCameraManager.socket().cameraState == .connected || INSCameraManager.socket().cameraState == .found {
                INSCameraManager.socket().commandManager.closeCamera({_ in
                })
            }
        }
        
        <<< ButtonRow() {
            $0.title = "Get Camera Log"
        }.onCellSelection() { _, row in
            if INSCameraManager.socket().cameraState == .connected || INSCameraManager.socket().cameraState == .found {
                INSCameraManager.shared().commandManager.fetchNewStorageFileURI(with: .log, timeout: 5) { error in

                    if let error = error {
                        print("Failed! \(error)")
                    } else {
                        print("Success")
                    }
                }
            }
            
        }
        
        <<< ActionSheetRow<String>("camera preview") { row in
            row.title = row.tag
            row.options = ["unknown", "idle", "export", "playback", "download", "liveView"]
        }.onChange({ [weak self] (row) in
            guard let value = row.value else { return }
            
            let state: INSSetAccessCameraFileStateAccessState
            switch value {
            case "unknown":
                state = .unknown
            case "idle":
                state = .idle
            case "export":
                state = .export
            case "playback":
                state = .playback
            case "download":
                state = .download
            case "liveView":
                state = .liveView
            case "close":
                // 特殊处理 close 情况
                INSCameraManager.shared().commandManager.setAppAccessFileState(.liveView, completion: { _ in })
                return
            default:
                return
            }
            
            INSCameraManager.shared().commandManager.setAppAccessFileState(state, completion: { _ in
                // 完成回调可以在这里处理
            })
        })
        
//        <<< ButtonRow() {
//            $0.title = "function"
//        }.onCellSelection() { _, row in
//            let options = INSCameraOptions()
//            options.photoSubMode = 100
//            options.videoSubMode = 2
//            
//            let types = [
//                NSNumber(value: INSCameraOptionsType.photoSubMode.rawValue),
//                NSNumber(value: INSCameraOptionsType.videoSubMode.rawValue),
//            ]
//            print("🍁🍁:【setPhotographyOptionsFor】 *** setCameraOptionsFor *** videoSubMode = \(options.videoSubMode), types: \(types)")
//            INSCameraManager.shared().commandManager.setOptions(options, forTypes:types, completion: { (err, types) in
//                if let err = err {
//                    print(err)
//                } else {
//                    print("🍁🍁setOptions Success!")
//                }
//            })
//        }
//        
//        <<< ButtonRow() {
//            $0.title = "videoResolution"
//        }.onCellSelection() { _, row in
//            let options = INSPhotographyOptions()
//            let functionMode = INSCameraFunctionMode(functionMode: 2)
//            options.videoResolution = INSVideoResolution3840x3840x30
//            let types = [
//                NSNumber(value: INSPhotographyOptionsType.videoResolution.rawValue),
//            ]
//            
//            print("🍁🍁:【setPhotographyOptionsFor】 *** setCameraOptionsFor *** functionMode = \(functionMode.functionMode), \(options.videoResolution)")
//            INSCameraManager.shared().commandManager.setPhotographyOptions(options, for: functionMode, types: types, completion: {
//                error, _ in
//                if let error = error {
//                    print(error)
//                }else{
//                    print("🍁🍁Success!")
//                    
//                    let timelapseOptions:INSStartCaptureTimelapseOptions = INSStartCaptureTimelapseOptions()
//                    
//                    timelapseOptions.mode = .video
//                    timelapseOptions.timelapseOptions?.duration = 60
//                    
//                    INSCameraManager.shared().commandManager.startCaptureTimelapse(with: timelapseOptions, completion: {_ in
//                        
//                    })
//                }
//                
//            })
//        }
//        
//        <<< ButtonRow() {
//            $0.title = "start recorder"
//        }.onCellSelection() { _, row in
//            let timelapseOptions:INSStartCaptureTimelapseOptions = INSStartCaptureTimelapseOptions()
//            
//            timelapseOptions.mode = .video
//            timelapseOptions.timelapseOptions?.duration = 60
//            
//            INSCameraManager.shared().commandManager.startCaptureTimelapse(with: timelapseOptions, completion: {_ in 
//                
//            })
//            
//        }
     
//        <<< ActionSheetRow<String>("Set Sharpness") { row in
//               row.title = row.tag
//               row.options = ["0", "3","6"]
//        }.onChange({[weak self] (row) in
//            let optionTypes = [
//                NSNumber(value: INSPhotographyOptionsType.sharpness.rawValue)
//            ];
//            
//            let functionMode = INSCameraFunctionMode(functionMode: 0)
//            let options = INSPhotographyOptions()
//            
//            options.sharpness = UInt32(row.value!)!
//            
//            INSCameraManager.shared().commandManager.getPhotographyOptions(with: functionMode, types: optionTypes, completion: { [weak self] error, options,arg  in
//                
//                print("options.sharpness: \(options?.sharpness)")
//                
//            })
//        })
        
        
        <<< ActionSheetRow<String>("Set Mute") { row in
            row.title = row.tag
            row.options = ["open", "close"]
        }.onChange({(row) in
            let optionTypes = [
                NSNumber(value: INSCameraOptionsType.mute.rawValue),
                ];
    
            let options = INSCameraOptions()
            
            if "open" == row.value {
                options.mute = true
            } else {
                options.mute = false
            }

            INSCameraManager.socket().commandManager.setOptions(options, forTypes: optionTypes, completion: {error,successTypes in
                if let error = error {
                    print("Error:\(error)")
                    return
                }
                
                print("Success")
            })
        })
        
        
        
//        <<< ButtonRow() {
//            $0.title = "获取镜头类型"
//        }.onCellSelection() { _, row in
//            INSCameraManager.shared().commandManager.getActiveSensor { error, senor, _, _ in
//                print("ActiveSensor:\(senor)")
//            }
//        }
        
//        <<< ActionSheetRow<String>("Set AppAccessFileState") { row in
//            row.title = row.tag
//            row.options = ["0", "1", "2", "3", "4", "5"]
//        }.onChange({[weak self] (row) in
//            let enumValue:UInt = UInt(row.value ?? "0") ?? 0
//            let stateValue = INSSetAccessCameraFileStateAccessState(rawValue: enumValue) ?? .unknown
//
////            print("AppAccessFileState :\(enumValue)")   
//            print("AppAccessFileState :\(stateValue)")
//            
//            INSCameraManager.shared().commandManager.setAppAccessFileState(.liveView, completion: {
//                error in
//                
//                
//            })
//        })

        
    }
}
