# KUZAT

Universal viewer-only video player for YouTube, VK Видео and direct video sources.

## Current status

### Stage 5 — Playback history and Continue Watching 🟢 foundation connected

Implemented:

- local `SharedPreferences` playback store;
- periodic progress saving;
- save on player exit;
- resume from the last saved position;
- Library connected to the same playback history;
- completed items removed from Continue Watching near the end;
- VK player position persistence;
- no download workflow.

### Stage 6 — Final player UX and preferences 🟡 started

Started:

- centralized `PlayerPreferences` service for autoplay and default quality;
- settings keys are now shared by the player layer instead of being duplicated conceptually.

Still to connect:

1. apply autoplay preference when opening YouTube/direct/VK sources;
2. apply default quality when adaptive tracks are available;
3. improve Continue Watching cards and resume action;
4. auto-hide controls with tap-to-show;
5. stronger network/error states;
6. Android platform/build scaffold;
7. real-device testing;
8. final cleanup before merge to `main`.

## Player capabilities already present

- YouTube through the official YouTube IFrame player wrapper;
- direct MP4 playback;
- HLS/DASH track API integration through `video_player`;
- Auto/manual track selection where the source exposes adaptive tracks;
- VK Video resolver and viewer player;
- seek ±10 seconds;
- volume/mute;
- playback speed;
- fullscreen;
- buffering indicator;
- dark KUZAT interface;
- `Главная / Библиотека / Настройки` navigation.

## Important limitations

This repository has not yet been verified by a real Android device build in this workflow.

- Real VK links still need device/network verification.
- HLS/DASH adaptive switching needs Android-device verification with real multi-rendition streams.
- YouTube quality remains controlled by YouTube; KUZAT does not promise forced 1080p/720p selection.
- A single MP4 cannot provide hidden adaptive quality switching.

## Quality model

- **HLS/DASH:** real track selection is available when the source exposes multiple video tracks.
- **Single MP4:** the source provides its own fixed quality.
- **VK:** manual switching is possible when the resolver exposes multiple direct renditions. True adaptive switching requires HLS/DASH.
- **YouTube:** the official embedded player manages playback quality.

## Repository workflow

Development is being done on branch `kuzat-stage-2-player`.

Changes are kept in small stages so each feature can be checked before moving to the next one.
