# ConnectIT v0.1.12 — Android emulator acceptance

**Scope:** Test the actual Android implementation of flutter_secure_storage, Ed25519 identity persistence, SecureBind PIN failure counter and fresh Master-enrolled device sign-in across two separate app test invocations.

1. Returning-only loadExisting() refuses an empty or corrupted OS secure store without generating a key.
2. First explicit loadOrCreate() writes an identity; another native plugin instance retrieves the same key and token and proves an Ed25519 signature.
3. A failed local PIN attempt persists across newly constructed OS-protected store and gate objects.
4. A disposable GitHub CI Master, loopback-only port mapped through Android ADB reverse, issues the first signed certificate to an emulator-generated key.
5. A separate Flutter test process invokes returning-device auth, verifies the original account and device ID, and must leave exactly ONE Master device row.

All credentials, storage and certificates are ephemeral CI fixtures; no production passwords, accounts or keys are requested. The approved BlazeDevStudio v3 primary B and network vector artwork are unchanged, and their exact fingerprints are checked in CI.

## Security/acceptance boundaries

- Android emulator execution is **not** physical Android KeyStore hardware, biometric/user-presence, backup/restore, OEM firmware, or rooted-device acceptance.
- ADB reverse and debug-only Android cleartext traffic allow only localhost test Master. The Dart client continues to reject remote plaintext HTTP.
- Two Flutter invocations are not equivalent to a device power cycle; app data must be demonstrably preserved, never silently regenerated.
- Native PIN persistence doesn't solve OS clock manipulation, disk rollback or multi-process atomicity.
- No Windows build, WAN calling/video, LAN Messenger runtime edit, production APK signing, deployment, release or merge.

**Status:** draft NO-GO pending exact-head emulator results and later physical-device verification.
