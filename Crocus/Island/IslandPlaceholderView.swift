import SwiftUI

/// Stand-in for the pill-mode island until its real shape lands (#6):
/// a black idle pill at the top centre of the panel. (Notch mode uses
/// `NotchIslandView`.)
struct IslandPlaceholderView: View {
    let model: OverlayPanelModel

    var body: some View {
        let geometry = model.geometry
        let isNotch = geometry.mode == .notch
        let island = geometry.idleIslandRect
        let cornerRadius = geometry.metrics.idle.cornerRadius
        let topOffset = isNotch ? 0 : geometry.metrics.topOffset

        ZStack(alignment: .top) {
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
