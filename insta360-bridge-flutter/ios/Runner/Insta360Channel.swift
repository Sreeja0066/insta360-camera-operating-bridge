import Flutter
import UIKit
import INSCameraSDK

class Insta360Channel: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private let wifiHelper = WifiHelper.shared
    private let recordingManager = RecordingManager.shared
    private var demoMode = false
    
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.noveloffice.insta360bridge/camera", binaryMessenger: registrar.messenger())
        let instance = Insta360Channel()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        instance.setupCallbacks()
        
        // Auto-connect to last-used camera on launch
        instance.wifiHelper.autoConnect()
    }
    
    private func setupCallbacks() {
        // Wire WifiHelper events to Flutter
        wifiHelper.onScanResults = { [weak self] results in
            self?.invokeDartEvent("onWifiList", arguments: results)
        }
        
        wifiHelper.onConnectionStatus = { [weak self] status in
            self?.invokeDartEvent("onWifiConnected", arguments: ["status": status])
            if status == "CONNECTED" {
                // For B-end SDK, we use setup() after Wi-Fi is connected
                print("[Insta360Channel] WiFi connected, triggering SDK camera setup")
                INSCameraManager.socket().setup()
            }
        }
    }
    
    // MARK: - Method Call Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // Camera control
        case "getStatus":
            result(getCameraStatus())
        case "connectCamera":
            INSCameraManager.socket().setup()
            result(nil)
        case "getExportedFiles":
            let files = getExportedFilesList()
            if let data = try? JSONSerialization.data(withJSONObject: files),
               let jsonString = String(data: data, encoding: .utf8) {
                result(jsonString)
            } else {
                result("[]")
            }
        case "getRecordings":
            result(recordingManager.getRecordings())
        case "startRecording":
            startRecording(result: result)
        case "stopRecording":
            stopRecording(result: result)
            
        // WiFi management
        case "scanWifi":
            wifiHelper.scanWifi()
            result(nil)
        case "stopScan":
            // On iOS, scanning is just returning a list, but we acknowledge the stop request
            print("[Insta360Channel] stopScan called")
            result(nil)
        case "connectWifi":
            let args = call.arguments as? [String: Any] ?? [:]
            let ssid = args["ssid"] as? String ?? ""
            let password = args["password"] as? String ?? ""
            wifiHelper.connectToNetwork(ssid: ssid, password: password)
            result(nil)
        case "getSavedCameras":
            let cameras = wifiHelper.getSavedCameras()
            if let data = try? JSONSerialization.data(withJSONObject: cameras),
               let jsonString = String(data: data, encoding: .utf8) {
                result(jsonString)
            } else {
                result("[]")
            }
        case "removeSavedCamera":
            let args = call.arguments as? [String: Any] ?? [:]
            let ssid = args["ssid"] as? String ?? ""
            wifiHelper.removeSavedCamera(ssid: ssid)
            result(nil)
        case "getCurrentSSID":
            print("[Insta360Channel] Fetching current SSID...")
            wifiHelper.fetchCurrentSSID { ssid in
                print("[Insta360Channel] SSID fetch complete: \(ssid ?? "nil")")
                result(ssid)
            }
        case "openWifiSettings":
            // Attempt multiple known schemes to get directly to the WIFI tab
            let schemes = ["App-Prefs:root=WIFI", "App-Prefs:WIFI", "prefs:root=WIFI"]
            for scheme in schemes {
                if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    result(nil)
                    return
                }
            }
            // Fallback to general settings
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
            result(nil)
            
        // Recordings
        case "exportRecording":
            let args = call.arguments as? [String: Any] ?? [:]
            let recordingId = args["recordingId"] as? String ?? ""
            exportRecording(recordingId: recordingId, result: result)
            
        // Google Drive — placeholder
        case "signInToDrive":
            signInToDrive(result: result)
        case "uploadToDrive":
            let args = call.arguments as? [String: Any] ?? [:]
            let filePath = args["filePath"] as? String ?? ""
            uploadToDrive(filePath: filePath, result: result)
        case "uploadPendingFiles":
            result(FlutterError(code: "NOT_IMPLEMENTED", message: "iOS Google Drive is in development", details: nil))
        case "getPendingUploadCount":
            result(0)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Send events to Flutter
    
    private func invokeDartEvent(_ method: String, arguments: Any? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod(method, arguments: arguments)
        }
    }
    
    // MARK: - Camera Control Implementation
    
    private func getCameraStatus() -> String {
        if demoMode { return "CONNECTED" }
        
        let state = INSCameraManager.socket().cameraState
        switch state {
        case .connected:
            return "CONNECTED"
        case .found, .synchronized:
            return "CONNECTING"
        case .noConnection, .connectFailed:
            return "DISCONNECTED"
        @unknown default:
            return "DISCONNECTED"
        }
    }
    
    private func startRecording(result: @escaping FlutterResult) {
        print("[Insta360Channel] startRecording called")
        if demoMode {
            invokeDartEvent("onRecordingStarted")
            result(nil)
            return
        }
        
        // Use INSCaptureOptions as required by the B-end SDK
        let options = INSCaptureOptions()
        
        // In the B-end SDK, capture methods are on the commandManager
        INSCameraManager.shared().commandManager.startCapture(with: options) { (error: Error?) in
            if let error = error {
                print("[Insta360Channel] startCapture error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.invokeDartEvent("onRecordingFailed", arguments: ["reason": error.localizedDescription])
                }
            } else {
                print("[Insta360Channel] startCapture success")
                DispatchQueue.main.async {
                    self.invokeDartEvent("onRecordingStarted")
                }
            }
        }
        result(nil)
    }
    
    private func exportRecording(recordingId: String, result: @escaping FlutterResult) {
        // Need to find the .insv files from the camera first
        INSCameraManager.shared().commandManager.fetchCameraFileList { (error, fileList) in
            guard let fileList = fileList else {
                self.invokeDartEvent("onExportFailed", arguments: ["error": "No files found on camera", "resolution": "all"])
                result(FlutterError(code: "FAILED", message: "No files found", details: nil))
                return
            }
            
            // For now, take the last one
            let lastFile = fileList.last as? String ?? ""
            let paths = [lastFile]
            
            VideoExporter.shared.exportBothResolutions(recordingId: recordingId, filePaths: paths) { progress, res in
                let pct = Int(progress * 100)
                self.invokeDartEvent("onExportProgress", arguments: ["progress": pct, "resolution": res])
            } completion: { path4K, path1080p, error in
                if let error = error {
                    self.invokeDartEvent("onExportFailed", arguments: ["error": error.localizedDescription, "resolution": "all"])
                    result(FlutterError(code: "FAILED", message: error.localizedDescription, details: nil))
                } else {
                    self.invokeDartEvent("onExportSuccess", arguments: ["path": path1080p ?? "", "resolution": "1080p"])
                    self.invokeDartEvent("onExportSuccess", arguments: ["path": path4K ?? "", "resolution": "4K"])
                    result("Export successful")
                }
            }
        }
    }
    
    private func signInToDrive(result: @escaping FlutterResult) {
        // AppAuth implementation goes here, for now use a placeholder
        print("[Insta360Channel] signInToDrive called")
        // Normally this involves opening a UI and calling DriveUploader.shared.saveAuthState()
        result(nil)
    }
    
    private func uploadToDrive(filePath: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: filePath)
        DriveUploader.shared.upload(fileURL: url) { fileID, error in
            if let error = error {
                self.invokeDartEvent("onDriveUploadFailed", arguments: ["error": error.localizedDescription])
                result(FlutterError(code: "FAILED", message: error.localizedDescription, details: nil))
            } else {
                self.invokeDartEvent("onDriveUploadSuccess", arguments: ["fileID": fileID ?? ""])
                result(fileID)
            }
        }
    private func getExportedFilesList() -> [[String: Any]] {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsDir.appendingPathComponent("exported_videos")
        
        var results = [[String: Any]]()
        
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: .skippingHiddenFiles) else {
            return []
        }
        
        for fileURL in files where fileURL.pathExtension == "mp4" {
            let attr = try? fileManager.attributesOfItem(atPath: fileURL.path)
            let size = attr?[.size] as? Int64 ?? 0
            let date = attr?[.modificationDate] as? Date ?? Date()
            
            let resolution = fileURL.lastPathComponent.contains("_4K_") ? "4K (3840×1920)" : "1080p (1920×960)"
            
            results.append([
                "name": fileURL.lastPathComponent,
                "path": fileURL.path,
                "size": size,
                "sizeFormatted": formatFileSize(size),
                "resolution": resolution,
                "lastModified": Int64(date.timeIntervalSince1970 * 1000)
            ])
        }
        
        return results.sorted { ($0["lastModified"] as? Int64 ?? 0) > ($1["lastModified"] as? Int64 ?? 0) }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        if kb >= 1 { return String(format: "%.1f KB", kb) }
        return "\(bytes) B"
    }
}
