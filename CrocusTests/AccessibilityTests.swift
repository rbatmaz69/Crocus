import CoreGraphics
import Testing
@testable import Crocus

@Suite("Accessibility")
struct AccessibilityTests {
    @Test func increasedContrastLightensSecondaryText() {
        #expect(CrocusColors.secondaryToken(increasedContrast: false) == CrocusColors.Spec.secondary)
        #expect(CrocusColors.secondaryToken(increasedContrast: true).hex == 0xC7C7CC)
    }

    @Test func increasedContrastStrengthensTheProgressTrack() {
        #expect(CrocusColors.progressTrackOpacity(increasedContrast: false) == 0.20)
        #expect(CrocusColors.progressTrackOpacity(increasedContrast: true) == 0.35)
    }

    @Test func secondaryTextContrastAgainstBlack() {
        // Spec: #98989D on black 7.4:1; Increase Contrast must be higher.
        let normal = contrastOnBlack(CrocusColors.Spec.secondary)
        let increased = contrastOnBlack(CrocusColors.Spec.secondaryHighContrast)
        #expect(normal >= 7)
        #expect(increased > normal)
        #expect(contrastOnBlack(CrocusColors.Spec.primary) > 20.9)
    }

    @Test func hitTargetsAreAtLeast28Points() {
        #expect(CrocusMetrics.PageDots.hitSize >= 28)
        #expect(CrocusMetrics.Expanded.buttonHeight >= 28)
        #expect(IslandCircleButton.size >= 28)
    }

    @Test func everyKindHasASpokenTitle() {
        for kind in ActivityKind.allCases {
            #expect(!kind.title.isEmpty)
        }
    }

    private func contrastOnBlack(_ token: ColorToken) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear(token.red) + 0.7152 * linear(token.green) + 0.0722 * linear(token.blue)
        return (luminance + 0.05) / 0.05
    }
}
