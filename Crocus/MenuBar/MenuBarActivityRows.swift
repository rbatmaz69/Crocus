import SwiftUI

/// What each activity shows in its row of the menu bar panel (#61): the same
/// actions as on the island, styled for the system appearance.

extension ActivityKind {
    var panelSymbol: String {
        switch self {
        case .cameraMicrophone: "video.fill"
        case .calendar: "calendar"
        case .timer: "timer"
        case .liveActivity: "app.badge"
        case .download: "arrow.down"
        case .music: "music.note"
        }
    }

    var panelTint: Color {
        switch self {
        case .cameraMicrophone: .green
        case .calendar: .red
        case .timer: .orange
        case .liveActivity: .indigo
        case .download: .cyan
        case .music: .pink
        }
    }
}

// MARK: - Timer

extension TimerFormat {
    /// "04:32 remaining", "04:32 · paused", "Finished"; the stopwatch shows
    /// its time ("01:05", "01:05 · paused").
    static func panelDetail(_ state: TimerState, now: Date) -> String {
        let time = readout(state, now: now)
        switch (state.kind, state.phase) {
        case (.timer, .finished): return "Finished"
        case (_, .paused): return "\(time) · paused"
        case (.timer, _): return "\(time) remaining"
        case (.stopwatch, _): return time
        }
    }
}

extension TimerActivity {
    var panelSymbol: String { TimerFormat.symbol(state.kind) }
    var panelTitle: String { TimerFormat.title(state.kind) }

    var panelDetail: AnyView {
        let state = state
        return AnyView(TimerTicking(state: state) { date in
            MenuBarDetail(text: TimerFormat.panelDetail(state, now: date))
        })
    }

    var panelControls: AnyView {
        AnyView(HStack(spacing: 6) {
            switch state.phase {
            case .running:
                MenuBarRoundButton(systemName: "pause.fill", label: "Pause") { self.onPause?() }
            case .paused:
                MenuBarRoundButton(systemName: "play.fill", label: "Resume") { self.onResume?() }
            case .finished:
                MenuBarRoundButton(systemName: "arrow.clockwise", label: "Restart") { self.onRestart?() }
            }
            MenuBarRoundButton(systemName: "xmark", label: "Stop") { self.onStop?() }
        })
    }
}

// MARK: - Music

extension NowPlayingActivity {
    var panelTitle: String { state.title }

    var panelDetail: AnyView {
        let parts = [state.artist, state.player.displayName].compactMap { $0 }
        return AnyView(MenuBarDetail(text: parts.joined(separator: " · ")))
    }

    var panelControls: AnyView {
        let playing = state.isPlaying
        return AnyView(MenuBarRoundButton(systemName: playing ? "pause.fill" : "play.fill", label: playing ? "Pause" : "Play") {
            self.onCommand?(.playPause)
        })
    }
}

// MARK: - Live Activity

extension LiveActivity {
    var panelSymbol: String { state.symbol }
    var panelTitle: String { state.title }

    var panelDetail: AnyView {
        let text: String? = switch state.phase {
        case .ended(let result, let text, _): text ?? result.title
        case .running: isStale ? "No updates" : state.status
        }
        return AnyView(text.map { MenuBarDetail(text: $0) })
    }

    var panelControls: AnyView {
        switch state.phase {
        case .ended(let result, _, _):
            AnyView(LiveActivityResultSymbol(result: result))
        case .running:
            switch state.progress {
            case .value(let value): AnyView(MenuBarProgress(value: value))
            case .indeterminate: AnyView(ProgressView().controlSize(.small))
            }
        }
    }
}

// MARK: - Downloads

extension DownloadsActivity {
    var panelDetail: AnyView {
        let text = items.count == 1 ? items[0].name : DownloadsFormat.count(items.count)
        return AnyView(MenuBarDetail(text: text))
    }

    var panelControls: AnyView {
        if allEnded { return AnyView(LiveActivityResultSymbol(result: endResult)) }
        if let overall { return AnyView(MenuBarProgress(value: overall)) }
        return AnyView(ProgressView().controlSize(.small))
    }
}

// MARK: - Calendar

extension CalendarActivity {
    var panelTint: Color { .red }
    var panelTitle: String { event.title }
    var panelDetail: AnyView { AnyView(MenuBarDetail(text: CalendarFormat.subtitle(event))) }

    var panelControls: AnyView {
        guard event.joinURL != nil else { return AnyView(EmptyView()) }
        return AnyView(MenuBarPillButton(title: "Join", prominent: true) { self.onJoin?() })
    }
}

// MARK: - Camera and microphone

extension PrivacyActivity {
    var panelSymbol: String { state.isShown(.camera) ? "video.fill" : "mic.fill" }
    var panelTint: Color { state.isShown(.camera) ? .green : .orange }
    var panelDetail: AnyView {
        AnyView(MenuBarDetail(text: state.shown.map(PrivacyFormat.title).joined(separator: " · ")))
    }
}
