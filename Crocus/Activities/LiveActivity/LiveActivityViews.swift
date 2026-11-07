import SwiftUI

/// Source symbol in a squircle (22 pt compact, 34 pt expanded).
struct LiveActivitySymbol: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(CrocusColors.surface)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(CrocusColors.primary)
            }
    }
}

/// Right wing: progress ring, spinner, or the result once ended.
struct LiveActivityIndicator: View {
    let activity: LiveActivity

    var body: some View {
        let state = activity.state
        switch state.phase {
        case .ended(let result, _, _):
            LiveActivityResultSymbol(result: result)
        case .running:
            let tint = activity.isStale ? CrocusColors.secondary : CrocusColors.progress
            switch state.progress {
            case .indeterminate: IslandSpinner(tint: tint)
            case .value(let value): IslandProgressRing(progress: value, tint: tint)
            }
        }
    }
}

struct LiveActivityResultSymbol: View {
    let result: LiveActivityResult

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 20, height: 20)
            .transition(.scale.combined(with: .opacity))
    }

    private var symbol: String {
        switch result {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .cancelled: "minus.circle.fill"
        }
    }

    private var color: Color {
        switch result {
        case .success: CrocusColors.positive
        case .failure: CrocusColors.lowBattery
        case .cancelled: CrocusColors.secondary
        }
    }
}

/// Expanded header, right: "since 2:14" (ticking), "No updates" or the result.
struct LiveActivityHeaderStatus: View {
    let activity: LiveActivity

    var body: some View {
        let state = activity.state
        switch state.phase {
        case .ended(let result, _, _):
            Text(result.title)
        case .running where activity.isStale:
            Text("No updates")
        case .running:
            HStack(spacing: 0) {
                Text("since ")
                Text(state.startedAt, style: .timer)
            }
            .monospacedDigit()
        }
    }
}

/// Expanded card: symbol, title, status, percentage, progress bar, action and
/// "Hide".
struct LiveActivityCard: View {
    let activity: LiveActivity

    var body: some View {
        let state = activity.state

        HStack(spacing: 12) {
            LiveActivitySymbol(symbol: state.symbol, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .islandFont(CrocusTypography.title)
                    .lineLimit(1)
                if let status = statusText {
                    Text(status)
                        .islandFont(CrocusTypography.status)
                        .foregroundStyle(.islandSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .foregroundStyle(CrocusColors.primary)
        // One element: "Build running, 40 percent, compiling 128 of 320 files".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activity.accessibilityLabel)

        if case .value(let value) = state.progress {
            IslandProgressBar(progress: value, tint: activity.isStale ? CrocusColors.secondary : CrocusColors.progress)
        }

        HStack(spacing: 8) {
            if let action = state.action {
                IslandButton(title: action.title, primary: true) { activity.onOpenAction?(action.url) }
            }
            IslandButton(title: "Hide") { activity.onHide?() }
        }
    }

    private var statusText: String? {
        switch activity.state.phase {
        case .ended(let result, let text, _): text ?? result.title
        case .running: activity.isStale ? "No updates" : activity.state.status
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity.state.phase {
        case .ended(let result, _, _):
            LiveActivityResultSymbol(result: result)
        case .running:
            switch activity.state.progress {
            case .value(let value):
                Text("\(Int((value * 100).rounded())) %")
                    .islandFont(CrocusTypography.value)
            case .indeterminate:
                IslandSpinner()
            }
        }
    }
}
