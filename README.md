# MacPaper

**Native animated wallpaper engine for macOS.** Video, WebGL and shaders rendered cleanly behind your desktop icons. Zero Dock clutter. Fully native. Free and open-source.

---

## Features

- 🎬 **Video wallpapers** — any `.mp4` / `.mov` loops seamlessly behind your icons via `AVQueuePlayerLooper`.
- 🌐 **Web wallpapers** — drop any URL (HTML5, Canvas, Shadertoy) and it lives on your desktop through a transparent `WKWebView`.
- 🖥️ **Multi-monitor** — assign a unique source per display; remembered by stable hardware UUIDs, survives reconnects.
- 🎛️ **Live adjustments** — brightness, blur, playback speed, mute, fit mode — all applied in real time.
- 📚 **Library** — keep your videos in `~/Movies/MacPaper`, with auto-generated thumbnails.
- ⏯️ **Playlist** — rotate through the library on an interval, with optional shuffle.
- 💤 **Smart Pause** — automatically halts rendering on fullscreen apps or Low Power Mode.
- 🎨 **Beautiful SwiftUI Preferences** — System-Settings-style sidebar window with everything one click away.
- 🌍 **English / Русский** — built-in language switcher, auto-detects from system.
- 🧭 **Menu-bar only** — no Dock icon, no windows in your way.
- 🚀 **Launch at Login** via `SMAppService`.

## Requirements

- macOS 13 Ventura or newer
- Swift 5.9+ (Xcode 15 or Command Line Tools)

## Build & Run

```sh
swift build -c release
./scripts/make-app.sh       # assembles MacPaper.app
open MacPaper.app
```

Press `⌘,` to open Preferences.

## Distribution builds

```sh
./scripts/make-dmg.sh       # MacPaper-0.1.0.dmg  (drag-and-drop installer)
./scripts/make-pkg.sh       # MacPaper-0.1.0.pkg  (flat installer → /Applications)
```

All bundles are ad-hoc signed. For distribution to other Macs without Gatekeeper warnings you'll need an Apple Developer ID and notarization.

## Project layout

```
Sources/MacPaper/
├── main.swift                  entry point
├── AppDelegate.swift           menu-bar app + controller wiring
├── WallpaperController.swift   manages per-screen wallpaper windows
├── WallpaperWindow.swift       video + web wallpaper window subclasses
├── WallpaperBackend.swift      WallpaperSource enum
├── Preferences.swift           user defaults storage
├── PreferencesWindow.swift     SwiftUI preferences UI
├── Localization.swift          EN / RU i18n
├── Library.swift               ~/Movies/MacPaper file library
├── Playlist.swift              interval-based rotation
├── SmartPause.swift            fullscreen / low-power auto-pause
├── Thumbnails.swift            AVAssetImageGenerator cache
├── Hotkeys.swift               global hotkey (⌃⌥⌘→)
├── DropTarget.swift            menu-bar drag-and-drop
├── LoginItem.swift             launch-at-login (SMAppService)
└── License.swift               (unused; Pro gating disabled)
```

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘O` | Choose video file |
| `⌘U` | Open web URL |
| `⌘S` | Start / Stop |
| `⌘,` | Preferences |
| `⌃⌥⌘→` | Next wallpaper (global) |

## License

MIT. See `LICENSE`.
