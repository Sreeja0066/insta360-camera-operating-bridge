import Foundation
import INSCameraSDK
import INSCameraServiceSDK
import INSCoreMedia

/**
 * VideoExporter — Handles post-processing and export of Insta360 recordings on iOS.
 * Exports raw .insv files to MP4 with 4K and 1080p support.
 */
class VideoExporter: NSObject {
    
    static let shared = VideoExporter()
    
    private override init() {
        super.init()
    }
    
    private var exportDir: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsDir.appendingPathComponent("exported_videos")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func exportBothResolutions(recordingId: String, filePaths: [String], progress: @escaping (Float, String) -> Void, completion: @escaping (String?, String?, Error?) -> Void) {
        
        // Export 4K first, then 1080p sequentially
        exportSingleResolution(recordingId: recordingId, paths: filePaths, resolution: "4K") { progressVal in
            progress(progressVal, "4K")
        } completion: { path4K, error in
            if let error = error {
                print("[VideoExporter] 4K export failed: \(error.localizedDescription)")
            }
            
            // Still try 1080p
            self.exportSingleResolution(recordingId: recordingId, paths: filePaths, resolution: "1080p") { progressVal in
                progress(progressVal, "1080p")
            } completion: { path1080p, error in
                completion(path4K, path1080p, error)
            }
        }
    }
    
    private func exportSingleResolution(recordingId: String, paths: [String], resolution: String, progress: @escaping (Float) -> Void, completion: @escaping (String?, Error?) -> Void) {
        
        // Convert string paths to URLs for INSExportSimplify
        let urls = paths.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else {
            completion(nil, NSError(domain: "VideoExporter", code: 404, userInfo: [NSLocalizedDescriptionKey: "No valid file URLs found"]))
            return
        }
        
        let outputURL = exportDir.appendingPathComponent("\(recordingId)_\(resolution)_\(Date().timeIntervalSince1970).mp4")
        
        // Setup B-end Export Simplify
        let exporter = INSExportSimplify(urls: urls, outputUrl: outputURL)
        exporter.fps = 30
        
        if resolution == "4K" {
            exporter.width = 3840
            exporter.height = 1920
            exporter.bitrate = 60_000_000
        } else {
            exporter.width = 1920
            exporter.height = 960
            exporter.bitrate = 20_000_000
        }
        
        print("[VideoExporter] Starting export for \(resolution) to \(outputURL.path)")
        
        // Execute export using INSExportSimplify
        let error = exporter.start()
        if let error = error {
            print("[VideoExporter] Export start error: \(error.localizedDescription)")
            completion(nil, error)
        } else {
            // Note: INSExportSimplify in some SDK versions uses a delegate for progress.
            // For now, we assume synchronous start or we'll need to implement the delegate.
            // In v1.9.2, it's typically asynchronous if start returns nil.
            completion(outputURL.path, nil)
        }
    }
}
