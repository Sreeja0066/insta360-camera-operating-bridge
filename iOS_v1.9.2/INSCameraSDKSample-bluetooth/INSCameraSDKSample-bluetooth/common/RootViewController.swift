//
//  RootViewController.swift
//  INSCameraSDK
//
//  Created by zeng bin on 4/13/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK
import INSCameraServiceSDK

class RootViewController: FormViewController, INSCameraSDKLoggerProtocol {
    
    var filePath: String = ""
    
    let time = NSDate().timeIntervalSince1970 * 1000;
    let formatter = DateFormatter()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Demo"
        
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        if let path: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            filePath = (path as NSString).appendingPathComponent("\(Int(Date().timeIntervalSince1970)).txt")
            let ret = FileManager.default.createFile(atPath: filePath, contents: nil)
            if ret {
                print("文件创建成功")
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraBatteryStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraBatteryLow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraStorageStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraStorageFull, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraWillShutDown, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraFWUpgradeDone, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraCaptureStopped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraCaptureSplit, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraTakePictureStateUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraTemperatureStatus, object: nil)
        
        INSCameraManager.usb().addObserver(self,
                                              forKeyPath: #keyPath(INSCameraManager.cameraState),
                                              options: [.new],
                                              context: nil);
        
        INSCameraManager.socket().addObserver(self,
                                              forKeyPath: #keyPath(INSCameraManager.cameraState),
                                              options: [.new],
                                              context: nil);
        
