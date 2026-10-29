# ConnectIT v0.1.5 — First-device login and SecureBind client staging

**Status:** Go Master endpoint and live Python client protocol regression tested. Flutter Dart implementation is staged, NOT analyzer-compiled, not wired into LAN Messenger release, and not deployable with plaintext keys. No platform-OS hardware keystore or PIN verifier has been provided here.

## Master endpoint addition

Authenticated `GET /v1/devices/self` returns **only** `account_id`, `device_id`, `server_time`. It checks the existing Master-signed bearer token and the request-bound Ed25519 proof, replay nonce, active device state and account. Unauthenticated requests are denied. A previously revoked signer is denied. The returned internal `device_id` is REQUIRED by the original `ConnectIT-SecureBind-v1` approval canonical signing format. Original v0.1.4 API had no authenticated way for client to learn this ID, preventing implementation of its approval UI.

## Dart staged adapter

`lib/connectit/master_auth_client.dart` now implements real HTTP request shapes for: first device enrollment, client-side pin verification of the Master-issued Ed25519 JWT, second device binding start, trusted self lookup, pending approvals, explicit local-PIN-gated signed decision, and time-gated binding finalization. It refuses non-loopback HTTP, embeds no bootstrap admin passwords, performs no implicit OS keystore fallback, does not send a local PIN to Master, and follows no redirects.

The implementer MUST supply `ConnectITSecureSigner` using OS-protected Ed25519 private key and installation secret storage. PIN verification must also be OS-protected and must never be replaced with a function that always returns true. HTTPS certificate validation and a **trusted out-of-band Master signing public key pin** are required; `/v1/public-key` is not a trust bootstrap by itself. Do not log credentials or tokens. A device association request should be shown in the UI and never automatically approved. The existing LAN-only app must remain independently usable.

## Verification

Linux Go Master `go test ./...`/`go vet ./...`; localhost real `tests/client_auth_flow.py` passes enrollment, pin-validated JWT, missing/bad auth, self lookup, second-device 409, pending list, early finalization fail, local approval, double approval fail, finalized second certificate, and revocation of original active device. **Four-hour countdown accelerated only by editing a temporary SQLite regression fixture**, not by an HTTP option, server policy or production bypass. Native Flutter analyzer/compile and OS-specific secure keystore/PIN flows remain unverified.

## Important residual risks

- Account passwords sent in request JSON **require HTTPS** in non-loopback deployments; a valid Master token does not substitute for HTTPS.
- Signed user certificate renewal is currently manual `/v1/enroll` for existing unchanged device; no background refresh scheduling.
- Master replay cache is in process memory, not a durable witness across restart.
- Real SecureBind notifications, a trusted platform PIN verifier, public user directory, a five-hop privacy-preserving discovery protocol, and direct-only internet media transport still absent.
- Distinguish user account ID (10 digits) from database internal device ID and local LAN peer ID; do not interchange them.
