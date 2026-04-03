import Foundation

struct PremiumService: PremiumServiceProtocol {
    // Placeholder until real licensing exists.
    // Debug builds default to premium to enable development/testing.
    var isPremium: Bool {
        #if DEBUG
        return UserDefaults.standard.object(forKey: "premiumUnlocked") as? Bool ?? true
        #else
        return UserDefaults.standard.bool(forKey: "premiumUnlocked")
        #endif
    }
}
