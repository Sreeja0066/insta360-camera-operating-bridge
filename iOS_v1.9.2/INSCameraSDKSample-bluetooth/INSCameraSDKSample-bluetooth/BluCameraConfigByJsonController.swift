//
//  BluCameraConfigByJsonController.swift
//  INSCameraSDKSample-bluetooth
//
//  Created by dml on 2025/2/7.
//  Copyright © 2025 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK
import INSCoreMedia
import Foundation


class BluCameraConfigByJsonController: FormViewController, URLSessionDelegate{

    // new section
    static let aebCaptureNumName           = "aeb_capture_num"
    static let rawCaptureTypeName          = "raw_capture_type"
    static let exposureBiasName            = "exposure_bias"
    static let photoResolutionName         = "photo_resolution"
    static let whiteBalanceName            = "white_balance"
    static let exposureProgramName         = "exposure_program"
    static let exposureISOName             = "exposure_iso"
    static let exposureShutterSpeedName    = "exposure_shutter_speed"
    static let fovTypeName                 = "fov_type"
    static let photographySelfTimerName    = "photography_self_timer"
    static let videoSelfieTypeName         = "video_selfie_type"
    static let livingPlatformName          = "living_platform"
    static let recordResolutionName        = "record_resolution"
    static let videoISOTopLimitName        = "video_iso_top_limit"
    static let exportTypeName              = "export_type"
    static let photoSizeIDName             = "photo_size_id"
    static let colorModeName               = "color_mode"
    static let accelerateFrequencyName     = "accelerate_frequency"
    static let recordDurationName          = "record_duration"
    static let exposureIndividualName      = "exposure_individual"
    static let livingBitrateName           = "living_bitrate"
    static let hdrPhotoModeName            = "hdr_photo_mode"
    static let hdrSwitchName               = "hdr_switch"
    static let iLogSwitchName              = "i_log_switch"
    static let pureVideoEnhanceSwitchName  = "pure_video_enhance_switch"
    static let lapseTimeName               = "lapse_time"
    static let burstCaptureParamsName      = "burst_capture_params"
    static let splicingBaseEnable      = "splicing_base_enable"
//    splicing_base_enable
//    burst_capture_params
//    lapse_time
    
    // Json配置化，文件下载路径q
    
    let docPath =  NSHomeDirectory() + "/Documents"
    
    var protoMapPath = ""
    var cameraAttrSupportManagerPath = NSHomeDirectory() + "/Documents/Insta360_camera_attr_support.json"
    
    var enableInternalSplicing:Bool = false
    var currentOptions:INSPhotographyOptions?
    var currentLapseTime: INSTimelapseOptions? = INSTimelapseOptions()
    
    // 参数管理
    let attrManager = INSCameraAttrManagerWrapper()
    
    var mediaSession = INSCameraMediaSession()
    var filePath: String = ""
    var shouldRestartPreview: Bool = true
    var state: INSCameraCaptureState = .notCapture
    var currentFocusSensor: INSSensorDevice = .unknown
    var storageState: INSCameraStorageStatus?
    var windowCropInfo: INSWindowCropInfo?
    
    var currentProtect: INSOffsetConvertOptions = []
    
    var cameraLogPath : String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Camera json config"
        
        // Notification
        notificationInit()

        // LOG
        logInit()
        
        // UI
        setupForm()
        
        // Preview
        setupRenderView()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let _ = INSCameraManager.shared().currentCamera else {
            return
        }
        fetchOptions { [weak self] in
            self?.runMediaSession()
        }
    }
    
    deinit {
        mediaSession.stopRunning { (err) in
            print("stop media session with err: \(String(describing: err))")
        }
        INSCameraManager.socket().removeObserver(self, forKeyPath: #keyPath(INSCameraManager.cameraState))
        
        newPlayer?.stopRunning()
        self.mediaSession.stopRunning(completion: { (_) in
            return
        })
    }
    
    
    // 预览
    
    var newPlayer: INSCameraSessionPlayer?
    
    func setupRenderView() {
        var frame = self.view.bounds;
        let height = frame.size.width * 0.667
        frame.origin.x = 0
        frame.origin.y = frame.size.height - height
        frame.size.height = height
        
        newPlayer = INSCameraSessionPlayer()
        newPlayer?.delegate = self
        newPlayer?.dataSource = self
        newPlayer?.gyroDelegate = self
        newPlayer?.render.renderModelType.displayType = .sphereStitch
        
        newPlayer?.expectedVideoResolution = INSVideoResolution1920x960x30
        newPlayer?.previewStreamType = .main
        
        print("setupRenderView renderModelType: \(newPlayer?.render.renderModelType.displayType)")
        
        if let view = newPlayer?.renderView {
            view.frame = frame;
            print("预览流: getView = \(view), frame = \(frame)")
            
            view.observationInfo
            
            self.view.addSubview(view)
        }
        
        let frameRect: CGRect = CGRect(x: 0, y: 0,
                                   width: self.view.bounds.width, height: self.view.bounds.width * 0.667)
        self.tableView.tableFooterView = UIView(frame: frameRect)
        
        let config = INSH264DecoderConfig()
        config.shouldReloadDecoder = false
        config.decodeErrorMaxCount = 30
        config.debugLiveStrem = false
        config.debugLog = false
        self.mediaSession.setDecoderConfig(config)
        if let path: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            filePath = (path as NSString).appendingPathComponent("\(Int(Date().timeIntervalSince1970)).txt")
            let ret = FileManager.default.createFile(atPath: filePath, contents: nil)
            if ret {
                print("文件创建成功")
            }
        }
    }
    
    
//    func getSonsor(completion: (() -> Void)? = nil) {
//        INSCameraManager.shared().commandManager.getActiveSensor { _, _, _, _ in
//            completion?()
//        }
//    }
    
    
    func setupForm() {
        form +++ Section("Json 解析")
        
        <<< ButtonRow("DownLoad CameraFile"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            
            weakSelf.downLoadCameraJsonFile(completion: {
                
                if let error = weakSelf.attrManager.loadJson(withAttrPath: weakSelf.cameraAttrSupportManagerPath, protoPath: weakSelf.protoMapPath) {
                    print("LoadJson Failed :\(error)")
                    return
                }
                print("LoadJson Success!")
                
                guard let lensType = weakSelf.attrManager.lensTypes().last else {
                    return
                }
                
                weakSelf.attrManager.setLensType(lensType)
                
                weakSelf.getCurrentCameraMode() {
                    weakSelf.getCameraOptions() {
                        weakSelf.getSplicingBaseStatuc() {
                            weakSelf.getLapseTime() {
                                self?.updateOptionsTobAttr()
                                weakSelf.updateLensTypeView()
                            }
                        }
                    }
                    
                    let allSupportAttrs = weakSelf.attrManager.allSupportedAttributes()
                    
                    for attr in allSupportAttrs {
                        print("\(attr)")
                    }
                }
            })
        })
        
        
        <<< ButtonRow("Take Picture") {
            $0.title = $0.tag
            }.onCellSelection(){[weak self] (_, _) in
                print("start takePicture \(Date())")
                
                // GPS setting HongKong
                let newestLocation = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: 22.2803, longitude: 114.1655),
                    altitude: 10.0,
                    horizontalAccuracy: 5.0,
                    verticalAccuracy: 5.0,
                    timestamp: Date()
                )
                let metaData = INSExtraMetadata()
                let mediaGps = INSMediaGps(clLocation: newestLocation, isValidLocation: true)
                metaData.gps = mediaGps
                let options:INSTakePictureOptions = INSTakePictureOptions()
                options.extraMetadata = metaData.serializeToProtobufData()
                // TODO: x3 hdr
                if (INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3 || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2)   && self?.attrManager.currentFunctionModeIntValue() == 8{
                    options.mode = INSPhotoMode.aeb
                    options.generateManually = true
                }
