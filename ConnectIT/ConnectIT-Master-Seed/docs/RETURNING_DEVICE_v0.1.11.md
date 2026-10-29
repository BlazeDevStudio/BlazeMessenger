# ConnectIT v0.1.11 — Returning-device authentication

## Client contract

POST /v1/auth/returning, JSON:
- username: ten-digit account ID
- password: existing account secret; transmitted only over verified HTTPS or localhost test transport
- device_public_key_b64: original installed Ed25519 public key
- installation_id: original random OS-protected installation token
- nonce: fresh base64url entropy (at least 16 bytes)
- proof_signature_b64: Ed25519 base64url over exact text:

    ConnectIT-returning-auth-v1\n<account_id>\n<nonce>\n<installation_id>

HTTP 200 includes a fresh seven-day Master-signed device certificate and
status=returning_existing_device. The Dart client checks the pinned Master
signature, issuer, audience, subject, original device public key and expiry;
then signed GET /v1/devices/self checks current active device trust.

## Fail-closed behavior

Only an already-active device whose exact key and HMAC-hashed installation
token match the Master's existing SQLite device record can sign in.
This endpoint never inserts or updates a device, creates a first enrollment,
changes installation ownership, overrides revocation or approves SecureBind.

Bad password, unsigned/malformed proof, reused nonce and unavailable durable
nonce persistence reject the request; no fallback to plaintext HTTP is allowed.
The original key remains responsible for signed requests.

The Android client uses loadExisting(), refusing missing, lost or corrupted
native OS-backed credentials; it never silently creates a new key or calls
enrollment as a fallback. New devices require explicit trusted-device SecureBind.

## Verification and limitations

Go and real localhost Master tests: genuine reauthentication, replay denial,
new-key denial, mutated installation token, invalid password, revocation and
stable device count. Dart tests: missing/corrupted OS identity fail closed.
Android widget tests verify an explicit returning action and preflight checks.
The 17 prior native credential/SecureBind tests and original branding source
are retained.

Reauthentication requires entering account credentials after restart.
No persistent session token, physical Android keystore proof, secure OS
user-presence verification, production APK signing, Windows release or WAN
messaging acceptance is established. Development release status is NO-GO.
