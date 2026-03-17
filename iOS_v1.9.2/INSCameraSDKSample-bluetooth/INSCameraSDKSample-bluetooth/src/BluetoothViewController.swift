//
//  BluetoothViewController.swift
//  INSCameraSDK
//
//  Created by zeng bin on 5/25/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK
import CoreBluetooth

extension INSCameraCaptureStatus {
    open override var description: String {
        var d = ""
        switch state {
        case .notCapture:
            d = "not capture"
        case .normalCapture:
            d = "normal capture \(captureTime)s"
        case .timelapseCapture:
            d = "timelapse capture \(captureTime)s"
        case .intervalShootingCapture:
            d = "interval shooting \(captureTime)s"
        case .singleShooting:
            d = "single shooting \(captureTime)s"
        case .hdrShooting:
            d = "hdr shooting \(captureTime)s"
        case .selfTimerShooting:
            d = "self timer shooting \(captureTime)s"
        case .bulletTimeCapture:
            d = "bullet timer shooting \(captureTime)s"
        case .settingNewValue:
            d = "setting new value \(captureTime)s"
        case .hdrVideoCapture:
            d = "hdr video value \(captureTime)s"
        case .burstShooting:
            d = "burst shooting \(captureTime)s"
        default:
            break
        }
        return d;
    }
}

extension INSAdoptionSystem : CustomStringConvertible {
    public var description: String {
        switch self {
        case .ios:
            return "Adoption iOS"
        case .android:
            return "Adoption android"
        default:
            return ""
        }
    }
}

let longShutterSpeed: [Int64] = [0, 30, 15, 60, 20];

var longShutterSpeedIndex = 0;

var cameraAttrSupportManagerPath = NSHomeDirectory() + "/Documents/Insta360_camera_attr_support.json"

class BluetoothViewController: FormViewController, INSBluetoothManagerDelegate {

    let bluetoothManager = INSBluetoothManager()
    
    var connectedDevice: INSBluetoothDevice?
    
    var commandManager: INSCameraBasicCommands? {
        guard let peripheral = self.connectedDevice else {
            return nil
        }
        
        if let commandManager = self.bluetoothManager.getCommandBy(peripheral) as? INSCameraBasicCommands {
            return commandManager
        }
        
        return nil
    }
    
    var connectTask: Any?
    
    var rssiTimer: Timer!
    
    let remoteControllersListSection = Section("Remote Controllers")
    
    let networkMonitor = INSNetworkMonitor()
    
    var lastPhotoURI: String?
    
    var deviceDict: [String: INSBluetoothDevice] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Bluetooth"
        self.setupForm()
        
        bluetoothManager.delegate = self
        
        bluetoothManager.addObserver(self, forKeyPath: "state", options: [.old, .new], context: nil)
        
        self.networkMonitor.label.frame = CGRect(x: 0, y: 64, width: 300, height: 28);
        self.view.addSubview(self.networkMonitor.label)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraStorageStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraStorageFull, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraUSBConnected, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraCaptureStopped, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(discoverBTPeripherals(_:)),
                                               name: .INSCameraDiscoverBTPeripherals, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(connectedToBTPeripheral(_:)),
                                               name: .INSCameraConnectedToBTPeripheral, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnectedBTPeripheral(_:)),
                                               name: .INSCameraDisconnectedBTPeripheral, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraCurrentCaptureStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraAuthorizationResult, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraTimelapseStatusUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraTemperatureStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: .INSCameraWifiStatusUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSetWifiConnectionNotification(_:)),
                                               name: .INSCameraCameraWifiStatus, object: nil)
    }
    
