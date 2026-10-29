package main

import (
	"crypto/sha256"
	"encoding/hex"
	"strconv"
	"strings"
)

// Durable device-proof replay protection. Both the validated public key and
// nonce are hashed before storage, avoiding a plaintext replay-credential log.
// SQLite PRIMARY KEY enforces uniqueness across goroutines and process restarts.
const deviceReplayTTL = int64(300)
const deviceReplayLimit = 50000
const replayDDL = `CREATE TABLE IF NOT EXISTS device_request_nonces (
    replay_hash TEXT NOT NULL PRIMARY KEY,
    expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS device_request_nonces_expiry ON device_request_nonces(expires_at);`

type nonceAdmit uint8

const (
	nonceAccepted nonceAdmit = iota
	nonceReplay
	nonceUnavailable
)

func migrateDeviceReplay(db *DB) error { return db.script(replayDDL) }

// Call ONLY after verifying the certificate, request timestamp and request-bound
// Ed25519 signature; do not insert unauthenticated values into persistent state.
func (a *api) admitDeviceNonce(publicKey, nonce string, now int64) nonceAdmit {
	if !validPub(publicKey) || !validNonce(nonce) {
		return nonceUnavailable
	}
	digest := sha256.Sum256([]byte(publicKey + "\x00" + nonce))
	key := hex.EncodeToString(digest[:])
	result := nonceUnavailable
	err := a.db.transaction(func() error {
		// Delete expired rows inside the same transaction as insertion so
		// retries during concurrent requests cannot slip through a gap.
		if _, e := a.db.query("DELETE FROM device_request_nonces WHERE expires_at <= ?", now); e != nil {
			return e
		}
		existing, e := a.db.query("SELECT expires_at FROM device_request_nonces WHERE replay_hash=?", key)
		if e != nil {
			return e
		}
		if len(existing) != 0 {
			until, e := strconv.ParseInt(strings.TrimSpace(existing[0]["expires_at"]), 10, 64)
			if e != nil || until > now {
				result = nonceReplay
				return nil
			}
			return nil // impossible after purge; fail closed
		}
		size, e := a.db.query("SELECT COUNT(*) AS count FROM device_request_nonces")
		if e != nil || len(size) != 1 {
			return e
		}
		count, e := strconv.ParseInt(size[0]["count"], 10, 64)
		if e != nil || count >= deviceReplayLimit {
			return nil
		} // fail closed under pressure
		if _, e = a.db.query("INSERT INTO device_request_nonces(replay_hash,expires_at) VALUES(?,?)", key, now+deviceReplayTTL); e != nil {
			return e
		}
		result = nonceAccepted
		return nil
	})
	if err != nil {
		return nonceUnavailable
	}
	return result
}