//                options.countDown = self?.attrManage.getPhotographySelfTimer() ?? 0
                var countDown:Int = 0
                let error = self?.attrManager.getAttrIntValue("", outValue: &countDown)
                if error != nil {
                    print("self?.attrManager.getAttrIntValue(outValue: &countDown) Failed!")
                }
                options.countDown = UInt32(countDown)
                
                INSCameraManager.shared().commandManager.takePicture(with: options, completion: { (error, optionInfo) in
                    print("end takePicture \(Date())")
                    
                    guard let uri = optionInfo?.uri else {
                        return
                    }
                    print("Take Picture Url:\(uri)")
                    self?.showAlert("Image Url:", uri)
                    
                    if (INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3 || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2)
                    {
                        let types = NSMutableArray()
                        let functionMode = INSCameraFunctionMode.init(functionMode: UInt32(self!.attrManager.currentFunctionModeIntValue()))
                        if let error = self?.attrManager.getAllAttrTypes(types) {
                            print("Error: getAllAttrTypes ")
                            return
                        }
                        self?.setAttrToLive(option: self!.currentOptions!, types: types as! [NSNumber])
                    }
                  
                    
                })
            }
        
        <<< ButtonRow("Capture") {
            $0.title = "Start \($0.tag!)"
        }.onCellSelection() {[weak self] _, row in
            if row.title?.starts(with: "Start") ?? false {
                row.title = "Stop \(row.tag!)"
                //开始录像，修改分辨率为副码流
                
                
                if INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3
                    || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2
                    || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneRS
                    || INSCameraManager.shared().currentCamera?.cameraType == kInsta360CameraNameOneR
                {
                    
                    let recorResolution = self?.getRecordResolutionClass(resulotionStr: self?.attrManager.getAttrStringValue(BluCameraConfigByJsonController.recordResolutionName))
                    
                    // let recorResolution = INSVideoResolution1440x720x30
                    
                    self?.newPlayer?.expectedVideoResolution = recorResolution ?? INSVideoResolution1440x720x30
                    self?.newPlayer?.expectedVideoResolutionSecondary = INSVideoResolution1440x720x30
                    self?.newPlayer?.previewStreamType = .secondary
                    
                    self?.newPlayer?.stopStream(completion: { _ in
                        self?.newPlayer?.startRunning(completion: {err in
                            if let err = err {
                                self?.showAlert(row.tag ?? "", "\(String(describing: err))")
                                return
                            }
                            
                            INSCameraManager.shared().commandManager.startCapture(with: nil, completion: { (err) in
                                if let err = err {
                                    self?.showAlert(row.tag!, "\(String(describing: err))")
                                    return
                                }
                            })
                        })
                    })
                } else {
                    INSCameraManager.shared().commandManager.startCapture(with: nil, completion: { (err) in
                        if let err = err {
                            self?.showAlert(row.tag!, "\(String(describing: err))")
                            return
                        }
                        self?.shouldRestartPreview = true
                        self?.runMediaSession()
                    })
                }
            } else {
                row.title = "Start \(row.tag!)"
                self?.shouldRestartPreview = true
                INSCameraManager.shared().commandManager.stopCapture(with: nil, completion: { (err, info) in
                    guard let info = info else {
                        return
                    }
                    self?.showAlert("Video URL:", info.uri)
                    print("video url"+(info.uri))
                    return;
                })
            }
            row.reload()
        }
        
        <<< ButtonRow("Start TimeLapse") {
            $0.title = $0.tag
            }.onCellSelection(){[weak self] (_, _) in
<<<<<<< HEAD:Samples/INSCameraSDKSample-bluetooth/INSCameraSDKSample-bluetooth/src/CameraConfigByJsonController2.swift

                if INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3 || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2 {
                    guard let strongSelf = self else{
                        return
                    }
                    let metaData = INSExtraMetadata()
                    let extraInfo = INSExtraInfo(version: Int32(INSExtraInfoVersion.one2.rawValue), metadata: metaData, gyroData: nil)
                    
                    let options = INSStartCaptureTimelapseOptions()
                    options.mode = .video
                    options.timelapseOptions = INSTimelapseOptions()
                    
                    INSCameraManager.shared().commandManager.startCaptureTimelapse(with: options) {error in
                        if let err = error {
                            strongSelf.showAlert("Error:", "\(err)")
                        }
=======
                guard let strongSelf = self else{
                    return
                }
                let metaData = INSExtraMetadata()
                let extraInfo = INSExtraInfo(version: Int32(INSExtraInfoVersion.one2.rawValue), metadata: metaData, gyroData: nil)
                
                let options = INSStartCaptureTimelapseOptions()
                options.mode = .video
                options.extraInfo = extraInfo
                
                options.timelapseOptions = INSTimelapseOptions()
                
                INSCameraManager.shared().commandManager.startCaptureTimelapse(with: options) {error in
                    if let err = error {
                        strongSelf.showAlert("Error:", "\(err)")
>>>>>>> dml/base_b2_1.8.3:Samples/INSCameraSDKSample-bluetooth/INSCameraSDKSample-bluetooth/BluCameraConfigByJsonController.swift
                    }
                }
            }
        
        <<< ButtonRow("stop TimeLapse") {
            $0.title = $0.tag
            }.onCellSelection(){[weak self] (_, _) in
<<<<<<< HEAD:Samples/INSCameraSDKSample-bluetooth/INSCameraSDKSample-bluetooth/src/CameraConfigByJsonController2.swift

                if INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3 || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2 {
                    guard let strongSelf = self else{
                        return
                    }
                    let metaData = INSExtraMetadata()
                    let extraInfo = INSExtraInfo(version: Int32(INSExtraInfoVersion.one2.rawValue), metadata: metaData, gyroData: nil)
                    
                    let options = INSStopCaptureTimelapseOptions()
                    options.mode = .video
                    
                    INSCameraManager.shared().commandManager.stopCaptureTimelapse(with: options) {error, videoInfo in
                        if let err = error {
                            strongSelf.showAlert("Error:", "\(err)")
                        }
=======
                guard let strongSelf = self else{
                    return
                }
                let metaData = INSExtraMetadata()
                let extraInfo = INSExtraInfo(version: Int32(INSExtraInfoVersion.one2.rawValue), metadata: metaData, gyroData: nil)
                
                let options = INSStopCaptureTimelapseOptions()
                options.mode = .video
                options.extraInfo = extraInfo
                
                INSCameraManager.shared().commandManager.stopCaptureTimelapse(with: options) {error, videoInfo in
                    if let err = error {
                        strongSelf.showAlert("Error:", "\(err)")
>>>>>>> dml/base_b2_1.8.3:Samples/INSCameraSDKSample-bluetooth/INSCameraSDKSample-bluetooth/BluCameraConfigByJsonController.swift
                    }
                }
      
            }
        
        <<< ActionSheetRow<String>("Set ProtectGlass Type") {
            $0.title = $0.tag
            $0.options = ["None", "Protect A", "Protect S"]
            $0.value = "None"
        }.onChange({ [weak self] (row) in
            
            if row.value == "None" {
                self?.currentProtect = []
            } else if row.value == "Protect A" {
                self?.currentProtect = .enablePlasticCement
            } else if row.value == "Protect S" {
                self?.currentProtect = .enableGlassShell
            }
            
            
            self?.newPlayer?.commitChanges() {error in
//                INSOffsetConvertOptionEnableGlassShell       = 1 << 7, // 玻璃保护镜(S)
//                INSOffsetConvertOptionEnablePlasticCement    = 1 << 8, // 塑胶保护镜(A)
            }
     
            
        })
    }
    
    /**
     * Lens Type
     **/
    let lensTypeViewTag = "Lens Type"
    func setupLensTypeView(){
        let lensTypes = self.attrManager.lensTypes()
        form.last!
        <<< ActionSheetRow<String>(lensTypeViewTag) { section in
            section.title = section.tag
            if let lastLensType = lensTypes.last{
                section.options = [lastLensType]
            }
        }.onChange({[weak self] (row) in
            guard let lenstype = row.value else {
                return
            }
//            self?.attrManage.setLensType(lensType: lenstype)
//            self?.updateModesView()
            let options = INSCameraOptions()
            options.focusSensor = .rear
            options.expectOutputType = .default
            self?.changeMultiCaptureType(options, .all)
        })
        
        self.attrManager.setLensType(lensTypes.last!)
        self.updateModesView()
    }
    
    func removeLensTypeView(){
        removeRow(tag: lensTypeViewTag)
        removeModesView()
    }
    
    func updateLensTypeView(){
        removeLensTypeView()
        setupLensTypeView()
    }
    
    /*
     * mode
     */
    let modeViewTag : String = "Modes"
    var suppportModes : [String] = []
    
    func updateModesView(){
        removeModesView()
        setupModesView()
    }
    
    func setupModesView(){
        let modes = self.attrManager.functionModes()
        
        form.last!
        <<< ActionSheetRow<String>(modeViewTag) { row in
            row.title = row.tag
            row.title = row.tag
            row.options = modes
            row.value = self.attrManager.currentFunctionMode()
        }.onChange({[weak self] (row) in
            guard let mode = row.value else {
                return
            }
            
            guard let weakself = self else {
                return
            }
            // 更新参数
            weakself.attrManager.setFunctionModeWith(mode)
            weakself.setModeToCamera(completion: {
                weakself.runMediaSession()
                
                weakself.getCameraOptions(completion: {
                    weakself.getLapseTime(completion: {
                        weakself.getSplicingBaseStatuc(completion: {
                            self?.updateOptionsTobAttr()
                            weakself.updateAttrsView()
                        })
                    })
                })
            })
        })
        self.updateAttrsView()
    }
    func removeModesView(){
        removeRow(tag: modeViewTag)
        removeAttrsView()
    }
    

    
    /*
     *  Attrs
     */

    var attrsViewString:[String]?
    let semaphore = DispatchSemaphore(value: 0)
    func setAttrsView(){
        attrsViewString = self.attrManager.allSupportedAttributes()
        
        guard let supportAttrs =  attrsViewString else {
            return
        }
        
        for attr in supportAttrs {
            let values = self.attrManager.attributeOptions(attr)

            form.last!
            <<< ActionSheetRow<String>(attr) { [weak self] row in
             
                row.title = row.tag
                row.options = values ?? []
                row.value = self?.attrManager.getAttrStringValue(attr)
                
                if values.count == 1 {
                    self?.attrManager.setAttrValue(attr, stringValue: values.first!)
                    row.value = values.first!
                    row.options = []
                }
                
            }.onChange({[weak self] (row) in
                guard let attrValue = row.value else {
                    return
                }
                
                guard let weakSelf = self else {
                    return
                }
            
                // functionMode
                weakSelf.attrManager.setAttrValue(attr, stringValue: attrValue)
                
                // lapse Time And duration
                if BluCameraConfigByJsonController.lapseTimeName == attr || BluCameraConfigByJsonController.recordDurationName == attr{
                    weakSelf.setLapseTimeToCamera(completion: {
                        weakSelf.removeAttrsView()
                        weakSelf.updateLensTypeView()
                    })
                    return
                }
                
                // splicing
                if BluCameraConfigByJsonController.splicingBaseEnable == attr {
                    weakSelf.setSplicingToCamera(){}
                    return
                }
                
                // types
                var type:Int = 0
                let error = weakSelf.attrManager.getAttrType(attr, outType: &type)
                
                if error != nil {
                    self?.showAlert("attrManager getAttrType", "Failed! ")
                    return
                }
                
                let types = [type]
                
                // INSOptions
                let optionTypes = types.map { (type) -> NSNumber in
                    return NSNumber(value: type)
                }
                let options: INSPhotographyOptions? = self?.getAttrToOptions()
                let functionMode = INSCameraFunctionMode(functionMode: UInt32(weakSelf.attrManager.currentFunctionModeIntValue()))
    

                if attr == "exposure_iso" {
                    if options?.videoISOTopLimit == 0 {
                        options?.videoISOTopLimit = 400
                    }
                    
                    if INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3 || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2 {
                        weakSelf.setAttrToLive(option: options!, types: optionTypes)
                    }
                    weakSelf.setSingleAttrToCamera(option: options!, functionMode: functionMode, types: optionTypes, completion: nil)
                } else {
                    if INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3 || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2 {
                        weakSelf.setAttrToLive(option: options!, types: optionTypes)
                    }
                    weakSelf.setSingleAttrToCamera(option: options!, functionMode: functionMode, types: optionTypes, completion: {
                        self?.getCameraOptions(completion: {[weak self] in
                            self?.getLapseTime(completion: {
                                self?.getSplicingBaseStatuc(completion: {
                                    self?.updateOptionsTobAttr()
                                        // 更新 UI
                                    self?.updateLensTypeView()
                                })
                            })
                        })
                    })
                  
                }

            })
        }
    }
    func removeAttrsView(){
        
        guard let attrsViewString = attrsViewString else {return}
        
        for attr in attrsViewString {
            removeRow(tag: attr)
            print("remove attr name:\(attr)")
        }
    }
    
    func updateAttrsView(){
        removeAttrsView()
        setAttrsView()
    }
    

    
    
    /*
     *  common mode
     */
    
    func removeRow(tag:String){
        if let rowToRemove = form.rowBy(tag: tag) {
            // 遍历表单里的所有 section
            for (sectionIndex, currentSection) in form.enumerated() {
                // 检查行是否在当前 section 里
                if let rowIndex = currentSection.firstIndex(of: rowToRemove) {
                    // 移除该行
                    currentSection.remove(at: rowIndex)
                    print("成功移除 tag 为 Capture 的行")
                    break
                }
            }
        }
    }
    

}


// MARK: - Camera message
extension BluCameraConfigByJsonController{

    
    @objc func downLoadCameraJsonFile(completion: (()->Void)?) {
        
        let outputURL = URL(fileURLWithPath: cameraAttrSupportManagerPath)
        
        let filePath = cameraAttrSupportManagerPath
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(atPath: filePath)
                print("文件已成功删除")
            } catch {
                print("删除文件失败: \(error)")
            }
        } else {
            print("文件不存在")
        }
        
        self.protoMapPath = Bundle.main.path(forResource: "common_camera_setting_proto", ofType: "json")!
        
        INSCameraManager.socket().commandManager.fetchStorageFileInfo(with: .json, completion: {error, fileResp in
            if let err = error {
                print("Error: fetchStorageFileInfo Failed!")
                
                if INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3 {
                    self.cameraAttrSupportManagerPath = Bundle.main.path(forResource: "x3", ofType: "json")!
                    completion?()
                }
                if INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2 {
                    self.cameraAttrSupportManagerPath = Bundle.main.path(forResource: "x2", ofType: "json")!
                    completion?()
                }
                return
            }
            
            guard let fileResp = fileResp else {
                return
            }
            
            print("Info: fetchStorageFileInfo Success!")
            
            INSCameraManager.socket().commandManager.fetchResource(withURI: fileResp.uri, toLocalFile: outputURL, progress: {progress in
            }, completion: { error in
                
                if let error = error {
                    print("Error: fetchResource Failed!")
                    return
                }
                
                print("Info: fetchResource Success!")
                
                completion?()
            })
            
        })
    }
}