//    func openTestVC(device: INSBluetoothDevice) {
//        let vc = FmgDebugListController(devcie: device, bluetoothManager: self.bluetoothManager)
//        self.navigationController?.pushViewController(vc, animated: true)
//    }
    
    deinit {
        if connectedDevice != nil {
            bluetoothManager.disconnectDevice(connectedDevice!)
        }
        if connectTask != nil {
            bluetoothManager.cancelConnect(connectTask!)
        }
        bluetoothManager.stopScan()
        
        bluetoothManager.removeObserver(self, forKeyPath: "state")
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleNotification(_ notification: Notification) -> Void {
        print(String(describing: notification.userInfo))
//        self.showAlert(notification.name.rawValue, String(describing: notification.userInfo))
    }
    
    @objc func handleSetWifiConnectionNotification(_ notification: Notification) {
        if let result = notification.userInfo?["wifiConnectionResult"] as? INSCameraWifiConnectionResult {
//            self.showAlert(notification.name.rawValue, "code = \(result.wifiConnectionResult)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        startUpdateRSSITimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        rssiTimer.invalidate()
    }
    var scannedDevices: [(INSBluetoothDevice, Int)] = []
    
    func setupForm() {
        
        // 保存扫描结果
     
        
        let camerasListSection = Section("Cameras")
        
        form +++ Section("Actions")
        
        <<< ButtonRow("Scan") { row in
            row.title = row.tag
        }.onCellSelection { [weak self] (_, _) in
            guard let self = self else { return }
            self.scannedDevices.removeAll() // 每次扫描前清空
            self.bluetoothManager.scanCameras { device, rssi, _ in
                let uuid = device.identifierUUIDStringSafe
                if self.scannedDevices.contains(where: { $0.0.identifierUUIDStringSafe == uuid }) {
                    return
                }
                self.scannedDevices.append((device, rssi) as! (INSBluetoothDevice, Int))
            }
            
            // 扫描一定时间后停止并弹窗，比如 3 秒
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.bluetoothManager.stopScan()
                self.showDevicePopup(devices: self.scannedDevices)
            }
        }
        <<< ButtonRow("Disconnect") {
            $0.title = "\($0.tag!)"
        }.onCellSelection() { [weak self] (_, _) in
            guard let device = self?.connectedDevice else {
                return
            }
            self?.bluetoothManager.disconnectDevice(device);
        }
        
        +++ Section("Commands")
        
        <<< ButtonRow("Check Authorization") {
            $0.title = "\($0.tag!)"
        }.onCellSelection() { [weak self] (_, row) in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
//            commandManager?.checkPhoneAuthorization(with: nil) { (err, status) in
//                if let err = err {
//                    self?.showAlert(row.tag!, String(describing: err))
//                    return
//                }
//                guard let status = status else {
//                    self?.showAlert(row.tag!, String(describing: err))
//                    return
//                }
//                if status.state == .authorized {
//                    self?.showAlert(row.tag!, "Authorized")
//                } else if status.state == .unauthorized {
//                    self?.showAlert(row.tag!, "UnAuthorized,请去授权")
//                } else if status.state == .systemBusy {
//                    self?.showAlert(row.tag!, "System Busy,请稍后授权")
//                }
//            }
        }
        
        <<< ButtonRow("Get Wifi Info") {
            $0.title = "\($0.tag!)"
        }.onCellSelection() { [weak self] (_, row) in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            
            let optionTypes = [
                NSNumber(value: INSCameraOptionsType.wifiChannelList.rawValue)
            ];
            commandManager?.getOptionsWithTypes(optionTypes) { (err, options, successTypes) in
                guard let options = options else {
                    self?.showAlert(row.tag!, String(describing: err))
                    return
                }
                self?.showAlert("ssid:\(String(describing: options.wifiInfo?.ssid)) pw:\(String(describing: options.wifiInfo?.password))", String(describing: err))
                
                print("ssid:\(String(describing: options.wifiInfo?.ssid)) pw:\(String(describing: options.wifiInfo?.password)), channel\(options.wifiInfo!.channel), mode\(options.wifiInfo!.mode), wifiState\(options.wifiInfo!.wifiState), wifiState\(options.wifiInfo!.wifiState)")
                
                self?.printWifiChannelList(options.wifiChannelList)
            }
        }
        
        <<< ButtonRow("Camera Activate") { row in
            row.title = row.tag;
        }.onCellSelection() { [weak self] _, row in
            
        
            
            guard let serialNumber = INSCameraManager.shared().currentCamera?.serialNumber else {
                self?.showAlert("提示", "请先连接相机")
                return
            }

            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            
            INSCameraActivateManager.setAppid("gjrc9kpv21b7hcf2", secret: "2nd62ekpu2how87t34aqb3obn6gjbqxw")
            
            INSCameraActivateManager.share().activateCamera(withSerial: serialNumber, commandManager: commandManager!) { deviceInfo, error in
                if let activateError = error {
                    self?.showAlert("Activate to \(serialNumber)", String(describing: activateError))
                } else {
                    let deviceType = deviceInfo?["deviceType"] ?? ""
                    let serialNumber = deviceInfo?["serial"] ?? ""
                    self?.showAlert("Activate to success", "deviceType: \(deviceType), serial: \(serialNumber)")
                }
            }
        }
        
        <<< ButtonRow("Take Picture") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            let metadata = INSExtraMetadata.init()
            metadata.removePurple = true
            let options = INSTakePictureOptions()
            options.extraMetadata = metadata.serializeToProtobufData()
            let exposureOptions = INSCameraExposureOptions()
            exposureOptions.program = 3
            exposureOptions.iso = 100
            exposureOptions.shutterSpeed = CMTime(value: longShutterSpeed[longShutterSpeedIndex],
                                                  timescale: 1)
            options.currenExposureOptions = exposureOptions
            commandManager?.takePicture(with: options, completion: { (err, photo) in
                guard let photo = photo else {
                    self?.showAlert(row.tag!, String(describing: err))
                    return
                }
                print("photo uri: \(photo.uri)")
                self?.lastPhotoURI = photo.uri
            })
        })
        
        <<< ButtonRow("Take Picture HDR") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            let metadata = INSExtraMetadata.init()
            metadata.removePurple = true
            let options = INSTakePictureOptions()
            options.extraMetadata = metadata.serializeToProtobufData()
            options.mode = INSPhotoMode.aeb
            options.delayHDRProcess = true
            commandManager?.takePicture(with: options, completion: { (err, photo) in
                guard let photo = photo else {
                    self?.showAlert(row.tag!, String(describing: err))
                    return
                }
                
                guard let sThumbnail = photo.sThumbnail else {
                    self?.showAlert(row.tag!, "success without thumbnail")
                    return
                }
                
                let playerController = PlayerViewController()
                playerController.image = UIImage(data: sThumbnail)
                playerController.renderType = INSRenderType.normal
                self?.show(playerController, sender: nil)
            })
        })
        
        <<< ButtonRow("Test Blue Download") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            
            commandManager?.fetchStorageFileInfo(with: .json, completion: {error, fileResp in
                
                guard let fileResp = fileResp else {
                    return
                }
                
                print("Info: fetchStorageFileInfo Success!")
                let outputURL = URL(fileURLWithPath: cameraAttrSupportManagerPath)
//                commandManager?.fetchResource(withURI: fileResp.uri, toLocalFile: outputURL, progress: {progress in}, completion: {
//                    error in
//                    
//                    guard let error = error else {
//                        print("Error!")
//                        return
//                    }
//                    
//                    print("inputUrl:\(fileResp.uri), outputUrl\(outputURL)")
//                    
//                })
                
            })
        })
        
        
        <<< ButtonRow("Start Capture") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            commandManager?.startCapture(with: nil, completion: { (err) in
                self?.showAlert(row.tag!, String(describing: err))
            })
        })
        <<< ButtonRow("Stop Capture") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            commandManager?.stopCapture(with: nil, completion: { (err, video) in
                self?.showAlert(row.tag!, "\(String(describing: err)), \(String(describing: video?.uri))")
            })
