# BlazeMessenger migration checkpoint — 2026-10-29

This repository is the owner's **new messaging-app development home**. This branch is intentionally isolated from `main`; no previous source is removed.

## Immutable source provenance

- **LAN Messenger / ConnectIT branding**: `BlazingSystems/BlazingSystems-Experiments`, PR #235, commit `e115889f8a5ff8b50f9fc0c48afbb6fa24340bfe`, source `experiment/apps/LAN-Messenger/`. Preserves original LAN file/call behavior, Flutter tests and branding.
- **ConnectIT Master, Satellite, draft**: legacy PR #234, commit `70982717496345287ce9f925ecd4a7af3f32eaa8`, source `experiment/apps/ConnectIT/`. This is baseline v0.1.4; later client auth and durable replay hardening are in the separately preserved **v0.1.6** archives, not contained in that historical Git commit.
- **ConnectIT v0.1.5–v0.1.6 migration COMPLETED**: `migration/connectit-v014-to-v016.patch` was applied on this branch after the v0.1.4 pinned import, restoring Master `device_replay.go`, the authenticated `/v1/devices/self` API, client authentication, and the stand-alone Dart staging source. GitHub Actions run `40824454161` passed Go vet/tests, live Master restart/replay denial, SecureBind, node revocation, signed two-Seed integration and Dart analysis/tests.
- **ConnectIT native credential experiment (v0.1.7-dev)**: `ConnectIT/ConnectIT-LAN-Messenger-Draft/native_flutter/` adds independently isolated `flutter_secure_storage`-backed Ed25519 identity and enrollment ID. Run `40825159761` passed Flutter analysis and 4 fake-store regressions. **No real Android/Windows secure storage or app-integrated PIN flow is claimed.**
- **Historical archives/binaries**: independent v0.1.1–v0.1.6 ZIPs and original LAN preview packages remain in private owner Google Drive **ConnectIT Development** folder `1jk-oT3iZsnEUiSdujaFbpwN9buFk8RTp`. New repo contains source, not compiled releases.

## Destination paths

- `apps/LAN-Messenger/` — Flutter LAN Messenger client, branding and runtime, isolated from ConnectIT WAN protocol.
- `ConnectIT/ConnectIT-Master-Seed/` — standalone Go/SQLite Master.
- `ConnectIT/ConnectIT-Seed/` — standalone Go Satellite.
- `ConnectIT/ConnectIT-LAN-Messenger-Draft/` — isolated ConnectIT Dart client interfaces, not activated in LAN Messenger.
- `.github/workflows/` — independent source import and security checks.

Build binaries, APKs, Windows installers, legacy ZIP handouts and private signing keys are **not** silently replaced or represented as a production release. Original files remain in Drive and historical GitHub commits. Do not delete the Experiments source until a separate owner-approved decommission and artifact audit.

## Reorganization safeguards

Do not assume `experiment/apps` continues to exist in the former repository. Use this manifest's immutable hashes to recover provenance. Before changes, discover the repository tree and Git branch HEAD. No merges, release tags or production deployment are authorized by this migration.
