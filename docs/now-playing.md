# Now Playing

Crocus shows what Spotify or the Music app is playing and lets you control it from the island – without private frameworks, inside the App Sandbox.

## In the island

- **Compact**: cover left, five moving bars right (still while paused, and with Reduce Motion – Crocus can't hear the audio, so they don't follow the music).
- **Expanded**: cover (click opens the player), title, artist, progress with `1:24` and `−2:27`, and previous / play-pause / next.
- If both players play, the one started last is shown. A paused player stays for 5 minutes; quitting it removes it at once.
- A song that was already playing when Crocus started appears with the next change (play, pause, skip) – the players only report changes.

## How it works

| | Spotify | Music |
|---|---|---|
| Track, artist, album, state | player notification | player notification |
| Position | player notification | Apple Event (`player position`) |
| Cover | Apple Event (`artwork url`), loaded from Spotify's image server | iTunes Search API (see below) |
| Play/pause, next, previous | Apple Events | Apple Events |

- Players post `com.spotify.client.PlaybackStateChanged` and `com.apple.Music.playerInfo` on every change; Crocus listens instead of polling.
- Apple Events only go to players that are running – otherwise macOS would launch them.
- **Music covers**: the sandbox doesn't let Crocus read Music's artwork, so it asks Apple's public iTunes Search API by artist and title (no account). Only an exact match is used, once per song; songs that aren't in the store keep a note symbol. This sends the artist and title to Apple.
- **Spotify** works without a Spotify account in Crocus.

## Permissions

The first time a player starts playing, macOS asks whether Crocus may control it. Denying turns off Now Playing for that player only; the menu bar menu then shows **Allow in System Settings…** (Privacy & Security → Automation).

To ask again from scratch:

```sh
tccutil reset AppleEvents com.rbatmaz69.crocus
```

Entitlements: `com.apple.security.automation.apple-events`; `scripting-targets` for Music (`com.apple.Music.playback`, `com.apple.Music.library.read`); a temporary exception for Spotify (`com.spotify.client`), whose scripting dictionary defines no access groups – to be justified in the App Review notes (#29); `network.client` for the covers.