//            fetchResource
//            commandManager.fetchResources(complete: {
//                
//            })
            
        })
        
        <<< ButtonRow("Set Function Mode") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            let alert = UIAlertController(title: "Select Function Mode",
                                          message: nil,
                                          preferredStyle: .actionSheet)
            ["Normal", "timeLapse"].forEach { code in
                alert.addAction(UIAlertAction(title: code, style: .default) { _ in
                    print("Selected country code: \(String(describing: code))")
                    // 在这里调用 resetCameraWifi 或其他方法
                    
                    guard let peripheral = self?.connectedDevice else { return }
                    let commandManager = self?.bluetoothManager.command(by: peripheral)
                    guard let country = code else {
                        return
                    }
                    
                    let cameraOptions = INSCameraOptions()
                    cameraOptions.photoSubMode = 2
                    
                    let optionTypes = [
                        NSNumber(value: INSCameraOptionsType.videoSubMode.rawValue),
                    ];
                    
                    commandManager?.setOptions(cameraOptions, forTypes: optionTypes) { error, types in
                        if let error = error {
                            self?.showAlert("Set Country Code Failed!", String.init(describing: error))
                        } else {
                            self?.showAlert("Set Country Code", " SUCCESS!")
                        }
                    }
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self?.present(alert, animated: true)
        })
        
        <<< ButtonRow() {
            $0.title = "get wifi info"
        }.onCellSelection() {[weak self] _, row in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            commandManager?.getOptionsWithTypes([NSNumber(value: INSCameraOptionsType.wifiInfo.rawValue)], completion: { (error, options, successTypes) in
                if let error = error {
                    self?.showAlert("失败", String.init(describing: error))
                } else {
                    if let wifiStatus = options?.wifiInfo?.wifiState {
                        self?.showAlert("获取wifi信息成功", "\(wifiStatus)")
                    } else {
                        self?.showAlert("失败", "wifiInfo nil")
                    }
                }
            })
        }
        
        
        <<< ButtonRow() {
            $0.title = "开启相机Wi-Fi"
        }.onCellSelection() {[weak self] _, row in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            commandManager?.openCameraWifi(with: nil, channel: 0, completion: { (err) in
                if let err = err {
                    self?.showAlert("失败", String.init(describing: err))
                } else {
                    self?.showAlert("成功", "开启Wi-Fi")
                }
            })
        }
        
        <<< ButtonRow() {
            $0.title = "关闭相机Wi-Fi"
        }.onCellSelection() {[weak self] _, row in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            commandManager?.closeCameraWifi(with: nil, completion: { (err) in
                if let err = err {
                    self?.showAlert("失败", String.init(describing: err))
                } else {
                    self?.showAlert("成功", "关闭Wi-Fi")
                }
            })
        }
        
        <<< ButtonRow() {
            $0.title = "关闭相机"
        }.onCellSelection() {[weak self] _, row in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            commandManager?.closeCamera({_ in 
                
            })
        }

        <<< ButtonRow("Reboot") {
            $0.title = $0.tag
        }.onCellSelection({ [weak self] (_, row) in
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            commandManager?.reboot(completion: { (err) in
                self?.showAlert(row.tag!, String(describing: err))
            })
        })
        
        form +++ Section("Country Code")
        <<< ButtonRow() {
            $0.title = "Show Wifi Info"
        }.onCellSelection() { [weak self] _, row in
            
            guard let peripheral = self?.connectedDevice else { return }
            let commandManager = self?.bluetoothManager.command(by: peripheral)
            
            let optionTypes = [
                NSNumber(value: INSCameraOptionsType.wifiChannelList.rawValue),
                NSNumber(value: INSCameraOptionsType.wifiInfo.rawValue),
            ];
            commandManager?.getOptionsWithTypes(optionTypes) { (err, options, successTypes) in
                guard let options = options else {
                    print("ERROR:\(err)")
                    return
                }
                let wifiChannelList = options.wifiChannelList
                
                // 弹出第一个 ActionSheet：显示国家码，并让用户选择频段
                let bandSelect = UIAlertController(
                    title: "Wi-Fi Info",
                    message: "Country Code: \(wifiChannelList.countryCode), channel: \(options.wifiInfo?.channel)",
                    preferredStyle: .actionSheet
                )
                
                bandSelect.addAction(UIAlertAction(title: "5G Channels", style: .default) { _ in
                    self?.showChannelList(title: "5G Channels",
                                          channels: wifiChannelList.channelList_5g,
                                          countryCode: wifiChannelList.countryCode)
                })
                
                bandSelect.addAction(UIAlertAction(title: "2.4G Channels", style: .default) { _ in
                    self?.showChannelList(title: "2.4G Channels",
                                          channels: wifiChannelList.channelList_2_4g,
                                          countryCode: wifiChannelList.countryCode)
                })
                
                bandSelect.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self?.present(bandSelect, animated: true)
            }
 
        }
        
        <<< ButtonRow("Reset Country Code") { row in
            row.title = row.tag
        }.onCellSelection { [weak self] _, row in
            let alert = UIAlertController(title: "Select Country Code",
                                          message: nil,
                                          preferredStyle: .actionSheet)
            ["CN", "JP"].forEach { code in
                alert.addAction(UIAlertAction(title: code, style: .default) { _ in
                    print("Selected country code: \(String(describing: code))")
                    // 在这里调用 resetCameraWifi 或其他方法
                    
                    
                    guard let peripheral = self?.connectedDevice else { return }
                    let commandManager = self?.bluetoothManager.command(by: peripheral)
                    guard let country = code else {
                        return
                    }
                    
                    let optionTypes = [
                        NSNumber(value: INSCameraOptionsType.wifiChannelList.rawValue),
                    ];
                    let wifiChannelList = INSCameraWifiChannelList.init(countryCode: country)
                    let options = INSCameraOptions()
                    options.wifiChannelList = wifiChannelList
                    commandManager?.setOptions(options, forTypes: optionTypes) { error, types in
                        if let error = error {
                            self?.showAlert("Set Country Code Failed!", String.init(describing: error))
                        } else {
                            self?.showAlert("Set Country Code", " SUCCESS!")
                        }
                    }
                    
                    
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self?.present(alert, animated: true)
        }
        
        <<< ButtonRow() {
            $0.title = "Reopen Wi-Fi"
        }.onCellSelection() { _, row in
            
            guard let peripheral = self.connectedDevice else { return }
            let commandManager = self.bluetoothManager.command(by: peripheral)
            commandManager.resetCameraWifi(with: nil, channel: 0){ error in
                
            }
            
        }

        +++ Section()
        
        
        +++ remoteControllersListSection
    }
    
    func startUpdateRSSITimer() {
        self.rssiTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self,
                                              selector: #selector(updateRSSI),
                                              userInfo: nil, repeats: true)
    }
    
    @objc func updateRSSI() {
        guard let connectedDevice = connectedDevice else {
            return
        }
        bluetoothManager.readRSSI(connectedDevice, completion: {[weak self] (_, rssi) in
            guard let rssi = rssi, let row: LabelRow = self?.form.rowBy(tag: "RSSI") else {
                return;
            }
            row.value = "\(rssi)"
            row.reload()
        })
    }
    
    func captureStatusForever() -> Void {
        if #available(iOS 10.0, *) {
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { (_) in
                guard let connectedDevice = self.connectedDevice else { return }
                let commandManager = self.bluetoothManager.command(by: connectedDevice)
                
                let start = Date().timeIntervalSinceReferenceDate;
                print("send capture status \(start)")
                commandManager.getCurrentCaptureStatus(completion: { (err, status) in
                    let end = Date().timeIntervalSinceReferenceDate
                    print("receive capture status \(end) -- \(end - start)")
                })
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bluetoothFirmware" {
            let row: LabelRow = form.rowBy(tag: "Bluetooth Firmware")!
            row.value = connectedDevice?.bluetoothFirmware
            row.reload()
        }
        
        if keyPath == "state"
        {
            guard let stateValue = change?[NSKeyValueChangeKey.newKey] as? UInt else {
                return;
            }
            let state = INSBluetoothManageState(rawValue: stateValue)
            if state == .ready {
                print("====bluttooth ready");
            } else if state == .bluetoothDisable {
                print("====bluttooth disable");
            }
            
        }
    }
    
    func switchAdoptionSystem() {
        guard let connectedDevice = connectedDevice else { return }
        
        guard let row = form.rowBy(tag: "Adoption System") else {
            return
        }
        var toSystem: INSAdoptionSystem? = nil
        if row.title?.contains("iOS") == true {
            toSystem = INSAdoptionSystem.android
        }
        if row.title?.contains("android") == true {
            toSystem = INSAdoptionSystem.ios
        }
        if toSystem == nil {
            return
        }
        
        let adoptionSystemType = INSCameraOptionsType.adoptionSystem.rawValue as NSNumber
        let types = [adoptionSystemType]
        let commandManager = bluetoothManager.command(by: connectedDevice)
        let options = INSCameraOptions()
        options.adoptionSystem = toSystem!
        commandManager.setOptions(options, forTypes: types) {[weak self] (err, successTypes) in
            if let err = err {
                self?.showAlert("get options failed", "\(err)")
                return
            }
            
            row.title = "\(toSystem!)   click to switch"
            row.reload()
        }
    }
    
    func device(_ device: INSBluetoothDevice, didDisconnectWithError error: Error?) {
        self.showAlert("Disconnect", String.init(describing: error))
//        connectedDevice?.removeObserver(self, forKeyPath: "bluetoothFirmware")
        connectedDevice = nil
    }
    
    func deviceDidConnected(_ device: INSBluetoothDevice) {
        if self.navigationController?.topViewController == self {
            self.connectedDevice = device
        } else {
            self.showAlert("蓝牙连接成功", "")
        }
    }
    
    @objc func discoverBTPeripherals(_ notification: Notification) {
        remoteControllersListSection.removeAll()
        guard let remoteControllers = notification.userInfo?["peripherals"] as? [INSCameraBTPeripheral] else {
            let row = LabelRow()
            row.value = "scaned nothing \(Date.init())"
            remoteControllersListSection.append(row)
            return
        }
        
        guard remoteControllers.count > 0 else {
            let row = LabelRow()
            row.value = "scaned nothing \(Date.init())"
            remoteControllersListSection.append(row)
            return
        }
        
        for rc in remoteControllers {
            let tag = rc.macAddr?.hexEncodedString() ?? ""
            let row = ButtonRow(tag) {
                $0.title = (rc.name ?? "") + tag
            }.onCellSelection({ [weak self] (_, _) in
                let commandManager = INSCameraManager.shared().commandManager
                commandManager.connect(rc, completion: { (err) in
                    if let err = err {
                        self?.showAlert("connect to \(rc.name!)", String(describing: err))
                    }
                })
            })
            remoteControllersListSection.append(row)
        }
    }
    
    @objc func connectedToBTPeripheral(_ notification: Notification) {
        var msg = ""
        if let peripheral = notification.userInfo?["peripheral"] as? INSCameraBTPeripheral {
            msg = (peripheral.name ?? "") + (peripheral.macAddr?.hexEncodedString() ?? "")
        }
        self.showAlert("camera connect to controller", msg)
    }
    
    @objc func disconnectedBTPeripheral(_ notification: Notification) {
        var msg = ""
        if let peripheral = notification.userInfo?["peripheral"] as? INSCameraBTPeripheral {
            msg = (peripheral.name ?? "") + (peripheral.macAddr?.hexEncodedString() ?? "")
        }
        self.showAlert("camera disconnect controller", msg)
    }
    
    override func textInputDidEndEditing<T>(_ textInput: UITextInput, cell: Cell<T>) {
        guard let tag = cell.row.tag else {
            return
        }
        if tag == "Wake Up Specific" {
            let value = cell.row.value as? String ?? "";
            var cameraProximityUUID:String = "";
            //trans every single char in string to ASCII
            cameraProximityUUID = cameraProximityUUID.trimmingCharacters(in: .whitespaces)
            for ch in value.unicodeScalars {
                let num = Int(ch.value)
                let str = String(format: "%0X", num)//String(15, radix) "\(num)"
                cameraProximityUUID.append(str)
            }
            
            self.bluetoothManager.wakeUpSpecificCamera(cameraProximityUUID, completion: { (err) in
                guard let err = err else {
                    self.showAlert("Wake Up", "No Error")
                    return
                }
                self.showAlert("Wake Up Error", String(describing: err))
            })
        }
    }
    
    func printWifiChannelList(_ list: INSCameraWifiChannelList) {
        print("countryCode:", list.countryCode)
        print("channelList_5g:", list.channelList_5g)
        print("channelList_2_4g:", list.channelList_2_4g)
    }
    
    func showChannelList(title: String, channels: [NSNumber], countryCode: String) {
        let alert = UIAlertController(
            title: "\(title) (\(countryCode))", // 标题带上国家码
            message: "Select a channel",
            preferredStyle: .actionSheet
        )
        
        for ch in channels {
            alert.addAction(UIAlertAction(title: "\(ch)", style: .default) { _ in
                print("Selected channel: \(ch)")
                // 这里执行切换频道的 SDK 调用
                // INSCameraManager.shared().commandManager.resetCameraWifi(with: nil, channel: ch.intValue) { error in ... }
                guard let peripheral = self.connectedDevice else { return }
                let commandManager = self.bluetoothManager.command(by: peripheral)
                commandManager.resetCameraWifi(with: nil, channel: ch.uint32Value){ error in
                    
                }
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showDevicePopup(devices: [(INSBluetoothDevice, Int)]) {
        guard !devices.isEmpty else {
            self.showAlert("No devices found", "")
            return
        }
        
        let alert = UIAlertController(title: "Available Devices", message: nil, preferredStyle: .actionSheet)
        
        for (device, rssi) in devices {
            let name = device.name ?? "unknown"
            alert.addAction(UIAlertAction(title: "\(name) (\(rssi))", style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                
                if let connected = self.connectedDevice {
                    self.bluetoothManager.disconnectDevice(connected)
                }
                
                self.bluetoothManager.connect(device) { error in
                    DispatchQueue.main.async {
                        let msg = error == nil ? "Connected" : "Failed"
                        self.showAlert("\(msg) to \(device.name ?? "unknown")", String(describing: error))
                        if error == nil {
                            self.connectedDevice = device
                            self.bluetoothManager.networkMonitor = self.networkMonitor
                        }
                    }
                }
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController, let view = self.view {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        self.present(alert, animated: true)
    }
}
