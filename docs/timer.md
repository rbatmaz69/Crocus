# Timer and Stopwatch

Crocus has a built-in timer (counts down) and stopwatch (counts up). One of each can run at the same time; starting a new timer replaces the running one.

## Start

- **Menu bar**: Crocus icon → **Start timer** → 1, 5, 10, 15 or 25 min, or the stopwatch. Under **Now** the panel pauses, resumes and stops them.
- **Shortcuts, Spotlight, Siri**:

| Action | Parameters |
|---|---|
| **Start Timer** | Duration (1 second to 24 hours) |
| **Start Stopwatch** | – |
| **Control Timer** | Action (Pause / Resume / Stop), Which (Timer / Stopwatch) |

```sh
shortcuts run "My 25 min focus timer"
```

## In the island

- **Compact**: `timer` or `stopwatch` symbol left, `04:32` right. Dimmed while paused.
- **Expanded**: the time, "Timer · 10:00 · ends 14:37", Pause / Resume and Stop, and the remaining time as a blue bar.
- **When the timer runs out**: a sound, the symbol bounces and VoiceOver says "Timer finished". The island shows `00:00` with **Restart** and **+1 Min** until you have looked at it (expanded, then collapsed) or for a minute at most.

## Relaunch

Timer and stopwatch keep running when Crocus quits or the Mac sleeps – Crocus stores when they end, not a counter. A timer that ran out while Crocus wasn't running is still announced if that was less than a minute ago; older ones are dropped silently.
