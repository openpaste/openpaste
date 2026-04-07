import Testing

@testable import OpenPaste

struct AccessibilityCheckerTests {
    @Test func isGrantedReturnsTrueInTestEnvironment() {
        // In test environment, isGranted should return true
        // (isAutomationTestEnvironment detects XCTestConfigurationFilePath)
        #expect(AccessibilityChecker.isGranted)
    }

    @Test func isAccessibilityFunctionalReturnsTrueInTestEnvironment() {
        #expect(AccessibilityChecker.isAccessibilityFunctional())
    }
}
