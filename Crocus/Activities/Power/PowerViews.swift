import SwiftUI

/// Storyboard C6, counted from when the event appears.
enum ChargingTimeline {
    /// The bolt bounces once the island has grown.
    static let boltBounce: Duration = .milliseconds(300)
    /// The battery fills from empty to the level: 300 → 900 ms, easeOut.
    static let fillStart: Duration = .milliseconds(300)
    static let fillDuration: Duration = .milliseconds(600)
    /// Holds until the event ends at 2500 ms (`EventKind.charging`).
    static var fillEnd: Duration { fillStart + fillDuration }
    /// Low battery: the warning symbol pulses once.
    static let warningPulse: Duration = .milliseconds(300)
}

/// Green `bolt.fill`; bounces at 300 ms (not with Reduce Motion).
struct ChargingBolt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = 0

    var body: some View {
        IslandCompactSymbol(systemName: "bolt.fill", color: CrocusColors.positive)
            .symbolEffect(.bounce, value: bounce)
            .task {
                guard !reduceMotion else { return }
                try? await Task.sleep(for: ChargingTimeline.boltBounce)
                bounce += 1
            }
    }
}

/// Red `exclamationmark.triangle.fill`; pulses once (not with Reduce Motion).
struct LowBatteryWarning: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = 0

    var body: some View {
        IslandCompactSymbol(systemName: "exclamationmark.triangle.fill", color: CrocusColors.lowBattery)
            .symbolEffect(.pulse, options: .nonRepeating, value: pulse)
            .task {
                guard !reduceMotion else { return }
                try? await Task.sleep(for: ChargingTimeline.warningPulse)
                pulse += 1
            }
    }
}

/// "82 %" (tabular digits) and a battery glyph. When charging, the glyph
/// fills from empty to the level (300 → 900 ms); with Reduce Motion it
/// shows the level at once.
struct BatteryValue: View {
    let level: Int
    let color: Color
    let fills: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double?

    var body: some View {
        HStack(spacing: 5) {
            IslandCompactValue(text: "\(level) %", color: color)
            BatteryGlyph(fraction: shown ?? (fills && !reduceMotion ? 0 : target), color: color)
        }
        .task {
            guard fills, !reduceMotion else { return }
            try? await Task.sleep(for: ChargingTimeline.fillStart)
            withAnimation(.easeOut(duration: ChargingTimeline.fillDuration.seconds)) { shown = target }
        }
    }

    private var target: Double { Double(level) / 100 }
}

/// Battery outline with a cap and a fill, 25 × 12 pt.
struct BatteryGlyph: View {
    let fraction: Double
    let color: Color

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(.islandSecondary, lineWidth: 1)
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: max((proxy.size.width) * min(max(fraction, 0), 1), fraction > 0 ? 2 : 0))
                }
                .padding(2)
            }
            .frame(width: 22, height: 12)
            RoundedRectangle(cornerRadius: 1).fill(.islandSecondary).frame(width: 1.5, height: 4)
        }
        .accessibilityHidden(true)
    }
}

private extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
