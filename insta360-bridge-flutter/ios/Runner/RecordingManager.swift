import Foundation

class RecordingManager {
    
    static let shared = RecordingManager()
    private let queue = DispatchQueue(label: "com.insta360bridge.recordingmanager")
    
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
        try queue.sync {
            var recordings = getRecordingsArray()
            
            guard let data = jsonString.data(using: .utf8),
                  let newRecord = try? JSONSerialization.jsonObject(with: data) else {
                throw NSError(domain: "RecordingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
            }
            
            recordings.append(newRecord)
            
            let outputData = try JSONSerialization.data(withJSONObject: recordings, options: .prettyPrinted)
            try outputData.write(to: recordingsFile)
        }
    }
    
    // MARK: - Get Recordings
    
    func getRecordings() -> String {
        return queue.sync {
            let recordings = getRecordingsArray()
            guard let data = try? JSONSerialization.data(withJSONObject: recordings),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return "[]"
            }
            return jsonString
        }
    }
    
    // MARK: - Update Recording Fields
    
    func updateRecording(id: String, updatesJson: String) throws {
        try queue.sync {
            var recordings = getRecordingsArray()
            
            guard let updatesData = updatesJson.data(using: .utf8),
                  let updates = try? JSONSerialization.jsonObject(with: updatesData) as? [String: Any] else {
                throw NSError(domain: "RecordingManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid updates JSON"])
            }
            
            var found = false
            for i in 0..<recordings.count {
                if let rec = recordings[i] as? [String: Any], rec["id"] as? String == id {
                    var mutableRec = rec
                    for (key, value) in updates {
                        mutableRec[key] = value
                    }
                    recordings[i] = mutableRec
                    found = true
                    break
                }
            }
            
            guard found else {
                throw NSError(domain: "RecordingManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Recording \(id) not found"])
            }
            
            let outputData = try JSONSerialization.data(withJSONObject: recordings, options: .prettyPrinted)
            try outputData.write(to: recordingsFile)
        }
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
