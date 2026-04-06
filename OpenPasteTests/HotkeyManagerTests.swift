import AppKit
import CoreGraphics
import Testing

@testable import OpenPaste

@Suite(.serialized)
struct HotkeyManagerTests {
    @Test func shiftCommandVMatchesConfiguredHotkey() {
        let matches = HotkeyManager.hotkeyMatches(
            modifiers: [.shift, .command],
            keyCode: 0x09,
            eventFlags: [.maskShift, .maskCommand],
            eventKeyCode: 0x09
        )

        #expect(matches)
    }

    @Test func plainCommandVDoesNotMatchShiftCommandV() {
        let matches = HotkeyManager.hotkeyMatches(
            modifiers: [.shift, .command],
            keyCode: 0x09,
            eventFlags: [.maskCommand],
            eventKeyCode: 0x09
        )

        #expect(matches == false)
    }

    @Test func autorepeatDoesNotMatchHotkey() {
        let matches = HotkeyManager.hotkeyMatches(
            modifiers: [.shift, .command],
            keyCode: 0x09,
            eventFlags: [.maskShift, .maskCommand],
            eventKeyCode: 0x09,
            isAutoRepeat: true
        )

        #expect(matches == false)
    }

    @Test func recordingSuspensionDisablesInterception() {
        let token = UUID()
        HotkeyManager.setHotkeyRecordingSuspended(true, token: token)
        defer { HotkeyManager.setHotkeyRecordingSuspended(false, token: token) }

        let matches = HotkeyManager.shouldInterceptHotkey(
            modifiers: [.shift, .command],
            keyCode: 0x09,
            eventFlags: [.maskShift, .maskCommand],
            eventKeyCode: 0x09
        )

        #expect(matches == false)
    }

    @Test func multipleRecordingTokensRequireFullRelease() {
        let firstToken = UUID()
        let secondToken = UUID()

        HotkeyManager.setHotkeyRecordingSuspended(true, token: firstToken)
        HotkeyManager.setHotkeyRecordingSuspended(true, token: secondToken)
        HotkeyManager.setHotkeyRecordingSuspended(false, token: firstToken)
        defer { HotkeyManager.setHotkeyRecordingSuspended(false, token: secondToken) }

        let matches = HotkeyManager.shouldInterceptHotkey(
            modifiers: [.shift, .command],
            keyCode: 0x09,
            eventFlags: [.maskShift, .maskCommand],
            eventKeyCode: 0x09
        )

        #expect(matches == false)
    }

    @Test func loadCustomHotkeySupportsAKeyCode() {
        defer {
            UserDefaults.standard.removeObject(forKey: Constants.customHotkeyModifiersKey)
            UserDefaults.standard.removeObject(forKey: Constants.customHotkeyKeyCodeKey)
            UserDefaults.standard.synchronize()
        }

        HotkeyManager.saveHotkey(modifiers: [.command], keyCode: 0x00)
        let (modifiers, keyCode) = HotkeyManager.loadCustomHotkey()

        #expect(modifiers == [.command])
        #expect(keyCode == 0x00)
    }

    @Test func saveHotkeyNormalizesIrrelevantModifiers() {
        defer {
            UserDefaults.standard.removeObject(forKey: Constants.customHotkeyModifiersKey)
            UserDefaults.standard.removeObject(forKey: Constants.customHotkeyKeyCodeKey)
            UserDefaults.standard.synchronize()
        }

        HotkeyManager.saveHotkey(modifiers: [.shift, .command, .capsLock], keyCode: 0x09)
        let (modifiers, keyCode) = HotkeyManager.loadCustomHotkey()

        #expect(keyCode == 0x09)
        #expect(modifiers == [.shift, .command])
    }
}
