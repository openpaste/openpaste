import Foundation
import Testing
@testable import OpenPaste

struct InstallMethodDetectorTests {
    @Test func detectsHomebrewFromCaskroomPath() {
        let bundleURL = URL(fileURLWithPath: "/opt/homebrew/Caskroom/openpaste/1.2.3/OpenPaste.app")

        #expect(InstallMethodDetector.detect(bundleURL: bundleURL) == .homebrew)
    }

    @Test func detectsBuildFromDerivedDataPath() {
        let bundleURL = URL(fileURLWithPath: "/Users/test/Library/Developer/Xcode/DerivedData/OpenPaste/Build/Products/Debug/OpenPaste.app")

        #expect(InstallMethodDetector.detect(bundleURL: bundleURL) == .buildFromSource)
    }

    @Test func detectsBuildFromGenericBuildPath() {
        let bundleURL = URL(fileURLWithPath: "/tmp/OpenPaste/build/Release/OpenPaste.app")

        #expect(InstallMethodDetector.detect(bundleURL: bundleURL) == .buildFromSource)
    }

    @Test func detectsDmgStyleApplicationsPath() {
        let bundleURL = URL(fileURLWithPath: "/Applications/OpenPaste.app")

        #expect(InstallMethodDetector.detect(bundleURL: bundleURL) == .dmg)
    }

    @Test func fallsBackToOtherForUnknownPath() {
        let bundleURL = URL(fileURLWithPath: "/Volumes/ExternalTools/OpenPaste.app")

        #expect(InstallMethodDetector.detect(bundleURL: bundleURL) == .other)
    }
}