# Downloads

Crocus shows downloads from Safari, Chrome and Firefox (and browsers built on them, e.g. Helium or Zen) while they run.

## Setup

Until the onboarding (#26) asks for it, use the menu bar: **Choose Downloads Folder…** and confirm the folder (`~/Downloads` is preselected). Crocus keeps access as a security-scoped bookmark, so it survives relaunches; the menu then shows the folder and **Change Downloads Folder…**. Only file names and sizes are read.

## In the island

- **Compact**: `arrow.down.circle` and a progress ring for all running downloads together; a spinner when a size is unknown.
- **Expanded**: "Downloads · 2 files", a row per download (up to 3, then "+2 more") with name, "412 MB of 1.2 GB", percentage and a bar.
- **Finished**: ✓ for 3 s, then gone. **Cancelled**: red ✕ for 3 s ("Cancelled"). With several, compact shows ✕ only if all were cancelled.
- Downloads done within 1 s never show, so small files don't flash the island.
- A download that hasn't grown for 60 s (paused, left over) disappears quietly and comes back once it grows again.

## How it works

| Browser | While downloading | Finished | Cancelled |
|---|---|---|---|
| Safari | `name.download` bundle | bundle gone, `name` there | bundle **kept** (to resume); its progress is withdrawn |
| Chrome | `name.crdownload` | renamed to `name` | file deleted |
| Firefox | `name.<random>.ext.part` + empty placeholder `name.ext` | `.part` renamed over the placeholder | both deleted |

- Changes in the folder trigger a scan (a file system event, no polling). While a download runs, its size is read once per second.
- Bytes and totals come from the progress browsers publish for Finder (`NSProgress`), otherwise from the growing file size. Some progress arrives without a file URL; it is matched to the partial file created within 3 s of it – files lying around from earlier are never matched.
- Safari keeps a cancelled download's bundle: when Safari withdraws its progress and the bundle is still there 2 s later, it counts as cancelled (on success the bundle goes right after).

## Entitlements

`com.apple.security.files.user-selected.read-only` and `com.apple.security.files.bookmarks.app-scope` – read only, only the folder the user picked.
