import BackgroundTasks
import UIKit

class BackgroundManager {
    static let shared = BackgroundManager()
    
    private let uploadTaskIdentifier = "com.noveloffice.insta360bridge.upload"
    
    func registerTasks() {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: uploadTaskIdentifier, using: nil) { task in
                self.handleUploadTask(task: task as! BGProcessingTask)
            }
        }
    }
    
    func scheduleUploadTask() {
        if #available(iOS 13.0, *) {
            let request = BGProcessingTaskRequest(identifier: uploadTaskIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 mins later
            request.requiresExternalPower = false
            request.requiresNetworkConnectivity = true
            
            do {
                try BGTaskScheduler.shared.submit(request)
                print("Background upload task scheduled!")
            } catch {
                print("Could not schedule background upload task: \(error)")
            }
        }
    }
    
    private func handleUploadTask(task: BGProcessingTask) {
        scheduleUploadTask() // Reschedule for periodic execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        // Logic for checking pending files and uploading via URLSession
        // task.setTaskCompleted(success: true)
    }
}
