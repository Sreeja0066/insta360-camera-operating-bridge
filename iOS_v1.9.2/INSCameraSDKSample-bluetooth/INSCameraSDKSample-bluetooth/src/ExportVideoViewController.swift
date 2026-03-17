//
//  CameraConfigByJsonController.swift
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


class ExportVideoViewController: FormViewController, URLSessionDelegate, INSRExporter2ManagerDelegate{

    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Export"
  
        setupForm()
        setLogFile()
    }
    
    deinit {
        videoExporter?.shutDown()
        videoExporter = nil
    }
    
    
    // Video
    var videoURL: URL?
    var videoURL2: URL?
    var videoExporter:INSExportSimplify?
    
    // Image
    var imageURL: URL?
    var imageExporter:INSExportImageSimplify?
    
    // params
    
    var colorFusion:Bool = false;
    var colorPlus:Bool = false;
    var stabMode:INSStabilizerStabMode = .still
    var dePurpleFringe:Bool = false
    var enableDenoise:Bool = false
    var currentProtect: INSOffsetConvertOptions = []
    
    var width = 2160
    var height = 1080
    
    // UI

    
    // 导出进度
    var progressRow: LabelRow?
      
      // 你可以调用这个接口来更新进度条
    var exportProgress: Float = 0 {
        didSet {
            updateProgressUI()
        }
    }
    private func updateProgressUI() {
         DispatchQueue.main.async {
             let percent = Int(self.exportProgress * 100)
             self.progressRow?.value = "\(percent)%"
             self.progressRow?.updateCell()
         }
     }
    
    let section:Section = Section("Common")
    let imageSection:Section = Section("image")
    let videoSection:Section = Section("video")
    func setupForm() {
    
        section
       
        
        <<< ButtonRow("Start Export"){ row in
            row.title = row.tag
        }.onCellSelection({ [weak self](_, _) in
            guard let weakSelf = self else {
                return
            }
            
            
            if let videoURL = weakSelf.videoURL {
                weakSelf.startExportVideo()
            } else {
                weakSelf.startExportImage()
            }
       
        })
        
        // 新增自定义 width 的输入行
        <<< IntRow("customWidth") { row in
            row.title = "Width"
            row.placeholder = "输入宽度"
            row.value = self.width // 初始值（可选）
        }
        .onChange { [weak self] row in
            guard let value = row.value, value > 0 else { return }
            self?.width = value
        }

        // 新增自定义 height 的输入行
        <<< IntRow("customHeight") { row in
            row.title = "Height"
            row.placeholder = "输入高度"
            row.value = self.height // 初始值（可选）
        }
        .onChange { [weak self] row in
            guard let value = row.value, value > 0 else { return }
            self?.height = value
        }
        
        <<< ActionSheetRow<String>("colorPlus") { row in
            row.title = row.tag
            row.options = ["open", "close"]
            row.value = "close"
        }.onChange({[weak self] (row) in
           
            guard let weakSelf = self else {return}
            
            if "open" == row.value {
                weakSelf.colorPlus = true
            } else {
                weakSelf.colorPlus = false
            }
        })
        
        <<< ActionSheetRow<String>("colorFusion") { row in
            row.title = row.tag
            row.options = ["open", "close"]
            row.value = "close"
        }.onChange({[weak self] (row) in
           
            guard let weakSelf = self else {return}
            
            if "open" == row.value {
                weakSelf.colorFusion = true
            } else {
                weakSelf.colorFusion = false
            }
        })
        
        <<< ActionSheetRow<String>("Stabilizer Mode") { row in
            row.title = row.tag
            row.options = ["Still", "FullDirectional"]
            row.value = "Still"
        }.onChange({[weak self] (row) in
           
            guard let weakSelf = self else {return}
            
            if "Still" == row.value {
                weakSelf.stabMode = .still
            } else if "FullDirectional" ==  row.value {
                weakSelf.stabMode = .fullDirectional
            }
        })
        
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
        })
        
 
        videoSection
        
        <<< LabelRow("Progress") {
               $0.title = "Export Progress"
               $0.value = "0%"
               self.progressRow = $0
           }
        
        <<< ActionSheetRow<String>("Denoise") { row in
            row.title = row.tag
            row.options = ["open", "close"]
            row.value = "close"
        }.onChange({[weak self] (row) in
           
            guard let weakSelf = self else {return}
            
            if "open" == row.value {
                weakSelf.enableDenoise = true
            } else {
                weakSelf.enableDenoise = false
            }
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
        
        form.append(section)
        
        if imageURL != nil {
//            form.append(imageSection)
        } else {
            form.append(videoSection)
        }
    }
    
    func setLogFile(){
        let coremediaLogFilePath = NSHomeDirectory() + "/Documents/mediaLog.txt"
        let logger = INSRegisterLogCallback.shareInstance()
        logger.configLogKind(.LOG_ALL, minLogLevel: .INS_LOG_INFO, optionalFullFilePath: coremediaLogFilePath)
    }
    
    // 导出图片
    func startExportImage(){
        
        guard let imageURL = imageURL else {return}
        
        imageExporter = INSExportImageSimplify()
        
        let outputPath = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/image_export_" + {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH-mm-ss"
            return formatter.string(from: Date())
        }() + ".jpeg")
        
        imageExporter?.colorFusion = colorFusion
        
        imageExporter?.protectType = self.currentProtect
        imageExporter?.colorPlus = self.colorPlus
        
        imageExporter?.exportImage(withInputUrl: imageURL, outputUrl: outputPath)
    }
    
    // 导出视频
    func startExportVideo(){
        let outputUrl = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/video_export_" + {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH-mm-ss"
            return formatter.string(from: Date())
        }() + ".mp4")
        
        guard let videoURL = videoURL else { return }
        let videoUrls = [videoURL, videoURL2].compactMap { $0 }
            
        self.videoExporter = INSExportSimplify(urls: videoUrls, outputUrl: outputUrl)
        
        self.videoExporter?.colorFusion = self.colorFusion
        self.videoExporter?.stabMode = self.stabMode
        self.videoExporter?.enableDenoise = self.enableDenoise
        self.videoExporter?.protectType = self.currentProtect
        self.videoExporter?.colorPlus = self.colorPlus
        
        let videoAsset = INSVideoAsset(path: videoURL.absoluteString, cacheDir: nil, option: .All)
        
        if let error = videoAsset.open() {
            print("videoAsset parser failed!")
            return
        }
        
        if videoAsset.extraMetadata?.videoTrackCount == 2 || videoUrls.count > 1 {
            self.videoExporter?.imageLayout = .respective2Images
        } else {
            self.videoExporter?.imageLayout = .horizontalMerged
        }

        if dePurpleFringe {
            let jsonFilePath: String = Bundle.main.path(forResource: "coreml_model_v2_scale6_scale4", ofType: "json")!
            let components = jsonFilePath.split(separator: "/")
            let modelFilePath = components.dropLast().joined(separator: "/")
            var jsonContent = ""
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: jsonFilePath))
                jsonContent = String(data: data, encoding: .utf8) ?? ""
            } catch {
                assertionFailure("\(jsonFilePath)文件无法读取")
            }
            
            let depurpleFringInfo = INSDefringeParam.init()
            depurpleFringInfo.modelJsonContent = jsonContent
            depurpleFringInfo.modelFilePath = modelFilePath
            depurpleFringInfo.enableDetect = true
            depurpleFringInfo.useFastInferSpeed = false
            videoExporter?.defringeParam = depurpleFringInfo
        }
        
        self.videoExporter?.exportManagedelegate = self
        
        self.videoExporter?.start()
    }
    
    
    func startDownloadVideo(){
        
        guard let cameraFile = self.videoURL?.absoluteString else {
            return
        }
        
        guard let videoName = self.videoURL?.lastPathComponent else {
            return
        }
        
        let outputUrl = URL.init(fileURLWithPath: NSHomeDirectory() + "/Documents/" + videoName)
        
        INSCameraManager.shared().commandManager.fetchResource(withURI: cameraFile, toLocalFile: outputUrl, progress: { progress in
            print("下载进度：\(String(describing: progress))")
        }, completion: {error in
            print("\(error)")
        })
    }
    
    func exporter2Manager(_ manager: INSExporter2Manager, progress: Float) {
        print("导出进度：\(progress)")
        self.exportProgress = progress
    }
    
    func exporter2Manager(_ manager: INSExporter2Manager, state: INSExporter2State, error: (any Error)?) {
        print("exporter2Manager, state:\(state), error:\(String(describing: error))")
        
        if state == .complete {
            self.showAlert("Export ","Success")
            
            videoExporter?.shutDown()
            videoExporter = nil
        }else {
            self.showAlert("Export ", "Falied")
        }
    }
    
    func exporter2Manager(_ manager: INSExporter2Manager, correctOffset: String, errorNum: Int32, totalNum: Int32, clipIndex: Int32, type: String) {
        
    }
}
