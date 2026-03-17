import Flutter
import UIKit
import INSCameraSDK

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register Insta360 bridge
    Insta360Channel.register(with: registrar(forPlugin: "Insta360Channel")!)
    
    // Register background tasks
    BackgroundManager.shared.registerTasks()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
