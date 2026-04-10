import Foundation
import Security

/// Keychain errors
public enum KeychainError: Error, Sendable {
    case invalidData
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case conversionFailed
}

/// Secure keychain storage for sensitive tokens and credentials
public final class Keychain: Sendable {
    private let service: String
    
    public init(service: String = "com.senor.platform") {
        self.service = service
    }
    
    /// Save data to keychain
    public func save(data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Save string to keychain
    public func save(string: String, account: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(data: data, account: account)
    }
    
    /// Retrieve data from keychain
    public func retrieveData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    /// Retrieve string from keychain
    public func retrieveString(account: String) -> String? {
        guard let data = retrieveData(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Delete item from keychain
    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Check if item exists
    public func exists(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Predefined Keychain Keys

public extension Keychain {
    enum Key: String {
        case deviantArtAccessToken = "deviantart_access_token"
        case deviantArtRefreshToken = "deviantart_refresh_token"
        case patreonAccessToken = "patreon_access_token"
        case patreonCreatorToken = "patreon_creator_token"
    }
    
    func save(string: String, key: Key) throws {
        try save(string: string, account: key.rawValue)
    }
    
    func retrieveString(key: Key) -> String? {
        return retrieveString(account: key.rawValue)
    }
    
    func delete(key: Key) throws {
        try delete(account: key.rawValue)
    }
}