        INSCameraManager.external().addObserver(self,
                                                forKeyPath: #keyPath(INSCameraManager.cameraState),
                                                options: [.new],
                                                context: nil);
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cameraDidDisconnectNotification(_:)),
                                               name: .INSCameraDidDisconnect, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cameraConnectionErrorNotification(_:)),
                                               name: .INSCameraConnectionError, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handUsbSandboxUnauthorized(_:)), name: .INSUsbSandboxUnauthorized, object: nil)
        
        setupForm();
        
        INSCameraSDKLogger.shared().logDelegate = self
        INSCameraSDKLogger.shared().logLevel = .release
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.updateCameraInfo()
    }
    
    @objc func handUsbSandboxUnauthorized(_ notification: Notification) {
        guard let didDiscoverNum = notification.userInfo?["usbSandboxShouldAuth"] as? NSNumber else {
            return
        }
        let didDiscover = didDiscoverNum.boolValue
        if didDiscover {
            INSCameraManager.external().presentExternalUsbSandboxPathPicker(on: self) { res in
                print("handUsbSandboxUnauthorized \(res)")
            }
        } else {
            INSCameraManager.external().dismissExternalUsbSandboxPathPicker()
        }
    }
    
    @objc func handleNotification(notification: NSNotification) {
        print("receive notification \(notification.name), info: \(String(describing: notification.userInfo))");
        self.updateCameraInfo()
    }
    
    func setupForm() {
        let bundle = Bundle(for: INSCameraManager.self)
        
        let statusSection: Section = Section("Status")
        <<< LabelRow("usb_connect_status") { row in
            row.title = "USB Status"
            row.value = "Not Connect"
        }
        <<< LabelRow("socket_connect_status") { row in
            row.title = "Wi-Fi Status"
            row.value = "Not Connect"
        }
        form.append(statusSection)
        
        form.append(actionsSection)
        
        if mediasSection.count > 0 {
            form.append(mediasSection)
        }
        
//        CameraInfoSection
        if CameraInfoSection.count > 0 {
            form.append(CameraInfoSection)
        }else{
            let cameraSection: Section = Section("Camera") { $0.tag = "Camera" }
            <<< LabelRow("Manufacturer") { row in
                row.title = row.tag
            }
            <<< LabelRow("Name") { row in
                row.title = row.tag
            }
            <<< LabelRow("ModelNumber") { row in
                row.title = row.tag
            }
            <<< LabelRow("SerialNumber") { row in
                row.title = row.tag
            }
            <<< LabelRow("FirmwareRevision") { row in
                row.title = row.tag
            }
            <<< LabelRow("HardwareRevision") { row in
                row.title = row.tag
            }
            <<< LabelRow("ProtocolString") { row in
                row.title = row.tag
            }
            <<< LabelRow("CameraType") { row in
                row.title = row.tag
            }
            <<< LabelRow("LensType") { row in
                row.title = row.tag
            }
            <<< LabelRow("PPID") { row in
                row.title = row.tag
            }
            form.append(cameraSection)
        }
            
        let infoSection: Section = Section("SDK")
        <<< LabelRow("INSCameraSDK Version") { row in
            row.title = row.tag
            let version = bundle.infoDictionary!["CFBundleShortVersionString"] as! String
            let build = bundle.infoDictionary!["CFBundleVersion"] as! String
            row.value = "\(version)_\(build)"
        }
        form.append(infoSection)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            let object = object as? INSCameraManager
            if (object == INSCameraManager.usb() || object == INSCameraManager.external())
                && keyPath == #keyPath(INSCameraManager.cameraState) {
                self.updateDeviceInfo()
                guard let stateValue = change?[NSKeyValueChangeKey.newKey] as? UInt else {
                    return;
                }
                guard let row: LabelRow = self.form.rowBy(tag: "usb_connect_status") else {
                    return;
                }
                let state = INSCameraState(rawValue: stateValue)
                if state == .found {
                    row.value = "Found";
                } else if state == .synchronized {
                    row.value = "Synchronized";
                } else if state == .connected {
                    row.value = "Connected";
                    self.startSendingHeartbeats()
                } else if state == .connectFailed {
                    row.value = "failed";
                    self.stopSendingHeartbeats()
                } else {
                    row.value = "Not Connect";
                    self.stopSendingHeartbeats()
                }
                row.updateCell()
            } else if object == INSCameraManager.socket() && keyPath == #keyPath(INSCameraManager.cameraState) {
                self.updateDeviceInfo()
                guard let stateValue = change?[NSKeyValueChangeKey.newKey] as? UInt else {
                    return;
                }
                guard let row: LabelRow = self.form.rowBy(tag: "socket_connect_status") else {
                    return;
                }
                let state = INSCameraState(rawValue: stateValue)
                if state == .found {
                    row.value = "Found";
                } else if state == .synchronized {
                    row.value = "Synchronized";
                } else if state == .connected {
                    row.value = "Connected";
                    self.startSendingHeartbeats()
                    self.updateCameraInfo()
                } else if state == .connectFailed {
                    row.value = "failed";
                    self.stopSendingHeartbeats()
                } else {
                    row.value = "Not Connect";
                    self.stopSendingHeartbeats()
                }
                row.updateCell()
            }
        }
    }
    
    func updateDeviceInfo() {
        let current = INSCameraManager.shared().currentCamera
        guard let section = form.sectionBy(tag: "Camera") else {
            return
        }
        
        if let device = current as? INSUSBDevice {
            form.rowBy(tag: "Manufacturer")?.value = device.manufacturer
            form.rowBy(tag: "Name")?.value = device.name
            form.rowBy(tag: "ModelNumber")?.value = device.modelNumber
            form.rowBy(tag: "SerialNumber")?.value = device.serialNumber
            form.rowBy(tag: "FirmwareRevision")?.value = device.firmwareRevision
            form.rowBy(tag: "HardwareRevision")?.value = device.hardwareRevision
            form.rowBy(tag: "ProtocolString")?.value = device.sessionProtocol
            form.rowBy(tag: "CameraType")?.value = device.cameraType
            if let offset = device.settings?.mediaOffset {
                form.rowBy(tag: "LensType")?.value = INSLensOffset(offset: offset).lensType
            }
            if let ppid = device.accessory?.value(forKey: "ppid") as? String {
                form.rowBy(tag: "PPID")?.value = ppid
            }
            section.reload()
        }
        else if let device = current as? INSWebServerDevice {
            form.rowBy(tag: "Manufacturer")?.value = device.manufacturer
            form.rowBy(tag: "Name")?.value = device.name
            form.rowBy(tag: "ModelNumber")?.value = device.modelNumber
            form.rowBy(tag: "SerialNumber")?.value = device.serialNumber
            form.rowBy(tag: "FirmwareRevision")?.value = device.firmwareRevision
            form.rowBy(tag: "HardwareRevision")?.value = device.hardwareRevision
            form.rowBy(tag: "ProtocolString")?.value = device.sessionProtocol
            form.rowBy(tag: "CameraType")?.value = device.cameraType
            if let offset = device.settings?.mediaOffset {
                form.rowBy(tag: "LensType")?.value = INSLensOffset(offset: offset).lensType
            }
            if let ppid = device.accessory?.value(forKey: "ppid") as? String {
                form.rowBy(tag: "PPID")?.value = ppid
            }
            section.reload()
        }
        else if let device = current as? INSSocketDevice {
            form.rowBy(tag: "Manufacturer")?.value = "-"
            form.rowBy(tag: "Name")?.value = device.name
            form.rowBy(tag: "ModelNumber")?.value = "-"
            form.rowBy(tag: "SerialNumber")?.value = device.serialNumber
            form.rowBy(tag: "FirmwareRevision")?.value = device.firmwareRevision
            form.rowBy(tag: "HardwareRevision")?.value = "-"
            form.rowBy(tag: "ProtocolString")?.value = "-"
            form.rowBy(tag: "CameraType")?.value = device.cameraType
            if let offset = device.settings?.mediaOffset {
                form.rowBy(tag: "LensType")?.value = INSLensOffset(offset: offset).lensType
            }
            section.reload()
        }
    }
    
    func startSendingHeartbeats() {
        let commandManager = INSCameraManager.shared().commandManager
        print("heartbeat start")
        GCDTimer.shared.scheduledDispatchTimer(WithTimerName: "HeartbeatsTimer", timeInterval: 0.5, queue: DispatchQueue.main, repeats: true) {
            commandManager.sendHeartbeats(with: nil)
//            print("heartbeats")
        }
    }
    
    func stopSendingHeartbeats(){
        GCDTimer.shared.cancleTimer(WithTimerName: "HeartbeatsTimer")
        print("heartbeat canceled")
    }
    
    @objc private func cameraDidDisconnectNotification(_ notification: Notification) {
        if let object = notification.object as? Error {
            print("ceciliafengye连接：cameraDidDisconnectNotification:error \(object)")
        }
    }
    
    @objc private func cameraConnectionErrorNotification(_ notification: Notification) {
        if let object = notification.object as? Error {
            print("ceciliafengye连接：cameraConnectionErrorNotification: error: \(object)")
        }
    }
    
    func logError(_ message: String, filePath: String, funcName: String, lineNum: Int) {
        
    }
    
    func logWarning(_ message: String, filePath: String, funcName: String, lineNum: Int) {
    
    }
    
    func logInfo(_ message: String, filePath: String, funcName: String, lineNum: Int) {
        guard message.contains("by-") else {
            return
        }
        let date = Date()
        let timeString = formatter.string(from: date)
        
        if let data = (timeString + ":" + message + "\n").data(using: .utf8), let fileHandle = FileHandle(forWritingAtPath: self.filePath) {
            
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        }
    }
    
    func logDebug(_ message: String, filePath: String, funcName: String, lineNum: Int) {
        
    }
    
    func logCrash(_ message: String, filePath: String, funcName: String, lineNum: Int) {
        
    }
}
