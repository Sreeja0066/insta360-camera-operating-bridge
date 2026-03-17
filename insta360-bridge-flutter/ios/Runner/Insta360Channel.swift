import Flutter
import UIKit
import INSCameraSDK

class Insta360Channel: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "insta360_bridge", binaryMessenger: registrar.messenger())
        let instance = Insta360Channel()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getStatus":
            result(getCameraStatus())
        case "connectCamera":
            connectCamera(result: result)
        case "startRecording":
            startRecording(result: result)
        case "stopRecording":
            stopRecording(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getCameraStatus() -> String {
        let state = INSCameraManager.shared().cameraState
        switch state {
        case .connected:
            return "CONNECTED"
        case .connecting:
            return "CONNECTING"
        default:
            return "DISCONNECTED"
        }
    }
    
    private func connectCamera(result: @escaping FlutterResult) {
        // Implementation for discovery and connection
        // On iOS, this usually involves EAAccessoryManager or WiFi
        INSCameraManager.shared().setup()
        result(nil)
    }
    
    private func startRecording(result: @escaping FlutterResult) {
        // Proxy OSC command logic here
        // The SDK docs mention using URLSession for OSC commands
        result(nil)
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        // Proxy OSC command logic here
        result(nil)
    }
}
