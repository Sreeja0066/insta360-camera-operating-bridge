//
//  Untitled.swift
//  INSCameraSDKSample-bluetooth
//
//  Created by Tommy Shelby on 2025/4/15.
//  Copyright © 2025 insta360. All rights reserved.
//


import UIKit
import Eureka
import INSCameraSDK
import INSCoreMedia
import Foundation

class DemoTestViewController: FormViewController{
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Test"
  
        setupForm()
    }
    
    var dePurpleFringe = false
    
    func setupForm() {
        form +++ Section("Param")
        
        <<< ButtonRow("Stitch Image"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.startExportImage()
        })
        
        <<< ButtonRow("Stitch Image Simplify"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.startExportImageSimplify()
        })
        
        <<< ButtonRow("copy file to app"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.copyFileToApp()
        })
        
        <<< ActionSheetRow<String>("De Purple Fringe") { row in
            row.title = row.tag
            row.options = ["open", "close"]
            row.value = "close"
        }.onChange({[weak self] (row) in
           
            guard let weakSelf = self else {return}
            
            if "open" == row.value {
                weakSelf.dePurpleFringe = true
            } else {
                weakSelf.dePurpleFringe = false
            }
        })
        
        <<< ButtonRow("StartTimeLapse"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.startTimelapse()
        })
        
        <<< ButtonRow("StartTimeLapse2"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.startTimelapse2()
        })
        
        <<< ButtonRow("stop"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.stopTimelapse()
        })
        
        <<< ButtonRow("Export Video Simplify"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.startExportVideoSimplify()
        })
        

        
        <<< ButtonRow("Test take"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.takeHdrPicture()
        })
        <<< ButtonRow("get LensType"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.getSenor()
        })
        
        <<< ButtonRow("set function mode"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.setFunctionMode()
        })
        
        <<< ButtonRow("set single mode"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.setSingleOptions()
        })
        
        <<< ButtonRow("take hdr picture(onlty x,x2,x3)"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.takeHDR()
        })
        
        <<< ButtonRow("get Lens Type"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.getLensType()
        })
        
        <<< ButtonRow("Test Simplify"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.startAutoCapture()
        })
        
        <<< ButtonRow("Test loop take"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.startAutoCapture()
        })
        
        <<< ButtonRow("Test Deavtivate"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.testDeActivate()
        })
        
        <<< ButtonRow("Set Country Code") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            
            self?.setCountryCode()

        })
        
        <<< ButtonRow("Get Country Code") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            
            self?.getWifiCountryCode()

        })
        
        <<< ButtonRow("Reset Camera Wi-Fi") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            
            self?.resetCameraWiFi()

        })
        
        
        <<< ButtonRow("Get Camera Template") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            
            let typeArray: [INSCameraOptionsType] = [.temperature]
            let optionTypes = typeArray.map { (type) -> NSNumber in
                return NSNumber(value: type.rawValue)
            }
            
            INSCameraManager.shared().commandManager.getOptionsWithTypes(optionTypes, requestOptions: nil) { [weak self] error, cameraOptions, _ in
                if let error = error {
                    self?.showAlert("Failed", "The camera mode has been get failed: \(error.localizedDescription)")
                    return
                }
                
                print("Camera Template:\(String(describing: cameraOptions?.temperature))")
            }

        })
        
        <<< ButtonRow("Test video Capture") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            
            self?.startLoopRecording(segments: 100)

        })
        
        <<< ButtonRow("Take Picture") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            
            self?.test3()

        })
        
        <<< ButtonRow("setLapse") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            self?.setTimelapse()
        })
        
        
        <<< ButtonRow("getOPtions") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            self?.getOPtions()
        })
        
        <<< ButtonRow("Test") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            self?.test2()
        })
        
        <<< ButtonRow("Test2") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            self?.test22()
        })
        
        
    }
    
    func printWifiChannelList(_ list: INSCameraWifiChannelList) {
        print("countryCode:", list.countryCode)
        print("channelList_5g:", list.channelList_5g)
        print("channelList_2_4g:", list.channelList_2_4g)
    }
    
    func getWifiCountryCode() {
        
        let optionTypes = [
            NSNumber(value: INSCameraOptionsType.wifiChannelList.rawValue)
        ];
        INSCameraManager.shared().commandManager.getOptionsWithTypes(optionTypes) { (err, options, successTypes) in
            guard let options = options else {
                print("ERROR:\(err)")
                return
            }
            self.printWifiChannelList(options.wifiChannelList)
        }
    }

    func setCountryCode() {
        let optionTypes = [
            NSNumber(value: INSCameraOptionsType.wifiChannelList.rawValue),
        ];
        let wifiChannelList = INSCameraWifiChannelList.init(countryCode: "JP")
        let options = INSCameraOptions()
        options.wifiChannelList = wifiChannelList
        
        INSCameraManager.shared().commandManager.setOptions(options, forTypes: optionTypes) { error, types in
         
        }
    }
    
    func resetCameraWiFi() {
        
        INSCameraManager.shared().commandManager.resetCameraWifi(with: nil, channel: 0){ error in
        }
        
    }
    
    
    func testThumber (){
//        VID_20250522_141405_00_003.insv
        let path1 = NSHomeDirectory() + "/Documents/VID_20250522_104820_00_001.insv"
        let path2 = NSHomeDirectory() + "/Documents/VID_20250522_104820_00_001.insv"
        
        // x4
//        VID_20250522_141405_00_003.insv
        let x4_path1 = NSHomeDirectory() + "/Documents/VID_20250522_141405_00_003.insv"
        
        let url1 = URL(fileURLWithPath: x4_path1)
        let url2 = URL(fileURLWithPath: path2)
        
        
        let urls:[URL] = [url1]
        
        let parser = INSVideoInfoParser(url: url1)

        var stitchedImage: UIImage?
            
        if parser.open() {
            
            let render = INSThumbnailRender()

            let data = parser.extraInfo?.thumbnail
            let extData = parser.extraInfo?.ext_thumbnail

            if let data = data {
                let buffer = render.copyPixelBuffer(withDecodeH264Data: data)
                let flatPanoRender = INSFlatPanoOffscreenRender(renderWidth: 512, height: 512)
                flatPanoRender.offset = parser.extraInfo?.metadata?.offset

                flatPanoRender.gyroStabilityOrientation = GLKQuaternionIdentity
                if let gyroData = parser.extraInfo?.gyroData {
                    let gyroPlayer = INSGyroPBPlayer(pbGyroData: gyroData)
                    let orientation = gyroPlayer?.getImageOrientation(with: .flatPanoRender)
                    flatPanoRender.gyroStabilityOrientation = orientation!
                }

                if let extData = extData {
                    let extBuffer = render.copyPixelBuffer(withDecodeH264Data: extData)
                    flatPanoRender.setRenderPixelBuffer(buffer.takeUnretainedValue(), right: extBuffer.takeUnretainedValue(), timestamp: Double(parser.extraInfo?.metadata?.thumbnailGyroTimestamp ?? 0))
                } else {
                    flatPanoRender.setRenderPixelBuffer(buffer.takeUnretainedValue(), timestamp: Double(parser.extraInfo?.metadata?.thumbnailGyroTimestamp ?? 0))
                }

                stitchedImage = flatPanoRender.renderToImage()
            }
            
        }
        
    }
    
    func testAssetParser (){
        let cache = NSHomeDirectory() + "/Documents/com.insta360.asset.video"
        let videoPath = NSHomeDirectory() + "/Documents/VID_20250627_111441_00_060.insv"
        
        let videoAsset = INSVideoAsset(path: videoPath, cacheDir: cache, option: .All)
        
        if let error = videoAsset.open() {
            print("ERROR:\(error)")
            return
        }
        
        let offsetV3 = videoAsset.extraMetadata?.offsetV3
        
        print("Finish")
        
    }
    
    func testThumberX4A3 (){
//        VID_20250522_141405_00_003.insv
//        let path1 = NSHomeDirectory() + "/Documents/VID_20250522_104820_00_001.insv"
//        let path2 = NSHomeDirectory() + "/Documents/VID_20250522_104820_00_001.insv"
        
        // x4
//        VID_20250522_141405_00_003.insv
        let x4_path1 = NSHomeDirectory() + "/Documents/VID_20250522_141405_00_003.insv"
        
        let url1 = URL(fileURLWithPath: x4_path1)
//        let url2 = URL(fileURLWithPath: path2)
        
        let urls:[URL] = [url1]
        let parser = INSVideoInfoParser(url: url1)

        var stitchedImage: UIImage?

        if parser.open() {
            
            let thumParser = INSThumbNailParser(thumbData: parser.extraInfo?.thumbnail)
            
            guard let buffer = thumParser.parseThumNail()?.takeRetainedValue() else {
                print("error")
                return
            }
            stitchedImage = UIImage(pixelBuffer: buffer)
            print("finish")
        }
    }
    
    
    func testSetPhotoSize(){
        // Forcing 18 MP or 5952X2976 Resolution.NSPhotographyOptionsTypePhotoSize
//        let types = [INSPhotographyOptionsType.photoSize]
        
        let optionsPhotography = INSPhotographyOptions()
        optionsPhotography.photoSize = INSPhotoSize5952x2976;
       
        let functionMode = INSCameraFunctionMode(functionMode: 6)
        let types: [NSNumber] = [NSNumber(value: INSPhotographyOptionsType.photoSize.rawValue)]
        INSCameraManager.shared().commandManager.setPhotographyOptions(optionsPhotography, for: functionMode, types: types) { error, successTypes in
            if let error = error {
                NSLog("Set Photography Options error: \(error)")
                return
            }
        }
        
//        [[INSCameraManager sharedManager].commandManager
//         getPhotographyOptionsWithFunctionMode:INSCameraFunctionModeNormalImage
//         types:types
//         completion:^(NSError * _Nullable error, INSPhotographyOptions * _Nullable options, NSArray<NSNumber *> * _Nullable successTypes) {
//            if(options.photoSize.width != optionsPhotography.photoSize.width || options.photoSize.height != optionsPhotography.photoSize.height) {
//                [[INSCameraManager sharedManager].commandManager
//                 setPhotographyOptions: optionsPhotography forFunctionMode:INSCameraFunctionModeNormalImage
//                 types:types completion:^(NSError * _Nullable error, NSArray<NSNumber *> * _Nullable successTypes) {
//                    NSLog(@"Set Photography Options: Error %@", error.description);
//                    NSLog(@"Set Photography Options: Expected photoSize %ld %ld", (long)optionsPhotography.photoSize.width, (long)optionsPhotography.photoSize.height);
//                    NSLog(@"Set Photography Options: Actual photoSize %ld %ld", (long)options.photoSize.width, (long)options.photoSize.height);
//                    NSLog(@"Success: %@", successTypes);
//                    completion();
//                }];
//            } else {
//                completion();
//            }
//        }];
    }
    func startTimelapse2(){
//        let timelapseOptions = INSTimelapseOptions()
//        timelapseOptions.lapseTime = UInt(500)
//        
//        let startTimelapseOptions = INSStartCaptureTimelapseOptions()
//        startTimelapseOptions.mode = .video
//        startTimelapseOptions.extraInfo = INSExtraInfo()
//        startTimelapseOptions.timelapseOptions = timelapseOptions
//
//        INSCameraManager.shared().commandManager.startCaptureTimelapse(with: startTimelapseOptions) { error in
//            if let error = error {
//                NSLog("Error STARTING timelapse recording: \(error.localizedDescription)")
//            } else {
//                NSLog("Record started!")
//            }
//        }
    }
    func startTimelapse() {
        let cameraOptions = INSCameraOptions()
        let videoMode: INSVideoSubMode = .timelapse
        cameraOptions.videoSubMode = UInt32(videoMode.rawValue)
        let forTypes: [NSNumber] = [
            NSNumber(value: INSCameraOptionsType.videoSubMode.rawValue)
        ]

        let photographyOptions = INSPhotographyOptions()
        photographyOptions.videoResolution = INSVideoResolution2880x2880x30

        let timelapseOptions = INSTimelapseOptions()
        timelapseOptions.lapseTime = UInt(500)

        let functionMode = INSCameraFunctionMode(functionMode: 2)

        INSCameraManager.socket().commandManager.setOptions(cameraOptions, forTypes: forTypes) { error, types in
            if let error {
                NSLog("setOptions error:\(error)")
            } else {
                let types: [NSNumber] = [NSNumber(value: INSPhotographyOptionsType.videoResolution.rawValue)]
                INSCameraManager.shared().commandManager.setPhotographyOptions(photographyOptions, for: functionMode, types: types) { error, successTypes in
                    if let error = error {
                        NSLog("Set Photography Options error: \(error)")
                        return
                    }

                    INSCameraManager.shared().commandManager.setTimelapseOptions(timelapseOptions, for: .video) { error in
                        if let error = error {
                            NSLog("Error setting timelapse options: \(error.localizedDescription)")
                            return
                        }

                        let startTimelapseOptions = INSStartCaptureTimelapseOptions()
                        startTimelapseOptions.mode = .video
                        startTimelapseOptions.timelapseOptions = timelapseOptions

                        INSCameraManager.shared().commandManager.startCaptureTimelapse(with: startTimelapseOptions) { error in
                            if let error = error {
                                NSLog("Error STARTING timelapse recording: \(error.localizedDescription)")
                            } else {
                                NSLog("Record started!")
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    func stopTimelapse() {
        let options = INSStopCaptureTimelapseOptions()
        options.mode = .video

        INSCameraManager.shared().commandManager.stopCaptureTimelapse(with: options) { error, videoInfo in
            if let error = error {
                NSLog("Error stopping timelapse capture: \(error.localizedDescription)")
            } else if let videoInfo = videoInfo {
                let uri = videoInfo.uri
                let downloadUrl = (INSHTTPURLForResourceURI(uri).absoluteString)
                NSLog("videoUri: \(uri)")
                NSLog("download url: \(downloadUrl)")
//                DispatchQueue.main.async {
//                    self.videoUri = "videoUri: \(uri)\n\ndownload url: \(downloadUrl)"
//                }
            } else {
                NSLog("No video information available")
            }
        }
    }
    
    // 导出图片
    func startExportImage(){
        
        let imagePath = NSHomeDirectory() + "/Documents/IMG_20250402_162331_00_021.insp"
        
        guard let image = UIImage(contentsOfFile: imagePath) else {
            print("Stitch: generate image failed")
            return
        }
        
        let url: URL = URL(fileURLWithPath: imagePath)
        let parser: INSImageInfoParser = INSImageInfoParser(url: url)
        
        if parser.open(), let extraInfo: INSExtraInfo = parser.extraInfo, let metadata = extraInfo.metadata {
            
            let render = INSFlatPanoOffscreenRender(renderWidth: 11904, height: 5952)
            
            render.render.stitchType = .disflow
            render.render.colorFusion = true
            render.eulerAdjust = metadata.euler
            render.offset = metadata.offsetV3
            
            
            if let gyroData = extraInfo.gyroData, let gyroPlayer = INSGyroPBPlayer(pbGyroData: gyroData) {
                let orientation = gyroPlayer.getImageOrientation(with: .flatPanoRender)
                render.gyroStabilityOrientation = orientation
            } else {
                render.gyroStabilityOrientation = GLKQuaternionIdentity
            }
            
            render.setRenderImage(image)
            
            let outPutImage = render.renderToImage()
            
            print("")
        }
    }
    
    func testImu(){
//        VID_20250729_145338_00_001.insv
//        VID_20250729_145405_00_002.insv
//        let imagePath = NSHomeDirectory() + "/Documents/VID_20250729_150002_00_003.insv"
//        let cache = NSHomeDirectory() + "/Documents/com.insta360.asset.video"
//        
//        let videoAsset = INSVideoAsset(path: imagePath, cacheDir: cache, option: .All)
//        
//        if (videoAsset.open() != nil) {
//            return
//        }
//        
//        let imudata = videoAsset.getGyroDataSize()
//        
//        print("")
      
//        INSCameraManager.setup(<#T##self: INSCameraManager##INSCameraManager#>)
        
        
        
//        let value = INSCameraManager.getTobSDKValue()
//        
//        print("\(value)")
//        
//        let manager = INSCameraManager.shared();
//        
//        INSCameraManager.shared().setTestAppid { error in
//            if error != nil {
//                print("error:\(String(describing: error))")
//            }
//            print("Finish")
//        }
        
//        setTestAppid(){error in
//            if error != nil {
//                print("error:\(String(describing: error))")
//            }
//            print("Finish")
//        }
    }
    
    func startExportImageSimplify(){
        
        let imagePath = NSHomeDirectory() + "/Documents/20250415-121358.jpeg"
        
        let imageURL: URL = URL(fileURLWithPath: imagePath)
        
        let imageExporter = INSExportImageSimplify()
        
        let outputPath = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/image_export_" + {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH-mm-ss"
            return formatter.string(from: Date())
        }() + ".jpeg")
        
        imageExporter.width = 11904
        imageExporter.height = 11904 / 2
        
        imageExporter.colorFusion = false
        
        imageExporter.exportImage(withInputUrl: imageURL, outputUrl: outputPath)
        
    }
    
    var videoExport: INSExportSimplify?
    
    func startExportVideoSimplify(){
        
        let outputPath = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/image_export_" + {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH-mm-ss"
            return formatter.string(from: Date())
        }() + ".mp4")
        
        let videoPath = NSHomeDirectory() + "/Documents/VID_20251029_172833_00_001.insv"
        let videoPath2 = NSHomeDirectory() + "/Documents/VID_20251027_171146_10_001.insv"
        let videoUrl: URL = URL(fileURLWithPath: videoPath)
        let videoUrl2: URL = URL(fileURLWithPath: videoPath2)
        
        
        let urls = [videoUrl/*, videoUrl2*/]
        
        videoExport = INSExportSimplify(urls: urls, outputUrl: outputPath)
        videoExport?.start()
        
//        let cachePath = NSHomeDirectory() + "/Documents/com.insta360.asset.video"
//        
//        let videoAsset:INSVideoAsset = INSVideoAsset(path: videoPath, cacheDir: cachePath, option: .All)
//        if let error = videoAsset.open() {
//            print("error: \(error)")
//        }
//        
//        let stabilizer = INSSequenceStabilizer(asset: videoAsset, param: INSStabilizerParam())
//        
//        let error = stabilizer.loadData()
//        
//        if let error = videoAsset.open() {
//            print("error: \(error)")
//        }

        print("")
    }
    
    
    func getLensType(){
        let settings: INSCameraDeviceSettings? = INSCameraManager.shared().currentCamera?.settings
        guard let mediaOffset = settings?.mediaOffset else {
            return
        }
        
        let secnsorType = INSLensOffset(offset: mediaOffset).lensType
        if secnsorType == INSLensType.oneR577Wide.rawValue {
            print("secnsorType:577Wide")
        } else if secnsorType == INSLensType.oneR577Pano.rawValue{
            print("secnsorType:577Pano")
        }
        
        print("secnsorType:\(secnsorType)")
        
    }
    
    
    
    func setFunctionMode(){
        
//        let functionMode = INSCameraFunctionMode(functionMode: 6)
//
//        var typeArray = [INSCameraOptionsType]()
//        let cameraOptions = INSCameraOptions()
//        
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
//        }
        
    }
    
    func setSingleOptions(){
        // Test Single Options
   

//        "raw_capture_type": {
//           "OFF": "0",
//           "RAW": "1",
//           "PURESHOT": "3",
//           "PURESHOT_RAW": "4",
//           "INSP": "5",
//           "INSP_RAW": "6"
//        },
//        "hdr_photo_mode": {
//            "OFF": "0",
//            "ON": "1",
//            "AEB": "2"
//        }
//        "hdr_photo_mode"            : "77",
//        "raw_capture_type"          : "25",
        
//        "PHOTO_SINGLE": "6",
        
        let typeArray: [INSPhotographyOptionsType] = [.whiteBalance]
        let photoOptionTypes = typeArray.map { NSNumber(value: $0.rawValue)}
        
//        let types = [77, 25]
//        // INSOptions
//        let optionTypes = types.map { (type) -> NSNumber in
//            return NSNumber(value: type)
//        }/Users/tommyshelby/workSpace/iOS/camera_sdk/Samples/INSCameraSDKSample-bluetooth/INSCameraSDKSample-bluetooth/src/CameraConfigByJsonController.swift
        
        let photographyOptions = INSPhotographyOptions()
        
        
        photographyOptions.whiteBalance = .colorTemp2700K
        
        let functionMode = INSCameraFunctionMode(functionMode: 6)
        let functionModeLive = INSCameraFunctionMode(functionMode: 1)
        
        INSCameraManager.shared().commandManager.setPhotographyOptions(photographyOptions, for: functionMode, types: photoOptionTypes, completion:  { [weak self] error, _ in
            if let error = error {
                self?.showAlert("Failed", "The camera resolution has been set failed: \(error.localizedDescription)")
                return
            }
        })
        
        INSCameraManager.shared().commandManager.setPhotographyOptions(photographyOptions, for: functionModeLive, types: photoOptionTypes, completion:  { [weak self] error, _ in
            if let error = error {
                self?.showAlert("Failed", "The camera resolution has been set failed: \(error.localizedDescription)")
                return
            }
        })

    }
    
    func test2() {
        let options:INSTakePictureOptions = INSTakePictureOptions()
        
        options.countDown = 0
        
        INSCameraManager.shared().commandManager.takePicture(with: options, completion: { (error, optionInfo) in
            print("end takePicture \(Date())")
            
            guard let uri = optionInfo?.uri else {
                return
            }
            print("Take Picture Url:\(uri)")
            self.showAlert("Image Url:", uri)
        })
    }
    
    
    func test22() {
        let options:INSTakePictureOptions = INSTakePictureOptions()
        
        options.countDown = 3
        
        INSCameraManager.shared().commandManager.takePicture(with: options, completion: { (error, optionInfo) in
            print("end takePicture \(Date())")
            
            guard let uri = optionInfo?.uri else {
                return
            }
            print("Take Picture Url:\(uri)")
            self.showAlert("Image Url:", uri)
        })
    }
    
    func test3() {
        
        let options = INSStartCaptureTimelapseOptions()
        options.mode = .image
        options.timelapseOptions = INSTimelapseOptions()
        
        INSCameraManager.shared().commandManager.startCaptureTimelapse(with: options) {error in
            if let err = error {
                print("error - ")
            }
        }
        
    }
    
    
    func parserVideoAsset() {
        
    
        
        
        
    }
    
    
    func setTimelapse() {
        var mode:INSTimelapseMode = INSTimelapseMode.image
        
        let options:INSTimelapseOptions = INSTimelapseOptions()
        var lapseTimeTmp : Double = 10
        var durationTmp : Double = 0
        
        options.lapseTime = UInt(lapseTimeTmp * 1000)
        options.duration  = UInt(durationTmp)
        
        INSCameraManager.shared().commandManager.setTimelapseOptions(options, for: mode, completion: {[weak self] (err) in
            if let err = err {
                self?.showAlert("Set LapseTime failed", err.localizedDescription);
                return
            }
        })
    }
    
    func setOPtions() {
        
    }
    
    func getOPtions() {
        
        let typeArray: [INSCameraOptionsType] = [.videoSubMode, .photoSubMode]
        
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
            
            guard let cameraOptions = cameraOptions else {return}
            
            var captureMode: HUMCaptureMode? = nil

            if cameraOptions.photoSubMode != 100 {
                captureMode = HUMCaptureMode.modePhotoFrom(value: cameraOptions.photoSubMode)
            }
            else if cameraOptions.videoSubMode != 100 {
                captureMode = HUMCaptureMode.modeVideoFrom(value: cameraOptions.videoSubMode)
            }
            guard let mode = captureMode else {return}
            
//            self?.attrManager.setFunctionModeWith(NSInteger(mode.functionMode.functionMode))
            
            print("DemoTest function Mode: \(mode.functionMode.functionMode)")
        }
        
    }
    
    
    var isCapturing = false

    func startAutoCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        captureNext()
    }

    func stopAutoCapture() {
        isCapturing = false
    }

    private func captureNext() {
        guard isCapturing else { return }

        let options = INSTakePictureOptions()
        options.mode = .aeb
        
        INSCameraManager.shared().commandManager.takePicture(with: options) { [weak self] error, optionInfo in
            guard let self = self else { return }
            print("end takePicture \(Date())")

            if let uri = optionInfo?.uri {
                print("Take Picture Url: \(uri)")
                self.showAlert("Image Url:", uri)
            } else {
                print("No image URI received")
            }

            // 拍完后延时5秒，再拍下一张
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.captureNext()
            }
        }
    }

        
    
    
    func takeHdrPicture(){
        let options:INSTakePictureOptions = INSTakePictureOptions()


        INSCameraManager.shared().commandManager.takeHDRPicture(with: options){error, urls, datas in
            if error != nil {
                self.showAlert("HDR Take:", "Failed!")
                return
            }
            
            guard let urls = urls else {
                return
            }
//            Task.process(withURI:)
            
            for url in urls {
                print("url:\(url)")
            }
            
        }
    }	
    
    
    func getSenor(){
        INSCameraManager.socket().commandManager.getActiveSensor { error, device, str1, str2 in
            if error != nil {
                self.showAlert("HDR Take:", "Failed!")
                return
            }
            
            print("device:\(device)")
        }
    }
    
    func takeHDR(){
        let options:INSTakePictureOptions = INSTakePictureOptions()
        
        INSCameraManager.shared().commandManager.takePicture(with: options, completion: { (error, optionInfo) in
            print("end takePicture \(Date())")
            guard let uri = optionInfo?.uri else {
                return
            }
            print("Take Picture Url:\(uri)")
            self.showAlert("Image Url:", uri)
        })
    }
    
    
    
    func pictureGps(){
//        let newestLocation = CLLocation(
//            coordinate: CLLocationCoordinate2D(latitude: 22.2803, longitude: 114.1655),
//            altitude: 10.0,
//            horizontalAccuracy: 5.0,
//            verticalAccuracy: 5.0,
//            timestamp: Date()
//        )
//        let metaData = INSExtraMetadata()
//        let mediaGps = INSMediaGps(clLocation: newestLocation, isValidLocation: true)
//        metaData.gps = mediaGps
//        let extraInfo = INSExtraInfo(version: Int32(INSExtraInfoVersion.one2.rawValue), metadata: metaData, gyroData: nil)
//        
//        let options:INSTakePictureOptions = INSTakePictureOptions(extraInfo: extraInfo)
//
//        
//        INSCameraManager.shared().commandManager.takePicture(with: options, completion: { (error, optionInfo) in
//            print("end takePicture \(Date())")
//            
//            guard let uri = optionInfo?.uri else {
//                return
//            }
//            print("Take Picture Url:\(uri)")
//        })
    }
    
    
    func copyFileToApp(){
//        let jsonFilePath: String = Bundle.main.path(forResource: "coreml_model_v2_scale6_scale4", ofType: "json")!
        guard let jsonFilePath: String = Bundle.main.path(forResource: "coreml_model_v2_scale6_scale4", ofType: "json", inDirectory: "models/dePurpleFring") else {
            return
        }
//        guard let jsonFilePath = Bundle.main.path(
//            forResource: "coreml_model_v2_scale6_scale4",
//            ofType: "json",
//            inDirectory: "models/dePurpleFring" // 子目录路径
//        ) else{
//            return
//        }
//        guard let jsonFilePath = Bundle.main.url(forResource: "coreml_model_v2_scale6_scale4", withExtension: "json", subdirectory: "models/dePurpleFring")?.absoluteString else {
//            return
//        }
        
        
        var jsonContent = ""
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: jsonFilePath))
            jsonContent = String(data: data, encoding: .utf8) ?? ""
        } catch {
            assertionFailure("\(jsonFilePath)文件无法读取")
        }
        
        let components = jsonFilePath.split(separator: "/")
        let directoryPath = components.dropLast().joined(separator: "/") + "/"
        
        print("Finish")
    }
    
    func testDeActivate() {
        
        let options = INSCameraOptions()
        options.activateTime = 0
        let types = [INSCameraOptionsType.activateTime.rawValue as NSNumber]
        INSCameraManager.shared().commandManager.setOptions(options, forTypes: types, completion: { (err, _) in
            let msg = err == nil ? "Success" : "Failed \(err!)"
            self.showAlert("Deactivate", msg)
        })
    }
    
    func testStartCapture() {
        INSCameraManager.shared().commandManager.startCapture(with: nil) { error in
            if let error = error {
                NSLog("Error STARTING timelapse recording: \(error.localizedDescription)")
            } else {
                NSLog("Record started!")

                // 3秒后自动停止录制
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.testStopCapture()
                }
            }
        }
    }
    
    

    func testStopCapture() {
        INSCameraManager.shared().commandManager.stopCapture(with: nil) { error, videoInfo in
            if let error = error {
                NSLog("Error STOPPING timelapse recording: \(error.localizedDescription)")
            } else {
                NSLog("Record stopped!")

                if let videoInfo = videoInfo {
                    NSLog("Video info: \(videoInfo.uri)")
                }
            }
        }
    }
    
    func startLoopRecording(segments: Int) {
        var currentSegment = 0

        func recordNextSegment() {
            guard currentSegment < segments else {
                NSLog("All segments recorded")
                return
            }

            NSLog("Starting segment \(currentSegment + 1)")

            INSCameraManager.shared().commandManager.startCapture(with: nil) { error in
                print("dml - Start Record, \(currentSegment)")
                
                if let error = error {
                    NSLog("dml - Error starting capture: \(error)")
                } else {
                    // 3秒后停止
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        INSCameraManager.shared().commandManager.stopCapture(with: nil) { error, videoInfo in
                            print("dml - Stop Record, \(currentSegment)")
                            if let error = error {
                                NSLog("dml -Error stopping capture: \(error)")
                            } else {
                                if let uri = videoInfo?.uri {
                                    NSLog("dml - Video uri: \(uri)")
                                }else {
                                    NSLog("dml - Video uri is nil ================================")
                                }
                            }
                            currentSegment += 1
                            recordNextSegment()
                        }
                    }
                }
            }
        }

        recordNextSegment()
    }
    
    
    
}
