//
//  CameraFrameViewController.swift
//  INSCameraSDKDemo
//
//  Created by HkwKelvin on 2019/9/25.
//  Copyright © 2019 insta360. All rights reserved.
//

import UIKit

import Eureka
import INSCameraSDK

class CameraFrameViewController: FormViewController {
    
    func player(_ player: INSCameraPlayer, onStitchedFrame stitchedFrame: INSCameraVideoFrame) {
        fps += 1
        if CFAbsoluteTimeGetCurrent() - lastUpdateTime >= 1.0 {
            lastUpdateTime = CFAbsoluteTimeGetCurrent()
            self.updateSummary(timestamp: stitchedFrame.timestamp, fps: fps)
            fps = 0
        }
        
        #if true
        let image: UIImage = UIImage(pixelBuffer: stitchedFrame.pixelBuffer)
        DispatchQueue.main.async {
            self.imageView.image = image
        }
        #endif
    }
    
    
    let configurationVC = LiveConfigurationViewController();
    
    var mediaSession = INSCameraMediaSession()

    var player: INSCameraPlayer = INSCameraPlayer()
    
    let imageView = UIImageView(frame: CGRect(x: 0, y: 400, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width / 2))
   
    var shouldRestart: Bool = false
    
    var fps: Int = 0
    
    var lastUpdateTime: CFTimeInterval = 0
    
    deinit {
        mediaSession.stopRunning { (err) in
            print("stopRunning \(String(describing: err))")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupForm()
        self.setup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if shouldRestart {
            setupMediaSession()
            mediaSession.startRunning(completion: { [weak self] (error) in
                self?.shouldRestart = false
                print("start error: \(String(describing: error))")
            })
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        mediaSession.stopRunning { (err) in
            print("stopRunning \(String(describing: err))")
        }
    }
    
    func setup() {
        self.view.addSubview(imageView)
        
        player.delegate = self
        player.outputPixelFormat = kCVPixelFormatType_32BGRA
        mediaSession.plug(player)
        
        setupMediaSession()
    }
    
    func setupMediaSession() -> Void {
        mediaSession.expectedVideoResolution = configurationVC.inputVideoResolution
        mediaSession.expectedVideoResolutionSecondary = configurationVC.inputVideoResolution2
        mediaSession.previewStreamType = INSPreviewStreamTypeWithValue(configurationVC.previewStreamNum)
    }
    
    func setupForm() {
        form +++ Section("")
            <<< ButtonRow("Basic Configuration") {
                $0.title = $0.tag
                $0.presentationMode = .show(controllerProvider: .callback() { [weak self] in
                    self?.shouldRestart = true
                    return self!.configurationVC
                    }, onDismiss: nil);
                }
            
            <<< ButtonRow("Start") {
                $0.title = $0.tag
                }.onCellSelection { [weak self] (_, row) in
                    guard let strongSelf = self else {
                        return
                    }
                    guard !strongSelf.mediaSession.running else {
                        strongSelf.showAlert(row.tag!, "session is running");
                        return
                    }
                    strongSelf.mediaSession.startRunning(completion: { (error) in
                        strongSelf.showAlert(row.tag!, "start error: \(String(describing: error))");
                        print("start error: \(String(describing: error))")
                    })
                    row.reload()
                }
            
            <<< ButtonRow("Stop") {
                $0.title = $0.tag
                }.onCellSelection { [weak self] (_, row) in
                    self?.mediaSession.stopRunning(completion: { (error) in
                        self?.showAlert(row.tag!, "stop error: \(String(describing: error))");
                        print("stop error: \(String(describing: error))")
                    })
                    row.reload()
                }
            
            <<< LabelRow("Status") {
                $0.title = $0.tag
            }
            
            <<< LabelRow(tag: "Summary")
    }
    
    func updateSummary(timestamp: TimeInterval, fps: Int) {
        DispatchQueue.main.async {
            if let row: LabelRow = self.form.rowBy(tag: "Summary") {
                row.value = "timestamp: \(timestamp), fps: \(fps)"
                row.reload()
            }
        }
    }
}

extension CameraFrameViewController: INSCameraPlayerDelegate {
    

}
