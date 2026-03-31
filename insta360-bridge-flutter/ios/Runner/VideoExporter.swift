import Foundation
import INSCameraSDK
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
        
        // Convert paths to INSWork objects - Use explicit INSWork if possible
        let works = paths.compactMap { INSWork(path: $0) }
        guard !works.isEmpty else {
            completion(nil, NSError(domain: "VideoExporter", code: 404, userInfo: [NSLocalizedDescriptionKey: "No valid works found"]))
            return
        }
        
        let outputURL = exportDir.appendingPathComponent("\(recordingId)_\(resolution)_\(Date().timeIntervalSince1970).mp4")
        
        // Setup B-end Export Options
        let options = INSExportOptions()
        options.targetPath = outputURL.path
        options.fps = 30
        
        if resolution == "4K" {
            options.width = 3840
            options.height = 1920
            options.bitrate = 60_000_000
        } else {
            options.width = 1920
            options.height = 960
            options.bitrate = 20_000_000
        }
        
        // Stabilization and Stitching - Use explicit enums
        options.stabType = INSStabType.auto
        options.exportMode = INSExportMode.panorama
        options.isDynamicStitch = true
        options.isDePurpleFilterOn = true
        
        print("[VideoExporter] Starting export for \(resolution) to \(outputURL.path)")
        
        // Execute export using INSExportManager (singleton in B-end SDK)
        INSExportManager.shared().exportVideo(with: works, options: options) { progressVal in
            DispatchQueue.main.async {
                progress(progressVal)
            }
        } completion: { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                } else {
                    completion(outputURL.path, nil)
                }
            }
        }
    }
}
