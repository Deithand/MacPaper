# Changelog

All notable changes to MacPaper will be documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2025-04-17

First public release.

### Added
- Native video wallpapers via `AVQueuePlayerLooper` (seamless loops, mute, playback speed).
- Web wallpapers via transparent `WKWebView` (HTML5, Canvas, Shadertoy).
- Per-monitor assignment with stable hardware-UUID persistence.
- Live adjustments: brightness, blur, playback speed, fit mode, mute.
- Library folder (`~/Movies/MacPaper`) with auto-generated thumbnails.
- Playlist with optional shuffle and configurable interval (1 min → 4 hours).
- Smart Pause: auto-pause on fullscreen apps and Low Power Mode.
- SwiftUI Preferences window (sidebar navigation, live bindings).
- English / Русский localization with in-app language switcher.
- Global hotkey `⌃⌥⌘→` to advance to next wallpaper.
- Drag-and-drop video files onto the menu-bar icon.
- Launch-at-login via `SMAppService`.
- Distribution scripts: `.app`, `.dmg`, `.pkg`.
- GitHub Actions: CI on every push, automatic release on `v*` tags.

[0.1.0]: https://github.com/Deithand/MacPaper/releases/tag/v0.1.0
