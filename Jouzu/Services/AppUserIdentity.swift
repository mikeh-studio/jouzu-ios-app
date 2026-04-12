import Foundation

enum AppUserIdentity {
    private static let ownerIdKey = "jouzu.sync.owner-id"

    static func currentOwnerId(userDefaults: UserDefaults = .standard) -> String {
        if let existing = userDefaults.string(forKey: ownerIdKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }

        let ownerId = UUID().uuidString.lowercased()
        userDefaults.set(ownerId, forKey: ownerIdKey)
        return ownerId
    }
}
