import XCTest

@testable import OpenPaste

final class ClipboardCardTests: XCTestCase {
    func testShouldRevealQuickIndexBadge_WhenHovered_ReturnsTrue() {
        XCTAssertTrue(
            ClipboardCard.shouldRevealQuickIndexBadge(
                isHovered: true,
                revealQuickIndexBadge: false
            )
        )
    }

    func testShouldRevealQuickIndexBadge_WhenCommandPressed_ReturnsTrue() {
        XCTAssertTrue(
            ClipboardCard.shouldRevealQuickIndexBadge(
                isHovered: false,
                revealQuickIndexBadge: true
            )
        )
    }

    func testShouldRevealQuickIndexBadge_WhenInactive_ReturnsFalse() {
        XCTAssertFalse(
            ClipboardCard.shouldRevealQuickIndexBadge(
                isHovered: false,
                revealQuickIndexBadge: false
            )
        )
    }

    func testSupportsQuickIndexBadge_OnlyForFirstNineSlots() {
        XCTAssertTrue(ClipboardCard.supportsQuickIndexBadge(index: 0))
        XCTAssertTrue(ClipboardCard.supportsQuickIndexBadge(index: 8))
        XCTAssertFalse(ClipboardCard.supportsQuickIndexBadge(index: 9))
        XCTAssertFalse(ClipboardCard.supportsQuickIndexBadge(index: nil))
        XCTAssertFalse(ClipboardCard.supportsQuickIndexBadge(index: -1))
    }
}
