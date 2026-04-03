import Foundation
import CoreGraphics
import AppKit

final class ScreenSharingDetector: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private var pollTimer: Timer?
    private var onScreenSharingDetected: (() -> Void)?
    private var wasSharing = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    private static let screenSharingProcessNames: Set<String> = [
        "screensharingd", "ScreensharingAgent",
        "zoom.us", "CptHost",            // Zoom
        "Google Meet",
        "Cisco Webex", "webexmta",
        "Microsoft Teams", "MSTeams",
        "Discord", "Slack",
        "OBS", "obs", "obs-browser-page",
        "ScreenFlick", "screenflick",
    ]
    
    var isScreenSharingEnabled: Bool {
        get { userDefaults.bool(forKey: Constants.screenSharingAutoHideKey) }
        set { userDefaults.set(newValue, forKey: Constants.screenSharingAutoHideKey) }
    }
    
    func startMonitoring(onDetected: @escaping () -> Void) {
        pollTimer?.invalidate()
        onScreenSharingDetected = onDetected
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkScreenSharing()
        }
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    func isScreenBeingShared() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }
        
        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String else { continue }
            
            if Self.screenSharingProcessNames.contains(ownerName) {
                if let sharingState = window[kCGWindowSharingState as String] as? Int32, sharingState != 0 {
                    return true
                }
            }
        }
        
        return checkForScreenRecording()
    }
    
    private func checkForScreenRecording() -> Bool {
        // Check if any display is being mirrored (common during screen sharing)
        let maxDisplays: UInt32 = 16
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(maxDisplays, &displays, &displayCount)
        
        for i in 0..<Int(displayCount) {
            if CGDisplayIsInMirrorSet(displays[i]) != 0 {
                return true
            }
        }
        return false
    }
    
    private func checkScreenSharing() {
        guard isScreenSharingEnabled else { return }
        
        let isSharing = isScreenBeingShared()
        if isSharing && !wasSharing {
            onScreenSharingDetected?()
        }
        wasSharing = isSharing
    }
}
