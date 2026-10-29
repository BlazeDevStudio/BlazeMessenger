package main

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestDurableReplayAtomicConcurrencyAndExpiry(t *testing.T) {
	a, dir, _, _, _ := testSystem(t)
	_, device, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().Unix()
	nonce := rnd(24)
	var accepted, rejected, unavailable atomic.Int32
	var wait sync.WaitGroup
	for i := 0; i < 32; i++ {
		wait.Add(1)
		go func() {
			defer wait.Done()
			switch a.admitDeviceNonce(pub64(device), nonce, now) {
			case nonceAccepted:
				accepted.Add(1)
			case nonceReplay:
				rejected.Add(1)
			default:
				unavailable.Add(1)
			}
		}()
	}
	wait.Wait()
	if accepted.Load() != 1 || rejected.Load() != 31 || unavailable.Load() != 0 {
		t.Fatalf("atomic nonce race accepted=%d rejected=%d unavailable=%d", accepted.Load(), rejected.Load(), unavailable.Load())
	}
	rows, err := a.db.run("SELECT replay_hash,expires_at FROM device_request_nonces")
	if err != nil || len(rows) != 1 || len(rows[0]["replay_hash"]) != 64 || rows[0]["replay_hash"] == nonce {
		t.Fatalf("nonce must only be stored as a hash: %v %v", rows, err)
	}
	a.db.close()
	again, err := openDB(dbpath(dir))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(again.close)
	a.db = again
	if got := a.admitDeviceNonce(pub64(device), nonce, now); got != nonceReplay {
		t.Fatalf("nonce replay survived restart? result=%d", got)
	}
	// Simulate a naturally expired row; no arbitrary clock bypass in prod.
	if _, err := a.db.run("UPDATE device_request_nonces SET expires_at=?", now-1); err != nil {
		t.Fatal(err)
	}
	if got := a.admitDeviceNonce(pub64(device), nonce, now); got != nonceAccepted {
		t.Fatalf("expired nonce was not pruned: %d", got)
	}
	if got := a.admitDeviceNonce(pub64(device), rnd(24), now); got != nonceAccepted {
		t.Fatalf("new signed request refused: %d", got)
	}
}

func TestSignedHTTPRequestReplayFailsAfterMasterRestart(t *testing.T) {
	a, dir, account, device, pw := testSystem(t)
	enrollmentNonce := rnd(24)
	enrollment := map[string]any{
		"username": account, "password": pw, "device_public_key_b64": pub64(device),
		"installation_id": rnd(24), "nonce": enrollmentNonce,
		"proof_signature_b64": signDevice(device, "ConnectIT-enroll-v1\n"+account+"\n"+enrollmentNonce),
	}
	credential := submit(t, a, "/v1/enroll", enrollment, 200)["device_certificate"].(string)
	unix := strconv.FormatInt(time.Now().Unix(), 10)
	nonce := rnd(24)
	empty := sha256.Sum256(nil)
	canonical := "GET\n127.0.0.1:7070\n/v1/devices/self\n" + unix + "\n" + nonce + "\n" + hex.EncodeToString(empty[:])
	signature := signDevice(device, canonical)
	send := func(instance *api, sig string) (int, map[string]any) {
		req := httptest.NewRequest(http.MethodGet, "http://127.0.0.1:7070/v1/devices/self", nil)
		req.Header.Set("Authorization", "Bearer "+credential)
		req.Header.Set("X-Device-Time", unix)
		req.Header.Set("X-Device-Nonce", nonce)
		req.Header.Set("X-Device-Signature", sig)
		rec := httptest.NewRecorder()
		mux := http.NewServeMux()
		instance.routes(mux)
		mux.ServeHTTP(rec, req)
		var body map[string]any
		if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
			t.Fatal(err)
		}
		return rec.Code, body
	}
	if status, _ := send(a, "invalid"); status != http.StatusUnauthorized {
		t.Fatalf("bad proof bypassed signature gate: %d", status)
	}
	if status, _ := send(a, signature); status != http.StatusOK {
		t.Fatalf("first signed proof rejected: %d", status)
	}
	a.db.close()
	reopened, err := openDB(dbpath(dir))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(reopened.close)
	a.db = reopened
	if err := migrateDeviceReplay(a.db); err != nil {
		t.Fatal(err)
	}
	if status, body := send(a, signature); status != http.StatusConflict {
		t.Fatalf("signed replay after restart accepted: %d %v", status, body)
	}
}
