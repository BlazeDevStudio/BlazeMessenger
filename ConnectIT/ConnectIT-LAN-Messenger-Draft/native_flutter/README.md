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