// MARK: AttrManage
extension BluCameraConfigByJsonController {
    
    
    
    // 设置单个参数到相机
    func setSingleAttrToCamera(option:INSPhotographyOptions, functionMode:INSCameraFunctionMode, types:[NSNumber], completion: (()->Void)?) {
        INSCameraManager.shared().commandManager.setPhotographyOptions(option, for: functionMode, types: types, completion:  { [weak self] error, _ in
            if let error = error {
                self?.showAlert("Failed", "The camera a ttrhas been set failed: \(error.localizedDescription)")
                return
            }
            completion?()
        })
    }
    
    func setAttrToLive(option:INSPhotographyOptions, types:[NSNumber]){
        let functionModeLiveView = INSCameraFunctionMode.init(functionMode: 1)
        INSCameraManager.shared().commandManager.setPhotographyOptions(option, for: functionModeLiveView, types: types, completion:  { [weak self] error, _ in
            if let error = error {
                self?.showAlert("Failed", "The camera live attr has been set failed: \(error.localizedDescription)")
                return
            }
        })
    }
    
    // change lens
    func changeMultiCaptureType(_ options: INSCameraOptions, _ activeSensorDevice: INSSensorDevice) -> Void {
        let types:[NSNumber] = [NSNumber(value: INSCameraOptionsType.focusSensor.rawValue), NSNumber(value: INSCameraOptionsType.expectOutputType.rawValue)]
        INSCameraManager.shared().commandManager.setOptions(options, forTypes:types, completion: {[weak self] (err, types) in
            if let err = err {
                self?.showAlert("setOptions", err.localizedDescription);
                return
            }
            INSCameraManager.shared().commandManager.setActiveSensorWith(activeSensorDevice, completion: {[weak self] (err, mediaOffset, mediaOffsetV3)  in
                if let err = err {
                    self?.showAlert("失败", String.init(describing: err))
                } else {
                    self?.showAlert("成功", "current offset: \(mediaOffset ?? "")")
                    self?.shouldRestartPreview = true
                    self?.runMediaSession()
                }
            })
        })
    }
    
