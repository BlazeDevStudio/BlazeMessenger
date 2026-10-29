# ConnectIT — Android acceptance app (v0.1.10 development)

Independent Android-only test host for existing ConnectIT Master API, v0.1.6 SQLite replay gate, v0.1.7 OS-backed signer, v0.1.8 local PIN and v0.1.9 SecureBind review UI. This does NOT modify LAN Messenger, and its Android debug APK is NOT a production build.

## Branding — approved source of truth

Direct byte-for-byte copies of the owner-approved BlazeDevStudio v3 Drive vector kit, folder `BlazeDevStudio Branding/BlazeDevStudio/`:
- `assets/brand/main-plain.svg`: PRIMARY B icon (SHA-256: 55771df5907b913e3ae00221991237ab29d4a41679f492bbb43a9ecc607e9afd).
- `assets/brand/sublogo-network.svg`: NETWORK companion mark (SHA-256: 75e4375e0694d366163eb46565f14d2bdbcab1d070e96bf6e7ca797e68c6c559).

Preserve primary B blue ribbon, top white segment, white central triangle, lower white cutout, ruby marker and margins. No SVG paths were reconstructed/edited. The Z is auxiliary only and not used in this Android launcher. Palette: navy #090F1D, birthstone blue #72B2FF, electric blue #1671E6, support cyan #58CFFF, off-white #F4F7FF, ruby #F10843. The launcher raster is generated from the unchanged B SVG in CI.

## Manual security acceptance

1. Provision a *development* Master with a fresh ten-digit account. Verify its Ed25519 signing key **out of band** and enter its exact 32-byte public key in standard base64. Never trust a key merely because the same server returned it over HTTP.
2. Enter Master HTTPS URL (local HTTP may be used only over loopback through an Android forwarded port), ten-digit account ID, and password. Leave passwords out of screenshots.
3. Use **Enroll first device**, if this is truly the first trusted device, or **Start binding** with explicit user consent for a second device. No automatic enrollment fallback.
4. On an already-authorized testing device with a fresh session, open **Review pending devices**, configure the local PIN, inspect the entire target key and challenge, then confirm each decision.
5. For pending newer device, use **Finalize binding** after Master-defined approval intervals finish. Verify the newly signed certificate and device self identity. No 4-hour bypass.

## Limits / NO-GO

- No automatic account creation, session recovery after restart, delegated Master trust-pin provisioning, or production key rotation. Passwords and sessions are memory-only and not written to app preferences.
- The app's PIN uses platform-protected storage but is not proof of biometric or hardware-backed user presence; local lockout remains vulnerable to OS-clock/disk rollback.
- Native Android APK debug signing is not a production signer; physical dual-device authentication, OS keystore restoration, TLS public WAN acceptance, media calling and Android notification/background testing are not proven.
- Do not merge, publish, enable production payments, or change existing LAN Messenger packages based solely on CI.
