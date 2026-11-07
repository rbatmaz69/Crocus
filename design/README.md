# Crocus – Design reference

Source of truth for the visual design of Crocus (designs were created under the working title "Insel"; read "Insel" as "Crocus" and `insel://` as `crocus://`).

- `Crocus-Design.html` – standalone export from Claude Design with all boards and the clickable prototypes. Open in a browser (needs JavaScript).
- `boards/` – rendered PNGs of each board, used in the GitHub issues.

| Board | File |
|---|---|
| Overview, state model, priorities | `boards/00-overview.png` |
| Specification (sizes, colors, type, springs, VoiceOver) | `boards/01-spec.png` |
| Clickable prototype | `boards/02-prototype.png` |
| Wireframe A – notch mode | `boards/03-wireframe-notch.png` |
| Wireframe B – pill mode | `boards/04-wireframe-pill.png` |
| A – notch mode, compact & minimal | `boards/05-notch-compact.png` |
| B – pill mode, compact & minimal | `boards/06-pill-compact.png` |
| A – notch mode, expanded & stacked | `boards/07-notch-expanded.png` |
| B – pill mode, expanded & stacked | `boards/08-pill-expanded.png` |
| C – animation storyboards C1–C6 | `boards/09-animation-storyboards.png` |
| D – onboarding | `boards/10-onboarding.png` |
| E – settings | `boards/11-settings.png` |
| F – Shortcuts integration | `boards/14-shortcuts.png` |
| App icon and menu bar icon (sources, asset sets) | `icon/` |

## Key tokens

**Colors** (island is always black, so always the dark variants): island `#000000`, primary `#FFFFFF`, secondary `#98989D`, surface `#2C2C2E`, progress `#0A84FF`, camera/charging `#30D158`, microphone `#FF9F0A`, low battery `#FF453A`.

**Sizes (pt)**

| State | Notch | Pill |
|---|---|---|
| Top offset | 0 | 6, floating |
| Idle | 186 × 37 · r 10 | 96 × 20 · r 10 |
| Compact | 306 × 40 · r 14 | 216 × 30 · r 15 |
| Wings / gap | 60 / 186 | 60 / 96 |
| Minimal | +6 + 40 drop | +6 + 30 circle |
| Expanded | 460 × 150–260 · r 32 | 440 × 150–260 · r 30 |
| Header | 37 | 34 |
| Shoulder | r 10, concave | – |
| Shadow | none | 0 8 24 / 28 % + 0 1 3 / 20 % |

Notch width and menu bar height are read at runtime from `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea/-RightArea`, never hard-coded.

**Springs** – SwiftUI `spring(response:dampingFraction:)`

| Transition | response / damping |
|---|---|
| Idle → compact | 0.40 / 0.80 |
| Expand | 0.42 / 0.72 |
| Collapse | 0.35 / 1.00 |
| Drop detaches | 0.35 / 0.70 |
| Card swipe | 0.30 / 0.86 |
| Screen change | 0.55 / 0.82 |
| Hover hint | 0.30 / 0.90 · 1.03× |

Animation strength "Subtle": damping +0.1 and overshoot halved. "Lively": damping −0.06.
