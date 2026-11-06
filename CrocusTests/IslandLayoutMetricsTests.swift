import CoreGraphics
import Testing
@testable import Crocus

@Suite struct IslandLayoutMetricsTests {
    let notch = IslandLayoutMetrics.notch(notchSize: CGSize(width: 186, height: 37), rightWingReduced: false)
    let pill = IslandLayoutMetrics.pill

    @Test func pillGapEqualsIdlePill() {
        #expect(pill.gapWidth == CrocusMetrics.pill.idle.width)
        #expect(pill.gapWidth == 80)
    }

    @Test func compactWidthIsWingsPlusGap() {
        #expect(notch.compactWidth == 306)
        #expect(pill.compactWidth == 200)
        #expect(pill.compactWidth == CrocusMetrics.pill.compact.width)
    }

    @Test func wingsAreTheSameInBothModes() {
        // Same wings and insets → symbol and value sit at the same place
        // relative to the island's edges in both modes.
        #expect(notch.leadingWingWidth == pill.leadingWingWidth)
        #expect(notch.trailingWingWidth == pill.trailingWingWidth)
    }

    @Test func expandedAndHeader() {
        #expect(notch.expandedWidth == 460)
        #expect(pill.expandedWidth == 440)
        #expect(notch.headerHeight == 37)
        #expect(pill.headerHeight == 34)
        #expect(pill.headerGapWidth == 80)
        #expect(notch.headerGapWidth == 186)
    }

    @Test func reducedNotchWing() {
        let reduced = IslandLayoutMetrics.notch(notchSize: CGSize(width: 179, height: 32), rightWingReduced: true)
        #expect(reduced.trailingWingWidth == 44)
        #expect(reduced.compactWidth == 283) // 60 + 179 + 44
    }
}
