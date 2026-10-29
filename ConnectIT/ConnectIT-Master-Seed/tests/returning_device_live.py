"""Standalone localhost Master smoke: returning auth NEVER creates new devices.

Production clock, SecureBind countdown and device trust database are not bypassed.
"""
import base64
import json
import os
import pathlib
import secrets
import socket
import sqlite3
import subprocess
import tempfile

from client_auth_flow import MASTER, device, enroll, run, send, u64, verify_cert, wait

def returning(base, account, password, key, pub, install, nonce=None,
              sign_install=None):
    nonce = nonce or u64(secrets.token_bytes(24))
    signed_install = sign_install if sign_install is not None else install
    proof = 'ConnectIT-returning-auth-v1\n' + account + '\n' + nonce + '\n' + signed_install
    payload = dict(username=account, password=password,
                   device_public_key_b64=pub, installation_id=install,
                   nonce=nonce, proof_signature_b64=u64(key.sign(proof.encode())))
    return send(base + '/v1/auth/returning', 'POST', payload)

def main():
    assert MASTER.is_file(), "Build Master binary first"
    with socket.socket() as sk:
        sk.bind(('127.0.0.1', 0))
        port = sk.getsockname()[1]
    base = f'http://127.0.0.1:{port}'
    with tempfile.TemporaryDirectory(prefix='connectit-returning-') as root:
        state = pathlib.Path(root) / 'master'
        env = os.environ.copy()
        env['CONNECTIT_BOOTSTRAP_PASSWORD'] = 'Return-Test-Admin-Initial-472'
        run('init', '--dir', state, env=env)
        env['CONNECTIT_OLD_ADMIN_PASSWORD'] = env['CONNECTIT_BOOTSTRAP_PASSWORD']
        env['CONNECTIT_NEW_ADMIN_PASSWORD'] = 'Return-Test-Admin-Rotated-288'
        run('admin-rotate', '--dir', state, env=env)
        password = 'Return-Test-Account-Password-9112'
        env['CONNECTIT_PASSWORD'] = password
        run('account-create', '--dir', state, '--nickname', 'ReturningAuthFixture', env=env)
        with sqlite3.connect(state / 'connectit.sqlite3') as cx:
            account = cx.execute('SELECT id FROM accounts').fetchone()[0]
        issuer = base64.b64decode((state / 'public.key').read_text().strip())
        server = subprocess.Popen([str(MASTER), 'start', '--dir', str(state),
                                   '--listen', f'127.0.0.1:{port}'],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            wait(base)
            key, pub, install = device()
            code, _ = returning(base, account, password, key, pub, install)
            assert code == 403, f'unknown first device authenticated: {code}'
            code, result = enroll(base, account, password, key, pub, install)
            assert code == 200, code
            verify_cert(result['device_certificate'], issuer, account, pub)
            nonce = u64(secrets.token_bytes(24))
            code, renewed = returning(base, account, password, key, pub, install, nonce)
            assert code == 200, (code, renewed)
            verify_cert(renewed['device_certificate'], issuer, account, pub)
            assert renewed['status'] == 'returning_existing_device'
            code, _ = returning(base, account, password, key, pub, install, nonce)
            assert code == 409, f'proof replay accepted: {code}'
            code, _ = returning(base, account, password, key, pub, u64(secrets.token_bytes(24)))
            assert code == 403, f'replaced installation accepted: {code}'
            code, _ = returning(base, account, password, key, pub, install,
                                sign_install=u64(secrets.token_bytes(24)))
            assert code == 400, f'tampered install binding accepted: {code}'
            code, _ = returning(base, account, 'bad-password', key, pub, install)
            assert code == 401, f'wrong password accepted: {code}'
            alien, alien_pub, alien_install = device()
            code, _ = returning(base, account, password, alien, alien_pub, alien_install)
            assert code == 403, f'new key could sign in: {code}'
            with sqlite3.connect(state / 'connectit.sqlite3') as cx:
                rows = cx.execute('SELECT id FROM devices WHERE account_id=?', (account,)).fetchall()
            assert len(rows) == 1, f'returning auth changed device count: {len(rows)}'
            run('device-revoke', '--dir', state, '--device-id', rows[0][0], env=env)
            code, _ = returning(base, account, password, key, pub, install)
            assert code == 403, f'revoked device signed in: {code}'
            print(json.dumps({
                'new_device_denied': 'PASS', 'master_signed_renewed_cert': 'PASS',
                'replay_denied': 'PASS', 'identity_and_install_binding': 'PASS',
                'invalid_password_denied': 'PASS', 'device_count_preserved': 'PASS',
                'revocation_denied': 'PASS', 'server_mode': 'localhost_fixture'
            }))
        finally:
            if server.poll() is None:
                server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()

if __name__ == '__main__':
    main()
