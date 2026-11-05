import SwiftUI

/// Compact anatomy: symbol in the left wing (18 pt edge inset), value in the
/// right wing (16 pt edge inset) and nothing in the camera area between.
struct CompactLayout<Leading: View, Trailing: View>: View {
    let notchWidth: CGFloat
    let rightWingWidth: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let wing = CrocusMetrics.notch.wingWidth
        HStack(spacing: 0) {
            leading
                .frame(width: wing - CrocusMetrics.Compact.leadingInset, alignment: .leading)
                .padding(.leading, CrocusMetrics.Compact.leadingInset)
            Color.clear
                .frame(width: notchWidth)
            trailing
                .frame(width: max(rightWingWidth - CrocusMetrics.Compact.trailingInset, 0), alignment: .trailing)
                .padding(.trailing, CrocusMetrics.Compact.trailingInset)
        }
        .frame(maxHeight: .infinity)
    }
}