    func setSplicingToCamera(completion: (()->Void)?){

        var typeArray = [INSCameraOptionsType]()
        let cameraOptions = INSCameraOptions()
        
        if "true" == attrManager.getAttrStringValue(BluCameraConfigByJsonController.splicingBaseEnable) {
            cameraOptions.enableInternalSplicing = true
        } else {
            cameraOptions.enableInternalSplicing = false
        }
        
        typeArray.append(.internalSplicing)
        let optionTypes = typeArray.map { (type) -> NSNumber in
            return NSNumber(value: type.rawValue)
        }
        INSCameraManager.shared().commandManager.setOptions(cameraOptions, forTypes: optionTypes) { [weak self] error, _ in
            if let error = error {
                self?.showAlert("Failed", "The camera mode has been set failed: \(error.localizedDescription)")
                return
            }
            completion?()
        }
    }
    
    /// 获取当前模式
    func getCurrentCameraMode(completion: (()->Void)?)->Void{
        
        let typeArray: [INSCameraOptionsType] = [.videoSubMode, .photoSubMode]
        
        let optionTypes = typeArray.map { (type) -> NSNumber in
            return NSNumber(value: type.rawValue)
        }
        let requestOptions = INSCameraRequestOptions()
        requestOptions.timeout = 10
        
//        INSCameraManager.shared().commandManager.getOptionsWithTypes(optionTypes, requestOptions: requestOptions) { [weak self] error, cameraOptions, _ in
//            if let error = error {
//                self?.showAlert("Failed", "The camera mode has been get failed: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let cameraOptions = cameraOptions else {return}
//            
//            var captureMode: HUMCaptureMode? = nil
//
//            if cameraOptions.photoSubMode != 100 {
//                captureMode = HUMCaptureMode.modePhotoFrom(value: cameraOptions.photoSubMode)
//            }
//            else if cameraOptions.videoSubMode != 100 {
//                captureMode = HUMCaptureMode.modeVideoFrom(value: cameraOptions.videoSubMode)
//            }
//            guard let mode = captureMode else {return}
//            
//            self?.attrManager.setFunctionModeWith(NSInteger(mode.functionMode.functionMode))
//            
//            completion?()
//        }
    }
    
    
    func getSplicingBaseStatuc(completion: (()->Void)?){
        /***
         * 获取相机是否为机内拼接
         */
        // TODO: (splicing_base_enable) 特殊参数需要单独获取，INSCamera的接口问题，有待改善
        let typeArray: [INSCameraOptionsType] = [.internalSplicing]
        let optionTypes = typeArray.map { (type) -> NSNumber in
            return NSNumber(value: type.rawValue)
        }
        
        let requestOptions = INSCameraRequestOptions()
        requestOptions.timeout = 10
        INSCameraManager.shared().commandManager.getOptionsWithTypes(optionTypes, requestOptions: requestOptions) { [weak self] error, cameraOptions, _ in
            if let error = error {
                self?.showAlert("Failed", "The camera mode has been get failed: \(error.localizedDescription)")
                return
            }
            
            self?.enableInternalSplicing = cameraOptions!.enableInternalSplicing
            
            completion?()
        }
    }
    
    func getCameraOptions(completion: (()->Void)?){
        /***
         * 获取相机当前参数
         */
        
        let types = NSMutableArray()
        
        if let error = self.attrManager.getAllAttrTypes(types) {
            print("Error: getAllAttrTypes ")
            return
        }
        
        let functionMode = INSCameraFunctionMode.init(functionMode: UInt32(self.attrManager.currentFunctionModeIntValue()))
        
        INSCameraManager.shared().commandManager.getPhotographyOptions(with: functionMode, types: types as! [NSNumber], completion: {[weak self] error, camerOptions, successTags in
            if error != nil {
                print("Get Message Failed!")
                return
            }
            print("getPhotographyOptions Success!")
            self?.currentOptions = camerOptions
            completion?()
        })
    }
    
    func getLapseTime(completion: (()->Void)?){
        
        let functionMode = self.attrManager.currentFunctionModeIntValue()
        let functionModeHum = HUMCaptureMode.modeFuncionFrom(value: UInt32(functionMode))
        
        var mode:INSTimelapseMode? = nil
        
        if functionModeHum.isPhotoMode {
            mode = INSTimelapseMode.image
        }else if functionModeHum.isVideoMode {
            mode = INSTimelapseMode.video
        }
        
        guard let mode = mode else {return}
        
        INSCameraManager.shared().commandManager.getTimelapseOptions(with: mode) {[weak self] (err, options) in
            if let err = err {
                self?.showAlert("Update failed", err.localizedDescription);
                return
            }
    
            
            guard let options = options else {return}
            
            self?.currentLapseTime?.lapseTime = options.lapseTime
            self?.currentLapseTime?.duration = options.duration
            
            self?.attrManager.setAttrValue(BluCameraConfigByJsonController.lapseTimeName, intValue: Int(options.lapseTime / 1000) )
            self?.attrManager.setAttrValue(BluCameraConfigByJsonController.recordDurationName, intValue: Int(options.duration))
            let tmpvalue = self?.attrManager.getAttrStringValue(BluCameraConfigByJsonController.recordDurationName)
            
            completion?()
        }
    }
    
