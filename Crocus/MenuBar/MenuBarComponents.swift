import SwiftUI

/// Building blocks of the menu bar panel (#61, board G). Unlike the island
/// they follow the system appearance: light and dark, Increase Contrast.
enum MenuBarMetrics {
    static let panelWidth: CGFloat = 300
    static let padding: CGFloat = 10
    static let groupRadius: CGFloat = 11
    static let rowHeight: CGFloat = 44
    static let footerRowHeight: CGFloat = 28
    static let tileSize: CGFloat = 26
    /// Every control is at least this big (also the round buttons).
    static let hitSize: CGFloat = 28
}

/// The coloured square in front of a row.
struct MenuBarTile: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(tint.gradient)
            .frame(width: MenuBarMetrics.tileSize, height: MenuBarMetrics.tileSize)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// Round 28 pt control, e.g. pause or stop.
struct MenuBarRoundButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .frame(width: MenuBarMetrics.hitSize, height: MenuBarMetrics.hitSize)
                .background(Circle().fill(.quaternary))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Small capsule button; the prominent one is filled with the accent colour.
struct MenuBarPillButton: View {
    let title: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 11)
                .frame(minHeight: MenuBarMetrics.hitSize)
                .background(Capsule().fill(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// "40 %" over a short bar.
struct MenuBarProgress: View {
    let value: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(DownloadsFormat.percent(value))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
            ProgressView(value: min(max(value, 0), 1))
                .progressViewStyle(.linear)
                .controlSize(.mini)
                .frame(width: 64)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DownloadsFormat.percent(value))
    }
}

/// Second line of a row, e.g. "04:32 remaining".
struct MenuBarDetail: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

/// A rounded group of rows on a faint fill.
struct MenuBarGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: MenuBarMetrics.groupRadius, style: .continuous).fill(.quinary))
    }
}

/// Thin line between rows, starting after the tile.
struct MenuBarSeparator: View {
    var body: some View {
        Divider().padding(.leading, MenuBarMetrics.padding + MenuBarMetrics.tileSize + 10)
    }
}

/// Section caption ("Now", "Start timer"), optional trailing hint.
struct MenuBarSectionLabel: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One row: tile, title and detail, controls on the right.
struct MenuBarRow<Detail: View, Trailing: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    @ViewBuilder var detail: Detail
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            MenuBarTile(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                detail
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 6)
            trailing
        }
        .padding(.horizontal, MenuBarMetrics.padding)
        .frame(minHeight: MenuBarMetrics.rowHeight)
    }
}
