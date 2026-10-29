# ConnectIT v0.1.6 — Persistent device-request replay protection (development only)

## Security delta
The Master previously held signed HTTP device request nonces in process-local memory. A Master restart could accept the same captured signed request again while the request timestamp was still inside its 120-second validity window.

v0.1.6 adds `device_request_nonces` in SQLite, storing only SHA-256 hashes of (`device_public_key`, 0x00, `nonce`) plus expiry (300 seconds). `admitDeviceNonce` performs cleanup, duplicate detection, the 50,000-row safety limit, and insertion inside ONE `BEGIN IMMEDIATE` transaction. A valid signature is mandatory before it is called. DB errors or missing schema fail closed (503), never falling back to memory. Duplicate signatures and concurrent requests fail with HTTP 409. This applies to authenticated device endpoints including `/v1/devices/self`, `/v1/bind/pending`, and `/v1/bind/decision`.

## Backward compatibility
The Master startup runs `migrateDeviceReplay()` for existing v0.1.5 databases; fresh `init` includes the same table and expiry index. The staged Dart HTTP client already sends a random 24-byte nonce for each signed request and needs no code change. Satellite source, binaries, federation wire format, node revocations, and the original LAN Messenger application are unchanged.

## Verified locally
- `go vet ./...`, `CGO_ENABLED=1 go test ./...` Master PASS.
- Master process rebuilt as Linux x86-64 and exercised by existing `tests/client_auth_flow.py`: PASS.
- `tests/device_replay_restart.py`: first signed proof 200, identical proof after stop/start 409, new proof 200. Migration from a simulated v0.1.5 schema (table absent): PASS; hashed-only DB rows checked.
- 32 simultaneous signed nonce admissions: exactly one accepted, 31 rejected; expiry pruning: PASS.
- Satellite `go vet ./...` and `CGO_ENABLED=0 go test ./...`: PASS (code unchanged).
- `tests/node_revoke_live.py` and `tests/signed_mesh_e2e.py`: PASS; 201 signed opaque messages, one hop, retrieval after Master offline.
- The combined Go race-test command exceeded a bounded execution time; this cycle **does not** assert the full race suite passed. No Flutter SDK is available; Flutter/Dart and physical OS credential store remains NOT verified.

## Strict limitations
A DB filesystem rollback or restored historical backup may restore older replay state; SQLite alone is NOT a trusted monotonic hardware witness. Multi-Master replication and external durable nonce consensus are not implemented. At the fixed 50,000-active-nonce capacity, new authenticated requests receive HTTP 503 until expiry cleanup frees space. No automatic node-key rotation, real-world WAN TLS tests, user notification push, OS PIN verifier, native ConnectIT APK/EXE, privacy directory or direct-only WebRTC calls yet.

GitHub reorganization is in progress. **DO NOT** automatically apply this patch to an old repo, force-push, merge, retag, or overwrite LAN Messenger builds. This file is a code handoff for the future designated canonical ConnectIT source home; the v0.1.5 handoff remains its immediate baseline, ultimately depending on draft PR #234. Development NO-GO.
