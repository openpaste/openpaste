import AppKit
import Foundation
import Testing

@testable import OpenPaste

struct BottomShelfPanelDragSessionTests {
    @Test @MainActor func resignKey_doesNotRequestCloseDuringActiveDrag() {
        let panel = makePanel()
        var closeRequestCount = 0
        panel.onRequestClose = { closeRequestCount += 1 }

        panel.beginDragSession()
        panel.resignKey()

        #expect(panel.isDragSessionActive)
        #expect(closeRequestCount == 0)
    }

    @Test @MainActor func endDragSession_postsNotificationAndAllowsSubsequentClose() {
        let panel = makePanel()
        var closeRequestCount = 0
        var didReceiveNotification = false
        panel.onRequestClose = { closeRequestCount += 1 }

        let token = NotificationCenter.default.addObserver(
            forName: BottomShelfPanel.dragSessionDidEndNotification,
            object: panel,
            queue: nil
        ) { _ in
            didReceiveNotification = true
        }
        defer { NotificationCenter.default.removeObserver(token) }

        panel.beginDragSession()
        panel.endDragSession(closeIfNeeded: false)
        panel.resignKey()

        #expect(!panel.isDragSessionActive)
        #expect(didReceiveNotification)
        #expect(closeRequestCount == 1)
    }

    @MainActor
    private func makePanel() -> BottomShelfPanel {
        let hostView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 120))
        return BottomShelfPanel(contentView: hostView, frame: hostView.frame)
    }
}
