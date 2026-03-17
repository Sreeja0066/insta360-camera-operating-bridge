//
//  RecordViewController.swift
//  INSCameraSDK
//
//  Created by zeng bin on 4/13/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK
import INSCoreMedia
import AVFoundation

class RecordViewController: FormViewController, INSCameraPreviewPlayerDelegate {
    
    var mediaSession = INSCameraMediaSession()
    var previewPlayer: INSCameraPreviewPlayer?
    
    var storageState: INSCameraStorageStatus?
    
    var videoEncode: INSVideoEncode = .H264 {
        didSet {
            self.updateConfiguration()
        }
    }
    
    var gyroTimestamp: Double = 34.0
    
    let configurationVC = LiveConfigurationViewController()
    
    var windowCropInfo: INSWindowCropInfo?
    
    deinit {
        mediaSession.stopRunning { (err) in
            print("stop media session with err: \(String(describing: err))")
        }
        
        INSCameraManager.usb().removeObserver(self, forKeyPath: #keyPath(INSCameraManager.cameraState))
        INSCameraManager.socket().removeObserver(self, forKeyPath: #keyPath(INSCameraManager.cameraState))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Record"
        
        INSCameraManager.usb().addObserver(self,
                                              forKeyPath: #keyPath(INSCameraManager.cameraState),
                                              options: [.old, .new],
                                              context: nil);
        INSCameraManager.socket().addObserver(self,
                                           forKeyPath: #keyPath(INSCameraManager.cameraState),
                                           options: [.old, .new],
                                           context: nil);
        
        setupForm();
        
        setupRenderView()
        
        fetchOptions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        guard let _ = INSCameraManager.shared().currentCamera else {
            return
        }
        
        fetchOptions { [weak self] in
            self?.updateConfiguration()
            self?.runMediaSession()
        }
    }
    
    func setupRenderView() {
        var frame = self.view.bounds;
        let height = frame.size.width * 0.667
        frame.origin.x = 0
        frame.origin.y = frame.size.height - height
        frame.size.height = height
        
        previewPlayer = INSCameraPreviewPlayer(frame: frame, renderType: .sphericalPanoRender)
        previewPlayer?.play(withGyroTimestampAdjust: gyroTimestamp)
        previewPlayer?.delegate = self
        self.view.addSubview(previewPlayer!.renderView)
        mediaSession.plug(self.previewPlayer!)
        
        // adjust field of view parameters
        if let offset = INSCameraManager.shared().currentCamera?.settings?.mediaOffset,
            INSLensOffset(offset: offset).lensType == INSLensType.oneR577Wide.rawValue
            || INSLensOffset(offset: offset).lensType == INSLensType.oneR283Wide.rawValue {
            previewPlayer?.renderView.enablePanGesture = false
            previewPlayer?.renderView.enablePinchGesture = false
            
            previewPlayer?.renderView.render.camera?.xFov = 37
            previewPlayer?.renderView.render.camera?.distance = 700
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupForm() {
        form +++ Section("Basic") {
            $0.header?.height = { CGFloat(0.0) };
            }
            <<< ButtonRow("Configure") {
                $0.title = $0.tag
                $0.presentationMode = .show(controllerProvider: .callback() {[weak self] in
                    return self!.configurationVC
                    }, onDismiss: nil);
            }
            
            <<< SwitchRow("Player Buffer On") {
                $0.title = $0.tag
                }.onChange({[unowned self] (row) in
                    if (row.value == true) {
                        self.previewPlayer?.play(withSmoothBuffer: true)
                    } else {
                        self.previewPlayer?.play(withSmoothBuffer: false)
                    }
                })
            <<< SwitchRow("Rolling Shutter On") {
                $0.title = $0.tag
                }.onChange({[unowned self] (row) in
                    if let renderView = self.previewPlayer?.renderView {
                        renderView.render.enableRollingShutter = row.value!
                        renderView.render.sweepTime = 23.51
                    }
                })
            <<< SwitchRow("Gyro Statiblity On") {
                $0.title = $0.tag
                $0.value = true
                }.onChange({[unowned self] (row) in
                    if let renderView = self.previewPlayer?.renderView {
                        renderView.render.gyroPlayer!.gyroPlayMode = row.value! == true ? self.configurationVC.gyroPlayMode : .none
                    }
                })
            <<< SliderRow(){
                $0.value = Float(gyroTimestamp)
                $0.cell.slider.minimumValue = -40.0
                $0.cell.slider.maximumValue = 40.0
                $0.shouldHideValue = false
                }.onChange({ [unowned self] (row) in
//                    4k30    sweepTime = 23.5    gyro = 34
//                    5.7k30    sweepTime = 23.5    gyro = 34
//                    4k60    sweepTime = 16.3    gyro = 7
                    if let gyroPlayer = self.previewPlayer?.renderView.render.gyroPlayer {
                        gyroPlayer.gyroTimestampAdjust = Double(row.value!)
                    }
                })
        <<< ActionSheetRow<String>("set multiCaptureType") {
            $0.title = $0.tag
            $0.options = ["pano", "instaPano", "wideAngle"]
        }.onChange({ [weak self] (row) in
            self?.mediaSession.stopRunning { (err) in
                guard err == nil else {
                    print("stop media session with err: \(String(describing: err))")
                    return
                }
                let captureType = row.value!
                
                switch captureType {
                case "pano" :
                    let options = INSCameraOptions()
                    options.focusSensor = .all
                    options.expectOutputType = .default
                    self?.changeMultiCaptureType(options, .all)
                case "instaPano" :
                    let options = INSCameraOptions()
                    options.focusSensor = .rear
                    options.expectOutputType = .instaPano
                    self?.changeMultiCaptureType(options, .all)
                case "wideAngle" :
                    let options = INSCameraOptions()
                    options.focusSensor = .rear
                    options.expectOutputType = .default
                    self?.changeMultiCaptureType(options, .rear)
                default:
                    break;
                }
            }
        })
            <<< ButtonRow("Take Picture") {
                $0.title = $0.tag
                }.onCellSelection({ (_, _) in
                    print("start takePicture \(Date())")
                    INSCameraManager.shared().commandManager.takePicture(with: nil, completion: { (_, _) in
                        print("end takePicture \(Date())")
                    })
                })
            <<< ButtonRow("Capture") {
                $0.title = "Start \($0.tag!)"
                }.onCellSelection() {[unowned self] _, row in
                    if row.title?.starts(with: "Start") ?? false {
                        
                        row.title = "Stop \(row.tag!)"
                        //开始录像，修改分辨率为副码流
                        self.mediaSession.stopRunning(completion: { (err) in
                            self.runMediaSession()
                        })
                        
                        if(self.storageState?.cardState == .normal) {
                            INSCameraManager.shared().commandManager.startCapture(with: nil, completion: { (err) in
                                if let err = err {
                                    self.showAlert(row.tag!, "\(String(describing: err))")
                                    return
                                }
                            })
                        }else {
                            row.title = "Start \(row.tag!)"
                            self.showAlert(row.tag!, "No SDCard")
                        }
                    } else {
                        row.title = "Start \(row.tag!)"
                        //录像完毕，切回主码流
                        self.mediaSession.stopRunning(completion: { (err) in
                            self.runMediaSession()
                        })
                        
                        if(self.storageState?.cardState == .normal) {
                            INSCameraManager.shared().commandManager.stopCapture(with: nil, completion: { (err, info) in
                                self.showAlert(row.tag!, "\(String(describing: err)), \(String(describing: info?.uri))")
                                guard let info = info else {
                                    return
                                }
                                print("video url"+(info.uri))
                                
                                return;
                            })
                        } else {
                            row.title = "Stop \(row.tag!)"
                            self.showAlert(row.tag!, "No SDCard")
                        }
                        
                    }
                    row.reload()
            }
    }
    
    func changeMultiCaptureType(_ options: INSCameraOptions, _ activeSensorDevice: INSSensorDevice) -> Void {
        let types:[NSNumber] = [NSNumber(value: INSCameraOptionsType.focusSensor.rawValue), NSNumber(value: INSCameraOptionsType.expectOutputType.rawValue)]
        INSCameraManager.shared().commandManager.setOptions(options, forTypes:types, completion: { (err, types) in
            if let err = err {
                self.showAlert("setOptions", err.localizedDescription);
                return
            }
            INSCameraManager.shared().commandManager.setActiveSensorWith(activeSensorDevice, completion: { (err, mediaOffset, mediaOffsetV3)  in
                if let err = err {
                    self.showAlert("失败", String.init(describing: err))
                } else {
                    self.showAlert("成功", "current offset: \(mediaOffset ?? "")")
                    self.previewPlayer?.renderView.clearCurrentPlayImage()
                    self.runMediaSession()
                }
            })
        })
    }
    
    
    func fetchOptions(completion: (() -> Void)? = nil) {
        var optionTypes = [
            NSNumber(value: INSCameraOptionsType.storageState.rawValue),
            NSNumber(value: INSCameraOptionsType.videoEncode.rawValue),
            NSNumber(value: INSCameraOptionsType.windowCropInfo.rawValue),
        ]
        if INSCameraManager.shared().currentCamera?.cameraType == kInsta360CameraNameOneR {
            optionTypes.append(NSNumber(value: INSCameraOptionsType.gyroTimestamp.rawValue))
        }
        
        INSCameraManager.shared().commandManager.getOptionsWithTypes(optionTypes) { [weak self] (err, options, successTypes) in
            guard let options = options else {
                self?.showAlert("get options", String(describing: err))
                completion?()
                return
            }
            self?.storageState = options.storageStatus
            if self?.videoEncode != options.videoEncode {
                self?.videoEncode = options.videoEncode
            }
            
            if options.gyroTimestamp != 0 {
                self?.previewPlayer?.play(withGyroTimestampAdjust: options.gyroTimestamp)
            }
            self?.windowCropInfo = options.windowCropInfo
            
            var mediaOffset = INSCameraManager.socket().currentCamera?.settings?.mediaOffsetV3
            
            print("dml before conver: \(String(describing: mediaOffset))")
            
            if let windowCropInfo = self?.windowCropInfo, let offset = mediaOffset {
                mediaOffset = INSOffsetCalculator.cropOffset(offset, srcWidth: Int32(windowCropInfo.srcWidth), srcHeight: Int32(windowCropInfo.srcHeight), dstWidth: Int32(windowCropInfo.dstWidth), dstHeight: Int32(windowCropInfo.dstHeight), xOffset: windowCropInfo.cropOffsetX, yOffset: windowCropInfo.cropOffsetY)
            }
            self?.previewPlayer?.play(withOffset: mediaOffset!)
            
            completion?()
        }
    }
    
    func updateConfiguration() -> Void {
        mediaSession.expectedVideoResolution = self.configurationVC.inputVideoResolution
        mediaSession.expectedVideoResolutionSecondary = self.configurationVC.inputVideoResolution2
        mediaSession.previewStreamType = INSPreviewStreamTypeWithValue(self.configurationVC.previewStreamNum)
        mediaSession.expectedAudioSampleRate = self.configurationVC.audioSampleRate
        mediaSession.gyroPlayMode = self.configurationVC.gyroPlayMode
        mediaSession.videoStreamEncode = self.videoEncode
        if configurationVC.previewStreamRotation == 1 {
            mediaSession.previewStreamRotation = INSPreviewStreamRotation.horizon180
        }
    }
    
    func runMediaSession() {
        guard INSCameraManager.shared().cameraState == .connected else {
            return
        }
        if mediaSession.running {
            self.view.isUserInteractionEnabled = false
            mediaSession.commitChanges(completion: { (err) in
                print("commitChanges media session with error: \(String(describing: err))")
                self.view.isUserInteractionEnabled = true
                if let err = err {
                    self.showAlert("commitChanges media failed!", err.localizedDescription);
                    return;
                }
            })
        } else {
            self.view.isUserInteractionEnabled = false
            mediaSession.startRunning { (err) in
                print("start running media session with error: \(String(describing: err))")
                self.view.isUserInteractionEnabled = true
                if let err = err {
                    self.showAlert("start media failed!", err.localizedDescription);
                    self.previewPlayer?.play(withSmoothBuffer: false)
                    return;
                }
            }
        }
    }
    
    func offset(toPlay player: INSCameraPreviewPlayer) -> String? {
        
        if let currentOffset = player.renderView.render.offset {
            return currentOffset
        }
        
        let settings: INSCameraDeviceSettings? = INSCameraManager.shared().currentCamera?.settings
        let mediaOffset = settings?.mediaOffsetV3
        let resolution = configurationVC.inputVideoResolution
        
        if let windowCropInfo, let mediaOffset = mediaOffset {
           let offset = INSOffsetCalculator.cropOffset(mediaOffset, srcWidth: Int32(windowCropInfo.srcWidth), srcHeight: Int32(windowCropInfo.srcHeight), dstWidth: Int32(windowCropInfo.dstWidth), dstHeight: Int32(windowCropInfo.dstHeight), xOffset: windowCropInfo.cropOffsetX, yOffset: windowCropInfo.cropOffsetY)
            return offset
        }
        
        
        return mediaOffset
        
//        let mediaOffset = INSCameraManager.shared().currentCamera?.settings?.mediaOffset
//        
////        return mediaOffset
//        if (INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX
//            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneR
//            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2
//            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3
//            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX4
//            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameA3
//        )
//            && INSLensOffset.isValidOffset(mediaOffset!) {
//            return  INSOffsetCalculator.convertOffset(mediaOffset!, to:.oneX3040_2_2880)
//        } else {
//            return mediaOffset
//        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(INSCameraManager.cameraState) {
            guard let stateValue = change?[NSKeyValueChangeKey.newKey] as? UInt else {
                return;
            }
            let state = INSCameraState(rawValue: stateValue)
            if state == .found {
            } else if state == .connected {
                self.runMediaSession()
            } else {
                self.mediaSession.stopRunning(completion: { (_) in
                    return
                })
            }
        }
    }
}
