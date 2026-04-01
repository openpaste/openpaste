import Testing
import Foundation
import AppKit
@testable import OpenPaste

@Suite(.serialized)
@MainActor
struct OnboardingViewModelTests {

    // MARK: - Initial State

    @Test func initialStepIsWelcome() {
        let vm = OnboardingViewModel()
        #expect(vm.currentStep == .welcome)
        #expect(vm.stepIndex == 0)
        #expect(vm.isFirstStep == true)
        #expect(vm.isLastStep == false)
    }

    @Test func totalStepsIsFive() {
        let vm = OnboardingViewModel()
        #expect(vm.totalSteps == 5)
    }

    @Test func defaultHotkeyIsShiftCommandV() {
        // Clean UserDefaults for test
        UserDefaults.standard.removeObject(forKey: Constants.customHotkeyModifiersKey)
        UserDefaults.standard.removeObject(forKey: Constants.customHotkeyKeyCodeKey)
        UserDefaults.standard.synchronize()

        let vm = OnboardingViewModel()
        #expect(vm.hotkeyKeyCode == 0x09)
        #expect(vm.hotkeyModifiers == [.shift, .command])
        #expect(vm.hotkeyDisplayString == "⇧⌘V")
    }

    // MARK: - Navigation

    @Test func nextStepAdvances() {
        let vm = OnboardingViewModel()
        vm.nextStep()
        #expect(vm.currentStep == .permissions)
        #expect(vm.stepIndex == 1)
        #expect(vm.isFirstStep == false)
    }

    @Test func previousStepGoesBack() {
        let vm = OnboardingViewModel()
        vm.nextStep() // -> permissions
        vm.nextStep() // -> shortcut
        vm.previousStep() // -> permissions
        #expect(vm.currentStep == .permissions)
    }

    @Test func previousStepDoesNothingAtWelcome() {
        let vm = OnboardingViewModel()
        vm.previousStep()
        #expect(vm.currentStep == .welcome)
    }

    @Test func nextStepDoesNothingAtReady() {
        let vm = OnboardingViewModel()
        for _ in 0..<10 {
            vm.nextStep()
        }
        #expect(vm.currentStep == .ready)
        #expect(vm.isLastStep == true)
    }

    @Test func canNavigateThroughAllSteps() {
        let vm = OnboardingViewModel()
        let expectedSteps: [OnboardingStep] = [.welcome, .permissions, .shortcut, .preferences, .ready]
        for (i, expected) in expectedSteps.enumerated() {
            #expect(vm.currentStep == expected)
            if i < expectedSteps.count - 1 {
                vm.nextStep()
            }
        }
    }

    // MARK: - Can Proceed

    @Test func canProceedTrueForWelcome() {
        let vm = OnboardingViewModel()
        #expect(vm.canProceed == true)
    }

    @Test func canProceedTrueForPermissionsEvenWithoutGrant() {
        let vm = OnboardingViewModel()
        vm.nextStep() // permissions
        #expect(vm.canProceed == true)
    }

    // MARK: - Completion

