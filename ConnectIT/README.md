# ConnectIT — independent development products

> Development-only source. No approved production release, signing authority, public deployment, or end-to-end Windows/Android client is established.

## Current source map (2026-10-31)

- `ConnectIT-Master-Seed/`: Go/SQLite account, device enrollment, signed certificates and binding authority.
- `ConnectIT-Seed/`: Go satellite relay and signed federation experiments.
- `ConnectIT-LAN-Messenger-Draft/lib/connectit/`: isolated Dart Master protocol adapter (not the shipping LAN Messenger).
- `ConnectIT-LAN-Messenger-Draft/native_flutter/`: native-credential and SecureBind staging package.
- `ConnectIT-LAN-Messenger-Draft/android_smoke/`: separate, **debug-only** Flutter authentication acceptance app (v0.1.12), with modular entrypoint and device-access page. CI generates the native Android host rather than storing generated platform code in the repository.

The historical v0.1.3 federation milestones below remain relevant to the Seed protocol. They do **not** describe the current Android staging milestone or establish shipping readiness. Main LAN Messenger sources and branding are independent.

## Historical federation milestone (v0.1.3)

**Development only; NO-GO for production.**

Separate, individually distributable source trees: `ConnectIT-Master-Seed/` (SQLite and account authority), `ConnectIT-Seed/` (Go satellite relay), `ConnectIT-LAN-Messenger-Draft/` (disabled-by-default Flutter interface draft). A test-only Android authentication host is built separately; no complete ConnectIT client or production native app is established. The original LAN Messenger code is untouched.

v0.1.2 introduced Master-signed device revocation cache; v0.1.3 adds Master-authorized short-lived Seed certificates, signed peer GET/response exchange with explicit peer ID allowlists, replay controls, no remote shared-password fallback. See `ConnectIT-Seed/docs/FEDERATION_v0.1.3.md` for commands and threat limitations.

To run CI locally: build Master and Seed in their own `go.mod` directories; run `go test ./...` and `go vet ./...`. See `ConnectIT-Master-Seed/tests/signed_mesh_e2e.py` for 201-message Master→Seed-A→Seed-B smoke. A real internet TLS deployment, peer certificate revocation, key protection, automatic renewal, E2EE native client, SecureBind UI, NAT traversal, five-hop discovery and real Android/Windows integration remain blocked.

Historical audit trail: v0.1.2 draft PR #231; v0.1.3 draft PR is stacked and should not be merged until dependency accepted. Binary/source ZIPs are stored in user's private Drive under `ConnectIT Development`; no release artifact or signing key should be committed here.
