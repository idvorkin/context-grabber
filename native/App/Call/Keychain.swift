//  The gist token in the iOS Keychain: readable by this app only, on this device, after the phone's first unlock —
//  so an upload at the end of a locked-screen call still works (gist upload spec, "The token, once").

import Foundation
import Security

enum Keychain {
  private static let service = "com.idvorkin.grabbernative"

  static func get(_ account: String) -> String? {
    var query = base(account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    let value = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  /// Empty or whitespace forgets it. Throws with the Keychain's status.
  static func set(_ account: String, _ value: String) throws {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    SecItemDelete(base(account) as CFDictionary)
    guard !trimmed.isEmpty else { return }
    var item = base(account)
    item[kSecValueData as String] = Data(trimmed.utf8)
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError(status: status) }
  }

  private static func base(_ account: String) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
  }
}

struct KeychainError: Error, LocalizedError {
  let status: OSStatus
  var errorDescription: String? {
    "the Keychain said \(status): \(SecCopyErrorMessageString(status, nil) as String? ?? "unknown")"
  }
}
