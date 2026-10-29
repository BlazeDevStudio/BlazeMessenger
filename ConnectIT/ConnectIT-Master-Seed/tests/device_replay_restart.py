"""Real-process Master restart replay regression, in disposable localhost state."""
import base64
import hashlib
import http.client
import json
import os
import pathlib
import secrets
import sqlite3
import subprocess
import tempfile
import time
from urllib.parse import urlsplit
from client_auth_flow import MASTER, device, enroll, run, wait, u64

PORT = 17991
BASE = f'http://127.0.0.1:{PORT}'

def signed_read(key, cert, stamp, nonce):
    url=urlsplit(BASE+'/v1/devices/self')
    body_hash=hashlib.sha256(b'').hexdigest()
    text='\n'.join(('GET',url.netloc,url.path,stamp,nonce,body_hash))
    headers={'Authorization':'Bearer '+cert,'X-Device-Time':stamp,'X-Device-Nonce':nonce,
             'X-Device-Signature':u64(key.sign(text.encode()))}
    conn=http.client.HTTPConnection(url.hostname,url.port,timeout=5)
    try:
        conn.request('GET',url.path,headers=headers)
        result=conn.getresponse()
        return result.status,json.loads(result.read(8192))
    finally:
        conn.close()

def start_server(path):
    p=subprocess.Popen([str(MASTER),'start','--dir',str(path),'--listen',f'127.0.0.1:{PORT}'],
                        stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    wait(BASE)
    return p

def stop_server(p):
    p.terminate()
    try:p.wait(timeout=5)
    except subprocess.TimeoutExpired:
        p.kill();p.wait(timeout=3)

with tempfile.TemporaryDirectory(prefix='connectit-replay-v016-') as home:
    directory=pathlib.Path(home)/'master'
    env=os.environ.copy();env['CONNECTIT_BOOTSTRAP_PASSWORD']='Temporary-TEST-ReplayPassphrase-9919'
    run('init','--dir',directory,env=env)
    env.update(CONNECTIT_OLD_ADMIN_PASSWORD=env['CONNECTIT_BOOTSTRAP_PASSWORD'],
               CONNECTIT_NEW_ADMIN_PASSWORD='Rotated-TEST-ReplayPassphrase-9920',
               CONNECTIT_PASSWORD='Account-TEST-ReplayPassword-9921')
    run('admin-rotate','--dir',directory,env=env)
    run('account-create','--dir',directory,'--nickname','ReplayFixture',env=env)
    with sqlite3.connect(directory/'connectit.sqlite3') as db:
        account=db.execute('SELECT id FROM accounts').fetchone()[0]
        # Recreate the exact upgrade situation: an existing v0.1.5 database
        # does not yet have the v0.1.6 replay table/index.
        db.execute('DROP TABLE device_request_nonces')
    server=start_server(directory)
    try:
        key,pub,installation=device()
        status,data=enroll(BASE,account,env['CONNECTIT_PASSWORD'],key,pub,installation)
        assert status==200,(status,data)
        cert=data['device_certificate']
        stamp=str(int(time.time()));nonce=u64(secrets.token_bytes(24))
        assert signed_read(key,cert,stamp,nonce)[0]==200
        stop_server(server)
        server=start_server(directory)
        assert signed_read(key,cert,stamp,nonce)[0]==409, 'replayed signed proof accepted after Master restart'
        assert signed_read(key,cert,stamp,u64(secrets.token_bytes(24)))[0]==200
        with sqlite3.connect(directory/'connectit.sqlite3') as db:
            rows=db.execute('SELECT replay_hash FROM device_request_nonces').fetchall()
            assert len(rows)>=2 and all(len(x[0])==64 for x in rows)
            assert all(nonce not in x[0] and pub not in x[0] for x in rows)
        print(json.dumps({'signed_device_first':200,'same_proof_after_master_restart':409,
                          'fresh_proof_after_restart':200,'durable_hash_only_nonces':'PASS',
                          'live_master_restart':'PASS','legacy_db_schema_migration':'PASS'}))
    finally:
        stop_server(server)
