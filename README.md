# BlazeMessenger — Messaging Ecosystem (Development)

This is the **new dedicated repository** for the owner's LAN Messenger and ConnectIT projects. Source has been safely migrated to a **draft branch** from the former `BlazingSystems-Experiments` repository. Production releases and original repositories are preserved.

| Folder | Role | Current verified scope |
| --- | --- | --- |
| [apps/LAN-Messenger](apps/LAN-Messenger) | Flutter LAN chat, file transfer and voice/video calls | Legacy v0.3.5 preview source and original ConnectIT branding, with independent LAN app QA limitations |
| [ConnectIT/ConnectIT-Master-Seed](ConnectIT/ConnectIT-Master-Seed) | Go + SQLite account, device and node authority | v0.1.6 durable signed-request replay, SecureBind server flow, signed revocations |
| [ConnectIT/ConnectIT-Seed](ConnectIT/ConnectIT-Seed) | Standalone Go satellite relay | Authenticated peer federation, encrypted-envelope forwarding, signed revocation snapshots |
| [ConnectIT/ConnectIT-LAN-Messenger-Draft](ConnectIT/ConnectIT-LAN-Messenger-Draft) | Separate Dart ConnectIT auth/transport protocol staging | v0.1.6 Master client analyzed/tested; **not installed in LAN Messenger runtime** |
| [native_flutter](ConnectIT/ConnectIT-LAN-Messenger-Draft/native_flutter) | Native Flutter identity protection staging | OS-protected Ed25519 seed storage and failure-path regression tests; not released |

## Developer checks

```bash
(cd ConnectIT/ConnectIT-Master-Seed && CGO_ENABLED=1 go test ./...)
(cd ConnectIT/ConnectIT-Seed && CGO_ENABLED=0 go test ./...)
(cd ConnectIT/ConnectIT-LAN-Messenger-Draft && dart pub get && dart test test/master_auth_client_test.dart)
(cd ConnectIT/ConnectIT-LAN-Messenger-Draft/native_flutter && flutter pub get && flutter analyze && flutter test)
```

For native app setup, see the LAN Messenger project documentation and CI. The **ConnectIT transport has not been connected to the LAN Messenger's production call or file-transfer code**.

## Migration provenance and archives

The [source manifest](migration/SOURCE_MANIFEST.md) pins the original commit IDs and explains how the v0.1.6 patch was applied. Historical v0.1.1–v0.1.6 source ZIPs, Linux/Windows binaries and preview packages remain archived in the owner's private Google Drive **ConnectIT Development** folder.

Original upstream: [BlazingSystems-Experiments](https://github.com/BlazingSystems/BlazingSystems-Experiments), including ConnectIT PRs #231, #233, #234 and the separate LAN Messenger PR #235. **Do not delete those sources until independently verified and approved.**

## Security and release boundaries

**Development / NO-GO.** No new production APK/EXE is asserted. Windows call/video freeze, PiP cleanup, physical WAN/NAT acceptance, SecureBind trusted PIN/user-presence UI, production key provisioning/attestation, and device recovery remain open. Do not merge this draft branch or publish signed releases without owner acceptance and native-platform evidence.
