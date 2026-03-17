//
//  GpsViewController.swift
//  INSCameraSDKDemo
//
//  Created by HkwKelvin on 2018/11/20.
//  Copyright © 2018年 insta360. All rights reserved.
//

import UIKit
import INSCameraSDK
import Eureka

class GpsViewController: FormViewController {
    
    let commandsManager = INSCameraManager.shared().commandManager;
    
    var uri: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupForm()
    }
    
    func setupForm() {
        
        form +++ Section("Basic")
        <<< ButtonRow() {
            $0.title = "upload gps datas"
            }.onCellSelection() {[weak self] _, row in
                
                let options = INSCaptureOptions()
                self?.commandsManager.startCapture(with: options, completion: { (err) in
                    if let err = err {
                        print("\(row.title!) failed with error: \(err)")
                        self?.showAlert(row.title!, err.localizedDescription);
                        return
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                        var gpsDatas: [INSCameraGpsInfo] = [INSCameraGpsInfo]()
                        for _ in 0..<100 {
                            let location: CLLocation = CLLocation(coordinate: CLLocationCoordinate2DMake(22.219749, 11.264474), altitude: 50.0, horizontalAccuracy: 1.0, verticalAccuracy: 1.0, course: 0.012, speed: 10.0, timestamp: Date())
                            let mediaGps = INSCameraGpsInfo(clLocation: location, isValidLocation: true)
                            
                            gpsDatas.append(mediaGps)
                        }
                        var datas: Data = Data()
                        for gps in gpsDatas {
                            guard let gpsD = gps.toGpsData() else {
                                continue
                            }
                            datas.append(gpsD)
                        }
                        print("--- \(datas)")
                        self?.commandsManager.uploadGpsDatas(gpsDatas, completion: { (error) in
                            if let error = error {
                                self?.showAlert("error", "upload gps datas error: \(error)")
                                print("upload gps datas error: \(error)")
                            }
                            else {
                                self?.showAlert("success", "upload gps datas success")
                                print("upload gps datas success")
                            }
                            
                            self?.commandsManager.stopCapture(with: options, completion: { [weak self] (err, video) in
                                if let err = err {
                                    print("\(row.title!) failed with error: \(err)")
                                    self?.showAlert(row.title!, err.localizedDescription);
                                    return
                                }
                                
                                self?.uri = video?.uri.replacingOccurrences(of: "_10_", with: "_00_")
                            })
                        })
                    })
                })
        }
        <<< ButtonRow() {
            $0.title = "File mnd (gps datas)"
            }.onCellSelection() {[weak self] _, row in
                guard let uri = self?.uri else {
                    print("you should shoot a video first")
                    return
                }
                
                let options: INSGetFileMndOptions = INSGetFileMndOptions()
                options.type = .gps
                options.uri  = uri
                self?.commandsManager.getFileMnd(with: options, completion: { (error, data) in
                    if let error = error {
                        print("File mnd (gps datas) error: \(error)")
                        self?.showAlert("error", "File mnd (gps datas) error: \(error)")
                        return
                    }
                    if let data = data, let extraGpsData: INSExtraGPSData = INSExtraGPSData(gpsData: data) {
                        print("gps count: \(String(describing: extraGpsData.gpsArray?.count))")
                        self?.showAlert("success", "gps count: \(String(describing: extraGpsData.gpsArray?.count))")
                    }
                })
        }
    }
}
