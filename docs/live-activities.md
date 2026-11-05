# Live Activities

Any app, script or shortcut can show its own activity in the Crocus island – a build, an upload, a render, a long-running job. Send `crocus://` URLs; App Intents for the Shortcuts app follow in #12 and use the same rules.

Use `open -g` so the Terminal keeps the focus (Crocus also hands focus back on its own).

```sh
open -g "crocus://start?id=build&title=Build&symbol=hammer&progress=0&status=Starting"
open -g "crocus://update?id=build&progress=0.4&status=128%20of%20320"
open -g "crocus://end?id=build&result=success"
```

## Commands

| Command | Required | Optional |
|---|---|---|
| `start` | `id`, `title` | `symbol`, `progress`, `status`, `source`, `action`, `actionTitle` |
| `update` | `id` | `title`, `symbol`, `progress`, `status`, `source`, `action`, `actionTitle` |
| `end` | `id` | `result`, `text` |

Starting an id that already exists restarts it with the new values. Updates and ends for unknown ids are ignored.

## Parameters

| Parameter | Rules |
|---|---|
| `id` | 1–64 characters: letters, digits, `.` `_` `-` |
| `title` | up to 60 characters (longer is shortened with "…") |
| `symbol` | an [SF Symbol](https://developer.apple.com/sf-symbols/) name, e.g. `hammer`, `arrow.up.circle`; unknown names show `app.badge` |
| `progress` | a number from 0 to 1 (clamped); empty or missing on start = indeterminate spinner |
| `status` | up to 120 characters |
| `source` | shown in the expanded header, up to 40 characters (default "Live Activity") |
| `action` | a link for the primary button – only `https://`, `http://` and `file://` |
| `actionTitle` | button title, up to 24 characters (default "Open") |
| `result` | `success` (default), `failure` or `cancelled` |
| `text` | shown with the result, up to 120 characters |

Remember to percent-encode values (`%20` for spaces).

## Lifecycle

- **End** shows the result (✓ / ✕ / –) for 3 s, then the activity disappears. If the card is open, it stays until the island collapses, but no longer than 30 s.
- **Stale**: without an update for 8 h the activity shows "No updates"; it can be dismissed with **Hide**.
- Activities are not kept across restarts of Crocus.
- Priority: Live Activities come after camera/microphone, calendar and timer, before downloads and music.

## Example: report a build

```sh
#!/bin/sh
open -g "crocus://start?id=build&title=Build&symbol=hammer&source=build.sh&action=file://$PWD/build.log&actionTitle=Open%20Log"
total=320
for i in $(seq 1 $total); do
  # … compile file $i …
  if [ $((i % 16)) -eq 0 ]; then
    open -g "crocus://update?id=build&progress=$(echo "scale=2; $i/$total" | bc)&status=$i%20of%20$total"
  fi
done
open -g "crocus://end?id=build&result=success&text=Build%20finished"
```
