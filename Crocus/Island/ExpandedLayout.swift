import SwiftUI

/// Expanded anatomy: a header split left and right of the camera (source /
/// status), then the content with 22 pt inset and 14 pt row spacing. Reports
/// its natural height so the island can follow the content.
struct ExpandedLayout<Source: View, Status: View, Content: View>: View {
    let notchSize: CGSize
    var onHeightChange: (CGFloat) -> Void
    @ViewBuilder var source: Source
    @ViewBuilder var status: Status
    @ViewBuilder var content: Content

    var body: some View {
        let inset = CrocusMetrics.Expanded.contentInset
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                source.frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: notchSize.width)
                status.frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 11))
            .foregroundStyle(CrocusColors.secondary)
            .lineLimit(1)
            .frame(height: notchSize.height)

            VStack(alignment: .leading, spacing: CrocusMetrics.Expanded.rowSpacing) {
                content
            }
            .padding(.top, CrocusMetrics.Expanded.rowSpacing / 2)
            .padding(.bottom, inset)
        }
        .padding(.horizontal, inset)
        .frame(width: CrocusMetrics.notch.expanded.width)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
    }
}
