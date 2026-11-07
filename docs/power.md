# Charging and Low Battery

On MacBooks, Crocus briefly shows power events in the island and then returns to what it showed before. Desktop Macs have no internal battery, so there are none – on an external display too.

| Event | When | Shows | Duration |
|---|---|---|---|
| **Charging** | Power adapter plugged in (also when macOS holds the battery at 80 %) | green `bolt.fill`, `82 %`, battery filling | 2.5 s |
| **Low battery** | Reaching 10 % and 5 % on battery | red `exclamationmark.triangle.fill`, `9 %` | 4 s |

- Unplugging and "fully charged" are silent.
- Each low-battery warning comes once per discharge. Plugging in re-arms it; so does the level climbing 2 points above the threshold, so a level wobbling around 10 % doesn't repeat it. A level that is already low when Crocus starts isn't announced.
- VoiceOver reads "Charging, 82 percent" / "Battery low, 9 percent".

## Animation (storyboard C6)

| Time | Charging |
|---|---|
| 0 ms | adapter plugged in (IOKit power source notification) |
| 120 ms | island grows (C1) |
| 300 ms | bolt bounces; battery starts filling from empty |
| 900 ms | battery reaches the level (600 ms easeOut) |
| 2500 ms | island returns to its previous state |

Low battery: the warning symbol pulses once. With **Reduce Motion**, the content appears with its final value – no fill, no bounce, no pulse.

Debug builds can trigger the events from the menu bar panel: Developer → Activities → Simulate Plug-In / 10 % / 5 % Battery.
