# Crocus

Crocus brings a Dynamic-Island-style live activity area to the Mac: a black island that grows out of the notch (or floats as a pill on external displays) and shows timers, now playing, charging, calendar, downloads and more – with springy animations and full keyboard and VoiceOver support.

![Overview](design/boards/00-overview.png)

The visual design lives in [`design/`](design/README.md).

## Requirements

- macOS 26 Tahoe
- Xcode 27 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build

`project.yml` is the source of truth for the Xcode project. After changing it (or adding/removing files), regenerate the project:

```sh
xcodegen generate
```

Then open `Crocus.xcodeproj` in Xcode and run the `Crocus` scheme, or build and test from the command line:

```sh
xcodebuild -project Crocus.xcodeproj -scheme Crocus -destination 'platform=macOS' build
xcodebuild -project Crocus.xcodeproj -scheme Crocus -destination 'platform=macOS' test
```

Crocus runs as a menu bar agent (no Dock icon) inside the App Sandbox. Look for the capsule icon in the menu bar to open Settings or quit. The `crocus://` URL scheme is registered, e.g. `open crocus://test`.

Signing uses "Sign to Run Locally" by default; set your team in `project.yml` (`DEVELOPMENT_TEAM`) for distribution builds.

## Project layout

| Folder | Contents |
|---|---|
| `Crocus/App` | App entry point, app delegate, URL routing |
| `Crocus/Island` | Island shape, states and views |
| `Crocus/Activities` | One folder per activity source |
| `Crocus/Platform` | Screens, windows, permissions |
| `Crocus/DesignSystem` | Colors, typography, springs and sizes from the spec |
| `Crocus/Intents` | App Intents for Shortcuts |
| `CrocusTests` | Unit tests |
