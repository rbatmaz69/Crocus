import SwiftUI

/// Compact anatomy: symbol in the left wing (18 pt edge inset), value in the
/// right wing (16 pt edge inset) and nothing in the gap between (camera in
/// notch mode, same gap as the idle pill in pill mode).
struct CompactLayout<Leading: View, Trailing: View>: View {
    let metrics: IslandLayoutMetrics
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: metrics.leadingWingWidth - CrocusMetrics.Compact.leadingInset, alignment: .leading)
                .padding(.leading, CrocusMetrics.Compact.leadingInset)
            Color.clear
                .frame(width: metrics.gapWidth)
            trailing
                .frame(width: max(metrics.trailingWingWidth - CrocusMetrics.Compact.trailingInset, 0), alignment: .trailing)
                .padding(.trailing, CrocusMetrics.Compact.trailingInset)
        }
        .frame(maxHeight: .infinity)
    }
}
