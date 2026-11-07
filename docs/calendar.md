# Calendar

Crocus shows your next event in the island **5 minutes before** it starts and keeps it until **5 minutes after** the start, for joining late. Events with a video call get a **Join** button.

## In the island

- **Compact**: `calendar` symbol in the calendar's colour, countdown `5 min` … `1 min`, then `Now`. With the right wing reduced, a video call shows `video.fill`.
- **Expanded**: the calendar's colour as a 4 pt bar, the title, `14:30–15:00 · Video call · 4 attendees` (the location instead of "Video call" without a link), and a white **Join** button.
- **Join** opens the link and hides the event.
- Priority 2, after camera/microphone. Several events: the earliest; at the same start, the one with a video call.

## Which events

- All calendars, the next **24 hours** only, read only.
- Ignored: all-day events, events you declined, cancelled events. (Some account types don't report your response; those events are shown.)
- Video call links are found in the event's URL, location and notes: Zoom (`zoom.us/j/…`, `/my/…`), Google Meet, Microsoft Teams, FaceTime and Webex – `https` only. Links behind redirects (e.g. Outlook SafeLinks) aren't recognised; the event still shows, without Join.
- Re-read when the calendar changes, after the Mac wakes, when the clock changes, and at least hourly.

## Permission

Until the onboarding (#26) asks for it, use the menu bar panel: **Needs your permission** → Calendar → **Allow**. Denied, the calendar activity is off and the row offers **Open…** (Privacy & Security → Calendars).

To ask again from scratch:

```sh
tccutil reset Calendar com.rbatmaz69.crocus
```
