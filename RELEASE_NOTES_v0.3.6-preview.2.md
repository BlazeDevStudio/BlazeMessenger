# LAN Messenger v0.3.6 Preview 2 — Blaze V3 Brand, Call Reconnection & Notification Audio

**Developer Preview only.** Certified green across static analysis (`flutter analyze`), and all 95 unit, contract, and platform tests. Physical Windows ↔ Android device pair field acceptance and permanent Android release signing remain open acceptance gates.

## What's new in v0.3.6 Preview 2

### 1. BlazeDevStudio V3 Official Branding Scheme
- **Brand Migration**: Replaced the legacy ConnectIT artwork on native launchers and in-app headers with the official **BlazeDevStudio V3 sculpted B** identity featuring the three-connected-peer local network topology badge (`assets/branding/blazedevstudio-v3/lan-messenger-mark.svg`).
- **Adaptive Android Mipmaps**: Built multi-density Android icons (`mipmap-mdpi` through `mipmap-xxxhdpi`) and adaptive icon layers (`blaze_v3_background.png` and `blaze_v3_foreground.png`).
- **Compact Tray & Desktop Icons**: Generated multi-resolution Windows ICO (`lan_messenger.ico` 16px to 256px) and high-density Flutter UI header brand (`lan-messenger-mark-transparent.svg`).
- **Branding Provenance & Contract Tests**: Pinned upstream SVGs with immutable SHA-1 checks in `test/blazedevstudio_v3_branding_test.dart`, `test/blazedevstudio_v3_native_icon_test.dart`, and `test/lan_product_icon_contract_test.dart`.

### 2. Resilient Call Reconnection & ICE Restart
- **No More "Drop Dead" Call Termination**: Resolved the issue where temporary Wi-Fi drops, packet loss, or WebRTC `RTCPeerConnectionStateFailed` immediately aborted the call back to the conversation screen.
- **Grace Period Preservation**: Disconnections and ICE failures now enter an explicit `reconnecting` state with an on-screen timer countdown honoring `settings.reconnectGraceSeconds` (default 60s).
- **Automated ICE Restart & Renegotiation**: Actively initiates ICE restart (`pc.restartIce()` and offer with `iceRestart: true`) during network pauses or suspect watchdog states.
- **Active Call Session Handling**: Fixed a critical bug in `incomingSignal` that previously sent a `hangup` message whenever an incoming offer arrived during an active call. Now, matching active call sessions properly process renegotiation/restart offers, generate an answer, and seamlessly restore the media pipeline.

### 3. Android Custom Notification Audio Tone Fix
- **Versioned Audio Channels**: Replaced legacy `lan_v026_*` channels with versioned `lan_v036_*` channels (`lan_v036_call`, `lan_v036_video_call`, `lan_v036_message`, `lan_v036_file`) to bypass stale Android OS channel caches.
- **Stable Resource URIs**: Configured sound URIs with canonical `ContentResolver.SCHEME_ANDROID_RESOURCE` paths (`android.resource://$packageName/raw/$event`) instead of ephemeral AAPT integer resource IDs that changed between builds.
- **Explicit AudioAttributes**: Channels and notification builders now configure `AudioAttributes.CONTENT_TYPE_SONIFICATION` with `USAGE_NOTIFICATION_RINGTONE` for calls and `USAGE_NOTIFICATION` for messages and files, ensuring distinct on-app synthesized melodies (`call.wav`, `video_call.wav`, `message.wav`, `file.wav`) play accurately instead of falling back to the system default tone.

### 4. Comprehensive Validation
- All 95 tests passing 100% (including `test/call_reconnection_resilience_test.dart`).
- Dart analyzer clean with 0 warnings/errors.
