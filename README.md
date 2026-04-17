<div align="center">

# MacPaper

**A native animated-wallpaper engine for macOS.**
Video, WebGL and shaders rendered cleanly behind your desktop icons — zero Dock clutter, fully native, free and open-source.

[![CI](https://github.com/Deithand/MacPaper/actions/workflows/ci.yml/badge.svg)](https://github.com/Deithand/MacPaper/actions/workflows/ci.yml)
[![Release](https://github.com/Deithand/MacPaper/actions/workflows/release.yml/badge.svg)](https://github.com/Deithand/MacPaper/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/Deithand/MacPaper?sort=semver&display_name=tag)](https://github.com/Deithand/MacPaper/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Deithand/MacPaper/total.svg)](https://github.com/Deithand/MacPaper/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## Install

Download a pre-built binary from the **[latest release](https://github.com/Deithand/MacPaper/releases/latest)**:

| File | Description |
|------|-------------|
| `MacPaper-x.y.z.dmg` | Drag-and-drop disk image |
| `MacPaper-x.y.z.pkg` | Flat installer → `/Applications` |
| `SHA256SUMS.txt` | Checksums for both artifacts |

Or build from source (see [Development](#development)).

> **Note:** Builds are ad-hoc signed only. The first time you open MacPaper, macOS Gatekeeper will ask you to confirm opening an app from an unidentified developer. Right-click → Open to bypass.

## Features

- 🎬 **Video wallpapers** — any `.mp4` / `.mov` loops seamlessly via `AVQueuePlayerLooper`.
- 🌐 **Web wallpapers** — any URL renders live through a transparent `WKWebView` (HTML5, Canvas, Shadertoy, etc.).
- 🖥️ **Multi-monitor** — assign a unique source per display, remembered by stable hardware UUIDs, survives reconnects.
- 🎛️ **Live adjustments** — brightness, blur, playback speed, mute, fit mode — all applied in real time.
- 📚 **Library** — stored in `~/Movies/MacPaper`, with auto-generated thumbnails via `AVAssetImageGenerator`.
- ⏯️ **Playlist** — rotate through the library on an interval, with optional shuffle.
- 💤 **Smart Pause** — auto-halts rendering on fullscreen apps or Low Power Mode.
- 🎨 **SwiftUI Preferences** — System-Settings-style sidebar window with everything a click away.
- 🌍 **Internationalization** — English & Русский, with an in-app language switcher (auto-detects from the system on first launch).
- 🧭 **Menu-bar only** — no Dock icon, no windows in the way.
- 🚀 **Launch at Login** via `SMAppService`.
- ⌨️ **Global hotkey** — `⌃⌥⌘→` advances to the next wallpaper.
- 🖱️ **Drag-and-drop** — drop a video file onto the menu-bar icon to set it instantly.

## Requirements

- macOS **13 Ventura** or newer
- Swift **5.9+** (Xcode 15 or Command Line Tools)

## Development

```sh
git clone https://github.com/Deithand/MacPaper.git
cd MacPaper

# compile & run
swift build -c release
./scripts/make-app.sh
open MacPaper.app
```

### Distribution builds

```sh
./scripts/make-dmg.sh   # MacPaper-x.y.z.dmg  (drag-and-drop)
./scripts/make-pkg.sh   # MacPaper-x.y.z.pkg  (installer → /Applications)
```

All bundles are ad-hoc signed (`codesign -`). For distribution without Gatekeeper warnings you need an Apple Developer ID and notarization — the release workflow is ready to be extended with `productsign` + `notarytool`.

### Project layout

```
Sources/MacPaper/
├── main.swift                  entry point
├── AppDelegate.swift           menu-bar app + controller wiring
├── WallpaperController.swift   per-screen wallpaper-window manager
├── WallpaperWindow.swift       video + web wallpaper subclasses
├── WallpaperBackend.swift      WallpaperSource enum
├── Preferences.swift           UserDefaults storage
├── PreferencesWindow.swift     SwiftUI preferences UI
├── Localization.swift          EN / RU i18n
├── Library.swift               ~/Movies/MacPaper file library
├── Playlist.swift              interval-based rotation
├── SmartPause.swift            fullscreen / low-power auto-pause
├── Thumbnails.swift            AVAssetImageGenerator cache
├── Hotkeys.swift               global hotkey (⌃⌥⌘→)
├── DropTarget.swift            menu-bar drag-and-drop
└── LoginItem.swift             launch-at-login (SMAppService)
```

### Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘O` | Choose video file |
| `⌘U` | Open web URL |
| `⌘S` | Start / Stop |
| `⌘,` | Preferences |
| `⌃⌥⌘→` | Next wallpaper (global) |

## Continuous Integration

Two GitHub Actions workflows live in `.github/workflows/`:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`ci.yml`](.github/workflows/ci.yml) | push / PR to `main` | `swift build -c release`, assembles `.app`, smoke-tests the bundle |
| [`release.yml`](.github/workflows/release.yml) | push tag matching `v*` | Builds `.app`, `.dmg`, `.pkg`, computes SHA-256, publishes a GitHub Release with the artifacts attached |

### Cutting a new release

```sh
git tag v0.1.1
git push origin v0.1.1
```

GitHub Actions will build on `macos-14`, attach `MacPaper-0.1.1.dmg`, `MacPaper-0.1.1.pkg`, and `SHA256SUMS.txt` to a new release, auto-generating release notes from the commit history since the previous tag.

## Contributing

Issues and pull requests are welcome. If you open a PR, make sure `swift build -c release` passes locally — CI will double-check.

## License

Released under the [MIT License](LICENSE).
