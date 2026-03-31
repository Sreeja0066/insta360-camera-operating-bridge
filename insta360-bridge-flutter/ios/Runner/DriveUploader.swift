import Foundation
import AppAuth
import GTMAppAuth
import GoogleAPIClientForREST

/**
 * DriveUploader — Handles native iOS Google Drive uploads in the background.
 * Uses AppAuth for OAuth2 and GTLRDrive for the upload logic.
 */
class DriveUploader: NSObject {
    
    static let shared = DriveUploader()
    
    private let kClientID = "824840973539-5tu7i5md6hpopjd5gubb5mruagmf4a48.apps.googleusercontent.com"
    private let kRedirectURI = "com.googleusercontent.apps.824840973539-5tu7i5md6hpopjd5gubb5mruagmf4a48:/oauthredirect"
    
    private let driveService = GTLRDriveService()
    private var authState: OIDAuthState?
    
    private override init() {
        super.init()
        loadAuthState()
        if let authState = authState {
            driveService.authorizer = GTMAppAuthFetcherAuthorization(authState: authState)
        }
    }
    
    // MARK: - Auth Management
    
    func saveAuthState(_ state: OIDAuthState?) {
        self.authState = state
        if let state = state {
            let data = NSKeyedArchiver.archivedData(withRootObject: state)
            UserDefaults.standard.set(data, forKey: "googleDriveAuthState")
            driveService.authorizer = GTMAppAuthFetcherAuthorization(authState: state)
        } else {
            UserDefaults.standard.removeObject(forKey: "googleDriveAuthState")
            driveService.authorizer = nil
        }
    }
    
    private func loadAuthState() {
        if let data = UserDefaults.standard.data(forKey: "googleDriveAuthState"),
           let state = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? OIDAuthState {
            self.authState = state
        }
    }
    
    var isSignedIn: Bool {
        return authState?.isAuthorized ?? false
    }
    
    // MARK: - Upload Logic
    
    func upload(fileURL: URL, completion: @escaping (String?, Error?) -> Void) {
        guard isSignedIn else {
            completion(nil, NSError(domain: "DriveUploader", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"]))
            return
        }
        
        // 1. Ensure folder exists
        getOrCreateFolder { folderID in
            guard let folderID = folderID else {
                completion(nil, NSError(domain: "DriveUploader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not find/create folder"]))
                return
            }
            
            // 2. Prepare file metadata
            let driveFile = GTLRDrive_File()
            driveFile.name = fileURL.lastPathComponent
            driveFile.parents = [folderID]
            
            // 3. Create upload parameters
            let uploadParameters = GTLRUploadParameters(fileURL: fileURL, mimeType: "application/octet-stream")
            
            // 4. Execute upload
            let query = GTLRDriveQuery_FilesCreate.query(withObject: driveFile, uploadParameters: uploadParameters)
            query.fields = "id"
            
            self.driveService.executeQuery(query) { (ticket, file, error) in
                if let error = error {
                    print("[DriveUploader] Upload failed: \(error.localizedDescription)")
                    completion(nil, error)
                } else if let file = file as? GTLRDrive_File {
                    print("[DriveUploader] Upload success! ID: \(file.identifier ?? "unknown")")
                    
                    // Cleanup local file after successful upload as requested
                    try? FileManager.default.removeItem(at: fileURL)
                    print("[DriveUploader] Local file cleaned up: \(fileURL.lastPathComponent)")
                    
                    completion(file.identifier, nil)
                }
            }
        }
    }
    
    private func getOrCreateFolder(completion: @escaping (String?) -> Void) {
        let folderName = "Insta360Bridge"
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "name = '\(folderName)' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
        query.spaces = "drive"
        query.fields = "files(id)"
        
        driveService.executeQuery(query) { (ticket, result, error) in
            if let files = (result as? GTLRDrive_FileList)?.files, let first = files.first {
                completion(first.identifier)
            } else {
                // Create folder
                let folder = GTLRDrive_File()
                folder.name = folderName
                folder.mimeType = "application/vnd.google-apps.folder"
                
                let createQuery = GTLRDriveQuery_FilesCreate.query(withObject: folder, uploadParameters: nil)
                createQuery.fields = "id"
                
                self.driveService.executeQuery(createQuery) { (ticket, folder, error) in
                    completion((folder as? GTLRDrive_File)?.identifier)
                }
            }
        }
    }
}
