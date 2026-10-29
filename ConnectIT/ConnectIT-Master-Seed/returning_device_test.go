package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"testing"
)

// Source-linked endpoint coverage: no registration, renewal or escalation is
// allowed without proof of the original key, installation token and password.
func returningPayload(id, pw, install, nonce string, dev ed25519.PrivateKey) map[string]any {
	return map[string]any{
		"username": id,
		"password": pw,
		"installation_id": install,
		"device_public_key_b64": pub64(dev),
		"nonce": nonce,
		"proof_signature_b64": signDevice(dev, "ConnectIT-returning-auth-v1\n"+id+"\n"+nonce+"\n"+install),
	}
}

func TestReturningDeviceMustAlreadyBeActive(t *testing.T) {
	a, _, id, dev, pw := testSystem(t)
	install := rnd(24)
	// Returning login must NEVER auto-enroll the first trusted device.
	submit(t, a, "/v1/auth/returning", returningPayload(id, pw, install, rnd(24), dev), 403)
	rows, err := a.db.run("SELECT id FROM devices")
	if err != nil || len(rows) != 0 {
		t.Fatal("returning login created a device", err)
	}

	enrollNonce := rnd(24)
	enrolled := submit(t, a, "/v1/enroll", map[string]any{
		"username": id, "password": pw, "device_public_key_b64": pub64(dev),
		"installation_id": install, "nonce": enrollNonce,
		"proof_signature_b64": signDevice(dev, "ConnectIT-enroll-v1\n"+id+"\n"+enrollNonce),
	}, 200)
	if enrolled["device_certificate"] == "" {
		t.Fatal("original device enrollment failed")
	}

	good := returningPayload(id, pw, install, rnd(24), dev)
	out := submit(t, a, "/v1/auth/returning", good, 200)
	if out["status"] != "returning_existing_device" || out["device_certificate"] == "" {
		t.Fatal("no new signed certificate")
	}
	// Persisted replay ledger admits exactly one request proof.
	submit(t, a, "/v1/auth/returning", good, 409)

	// Device identity is stable: refreshing an auth certificate must not
	// create a second device or update its existing identifier.
	rows, err = a.db.run("SELECT id FROM devices WHERE account_id=?", id)
	if err != nil || len(rows) != 1 {
		t.Fatal("returning login mutated device count", err)
	}
	originalID := rows[0]["id"]

	// Password knowledge by itself never admits an unbound device.
	_, impostor, err := ed25519.GenerateKey(rand.Reader)
	if err != nil { t.Fatal(err) }
	submit(t, a, "/v1/auth/returning", returningPayload(id, pw, rnd(24), rnd(24), impostor), 403)
	// Original private key but a different installation token is also denied.
	submit(t, a, "/v1/auth/returning", returningPayload(id, pw, rnd(24), rnd(24), dev), 403)

	wrong := returningPayload(id, "incorrect-password", install, rnd(24), dev)
	submit(t, a, "/v1/auth/returning", wrong, 401)

	// Mutating installation identity without resigning MUST fail.
	tampered := returningPayload(id, pw, install, rnd(24), dev)
	tampered["installation_id"] = rnd(24)
	submit(t, a, "/v1/auth/returning", tampered, 400)

	// Old v0.1.5 enrollment proof has the wrong domain separator.
	badDomain := returningPayload(id, pw, install, rnd(24), dev)
	badDomain["proof_signature_b64"] = signDevice(dev, "ConnectIT-enroll-v1\n"+id+"\n"+badDomain["nonce"].(string))
	submit(t, a, "/v1/auth/returning", badDomain, 400)

	// Revocation takes precedence over a still-known private signing key.
	_, err = a.db.run("UPDATE devices SET state='revoked' WHERE id=?", originalID)
	if err != nil { t.Fatal(err) }
	submit(t, a, "/v1/auth/returning", returningPayload(id, pw, install, rnd(24), dev), 403)
	rows, err = a.db.run("SELECT id FROM devices")
	if err != nil || len(rows) != 1 || rows[0]["id"] != originalID {
		t.Fatal("returning login changed device ownership", err)
	}
}

func TestReturningDeviceRefusesMethodOrBadProof(t *testing.T) {
	a, _, id, dev, pw := testSystem(t)
	payload := returningPayload(id, pw, rnd(24), rnd(24), dev)
	payload["proof_signature_b64"] = "AAAA"
	submit(t, a, "/v1/auth/returning", payload, 400)
}
