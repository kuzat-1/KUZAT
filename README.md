# KUZAT

Universal viewer-only video player for YouTube, VK Видео and direct video sources.

## Current status

### Stage 5 — Playback history and Continue Watching 🟢 foundation connected

Implemented in the player:

- saves playback position to local `SharedPreferences` storage;
- saves progress periodically while playing;
- saves again when the player is closed;
- restores the last position when the same source is opened again;
- Library reads the same playback history store;
- finished videos are removed from Continue Watching when they are within the final 10 seconds;
- VK player also saves/restores position;
- no download button or download workflow.

### Player capabilities already present

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

These items are **not yet marked production-ready** because this repository has not been verified by a real Android device build in this workflow:

1. Real VK links still need device/network verification.
2. HLS/DASH adaptive track switching needs Android-device verification with real multi-rendition streams.
3. YouTube quality remains controlled by YouTube; KUZAT does not promise forced 1080p/720p selection.
4. Default quality and autoplay settings are stored by the Settings screen but still need to be applied consistently to every player.
5. Auto-hide player controls and final mobile UX polish remain.
6. Full Android/iOS/Web platform scaffolding and CI build verification remain.

## Quality model

- **HLS/DASH:** real track selection is available when the source exposes multiple video tracks.
- **Single MP4:** there is no hidden quality switch; the source has only the quality it provides.
- **VK:** manual switching is possible when the resolver exposes multiple direct renditions. True adaptive switching requires an adaptive HLS/DASH source.
- **YouTube:** the official embedded player manages playback quality.

## Repository workflow

Development is being done on branch `kuzat-stage-2-player`.

Changes are kept in small stages so each feature can be checked before moving to the next one.

## Next stage

### Stage 6 — Final player UX and platform verification 🟡

Planned order:

1. apply Settings values to player startup;
2. improve Continue Watching cards and resume action;
3. auto-hide controls;
4. stronger network/error states;
5. Android platform/build scaffold;
6. real-device testing for YouTube, VK, MP4 and HLS/DASH;
7. final cleanup before merging to `main`.
