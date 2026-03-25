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
                // Once WiFi is connected, trigger the SDK to connect to the camera
                print("[Insta360Channel] WiFi connected, triggering SDK camera connection")
                INSCameraManager.socket().connect()
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
            INSCameraManager.socket().connect()
            result(nil)
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
            result(wifiHelper.getCurrentSSID())
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
        case "saveRecordingMetadata":
            let args = call.arguments as? [String: Any] ?? [:]
            let jsonStr = args["data"] as? String ?? ""
            do {
                try recordingManager.saveRecordingMetadata(jsonString: jsonStr)
                invokeDartEvent("onMetadataSaved")
                result(nil)
            } catch {
                invokeDartEvent("onMetadataSaveFailed", arguments: ["reason": error.localizedDescription])
                result(FlutterError(code: "FAILED", message: error.localizedDescription, details: nil))
            }
        case "getRecordings":
            result(recordingManager.getRecordings())
        case "exportRecording":
            invokeDartEvent("onExportFailed", arguments: ["error": "iOS export not yet implemented", "resolution": "all"])
            result(FlutterError(code: "NOT_IMPLEMENTED", message: "iOS export is in development", details: nil))
            
        // Demo mode
        case "setDemoMode":
            let args = call.arguments as? [String: Any] ?? [:]
            demoMode = args["enabled"] as? Bool ?? false
            result(nil)
            
        // Google Drive — placeholder
        case "signInToDrive":
            result(FlutterError(code: "NOT_IMPLEMENTED", message: "iOS Google Drive is in development", details: nil))
        case "getDriveSignInStatus":
            result("")
        case "uploadToDrive":
            result(FlutterError(code: "NOT_IMPLEMENTED", message: "iOS Google Drive is in development", details: nil))
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
        // Default to video if possible, or just start capture with primary settings
        INSCameraManager.socket().startCapture(with: options) { [weak self] error in
            if let error = error {
                print("[Insta360Channel] startCapture error: \(error.localizedDescription)")
                self?.invokeDartEvent("onRecordingFailed", arguments: ["reason": error.localizedDescription])
            } else {
                print("[Insta360Channel] startCapture success")
                self?.invokeDartEvent("onRecordingStarted")
            }
        }
        result(nil)
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        print("[Insta360Channel] stopRecording called")
        if demoMode {
            invokeDartEvent("onRecordingStopped")
            result(nil)
            return
        }
        
        let options = INSCaptureOptions()
        INSCameraManager.socket().stopCapture(with: options) { [weak self] error in
            if let error = error {
                print("[Insta360Channel] stopCapture error: \(error.localizedDescription)")
                self?.invokeDartEvent("onRecordingStopFailed", arguments: ["reason": error.localizedDescription])
            } else {
                print("[Insta360Channel] stopCapture success")
                self?.invokeDartEvent("onRecordingStopped")
            }
        }
        result(nil)
    }
    
}
