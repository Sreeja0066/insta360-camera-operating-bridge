import Flutter
import UIKit
import INSCameraSDK
import AppAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  var currentAuthorizationFlow: OIDExternalUserAgentSession?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register Insta360 bridge
    Insta360Channel.register(with: registrar(forPlugin: "Insta360Channel")!)
    
    // Register background tasks
    BackgroundManager.shared.setupNetworkMonitoring()
    
    // Request notification permissions
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    UNUserNotificationCenter.current().delegate = self
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
      // Handle Google Drive OAuth redirect
      if let authorizationFlow = (UIApplication.shared.delegate as? AppDelegate)?.currentAuthorizationFlow,
         authorizationFlow.resumeExternalUserAgentFlow(with: url) {
          return true
      }
      return super.application(app, open: url, options: options)
  }
}
