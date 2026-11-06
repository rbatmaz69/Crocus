# Camera and Microphone Indicator

When any app uses a camera or microphone, Crocus shows it in the island – always on top. It doesn't replace the indicator macOS shows in the menu bar.

## In the island

- **Compact**: `video.fill` in green (camera) or `mic.fill` in orange (microphone) left – the camera if both are in use – and one 6 pt dot per device right.
- **Expanded**: "Privacy · Now", a row per device ("Camera active", "For 12 min · used by an app"), and **Privacy Settings…**, which opens Privacy & Security → Camera (or Microphone if only that is in use).
- Green `#30D158` and orange `#FF9F0A` are signal colours – used only for dots and symbols, never as areas.
- Appears at once; disappears 2 s after the device stops, so a quick restart (switching cameras in a call) doesn't flicker.
- "For 12 min" counts from when Crocus saw the device start. If it was already in use when Crocus started, the row says "In use".
- VoiceOver announces "Camera in use" / "Microphone no longer in use".

## How it works

- Microphones: CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere`; cameras: CoreMediaIO `kCMIODevicePropertyDeviceIsRunningSomewhere`. Crocus listens for changes instead of polling, and new devices (USB camera, AirPods) are picked up.
- These APIs only say *that* a device runs, not *which app* uses it – so Crocus never names an app.
- Only real hardware counts. Virtual and aggregate devices (Teams Audio, Loopback, OBS …) are ignored: they only pass audio or video on, and when they record, the real device runs too.
- Crocus records nothing, so there is no permission dialog. The sandbox hides cameras from CoreMediaIO, so Crocus has the `com.apple.security.device.camera` entitlement – only to see whether a camera runs (to be explained in the App Review notes, #29).
