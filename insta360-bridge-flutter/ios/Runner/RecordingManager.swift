import Foundation

class RecordingManager {
    
    static let shared = RecordingManager()
    
    private var recordingsDir: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsDir.appendingPathComponent("recordings")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var recordingsFile: URL {
        return recordingsDir.appendingPathComponent("recordings.json")
    }
    
    // MARK: - Save Recording Metadata
    
    func saveRecordingMetadata(jsonString: String) throws {
        var recordings = getRecordingsArray()
        
        guard let data = jsonString.data(using: .utf8),
              let newRecord = try? JSONSerialization.jsonObject(with: data) else {
            throw NSError(domain: "RecordingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        
        recordings.append(newRecord)
        
        let outputData = try JSONSerialization.data(withJSONObject: recordings, options: .prettyPrinted)
        try outputData.write(to: recordingsFile)
    }
    
    // MARK: - Get Recordings
    
    func getRecordings() -> String {
        let recordings = getRecordingsArray()
        guard let data = try? JSONSerialization.data(withJSONObject: recordings),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
    }
    
    // MARK: - Private
    
    private func getRecordingsArray() -> [Any] {
        guard FileManager.default.fileExists(atPath: recordingsFile.path),
              let data = try? Data(contentsOf: recordingsFile),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return []
        }
        return array
    }
}
