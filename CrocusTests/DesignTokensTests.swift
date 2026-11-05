import CoreGraphics
import Testing
@testable import Crocus

@Suite("Design tokens match the spec")
struct DesignTokensTests {
    @Test func colorHexValues() {
        #expect(CrocusColors.Spec.island.hex == 0x000000)
        #expect(CrocusColors.Spec.primary.hex == 0xFFFFFF)
        #expect(CrocusColors.Spec.secondary.hex == 0x98989D)
        #expect(CrocusColors.Spec.secondaryHighContrast.hex == 0xC7C7CC)
        #expect(CrocusColors.Spec.surface.hex == 0x2C2C2E)
        #expect(CrocusColors.Spec.progress.hex == 0x0A84FF)
        #expect(CrocusColors.Spec.positive.hex == 0x30D158)
        #expect(CrocusColors.Spec.microphone.hex == 0xFF9F0A)
        #expect(CrocusColors.Spec.lowBattery.hex == 0xFF453A)
    }

    @Test func colorTokenComponents() {
        let token = ColorToken(hex: 0x0A84FF)
        #expect(token.red == 10.0 / 255)
        #expect(token.green == 132.0 / 255)
        #expect(token.blue == 1.0)
    }

    @Test func springs() {
        #expect(CrocusSprings.idleToCompact == SpringSpec(response: 0.40, dampingFraction: 0.80))
        #expect(CrocusSprings.expand == SpringSpec(response: 0.42, dampingFraction: 0.72))
        #expect(CrocusSprings.collapse == SpringSpec(response: 0.35, dampingFraction: 1.00))
        #expect(CrocusSprings.dropDetach == SpringSpec(response: 0.35, dampingFraction: 0.70))
        #expect(CrocusSprings.cardSwipe == SpringSpec(response: 0.30, dampingFraction: 0.86))
        #expect(CrocusSprings.screenChange == SpringSpec(response: 0.55, dampingFraction: 0.82))
        #expect(CrocusSprings.hoverHint == SpringSpec(response: 0.30, dampingFraction: 0.90))
        #expect(CrocusSprings.hoverScale == 1.03)
    }

    @Test func typeStyles() {
        #expect(CrocusTypography.display == TypeStyle(size: 44, weight: .light, monospacedDigits: true))
        #expect(CrocusTypography.value == TypeStyle(size: 22, weight: .semibold, monospacedDigits: true))
        #expect(CrocusTypography.title == TypeStyle(size: 15, weight: .semibold, monospacedDigits: false))
        #expect(CrocusTypography.status == TypeStyle(size: 13, weight: .regular, monospacedDigits: false))
        #expect(CrocusTypography.caption == TypeStyle(size: 11, weight: .regular, monospacedDigits: true))
    }

    @Test func textSizeAdjustment() {
        #expect(CrocusTypography.title.size(for: .compact) == 14)
        #expect(CrocusTypography.title.size(for: .standard) == 15)
        #expect(CrocusTypography.title.size(for: .large) == 17)
        // Compact island text never goes below 13 pt.
        #expect(CrocusTypography.status.size(for: .compact, inCompactIsland: true) == 13)
        #expect(CrocusTypography.caption.size(for: .standard, inCompactIsland: true) == 13)
        #expect(CrocusTypography.caption.size(for: .compact) == 10)
    }

    @Test(arguments: [CrocusMetrics.notch, CrocusMetrics.pill])
    func compactWidthIsWingsPlusGap(_ metrics: IslandModeMetrics) {
        let wingsAndGap: CGFloat = metrics.wingWidth + metrics.wingWidth + metrics.gapWidth
        #expect(metrics.compact.width == wingsAndGap)
        #expect(metrics.gapWidth == metrics.idle.width)
    }

    @Test func notchMetrics() {
        let m = CrocusMetrics.notch
        #expect(m.topOffset == 0)
        #expect(m.idle == IslandShapeSpec(width: 186, height: 37, cornerRadius: 10))
        #expect(m.compact == IslandShapeSpec(width: 306, height: 40, cornerRadius: 14))
        #expect(m.expanded == ExpandedShapeSpec(width: 460, minHeight: 150, maxHeight: 260, cornerRadius: 32))
        #expect(m.minimalDiameter == 40)
        #expect(m.headerHeight == 37)
        #expect(m.shoulderRadius == 10)
        #expect(m.shadows.isEmpty)
    }

    @Test func pillMetrics() {
        let m = CrocusMetrics.pill
        #expect(m.topOffset == 6)
        #expect(m.idle == IslandShapeSpec(width: 96, height: 20, cornerRadius: 10))
        #expect(m.compact == IslandShapeSpec(width: 216, height: 30, cornerRadius: 15))
        #expect(m.expanded == ExpandedShapeSpec(width: 440, minHeight: 150, maxHeight: 260, cornerRadius: 30))
        #expect(m.minimalDiameter == 30)
        #expect(m.headerHeight == 34)
        #expect(m.shoulderRadius == nil)
        #expect(m.shadows == [ShadowSpec(y: 8, blur: 24, opacity: 0.28), ShadowSpec(y: 1, blur: 3, opacity: 0.20)])
    }
}
