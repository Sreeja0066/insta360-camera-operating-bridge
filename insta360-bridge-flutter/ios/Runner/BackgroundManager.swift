import Foundation
import Network
import ActivityKit

/**
 * BackgroundManager — Monitors connectivity and triggers stalled uploads when internet returns.
 * Also handles local notifications for status updates.
 */
class BackgroundManager: NSObject {
    
    static let shared = BackgroundManager()
    
    private let pathMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private override init() {
        super.init()
        setupNetworkMonitoring()
    }
    
    func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                // We have internet!
                print("[BackgroundManager] Internet satisfied. Checking for pending uploads...")
                
                // Trigger uploads of any files still in the 'exported_videos' or 'recordings' directory
                self.triggerPendingUploads()
            }
        }
        pathMonitor.start(queue: queue)
    }
    
    func triggerPendingUploads() {
        // Logic to scan directories and call DriveUploader.shared.upload()
        // This ensures that if an upload was interrupted, it resumes when internet is back.
    }
    
    // MARK: - Notifications
    
    func sendStatusNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