    func setLapseTimeToCamera(completion: (()->Void)?){
        
        let functionMode = self.attrManager.currentFunctionModeIntValue()
        let functionModeHum = HUMCaptureMode.modeFuncionFrom(value: UInt32(functionMode))
        
        var mode:INSTimelapseMode? = nil
        
        if functionModeHum.isPhotoMode {
            mode = INSTimelapseMode.image
        }else if functionModeHum.isVideoMode {
            mode = INSTimelapseMode.video
        }
        
        guard let mode = mode else {return}
        
        guard let options = self.currentLapseTime else {return}
        
        var lapseTimeTmp : Double = 0
        var error = self.attrManager.getAttrDoubleValue(BluCameraConfigByJsonController.lapseTimeName, outValue: &lapseTimeTmp)
        if error != nil {
            return
        }
        
        var durationTmp : Double = 0
        error = self.attrManager.getAttrDoubleValue(BluCameraConfigByJsonController.recordDurationName, outValue: &durationTmp)
        if error != nil {
            return
        }
        
        options.lapseTime = UInt(lapseTimeTmp * 1000)
        options.duration  = UInt(durationTmp)
        INSCameraManager.shared().commandManager.setTimelapseOptions(options, for: mode, completion: {[weak self] (err) in
            if let err = err {
                self?.showAlert("Set LapseTime failed", err.localizedDescription);
                return
            }
            completion?()
        })
        
    }
    
    func setModeToCamera(completion: (()->Void)?){
        let functionMode = INSCameraFunctionMode(functionMode: UInt32(self.attrManager.currentFunctionModeIntValue()))

        var typeArray = [INSCameraOptionsType]()
        let cameraOptions = INSCameraOptions()
        
//        let captureMode:HUMCaptureMode = HUMCaptureMode.modeFuncionFrom(value: functionMode.functionMode)
////
//        if captureMode.photoSubmode != 100{
//            cameraOptions.photoSubMode = captureMode.photoSubmode
//            typeArray.append(.photoSubMode)
//        }
//        
//        if captureMode.videoSubmode != 100{
//            cameraOptions.videoSubMode = captureMode.videoSubmode
//            typeArray.append(.videoSubMode)
//        }
//        let optionTypes = typeArray.map { (type) -> NSNumber in
//            return NSNumber(value: type.rawValue)
//        }
//        INSCameraManager.shared().commandManager.setOptions(cameraOptions, forTypes: optionTypes) { [weak self] error, _ in
//            if let error = error {
//                self?.showAlert("Failed", "The camera mode has been set failed: \(error.localizedDescription)")
//                print("Failed", "The camera mode has been set failed: \(error.localizedDescription)")
//                return
//            }
//            
//            completion?()
//        }
    }

    /***
     * update value
     */
    
    func updateOptionsTobAttr() {
        
        guard let lapseTime = self.currentLapseTime else {
            return
        }
        
        if enableInternalSplicing {
            self.attrManager.setAttrValue(BluCameraConfigByJsonController.splicingBaseEnable, stringValue: "true")
        } else {
            self.attrManager.setAttrValue(BluCameraConfigByJsonController.splicingBaseEnable, stringValue: "false")
        }
        
        guard let options = self.currentOptions else { return }
        // 更新所有属性，传递具体参数
        self.attrManager.setAttrValue(BluCameraConfigByJsonController.aebCaptureNumName, intValue: Int(options.aebCaptureNumber))
        
        var aebCapture: NSInteger = 0
        if attrManager.getAttrIntValue(BluCameraConfigByJsonController.aebCaptureNumName, outValue: &aebCapture) == nil {
        }
        
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.rawCaptureTypeName, intValue: Int(options.rawCaptureType))

//        TODO: 四舍五入 videoExposure
        self.attrManager.setAttrValue(BluCameraConfigByJsonController.exposureBiasName, doubleValue: Double(options.exposureBias))
        
//        TODO: UI适配
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.photoResolutionName, intValue: Int(options.photoSizeForJson))
        
        self.attrManager.setAttrValue(BluCameraConfigByJsonController.whiteBalanceName, intValue: Int(options.whiteBalanceValue))
        
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.fovTypeName, intValue: Int(options.fovType))
        var fov: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.fovTypeName, outValue: &fov) == nil {
        }

        self.attrManager.setAttrValue(BluCameraConfigByJsonController.photographySelfTimerName, intValue: Int(options.photographySelfTimer))
        
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.videoSelfieTypeName, intValue: Int(options.selfieMode))
        
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.livingPlatformName , intValue: Int(options.livePlantform.rawValue)
        )

        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.recordResolutionName, intValue: Int(options.videoResolutionForJson))
        
        self.attrManager.setAttrValue(BluCameraConfigByJsonController.videoISOTopLimitName, intValue: Int(options.videoISOTopLimit))
        
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.exportTypeName, intValue: Int(options.starlapseExportType.rawValue))
        
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.photoSizeIDName, intValue: Int(options.photoSizeId))
        
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.colorModeName, intValue: Int(options.videoGamma))
        
        self.attrManager.setAttrValue(BluCameraConfigByJsonController.accelerateFrequencyName, intValue: Int(options.accelerateFequency))
        
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.exposureIndividualName, intValue: Int(options.panoExposureMode))
        
        self.attrManager.setAttrValue(BluCameraConfigByJsonController.livingBitrateName, intValue: Int(options.videoBitrate))
        
        self.attrManager.setAttrValue(BluCameraConfigByJsonController.exposureISOName, intValue: Int(options.videoExposure!.iso))
        
        self.attrManager.setAttrValue(BluCameraConfigByJsonController.exposureShutterSpeedName, withNumerator: Double(options.videoExposure!.shutterSpeed.value), denominator: Double(options.videoExposure!.shutterSpeed.timescale))
        
        self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.exposureProgramName, intValue: Int(options.videoExposure!.program))
        
        self.attrManager.setAttrValue(BluCameraConfigByJsonController.burstCaptureParamsName, intValue: Int(options.burstCaptureNum))

        let functionMode = self.attrManager.currentFunctionModeIntValue()
        let functionModeHum = HUMCaptureMode.modeFuncionFrom(value: UInt32(functionMode))
        if functionModeHum.isPhotoMode {
            self.attrManager.setAttrEnumValue(BluCameraConfigByJsonController.hdrPhotoModeName, intValue: Int(options.photoHdrType))
        }else if functionModeHum.isVideoMode {
            if options.hdrSwitchStatus {
                self.attrManager.setAttrValue(BluCameraConfigByJsonController.hdrSwitchName, stringValue: "true")
            } else {
                self.attrManager.setAttrValue(BluCameraConfigByJsonController.hdrSwitchName, stringValue: "false")
            }
        }
        
        if options.iLogSwitch {
            self.attrManager.setAttrValue(BluCameraConfigByJsonController.iLogSwitchName, stringValue: "true")
        } else {
            self.attrManager.setAttrValue(BluCameraConfigByJsonController.iLogSwitchName, stringValue: "false")
        }

        if options.purevideoEnhancSwitch {
            self.attrManager.setAttrValue(BluCameraConfigByJsonController.pureVideoEnhanceSwitchName, stringValue: "true")
        } else {
            self.attrManager.setAttrValue(BluCameraConfigByJsonController.pureVideoEnhanceSwitchName, stringValue: "false")
        }
    }
    
    private func getAttrToOptions() -> INSPhotographyOptions?{

        guard let lapse = currentLapseTime else { return nil}
        
        let options : INSPhotographyOptions = INSPhotographyOptions()
        options.isUseJsonOptions = true

        // splicing enable
        var splicing: NSString?
        if attrManager.getAttrEnumStringValue("splicing_base_enable", outValue: &splicing) == nil {
            enableInternalSplicing = (splicing as String?) == "true"
        }

        // aebCaptureNumber
        var aebCapture: NSInteger = 0
        if attrManager.getAttrIntValue(BluCameraConfigByJsonController.aebCaptureNumName, outValue: &aebCapture) == nil {
            options.aebCaptureNumber = UInt32(aebCapture)
        }

        // rawCaptureType
        var rawType: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.rawCaptureTypeName, outValue: &rawType) == nil {
            options.rawCaptureType = UInt8(rawType)
        }

        // exposureBias
        var exposureBias: Double = 0
        if attrManager.getAttrDoubleValue(BluCameraConfigByJsonController.exposureBiasName, outValue: &exposureBias) == nil {
            options.exposureBias = Float(exposureBias)
        }

        // photoSizeForJson
        var photoSize: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.photoResolutionName, outValue: &photoSize) == nil {
            options.photoSizeForJson = UInt32(photoSize)
        }

        // whiteBalance
        var wb: NSInteger = 0
        if attrManager.getAttrIntValue(BluCameraConfigByJsonController.whiteBalanceName, outValue: &wb) == nil {
            options.whiteBalanceValue = UInt32(wb)
        }

        // fovType
        var fov: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.fovTypeName, outValue: &fov) == nil {
            options.fovType = UInt8(fov)
        }

        // photographySelfTimer
        var timer: NSInteger = 0
        if attrManager.getAttrIntValue(BluCameraConfigByJsonController.photographySelfTimerName, outValue: &timer) == nil {
            options.photographySelfTimer = UInt32(timer)
        }

        // selfieMode
        var selfie: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.videoSelfieTypeName, outValue: &selfie) == nil {
            options.selfieMode = UInt8(selfie)
        }

        // livePlatform
        var platform: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.livingPlatformName, outValue: &platform) == nil {
            options.livePlantform = .init(rawValue: UInt(platform)) ?? .default
        }

        // videoResolutionForJson
        var recordRes: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.recordResolutionName, outValue: &recordRes) == nil {
            options.videoResolutionForJson = UInt32(recordRes)
        }

        // videoISOTopLimit
        var isoTop: NSInteger = 0
        if attrManager.getAttrIntValue(BluCameraConfigByJsonController.videoISOTopLimitName, outValue: &isoTop) == nil {
            options.videoISOTopLimit = UInt32(isoTop)
        }

        // starlapseExportType
        var exportType: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.exportTypeName, outValue: &exportType) == nil {
            options.starlapseExportType = .init(rawValue: UInt(exportType)) ?? .starlapseVideo
        }

        // photoSizeId
        var photoSizeId: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.photoSizeIDName, outValue: &photoSizeId) == nil {
            options.photoSizeId = UInt32(photoSizeId)
        }

        // videoGamma
        var gamma: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.colorModeName, outValue: &gamma) == nil {
            options.videoGamma = UInt8(gamma)
        }

        // accelerateFequency
        var freq: NSInteger = 0
        if attrManager.getAttrIntValue(BluCameraConfigByJsonController.accelerateFrequencyName, outValue: &freq) == nil {
            options.accelerateFequency = UInt32(freq)
        }

