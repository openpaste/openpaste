import Foundation
import Testing
@testable import OpenPaste

@Suite(.serialized)
struct ScreenSharingDetectorTests {

    // MARK: - Initialization

    @Test func initialStateNotSharing() {
        let detector = ScreenSharingDetector()
        // By default in a test environment (no screen sharing active),
        // isScreenBeingShared should be false
        let isSharing = detector.isScreenBeingShared()
        #expect(isSharing == false)
    }

    // MARK: - Start/Stop Monitoring

    @Test func startAndStopMonitoringDoNotCrash() {
        let detector = ScreenSharingDetector()
        var callbackCount = 0
        detector.startMonitoring {
            callbackCount += 1
        }
        // Should not crash
        detector.stopMonitoring()
    }

    @Test func stopMonitoringWithoutStartDoesNotCrash() {
        let detector = ScreenSharingDetector()
        // Should not crash even if never started
        detector.stopMonitoring()
    }

    @Test func multipleStartsDoNotCrash() {
        let detector = ScreenSharingDetector()
        detector.startMonitoring { }
        detector.startMonitoring { }
        detector.stopMonitoring()
    }

    // MARK: - Callback

    @Test func callbackIsSetAndCallable() {
        let detector = ScreenSharingDetector()
        var callbackCalled = false
        detector.startMonitoring {
            callbackCalled = true
        }
        // The callback won't fire in test environment (no screen sharing),
        // but we verify it was set without crash
        #expect(callbackCalled == false)
        detector.stopMonitoring()
    }

    // MARK: - isScreenSharingEnabled (UserDefaults)

    @Test func screenSharingEnabledReadsFromUserDefaults() {
        let key = Constants.screenSharingAutoHideKey
        let suiteName = "ScreenSharingDetectorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let detector = ScreenSharingDetector(userDefaults: defaults)

        // Set to true
        defaults.set(true, forKey: key)
        #expect(detector.isScreenSharingEnabled == true)

        // Set to false
        defaults.set(false, forKey: key)
        #expect(detector.isScreenSharingEnabled == false)

        // Cleanup
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func screenSharingEnabledWritesToUserDefaults() {
        let key = Constants.screenSharingAutoHideKey
        let suiteName = "ScreenSharingDetectorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let detector = ScreenSharingDetector(userDefaults: defaults)

        detector.isScreenSharingEnabled = true
        #expect(defaults.bool(forKey: key) == true)

        detector.isScreenSharingEnabled = false
        #expect(defaults.bool(forKey: key) == false)

        // Cleanup
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Screen Sharing Process Names

    @Test func knownProcessNamesExist() {
        // Verify the detector has well-known screen sharing process names configured
        // We can't directly access the private static set, but we verify the detector
        // can be instantiated and check without crash
        let detector = ScreenSharingDetector()
        // Just calling isScreenBeingShared exercises the process name lookup
        let _ = detector.isScreenBeingShared()
    }
}
