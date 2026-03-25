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
                // Auto-setup camera SDK when WiFi connects
                INSCameraManager.shared().setup()
            }
        }
    }
    
    // MARK: - Method Call Handler
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // Camera control
        case "getStatus":
            result(getCameraStatus())
        case "connectCamera":
            connectCamera(result: result)
        case "startRecording":
            startRecording(result: result)
        case "stopRecording":
            stopRecording(result: result)
            
        // WiFi management
        case "scanWifi":
            wifiHelper.scanWifi()
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
            if let url = URL(string: "App-Prefs:root=WIFI") {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
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
            // Placeholder — requires INSCameraSDK export integration
            let args = call.arguments as? [String: Any] ?? [:]
            let recordingId = args["recordingId"] as? String ?? ""
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
    
    // MARK: - Camera Control
    
    private func getCameraStatus() -> String {
        let state = INSCameraManager.shared().cameraState
        switch state {
        case .connected:
            return "CONNECTED"
        case .found, .synchronized:
            return "CONNECTING"
        default:
            return "DISCONNECTED"
        }
    }
    
    private func connectCamera(result: @escaping FlutterResult) {
        INSCameraManager.shared().setup()
        result(nil)
    }
    
    private func startRecording(result: @escaping FlutterResult) {
        // Proxy OSC command logic here
        result(nil)
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        // Proxy OSC command logic here
        result(nil)
    }
}