//        // recordDuration
//        var recDuration: NSInteger = 0
//        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.recordDurationName, outValue: &recDuration) == nil {
//            options.recordDuration = UInt32(recDuration)
//        }

        // panoExposureMode
        var pano: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.exposureIndividualName, outValue: &pano) == nil {
            options.panoExposureMode = UInt8(pano)
        }

        // videoBitrate
        var bitrate: NSInteger = 0
        if attrManager.getAttrIntValue(BluCameraConfigByJsonController.livingBitrateName, outValue: &bitrate) == nil {
            options.videoBitrate = UInt32(bitrate)
        }
        
        // stillExposure
        let exposure = INSCameraExposureOptions()
        var iso: NSInteger = 0
        if attrManager.getAttrIntValue(BluCameraConfigByJsonController.exposureISOName, outValue: &iso) == nil {
            exposure.iso = UInt(iso)
        }

        var numerator: Double = 0, denominator: Double = 1
        if attrManager.getAttrFractionValue(BluCameraConfigByJsonController.exposureShutterSpeedName, numerator: &numerator, denominator: &denominator) == nil {
            exposure.shutterSpeed = CMTime(value: Int64(numerator), timescale: Int32(denominator))
        }

        var program: NSInteger = 0
        if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.exposureProgramName, outValue: &program) == nil {
            exposure.program = UInt8(program)
        }
        options.stillExposure = exposure
        options.videoExposure = exposure
        

        // burstCaptureNum
        var burstNum: NSInteger = 0
        if attrManager.getAttrIntValue(BluCameraConfigByJsonController.burstCaptureParamsName, outValue: &burstNum) == nil {
            options.burstCaptureNum = UInt32(burstNum)
        }

        // hdr/photo modes
        let functionMode = attrManager.currentFunctionModeIntValue()
        let functionModeHum = HUMCaptureMode.modeFuncionFrom(value: UInt32(functionMode))
        if functionModeHum.isPhotoMode {
            var hdrPhoto: NSInteger = 0
            if attrManager.getAttrEnumIntValue(BluCameraConfigByJsonController.hdrPhotoModeName, outValue: &hdrPhoto) == nil {
                options.photoHdrType = UInt32(hdrPhoto)
            }
        } else if functionModeHum.isVideoMode {
            var hdrSwitch: NSString?
            if attrManager.getAttrEnumStringValue(BluCameraConfigByJsonController.hdrSwitchName, outValue: &hdrSwitch) == nil {
                options.hdrSwitchStatus = (hdrSwitch as String?) == "true"
            }
        }

        // iLogSwitch
        var ilog: NSString?
        if attrManager.getAttrEnumStringValue(BluCameraConfigByJsonController.hdrSwitchName, outValue: &ilog) == nil {
            options.iLogSwitch = (ilog as String?) == "true"
        }

        // purevideoEnhancSwitch
        var pve: NSString?
        if attrManager.getAttrEnumStringValue(BluCameraConfigByJsonController.pureVideoEnhanceSwitchName, outValue: &pve) == nil {
            options.purevideoEnhancSwitch = (pve as String?) == "true"
        }
        
        return options
    }
    
    func getRecordResolutionClass(resulotionStr:String?) -> INSVideoResolution {
        
        var resolutionResult = INSVideoResolution()
        if let resulotionStr = resulotionStr {
        
            let parts = resulotionStr.components(separatedBy: "_") // 拆分成数组 ["3840", "960", "120"]
            if parts.count == 3,
               let width = Int(parts[0]),
               let height = Int(parts[1]),
               let fps = Int(parts[2]) {
                print("Width: \(width), Height: \(height), FPS: \(fps)")
                resolutionResult.width = width / 2
                resolutionResult.height = height
                resolutionResult.fps = fps
            } else {
                print("格式错误")
            }
            
        }
        return resolutionResult
    }
    
    func CMTimeToString(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        if seconds == 0 {
            return "0"
        }
        
        let denominator = 1.0 / seconds
        
        if denominator == 1.0 {
            return "1"
        }
        
        // 判断分母是否为整数（考虑浮点精度）
        let roundedDenominator = denominator.rounded()
        if abs(denominator - roundedDenominator) < 1e-6 {
            return String(format: "1/%.0f", roundedDenominator)
        } else {
            // 格式化小数，最多两位，自动去除末尾零
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.decimalSeparator = "."
            
            guard let formatted = formatter.string(from: NSNumber(value: denominator)) else {
                return "1/\(denominator)" // 备用方案
            }
            return "1/\(formatted)"
        }
    }
}