    @Test func completeOnboardingSetsUserDefault() {
        let key = Constants.hasCompletedOnboardingKey
        UserDefaults.standard.removeObject(forKey: key)

        let vm = OnboardingViewModel()
        vm.completeOnboarding()
        #expect(UserDefaults.standard.bool(forKey: key) == true)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test func skipOnboardingSetsUserDefault() {
        let key = Constants.hasCompletedOnboardingKey
        UserDefaults.standard.removeObject(forKey: key)

        let vm = OnboardingViewModel()
        vm.skipOnboarding()
        #expect(UserDefaults.standard.bool(forKey: key) == true)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test func shouldShowOnboardingReflectsUserDefault() {
        let key = Constants.hasCompletedOnboardingKey
        UserDefaults.standard.removeObject(forKey: key)
        #expect(OnboardingViewModel.shouldShowOnboarding == true)

        UserDefaults.standard.set(true, forKey: key)
        #expect(OnboardingViewModel.shouldShowOnboarding == false)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Hotkey Persistence

    @Test func completeOnboardingSavesHotkey() {
        let modsKey = Constants.customHotkeyModifiersKey
        let keyCodeKey = Constants.customHotkeyKeyCodeKey
        let onboardingKey = Constants.hasCompletedOnboardingKey
        UserDefaults.standard.removeObject(forKey: modsKey)
        UserDefaults.standard.removeObject(forKey: keyCodeKey)
        UserDefaults.standard.removeObject(forKey: onboardingKey)
        UserDefaults.standard.synchronize()

        let vm = OnboardingViewModel()
        vm.hotkeyKeyCode = 0x08 // C key
        vm.hotkeyModifiers = [.command, .option]
        vm.completeOnboarding()
        UserDefaults.standard.synchronize()

        #expect(UserDefaults.standard.integer(forKey: keyCodeKey) == 0x08)
        #expect(UserDefaults.standard.integer(forKey: modsKey) != 0)
        #expect(UserDefaults.standard.bool(forKey: onboardingKey) == true)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: modsKey)
        UserDefaults.standard.removeObject(forKey: keyCodeKey)
        UserDefaults.standard.removeObject(forKey: onboardingKey)
        UserDefaults.standard.synchronize()
    }

    @Test func loadsSavedHotkey() {
        let modsKey = Constants.customHotkeyModifiersKey
        let keyCodeKey = Constants.customHotkeyKeyCodeKey
        UserDefaults.standard.set(Int(NSEvent.ModifierFlags.command.rawValue), forKey: modsKey)
        UserDefaults.standard.set(0x0C, forKey: keyCodeKey) // Q key
        UserDefaults.standard.synchronize()

        let vm = OnboardingViewModel()
        #expect(vm.hotkeyKeyCode == 0x0C)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: modsKey)
        UserDefaults.standard.removeObject(forKey: keyCodeKey)
        UserDefaults.standard.synchronize()
    }

    // MARK: - HotkeyManager Integration

    @Test func hotkeyManagerLoadsCustomHotkey() {
        let modsKey = Constants.customHotkeyModifiersKey
        let keyCodeKey = Constants.customHotkeyKeyCodeKey
        UserDefaults.standard.set(Int(NSEvent.ModifierFlags([.command, .shift]).rawValue), forKey: modsKey)
        UserDefaults.standard.set(0x09, forKey: keyCodeKey) // V key
        UserDefaults.standard.synchronize()

        let (mods, keyCode) = HotkeyManager.loadCustomHotkey()
        #expect(keyCode == 0x09)
        #expect(mods.contains(.command))
        #expect(mods.contains(.shift))

        // Cleanup
        UserDefaults.standard.removeObject(forKey: modsKey)
        UserDefaults.standard.removeObject(forKey: keyCodeKey)
        UserDefaults.standard.synchronize()
    }

    @Test func hotkeyManagerDefaultsToShiftCommandV() {
        UserDefaults.standard.removeObject(forKey: Constants.customHotkeyModifiersKey)
        UserDefaults.standard.removeObject(forKey: Constants.customHotkeyKeyCodeKey)
        UserDefaults.standard.synchronize()

        let (mods, keyCode) = HotkeyManager.loadCustomHotkey()
        #expect(keyCode == 0x09)
        #expect(mods == [.shift, .command])
    }

    // MARK: - OnboardingStep Enum

    @Test func onboardingStepRawValues() {
        #expect(OnboardingStep.welcome.rawValue == 0)
        #expect(OnboardingStep.permissions.rawValue == 1)
        #expect(OnboardingStep.shortcut.rawValue == 2)
        #expect(OnboardingStep.preferences.rawValue == 3)
        #expect(OnboardingStep.ready.rawValue == 4)
    }

    // MARK: - Recording

    @Test func isRecordingHotkeyDefaultsFalse() {
        let vm = OnboardingViewModel()
        #expect(vm.isRecordingHotkey == false)
    }

    @Test func toggleRecording() {
        let vm = OnboardingViewModel()
        vm.isRecordingHotkey = true
        #expect(vm.isRecordingHotkey == true)
        vm.isRecordingHotkey = false
        #expect(vm.isRecordingHotkey == false)
    }
}
