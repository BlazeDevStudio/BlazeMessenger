# LAN Messenger — Source Structure & Cleanup Contract

**Scope:** `apps/LAN-Messenger` only.  
**Purpose:** make production hardening easier to review **before** debugging the unresolved
Windows/Android call issues. This is structural refactoring only, not a security
certification or user-facing preview release.

## Public Dart library boundaries

| Entry point | Responsibility | Private implementation | Compatibility |
| --- | --- | --- | --- |
| `lib/src/protocol.dart` | v1 network constants, random IDs, public-key fingerprints, path-safe file names, discovery payload | `protocol/peer.dart`, `protocol/chat_message.dart` | `Peer`, `ChatMessage`, `announcement()`, `safeFileName()`, v1 framing and on-disk record keys unchanged |
| `lib/src/identity.dart` | Durable device X25519 identity; name/load/rename | `identity/peer_cipher.dart` | `PeerCipher`, X25519 + HKDF + AES-GCM and caller imports unchanged; **no upgrade in cryptographic guarantees** |
| `lib/src/node.dart` | UDP discovery, pinned peer routing, authenticated HTTP, call events, resumable chunk state, file received callbacks | `node/file_transfer_state.dart` | `LanNode`, `TransferProgress`, `_ReceiveState`, `_CompletedIncomingFile` and network protocol unchanged |
| `lib/src/intercom.dart` | SDP/ICE/WebRTC and renderer lifecycle, call-specific remote control | existing helpers `call_transport_gate.dart`, `call_peer_watchdog.dart`, `serial_async_gate.dart` | No call-state modifications in cleanup |
| `lib/main.dart` | Single app coordinator, desktop presentation, notification bridge, UI | current large state class; separate later by bounded component | No UI behavior change in cleanup |
| `tool/prepare_platforms.py` | Idempotent generated-platform patching | Keeps removal of old Android overlay from generated trees | Removed the unused `tool/AndroidCallOverlay.kt` source template, **not** its cleanup guard |

### Why `part` is used temporarily

Dart `part` files keep **one library** and therefore preserve existing imports,
private members and serialized classes. This is deliberate low-risk scaffolding.
When the public/private boundaries are reviewed and runtime acceptance is green,
the files can become independently imported libraries with explicit dependency
injection. Moving them now and changing crypto, routing and state in one commit
would prevent a credible regression diagnosis.

### Refactor rules

1. **Do not change wire, identity or stored data while moving code.** Keep v1
   announcement, X25519 public keys, AEAD envelope, file hash/receipt behavior and
   saved chats backward compatible. Keep the exact same incoming/outgoing consent.
2. **Separate ownership:** `LanNode` owns networking; `Intercom` owns media;
   native Android/Windows lifecycle is a platform adapter; Flutter UI observes
   state, not raw socket/MediaStream lifetime.
3. **Do not bury errors.** Normalize exception ownership later in dedicated
   patches; no catch-all rewrite that hides an app crash or socket failure.
4. **No copied app source:** LocalSend, KDE Connect, Jami and Signal are public
   architecture references only. A dependency or adapted algorithm requires
   independent design review and license/provenance assessment.
5. **No production claim:** all four Android device-emulator acceptance jobs are
   failing at the preceding baseline, and physical Windows↔Android calling is
   unverified. A successful build or source-only test is not field acceptance.

## Next bounded codebase-cleanup slices (separate follow-up reviews)

- **LAN-CLEAN-02:** Extract `main.dart` (about 2,300 lines) into independent
  chat, settings, attachments and call presentation components with callbacks
  and one call-session authority. Avoid creating extensions that can accidentally
  bypass lifecycle ownership.
- **LAN-CLEAN-03:** Divide `node.dart` by transport, discovery and transfer
  services once endpoint pinning and transfer proxy tests are stable.
- **LAN-CLEAN-04:** Divide `intercom.dart` (about 950 lines) into capture,
  signaling, renderer and teardown subsystems with serialized ownership;
  preserve native crashes and cleanup logs for comparison.
- **LAN-CLEAN-05:** Consolidate native Android notifications and PiP entry into
  separately unit-testable platform adapter methods; trim duplicated icon
  rendering and versioned channel creation only after tests.
- **LAN-CLEAN-06:** Pin lint/format baselines without a noisy repository-wide
  reformat; validate case-sensitive source paths and SPDX/license inventory.

## Next gates after this cleanup

Execute `flutter analyze` and `flutter test` for Dart model compatibility,
run release builds with the existing six-job CI, and review the actual source-linked
failing Android-device jobs. Keep the independently green Docker socket tests
and Windows WER diagnostics. Do **not** disable emulator acceptance or claim
physical hardware proof.