// MARK: Notification
extension BluCameraConfigByJsonController {
    func notificationInit() {
        // 注册通知
        INSCameraManager.socket().addObserver(self,
                                           forKeyPath: #keyPath(INSCameraManager.cameraState),
                                           options: [.old, .new],
                                           context: nil);
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.currentCaptureStatusChange(_:)),
                                               name: NSNotification.Name.INSCameraCurrentCaptureStatus,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.batteryLowNotification(_:)),
                                               name: NSNotification.Name.INSCameraBatteryLow,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.storageFullNotification(_:)),
                                               name: NSNotification.Name.INSCameraStorageStatus,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.captureStoppedNotification(_:)),
                                               name: NSNotification.Name.INSCameraCaptureStopped,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.temperatureValueNotification(_:)),
                                               name: NSNotification.Name.INSCameraTemperatureStatus,
                                               object: nil)
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(INSCameraManager.cameraState) {
            guard let stateValue = change?[NSKeyValueChangeKey.newKey] as? UInt else {
                return;
            }
            let state = INSCameraState(rawValue: stateValue)
            if state == .found || state == .synchronized {
            } else if state == .connected {
                self.runMediaSession()
            } else {
                self.mediaSession.stopRunning(completion: { (_) in
                    return
                })
            }
        }
    }
    
    @objc func currentCaptureStatusChange(_ notification: Notification) {
        self.fetchOptions { [weak self] in
            self?.mediaSession.stopRunning { (error) in
                self?.runMediaSession()
            }
        }
        if let status = notification.userInfo?["status"] as? INSCameraCaptureStatus {
            state = status.state
        }
    }
    
    @objc func batteryLowNotification(_ notification: Notification) {
        
        if let status = notification.userInfo?["storage_status"] as? INSCameraBatteryStatus {
            self.showAlert("Notification", "Battery Low :\(status.batteryScale)")
        }
        
        print("Notification: Battery Low")
    }
    
    @objc func storageFullNotification(_ notification: Notification) {
        
        if let status = notification.userInfo?["card_state"] as? INSCameraCardState {
            self.showAlert("Notification", "Battery Low :\(status)")
        }
        
        print("Notification: Storage Full")
    }
    
    @objc func captureStoppedNotification(_ notification: Notification) {
        
        if let info = notification.userInfo?["video"] as? INSCameraVideoInfo, let errorCode = notification.userInfo?["error_code"] as? Int{
            self.showAlert("Notification", "Capture Stop, error code:\(errorCode)")
        }
        
        print("Notification: Capture Stop")
    }
    
    @objc func temperatureValueNotification(_ notification: Notification) {
        
        if let status = notification.userInfo?["temperature_status"] as? INSCameraTemperatureStatus {
            self.showAlert("Notification", "Temperature warning, \(status.temperature) ")
        }
        
        print("Notification: Temperature wa rning")
    }
}


// MARK: - Preview
extension BluCameraConfigByJsonController: INSCameraSessionPlayerDelegate, INSCameraSessionPlayerDataSource, INSCameraPreviewPlayerDelegate {
    
    func fetchOptions(completion: (() -> Void)? = nil) {
        var optionTypes = [
            NSNumber(value: INSCameraOptionsType.storageState.rawValue),
            NSNumber(value: INSCameraOptionsType.evoStatus.rawValue),
            NSNumber(value: INSCameraOptionsType.videoEncode.rawValue),
            NSNumber(value: INSCameraOptionsType.videoSubMode.rawValue),
            NSNumber(value: INSCameraOptionsType.windowCropInfo.rawValue),
            NSNumber(value: INSCameraOptionsType.photoSubMode.rawValue)
        ]
        if INSCameraManager.shared().currentCamera?.cameraType == kInsta360CameraNameOneR
            || INSCameraManager.shared().currentCamera?.cameraType == kInsta360CameraNameOneH
            || INSCameraManager.shared().currentCamera?.cameraType == kInsta360CameraNameOneRS {
            optionTypes.append(NSNumber(value: INSCameraOptionsType.gyroTimestamp.rawValue))
        }
        
        INSCameraManager.shared().commandManager.getOptionsWithTypes(optionTypes) { [weak self] (err, options, successTypes) in
            guard let strongSelf = self, let options = options else {
                self?.showAlert("get options", String(describing: err))
                completion?()
                return
            }
            print("模式， types:\(successTypes), videoSubMode:\(options.videoSubMode), photoSubMode:\(options.photoSubMode), error:\(err)")
            
            strongSelf.windowCropInfo = options.windowCropInfo
            strongSelf.currentFocusSensor = options.focusSensor
            strongSelf.storageState = options.storageStatus
            if options.gyroTimestamp != 0 {
            }
            
            completion?()
        }
    }
    
    func updateCameraIFrame(completion: ((Error?) -> Void)?) {
        INSCameraManager.shared().commandManager.requestIFrame { error in
            completion?(error)
        }
    }
    
    func runMediaSession() {
        print("runMediaSession shouldRestartPreview \(shouldRestartPreview), isRunning:\(newPlayer?.isRunning())")
        guard INSCameraManager.shared().cameraState == .connected, (shouldRestartPreview || !(newPlayer?.isRunning() ?? false)) else {
            return
        }
        if (newPlayer?.running ?? false) {
            self.view.isUserInteractionEnabled = false
            newPlayer?.stopRunning { [weak self] _ in
                self?.newPlayer?.startRunning { err in
                    self?.view.isUserInteractionEnabled = true
                    self?.updateCameraIFrame(completion: nil)
                    if let err = err {
                        self?.showAlert("start media failed!", err.localizedDescription);
                        return;
                    }
                }
            }
            
        } else {
            self.view.isUserInteractionEnabled = false
            //            newPlayer?.flag = .live
            self.newPlayer?.startRunning { [weak self] err in
                print("start running media session with error: \(String(describing: err))")
                self?.view.isUserInteractionEnabled = true
                self?.updateCameraIFrame(completion: nil)
                if let err = err {
                    self?.showAlert("start media failed!", err.localizedDescription);
                    return;
                }
            }
        }
    }
    
    
    func updateOffset(to player: INSCameraSessionPlayer) -> String? {
        print("updateOffset")
        return getMediaOffset()
    }
    
    func updateRenderModelType(to player: INSCameraSessionPlayer, renderModelType: INSRenderModelType) -> INSRenderModelType {
        
        renderModelType.displayType = .sphereStitch
        
        renderModelType.imageLayout = .horizontalMerged
        renderModelType.isHalfFisheye = false
        renderModelType.isSelfieVideo = false
        renderModelType.touchMode = false
        renderModelType.opticalFlowType = .disflow
        renderModelType.isHalfFisheyeBulletTime = false
//        renderModelType.contentMode = .fitScreen
        
     
        
        renderModelType.preferDynamicVertex = false
        renderModelType.aiFlowBottomPercision = .unknown
        renderModelType.dynamicAlphaFlag = false
        renderModelType.usingFisheyeMask = false
        
        if let windowCropInfo {
            renderModelType.cropInfo = INSCropInfo()
            renderModelType.cropInfo.srcWidth = Int32(windowCropInfo.srcWidth)
            renderModelType.cropInfo.srcHeight = Int32(windowCropInfo.srcHeight)
            renderModelType.cropInfo.dstWidth = Int32(windowCropInfo.dstWidth)
            renderModelType.cropInfo.dstHeight = Int32(windowCropInfo.dstHeight)
        }
        
        renderModelType.aiFlowVersion = 1
        renderModelType.expandFlowWorkRegion = true
        renderModelType.aiFlowFrameInterval = 2
        
        renderModelType.colorFusion = true
        renderModelType.dynamicStitchType = .dynamicVideo
        renderModelType.cameraType = INSCameraManager.shared().currentCamera?.cameraType ?? ""
        
        return renderModelType
    }
    
