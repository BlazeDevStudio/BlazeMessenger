# LAN Messenger v0.3.6 Preview 1 — Multiplatform Standalone Release & Security Hardening

**Developer Preview only.** Certified 100% green across all 6 GitHub Actions multiplatform CI jobs. Physical Windows ↔ Android device pair field acceptance and permanent Android release signing remain open acceptance gates.

## What's new in v0.3.6 Preview 1

- **Dedicated Standalone Repository**: Migrated out of experimental draft trees into the official standalone repository `BlazeDevStudio/BlazeMessenger`, with re-anchored workflows and build automation.
- **Cryptographic Identity Validation (LM-SEC-06)**: Validates that the loaded X25519 public key strictly matches the persisted private key during identity initialization. Corrupted, truncated, or tampered keys reject cleanly with an explicit `StateError` instead of running with broken crypto state.
- **Message Deduplication Sliding Window (LM-SEC-04)**: Upgraded chat message ID deduplication from an abrupt `.clear()` at 10,000 items to a bounded FIFO sliding window, eliminating replay attack windows during cache eviction.
- **Atomic File Persistence Bugfix**: Corrected a path-mutation issue in `RecoverableJsonFile` where Dart's `File.rename` mutated the caller's `File.path` property in place, ensuring subsequent saves promote safely without overwriting backups.
- **Native CallStyle and PiP Modernization (LM-DOC-01)**: Fully retired the legacy `AndroidCallOverlay.kt` template. Android incoming calls use native `NotificationCompat.CallStyle` with explicit Activity PendingIntents and system PiP, avoiding unnecessary `SYSTEM_ALERT_WINDOW` permissions.
- **Comparative Codebase & Architecture Audit**: Added `docs/REFERENCE_CODE_AUDIT_20261030.md` detailing 17 audit findings benchmarked against LocalSend, KDE Connect, Jami, and Signal protocols.
- **Comprehensive Test Suite**: All 87 unit, integration, and platform contract tests passing.

## Multiplatform Release Binaries & SHA256 Checksums

| Asset | Platform / Architecture | Description |
| --- | --- | --- |
| `LAN-Messenger-Windows-Optimized.zip` | Windows x64 | Portable release with bundled Microsoft VC++ runtime DLLs |
| `app-arm64-v8a-release.apk` | Android 64-bit ARM | Recommended for modern Android smartphones and tablets |
| `app-armeabi-v7a-release.apk` | Android 32-bit ARM | For legacy Android hardware |
| `app-x86_64-release.apk` | Android x86_64 | For Android emulators, ChromeOS, and x86 tablets |
| `SHA256SUMS.txt` | All | Cryptographic checksum manifest |

### Checksums

```
f2649e6a06128a499df592357351163f5c39419d5c3d24a679a108e93d83d711  LAN-Messenger-Windows-Optimized.zip
8ff458cce00d9851c14c1000f9ad9cf3e0995b060cd79e75299dad2a965db0eb  app-arm64-v8a-release.apk
87af119978219d1966617a57ba7c95f106c82b85e0be781dcdd965581b5d8da0  app-armeabi-v7a-release.apk
6d7510e00e4f1eeaf804d4f16cd161ae1baa26c9977101f68022f9b8a6a49f6c  app-x86_64-release.apk
```

## Release Gates and Remaining Work Before Production

1. **Physical Hardware Field Acceptance**:
   - Windows ↔ Android real-world video calls over non-isolated home/office routers.
   - Motorcycle backride helmet intercom testing over Wi-Fi hotspot with Bluetooth headset SCO/A2DP audio switching.
   - Two physical Android phones testing orientation flips and front/rear camera switching during active WebRTC calls.
2. **Explicit Device Trust & Pairing Gate (LM-SEC-01 & LM-SEC-02)**:
   - Untrusted discovered peers must require explicit user confirmation (fingerprint/QR/SAS) before receiving files or remote control.
   - Default `autoReceiveFiles` to false for unknown peers.
3. **Permanent Release Signing**:
   - APKs in this preview are signed with the developer keystore. A permanent release keystore must be established for upgrade continuity before general availability.
