# ConnectIT Native Credential Store — v0.1.7 development

Android/Windows Flutter adapter for the independent ConnectIT Master client.
No import from LAN Messenger main.dart. This is NOT an integrated APK, a
Windows production installer, or a SecureBind approval UI.

- Generates a new Ed25519 private seed and cryptographically random 24-byte
  installation identifier on first launch only.
- Stores one versioned JSON record via flutter_secure_storage. Subsequent
  launches recreate the same signer, identity and installation identifier.
- Verifies saved public-key consistency by deriving from the private seed;
  malformed or unavailable storage is fatal, not an invitation to silently
  reenroll or fall back to unencrypted SharedPreferences/local files.
- Matches the existing ConnectITSecureSigner interface. Does NOT modify LAN
  Messenger's existing LAN X25519, call/transfer state, or peer identity.
- Android and Windows use the plugin's platform-protected storage. Keys exist
  in the app process memory while signing; this does not guarantee that keys
  are nonextractable or hardware-backed. No real device or biometric test yet.
- Make sure Android Auto Backup does not restore encrypted records without the
  corresponding Android keystore. Windows files may be tied to an OS account.
- A separate OS-enforced user-presence/PIN verifier, authenticated Master key
  pin provisioning, account recovery/revocation and full UI are STILL REQUIRED
  before enabling SecureBind approvals or replacing LAN Messenger credentials.
- No web target. Native Flutter binaries need physical Android + Windows smoke.

## Developer verification

From this folder: flutter pub get && flutter analyze && flutter test

The Flutter CI job uses a deterministic fake secret store for API and failure
tests; it does not represent proof of native Android/Windows secure keystore
behavior.


## v0.1.8 staging: local SecureBind PIN check (not a native release)

The new `connectit_local_pin_gate.dart` implements a **device-public-key-bound**
8–12-digit application PIN verifier. It uses a fresh 24-byte random salt and
PBKDF2-HMAC-SHA256 (210,000 iterations). Only salted derivation material and
lockout state are saved through the existing OS-protected ConnectITSecretStore.
It never stores or sends a plaintext PIN. Malformed or unavailable storage fails
closed, and new configuration refuses to overwrite an existing record.

A failed verification increments a persisted counter. Five consecutive failures
lock approval for 15 minutes; an expired lock is cleared only by a successful
PIN check. PIN changes require the existing PIN and explicit consent. These
read/modify/write operations are serialized across instances **inside a single
Dart isolate**, not across OS processes, isolates, or restored disk snapshots.
The OS clock can be manipulated and no external monotonic witness exists.

`connectit_securebind_decision.dart` is an **optional isolated integration
bridge** to `ConnectITMasterAuthClient.decideBinding`. It requires explicit
per-decision target confirmation and checks that PIN and Ed25519 signing
identities agree before requesting a signed Master action. The Master remains
responsible for certificate, signature, device, countdown and replay checks.

**Safety boundary:** A software PIN plus `flutter_secure_storage` is NOT
hardware-backed biometric/user-presence enforcement. The UI can forge a boolean,
the process can be compromised, the OS clock can change, and PIN-derived hashes
remain subject to offline attack after full OS storage compromise. Do not enable
unattended SecureBind approvals or claim a production-ready local-PIN or
attestation system on this basis. Real Android and Windows native prompt tests,
storage restore hardening, strong PIN recovery, operator approval policy and
native UI verification remain outstanding.

Run `flutter analyze` and `flutter test` from `native_flutter` to inspect its
unit-test surface. The workflow runs against fake encrypted-storage adapters;
those tests do **not** validate actual mobile/desktop keystore behavior. Existing
LAN Messenger call/video/file functionality is not touched by this module.