    func updateStabilizerParam(to player: INSCameraSessionPlayer) -> INSRealtimeStabilizerParam {
        let param = INSRealtimeStabilizerParam()
        if let offset = getMediaOffset() {
            param.offset = offset
        }
        param.preferredStabMode = .still//getPreferredStabMode()
        param.isSelfie = false
        param.isLiteGyro = false
        param.maxFilterAngleDegree = 25
        return param
    }
    //
    func updateStabilizerDynamicParam(to player: INSCameraSessionPlayer, dynamicParam: INSStabilizerDynamicParam) -> INSStabilizerDynamicParam {
        let param = dynamicParam
        param.onlineFilterType = .pathPlanSlidingWin
        return param
    }
    
    
    private func getMediaOffset() -> String? {

        let settings: INSCameraDeviceSettings? = INSCameraManager.shared().currentCamera?.settings
        var mediaOffset = settings?.mediaOffset
        
        if (INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOne
            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneR
            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneX2
            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX3
            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameX4
            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneH
            || INSCameraManager.shared().currentCamera?.name == kInsta360CameraNameOneRS)
            && INSLensOffset.isValidOffset(mediaOffset!) {
            if let windowCropInfo = self.windowCropInfo, let offset = mediaOffset {
                mediaOffset = INSOffsetCalculator.cropOffset(
                    offset, srcWidth: Int32(windowCropInfo.srcWidth),
                    srcHeight: Int32(windowCropInfo.srcHeight),
                    dstWidth: Int32(windowCropInfo.dstWidth),
                    dstHeight: Int32(windowCropInfo.dstHeight),
                    xOffset: windowCropInfo.cropOffsetX,
                    yOffset: windowCropInfo.cropOffsetY)
            }
            mediaOffset = INSOffsetCalculator.convertOffset(mediaOffset!, to:.oneX3040_2_2880)
        }
        
        if self.currentProtect != [], let cameraName = INSCameraManager.shared().currentCamera?.name, let offset = mediaOffset {
            mediaOffset = INSProtectorClassify.resolveOffsetShell(cameraName, offset: offset, options: self.currentProtect)
        }
        print("getMediaOffset: \(mediaOffset)")
        return mediaOffset
    }
    
    // 预览流图像
//    playerPrepared
    func playerPrepared(_ player: INSCameraSessionPlayer, sampleGroup: INSSampleGroup) {
        
        let pixelBuffer = sampleGroup.getPlayerImage().pixelBuffer
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("playerPrepared 宽度: \(width)，高度: \(height)")
        
        print("playerPrepared: \(sampleGroup.getPlayerImage().pts_ms) ms")
        
    }
    
    func playerPreviewer(_ player: INSCameraSessionPlayer, sampleGroup: INSSampleGroup, projectionInfo: INSProjectionInfo) {
        
        let pixelBuffer = sampleGroup.getPlayerImage().pixelBuffer
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("playerPreviewer 宽度: \(width)，高度: \(height)")
    }
    
}

//INSCameraSessionLiveDelegate
extension BluCameraConfigByJsonController: INSCameraSessionLiveDelegate{
    
    func playerLiving(_ player: INSCameraSessionPlayer, sampleGroup: INSSampleGroup) {
//        let pixelBuffer = sampleGroup.getPlayerImage().pixelBuffer
//        
//        let playerImage = sampleGroup.getPlayerImage()
//
//        print("playerPreviewer: \(sampleGroup.getPlayerImage().pts_ms) ms")
    }
    
    
}
// MARK: - Log
extension BluCameraConfigByJsonController: INSCameraSDKLoggerProtocol{
    
    func logInit() {
        INSCameraSDKLogger.shared().logDelegate = self
        INSCameraSDKLogger.shared().logLevel = .debug
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        cameraLogPath = (documentsPath as NSString).appendingPathComponent("cameraLog.txt")
        createFileIfNeeded()
    }
        
    
    func logInfo(_ message: String, filePath: String, funcName: String, lineNum: Int) {
//        print("Camera logInfo - message: \(message), filtePath:\(filePath), funcName:\(funcName), lineNum:\(lineNum)")
        logWrite(message, filePath: filePath, funcName: funcName, lineNum: lineNum)
    }
    func logCrash(_ message: String, filePath: String, funcName: String, lineNum: Int) {
//        print("Camera logCrash - message: \(message), filtePath:\(filePath), funcName:\(funcName), lineNum:\(lineNum)")
        logWrite(message, filePath: filePath, funcName: funcName, lineNum: lineNum)
        
    }
    func logDebug(_ message: String, filePath: String, funcName: String, lineNum: Int) {
//        print("Camera logDebug - message: \(message), filtePath:\(filePath), funcName:\(funcName), lineNum:\(lineNum)")
        logWrite(message, filePath: filePath, funcName: funcName, lineNum: lineNum)
    }
    func logError(_ message: String, filePath: String, funcName: String, lineNum: Int) {
        print("Camera logError - message: \(message), filtePath:\(filePath), funcName:\(funcName), lineNum:\(lineNum)")
        logWrite(message, filePath: filePath, funcName: funcName, lineNum: lineNum)
    }
    func logWarning(_ message: String, filePath: String, funcName: String, lineNum: Int) {
        print("Camera logWarning - message: \(message), filtePath:\(filePath), funcName:\(funcName), lineNum:\(lineNum)")
        logWrite(message, filePath: filePath, funcName: funcName, lineNum: lineNum)
    }
    
    
    
    private func createFileIfNeeded() {
        if !FileManager.default.fileExists(atPath: cameraLogPath) {
            FileManager.default.createFile(atPath: cameraLogPath, contents: nil)
        }
    }
    
    func logWrite(_ message: String,
                  filePath: String,      // 编译器宏：当前文件路径
                  funcName: String,  // 编译器宏：当前函数名
                  lineNum: Int) {
        let logMessage = """
              File: \(filePath)
              Function: \(funcName)
              Line: \(lineNum)
              Message: \(message)
              ---\n
              """
        do {
            if let handle = FileHandle(forWritingAtPath: cameraLogPath) {
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                handle.write(logMessage.data(using: .utf8)!)
            } else {
                try logMessage.write(toFile: cameraLogPath, atomically: true, encoding: .utf8)
            }
        } catch {
            print("日志写入失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Gyro
extension BluCameraConfigByJsonController: INSCameraSessionGyroDelegate {
    
    func onRawGyroData(_ rawData: Data, timestampMs: Int64) {
        // 处理原始陀螺仪数据
//        print("onRawGyroData raw gyro data of length: \(rawData.count), timestamp: \(timestampMs)")
    }
    
    func onParsedGyroData(_ gyroItems: NSMutableArray, timestampMs: Int64) {
        // 处理解析后的陀螺仪数据
//        print("onParsedGyroData Total items: \(gyroItems.count), timestamp: \(timestampMs)")
//        for item in gyroItems {
//            if let gyroItem = item as? INSGyroRawItem {
//                print("Parsed item with timestamp: \(gyroItem.timestamp)")
//                printGyroItem(gyroItem)
//            }
//        }
    }
    
}
