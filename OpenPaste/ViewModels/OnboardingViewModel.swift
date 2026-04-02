import Foundation
import AppKit
import ServiceManagement

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case permissions
    case shortcut
    case preferences
    case ready
}

@MainActor @Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var accessibilityGranted: Bool = false
    var launchAtLogin: Bool = true

    // Hotkey configuration
    var hotkeyModifiers: NSEvent.ModifierFlags = [.shift, .command]
    var hotkeyKeyCode: UInt16 = 0x09 // V key
    var hotkeyDisplayString: String = "⇧⌘V"
    var isRecordingHotkey: Bool = false

    private var permissionTimer: Timer?
    private var accessibilityObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?

    var stepIndex: Int { currentStep.rawValue }
    var totalSteps: Int { OnboardingStep.allCases.count }
    var isFirstStep: Bool { currentStep == .welcome }
    var isLastStep: Bool { currentStep == .ready }

    var canProceed: Bool {
        switch currentStep {
        case .welcome, .preferences, .ready:
            return true
        case .permissions:
            return true // allow skip even without permission
        case .shortcut:
            return hotkeyKeyCode != 0
        }
    }

    init() {
        accessibilityGranted = AXIsProcessTrusted()
        loadSavedHotkey()
    }

    func nextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
        if currentStep == .permissions {
            startPermissionPolling()
        }
    }

    func previousStep() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    func completeOnboarding() {
        stopPermissionPolling()
        saveHotkey()
        applyLaunchAtLogin()
        UserDefaults.standard.set(true, forKey: Constants.hasCompletedOnboardingKey)
    }

    func skipOnboarding() {
        stopPermissionPolling()
        UserDefaults.standard.set(true, forKey: Constants.hasCompletedOnboardingKey)
    }

    // MARK: - Permissions

    func openAccessibilitySettings() {
        // Register this binary in the TCC database with its current code signature
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        // If the system prompt was suppressed (already prompted once), open Settings directly
        if !trusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func checkAccessibilityPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func startPermissionPolling() {
        stopPermissionPolling()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAccessibilityPermission()
            }
        }

        // Instantly re-check when user toggles any Accessibility permission
        accessibilityObserver = DistributedNotificationCenter.default()
            .addObserver(forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.checkAccessibilityPermission()
                }
            }

        // Re-check when user returns to the app from System Settings
        activationObserver = NotificationCenter.default
            .addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.checkAccessibilityPermission()
            }
    }

    func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        if let observer = accessibilityObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            accessibilityObserver = nil
        }
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
            activationObserver = nil
        }
    }

    // MARK: - Hotkey

    func recordHotkey(event: NSEvent) {
        guard isRecordingHotkey else { return }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods.contains(.command) || mods.contains(.control) else { return }

        hotkeyKeyCode = event.keyCode
        hotkeyModifiers = mods
        hotkeyDisplayString = formatHotkey(modifiers: mods, keyCode: event.keyCode)
        isRecordingHotkey = false
    }

    private func formatHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    private func keyName(for keyCode: UInt16) -> String {
        let keyNames: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0A: "§", 0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E",
            0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2",
            0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
            0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0",
            0x1E: "]", 0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I",
            0x23: "P", 0x24: "↩", 0x25: "L", 0x26: "J", 0x27: "'",
            0x28: "K", 0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/",
            0x2D: "N", 0x2E: "M", 0x2F: ".",
            0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x35: "⎋",
        ]
        return keyNames[keyCode] ?? "Key\(keyCode)"
    }

    private func saveHotkey() {
        UserDefaults.standard.set(Int(hotkeyModifiers.rawValue), forKey: Constants.customHotkeyModifiersKey)
        UserDefaults.standard.set(Int(hotkeyKeyCode), forKey: Constants.customHotkeyKeyCodeKey)
    }

    private func loadSavedHotkey() {
        let savedMods = UserDefaults.standard.integer(forKey: Constants.customHotkeyModifiersKey)
        let savedKey = UserDefaults.standard.integer(forKey: Constants.customHotkeyKeyCodeKey)
        if savedMods != 0 && savedKey != 0 {
            hotkeyModifiers = NSEvent.ModifierFlags(rawValue: UInt(savedMods))
            hotkeyKeyCode = UInt16(savedKey)
            hotkeyDisplayString = formatHotkey(modifiers: hotkeyModifiers, keyCode: hotkeyKeyCode)
        }
    }

    // MARK: - Preferences

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login failed: \(error)")
        }
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
    }

    nonisolated static var shouldShowOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: Constants.hasCompletedOnboardingKey)
    }
}
