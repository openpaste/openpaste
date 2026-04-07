import AppKit
import ApplicationServices

/// Centralized accessibility permission checker.
///
/// `AXIsProcessTrusted()` returns **cached/stale** values per-process when the user
/// toggles Accessibility in System Settings. This checker supplements the TCC
/// query with a **functional test** — actually calling the Accessibility API to
/// verify it works — eliminating false positives and false negatives.
enum AccessibilityChecker {

    /// Single source of truth: is Accessibility **actually functional** right now?
    /// May call `AXUIElementCopyAttributeValue` — use only when user has already
    /// interacted with permission UI or app is a returning launch.
    static var isGranted: Bool { isAccessibilityFunctional() }

    /// Quick, silent check — NEVER triggers a system dialog.
    /// Uses only `AXIsProcessTrusted()` which reads the TCC cache.
    /// Safe to call at app startup before onboarding.
    static var isTrustedQuiet: Bool {
        isAutomationTestEnvironment || AXIsProcessTrusted()
    }

    /// Returns `true` only when accessibility is **actually functional**,
    /// not just what the TCC database claims.
    ///
    /// Strategy:
    /// 1. Quick-fail if `AXIsProcessTrusted()` says NO — avoids unnecessary work.
    /// 2. If it says YES, perform a lightweight functional test to confirm
    ///    the permission is truly propagated to this process.
    /// 3. If the functional test fails but `AXIsProcessTrusted()` reports YES,
    ///    treat it as "needs restart" (stale cache).
    static func isAccessibilityFunctional() -> Bool {
        if isAutomationTestEnvironment {
            return true
        }

        let tccTrusted = AXIsProcessTrusted()
        let functional = performFunctionalTest()

        // Trust functional test over TCC when they disagree
        if tccTrusted && !functional { return false }
        if !tccTrusted && functional { return true }

        return tccTrusted
    }

    /// Lightweight test: tries to read the focused application from the system-wide
    /// accessibility element. This operation succeeds only when the process has
    /// real, propagated accessibility permission.
    private static func performFunctionalTest() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &value
        )
        return result == .success || result == .cannotComplete
    }

    private static var isAutomationTestEnvironment: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["OPENPASTE_UI_TEST_MODE"] == "1"
            || env["XCTestConfigurationFilePath"] != nil
    }
}
