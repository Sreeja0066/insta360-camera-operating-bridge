import Foundation
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import Security

class WifiHelper {
    
    static let shared = WifiHelper()
    
    // Callbacks to Flutter channel
    var onScanResults: (([[String: Any]]) -> Void)?
    var onConnectionStatus: ((String) -> Void)?
    
    private let keychainService = "com.noveloffice.insta360bridge.cameras"
    private let lastUsedKey = "lastUsedCamera"
    
    // MARK: - Scan (returns saved cameras since iOS can't scan WiFi)
    
    func scanWifi() {
        // iOS cannot scan for WiFi networks — return saved cameras instead
        let savedCameras = getSavedCameras()
        
        if savedCameras.isEmpty {
            // No saved cameras — tell Flutter to show "first time" setup
            onScanResults?([])
        } else {
            // Return saved cameras as the "network list"
            let results = savedCameras.map { camera -> [String: Any] in
                return [
                    "ssid": camera["ssid"] ?? "",
                    "level": -40, // Placeholder signal level
                    "saved": true
                ]
            }
            onScanResults?(results)
        }
    }
    
    // MARK: - Connect to WiFi using NEHotspotConfiguration
    
    func connectToNetwork(ssid: String, password: String) {
        onConnectionStatus?("CONNECTING")
        
        let configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        configuration.joinOnce = false // Persist the connection
        
        NEHotspotConfigurationManager.shared.apply(configuration) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == NEHotspotConfigurationErrorDomain {
                        switch nsError.code {
                        case NEHotspotConfigurationError.alreadyAssociated.rawValue:
                            // Already connected to this network — treat as success
                            self?.saveCamera(ssid: ssid, password: password)
                            self?.onConnectionStatus?("CONNECTED")
                        case NEHotspotConfigurationError.userDenied.rawValue:
                            self?.onConnectionStatus?("USER_DENIED")
                        case NEHotspotConfigurationError.invalidSSID.rawValue:
                            self?.onConnectionStatus?("INVALID_SSID")
                        case NEHotspotConfigurationError.invalidWPAPassphrase.rawValue:
                            self?.onConnectionStatus?("INVALID_PASSWORD")
                        default:
                            self?.onConnectionStatus?("FAILED: \(error.localizedDescription)")
                        }
                    } else {
                        self?.onConnectionStatus?("FAILED: \(error.localizedDescription)")
                    }
                } else {
                    // Success — save camera for auto-connect
                    self?.saveCamera(ssid: ssid, password: password)
                    self?.onConnectionStatus?("CONNECTED")
                }
            }
        }
    }
    
    // MARK: - Auto-connect to last used camera
    
    func autoConnect() {
        guard let lastSSID = UserDefaults.standard.string(forKey: lastUsedKey),
              let password = getPasswordFromKeychain(ssid: lastSSID) else {
            return
        }
        connectToNetwork(ssid: lastSSID, password: password)
    }
    
    // MARK: - Get current WiFi SSID
    
    func getCurrentSSID() -> String? {
        // Requires "Access WiFi Information" entitlement
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for interface in interfaces {
            guard let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any] else { continue }
            return info[kCNNetworkInfoKeySSID as String] as? String
        }
        return nil
    }
    
    // MARK: - Keychain Camera Storage
    
    func saveCamera(ssid: String, password: String) {
        // Save password to Keychain
        let passwordData = password.data(using: .utf8)!
        
        // Delete existing entry if any
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: ssid
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new entry
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: ssid,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        
        // Save to saved cameras list
        var cameras = getSavedCameraSSIDs()
        if !cameras.contains(ssid) {
            cameras.append(ssid)
            UserDefaults.standard.set(cameras, forKey: "savedCameraSSIDs")
        }
        
        // Set as last used
        UserDefaults.standard.set(ssid, forKey: lastUsedKey)
    }
    
    func getSavedCameras() -> [[String: String]] {
        let ssids = getSavedCameraSSIDs()
        let lastUsed = UserDefaults.standard.string(forKey: lastUsedKey) ?? ""
        
        return ssids.map { ssid in
            return [
                "ssid": ssid,
                "isLastUsed": ssid == lastUsed ? "true" : "false"
            ]
        }
    }
    
    func removeSavedCamera(ssid: String) {
        // Remove from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: ssid
        ]
        SecItemDelete(query as CFDictionary)
        
        // Remove from saved list
        var cameras = getSavedCameraSSIDs()
        cameras.removeAll { $0 == ssid }
        UserDefaults.standard.set(cameras, forKey: "savedCameraSSIDs")
        
        // Also remove the NEHotspotConfiguration
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
    }
    
    // MARK: - Private Helpers
    
    private func getSavedCameraSSIDs() -> [String] {
        return UserDefaults.standard.stringArray(forKey: "savedCameraSSIDs") ?? []
    }
    
    private func getPasswordFromKeychain(ssid: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: ssid,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
