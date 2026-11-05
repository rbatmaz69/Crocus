import SwiftUI

/// Stand-in for the island until the real shapes land (#5 notch, #6 pill):
/// a black idle shape at the top centre of the panel. On a notch display it
/// covers the notch and is invisible; on other displays it shows as a pill.
struct IslandPlaceholderView: View {
    let model: OverlayPanelModel

    var body: some View {
        let geometry = model.geometry
        let isNotch = geometry.mode == .notch
        let island = geometry.idleIslandRect
        let cornerRadius = geometry.metrics.idle.cornerRadius
        let topOffset = isNotch ? 0 : geometry.metrics.topOffset

        ZStack(alignment: .top) {
            if model.showsDebugFrame {
                Rectangle()
                    .fill(Color.red.opacity(0.06))
                    .strokeBorder(Color.red.opacity(0.6), lineWidth: 1)
            }

            shape(cornerRadius: cornerRadius, hasNotch: isNotch)
                .fill(CrocusColors.island)
                .frame(width: island.width, height: island.height)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    model.islandFrameInWindow = frame
                }
                .padding(.top, topOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .islandEnvironment()
        .accessibilityHidden(true)
    }

    private func shape(cornerRadius: CGFloat, hasNotch: Bool) -> UnevenRoundedRectangle {
        // The notch hangs from the top edge: only the bottom corners are round.
        let top: CGFloat = hasNotch ? 0 : cornerRadius
        return UnevenRoundedRectangle(
            topLeadingRadius: top,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: top,
            style: .continuous
        )
    }
}
