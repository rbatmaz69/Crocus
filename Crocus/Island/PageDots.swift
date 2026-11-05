import SwiftUI

/// Geometry of the page dot row, kept pure for tests. Dots sit 19 pt apart;
/// the row reaches half a hit target (14 pt) beyond the outer dots and is
/// 28 pt tall, and a click goes to the nearest dot – so every dot can be hit
/// without gaps, even though the dots are closer than 28 pt.
enum PageDotsLayout {
    typealias Metrics = CrocusMetrics.PageDots

    static func rowWidth(count: Int) -> CGFloat {
        CGFloat(max(count - 1, 0)) * Metrics.spacing + Metrics.hitSize
    }

    /// Centre of a dot, measured from the row's left edge.
    static func centerX(of index: Int) -> CGFloat {
        Metrics.hitSize / 2 + CGFloat(index) * Metrics.spacing
    }

    /// The dot nearest to `x` (row coordinates); clamps outside the row.
    static func index(at x: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let raw = ((x - Metrics.hitSize / 2) / Metrics.spacing).rounded()
        return min(max(Int(raw), 0), count - 1)
    }
}

/// Page dots under the expanded card stack: show and pick the current card.
struct PageDots: View {
    let index: Int
    let count: Int
    let onSelect: (Int) -> Void

    var body: some View {
        let metrics = CrocusMetrics.PageDots.self
        ZStack(alignment: .leading) {
            ForEach(0..<count, id: \.self) { dot in
                Circle()
                    .fill(dot == index ? CrocusColors.primary : CrocusColors.secondary.opacity(metrics.inactiveOpacity))
                    .frame(width: metrics.dotSize, height: metrics.dotSize)
                    .position(x: PageDotsLayout.centerX(of: dot), y: metrics.hitSize / 2)
            }
        }
        .frame(width: PageDotsLayout.rowWidth(count: count), height: metrics.hitSize)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            onSelect(PageDotsLayout.index(at: location.x, count: count))
        }
        .animation(.easeInOut(duration: 0.15), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity \(index + 1) of \(count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if index + 1 < count { onSelect(index + 1) }
            case .decrement: if index > 0 { onSelect(index - 1) }
            @unknown default: break
            }
        }
    }
}
