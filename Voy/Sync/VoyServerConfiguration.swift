import Foundation
import Security

@MainActor
enum VoyServerConfiguration {
    private static let serverURLKey = "voyServerURL"
    private static let deviceIDKey = "voyServerDeviceID"
    private static let lastFingerprintKey = "voyServerLastFingerprint"
    private static let lastSyncDateKey = "voyServerLastSyncDate"
    private static let pendingFingerprintKey = "voyServerPendingFingerprint"
    private static let pendingSnapshotIDKey = "voyServerPendingSnapshotID"

    static var serverURLString: String {
        get { UserDefaults.standard.string(forKey: serverURLKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: serverURLKey) }
    }

    static var serverURL: URL? {
        URL(string: serverURLString)
    }

    static var deviceID: UUID {
        if let stored = UserDefaults.standard.string(forKey: deviceIDKey), let id = UUID(uuidString: stored) {
            return id
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: deviceIDKey)
        return id
    }

    static var lastFingerprint: String? {
        get { UserDefaults.standard.string(forKey: lastFingerprintKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastFingerprintKey) }
    }

    static var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncDateKey) }
    }

    static var pendingFingerprint: String? {
        get { UserDefaults.standard.string(forKey: pendingFingerprintKey) }
        set { UserDefaults.standard.set(newValue, forKey: pendingFingerprintKey) }
    }

    static var pendingSnapshotID: UUID? {
        get { UserDefaults.standard.string(forKey: pendingSnapshotIDKey).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: pendingSnapshotIDKey) }
    }

    static func disable() throws {
        serverURLString = ""
        lastFingerprint = nil
        lastSyncDate = nil
        pendingFingerprint = nil
        pendingSnapshotID = nil
        try VoyServerCredentials.setToken("")
    }
}

@MainActor
enum VoyServerCredentials {
    enum CredentialError: LocalizedError {
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case let .keychain(status):
                return SecCopyErrorMessageString(status, nil) as String? ?? "The token could not be stored securely."
            }
        }
    }

    private static let service = "com.yannickherrero.voy.server"
    private static let account = "mirror-token"

    static func token() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialError.keychain(status) }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func setToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let status = SecItemDelete(baseQuery as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw CredentialError.keychain(status)
            }
            return
        }

        let data = Data(trimmed.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw CredentialError.keychain(updateStatus) }

        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw CredentialError.keychain(addStatus) }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
