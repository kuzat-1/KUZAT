# KUZAT — Project Snapshot

This document is a human-readable snapshot of the current implementation on `kuzat-stage-2-player`.

## Included now

- Dark KUZAT home screen.
- Tabs: `Поиск / YouTube / VK Видео`.
- URL validation and routing.
- YouTube playback through the YouTube IFrame player.
- Direct video playback.
- VK Video resolver and player.
- HLS/DASH track support where the source exposes adaptive tracks.
- Play/pause, seek ±10 seconds, mute/volume, speed and fullscreen controls.
- Buffering and retry/error states.
- Playback position persistence.
- Continue Watching / Library with progress.
- Swipe-to-delete history items.
- Settings for autoplay and default quality.
- Android lifecycle handling: save progress when backgrounding and resume playback when appropriate.
- Android fullscreen with landscape orientation for direct/VK players.
- Android build workflow in GitHub Actions.
- No downloader workflow or download controls.

## Navigation

`Главная / Библиотека / Настройки`

## Quality behavior

- HLS/DASH: KUZAT can select exposed video tracks.
- Single MP4: fixed quality supplied by the source.
- VK: manual quality selection is possible when multiple direct renditions are resolved.
- YouTube: playback quality is controlled by YouTube's embedded player.

## Important status

The project is still in development. A successful Android APK build and real-device/network verification are required before calling the release production-ready.

## Branch

Current development branch: `kuzat-stage-2-player`

## Pull request

The staged work is collected in PR #2 toward `main`.
