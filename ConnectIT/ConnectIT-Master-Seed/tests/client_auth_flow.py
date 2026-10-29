"""Real Master localhost client auth / SecureBind integration test.

Requires cryptography, Master Linux executable; time shift is SQLITE TEST FIXTURE
ONLY, never a bypass exposed to real clients. No credential material is printed.
"""
import base64, hashlib, http.client, json, os, pathlib, secrets, sqlite3, subprocess, tempfile, time
from urllib.parse import urlsplit
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
from cryptography.hazmat.primitives import serialization

MASTER = pathlib.Path(__file__).resolve().parents[1] / 'bin/connectit-master'

def b64(b): return base64.b64encode(b).decode('ascii')
def u64(b): return base64.urlsafe_b64encode(b).rstrip(b'=').decode('ascii')
def decu(s): return base64.urlsafe_b64decode(s + '='*(-len(s)%4))

def device():
    private = Ed25519PrivateKey.generate()
    pub = b64(private.public_key().public_bytes(serialization.Encoding.Raw,serialization.PublicFormat.Raw))
    return private,pub,u64(secrets.token_bytes(32))

def send(url, method, data=None, key=None, cert=None, override_sig=None):
    u=urlsplit(url)
    assert u.scheme=='http' and u.hostname in ('127.0.0.1','localhost')
    body=json.dumps(data,separators=(',',':')).encode() if data is not None else b''
    headers={'Content-Type':'application/json'} if data is not None else {}
    if key is not None:
        stamp=str(int(time.time()));nonce=u64(secrets.token_bytes(24))
        uri=u.path + ('?' + u.query if u.query else '')
        canonical='\n'.join([method,u.netloc,uri,stamp,nonce,hashlib.sha256(body).hexdigest()]).encode()
        signature = override_sig if override_sig is not None else u64(key.sign(canonical))
        headers.update({'Authorization':'Bearer '+cert, 'X-Device-Time':stamp,
                        'X-Device-Nonce':nonce,'X-Device-Signature':signature})
    conn=http.client.HTTPConnection(u.hostname,u.port,timeout=6)
    try:
        conn.request(method,u.path + ('?' + u.query if u.query else ''),body if data is not None else None, headers)
        resp=conn.getresponse()
        raw=resp.read(256*1024)
        return resp.status,json.loads(raw)
    finally:conn.close()

def wait(base):
    for _ in range(80):
        try:
            status,_=send(base+'/healthz','GET')
            if status==200:return
        except Exception:pass
        time.sleep(.075)
    raise RuntimeError('Master not healthy')

def run(*args,env):
    return subprocess.run([str(MASTER),*map(str,args)],env=env,capture_output=True,text=True,check=True)

def verify_cert(cert,pin,account,pub):
    parts=cert.split('.');assert len(parts)==3
    Ed25519PublicKey.from_public_bytes(pin).verify(decu(parts[2]),(parts[0]+'.'+parts[1]).encode())
    header=json.loads(decu(parts[0])); assert header=={'alg':'EdDSA','typ':'JWT'}
    claims=json.loads(decu(parts[1]));now=int(time.time())
    assert claims['iss']=='blaze-seed-v1' and claims['aud']=='blaze-relays'
    assert claims['sub']==account and claims['device_public_key']==pub
    assert claims['iat']<=now+60 and now<claims['exp']<=now+7*86400+60

def enroll(base,account,password,key,pub,install):
    nonce=u64(secrets.token_bytes(24))
    payload={'username':account,'password':password,'device_public_key_b64':pub,
             'installation_id':install,'nonce':nonce,
             'proof_signature_b64':u64(key.sign(f'ConnectIT-enroll-v1\n{account}\n{nonce}'.encode()))}
    return send(base+'/v1/enroll','POST',payload)

def main():
    assert MASTER.is_file(),'Build the Master Linux binary before running'
    with tempfile.TemporaryDirectory(prefix='connectit-auth-v015-') as tmp:
        state=pathlib.Path(tmp)/'master'; base='http://127.0.0.1:17987'
        env=os.environ.copy();env.update(CONNECTIT_BOOTSTRAP_PASSWORD='Bootstrap-Passphrase-TEST-12345')
        run('init','--dir',state,env=env)
        env.update(CONNECTIT_OLD_ADMIN_PASSWORD=env['CONNECTIT_BOOTSTRAP_PASSWORD'],CONNECTIT_NEW_ADMIN_PASSWORD='RotatedAdmin-Passphrase-TEST-54321')
        run('admin-rotate','--dir',state,env=env)
        password='TestAccount-Passphrase-859213'
        env['CONNECTIT_PASSWORD']=password
        run('account-create','--dir',state,'--nickname','MasterClientAuthSmoke',env=env)
        cx=sqlite3.connect(state/'connectit.sqlite3')
        account=cx.execute('select id from accounts').fetchone()[0];cx.close()
        assert len(account)==10 and account.isdecimal()
        issuer=base64.b64decode((state/'public.key').read_text().strip())
        server=subprocess.Popen([str(MASTER),'start','--dir',str(state),'--listen','127.0.0.1:17987'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            wait(base)
            key_a,pub_a,install_a=device()
            status,out=enroll(base,account,password,key_a,pub_a,install_a)
            assert status==200,(status,out)
            cert_a=out['device_certificate'];verify_cert(cert_a,issuer,account,pub_a)
            status,self_info=send(base+'/v1/devices/self','GET')
            assert status==401,(status,self_info)
            status,self_info=send(base+'/v1/devices/self','GET',key=key_a,cert=cert_a)
            assert status==200,(status,self_info)
            assert self_info['account_id']==account and len(self_info['device_id'])>=16
            assert 'private' not in self_info and 'installation' not in self_info
            status,_=send(base+'/v1/devices/self','GET',key=key_a,cert=cert_a,override_sig=u64(b'\x00'*64))
            assert status==401, status
            key_b,pub_b,install_b=device()
            status,denial=enroll(base,account,password,key_b,pub_b,install_b)
            assert status==409,(status,denial)
            nonce=u64(secrets.token_bytes(24))
            begin={'username':account,'password':password,'device_public_key_b64':pub_b,
                   'installation_id':install_b,'nonce':nonce,'confirmed':True,
                   'proof_signature_b64':u64(key_b.sign(f'ConnectIT-bind-start-v1\n{account}\n{nonce}'.encode()))}
            status,pending=send(base+'/v1/bind/start','POST',begin)
            assert status==202,(status,pending)
            bind_id=pending['binding_id']
            status,inbox=send(base+'/v1/bind/pending','GET',key=key_a,cert=cert_a)
            assert status==200,(status,inbox)
            req=next(x for x in inbox['requests'] if x['id']==bind_id)
            assert req['target_key']==pub_b
            # Early finalize must fail because a trusted-device approval is required.
            nonce=u64(secrets.token_bytes(24))
            finish={'binding_id':bind_id,'username':account,'password':password,'nonce':nonce,
                    'proof_signature_b64':u64(key_b.sign(f'ConnectIT-bind-finalize-v1\n{bind_id}\n{nonce}'.encode()))}
            status,_=send(base+'/v1/bind/finalize','POST',finish)
            assert status==409,status
            # Move the database clock anchor in a private temporary SQLite fixture
            # to test the four-hour gate without a real four-hour wait.
            cx=sqlite3.connect(state/'connectit.sqlite3')
            cx.execute('UPDATE bindings SET started=? WHERE id=?',(int(time.time())-14400,bind_id))
            cx.commit(); cx.close()
            issued=int(time.time()); interval=12; approval=u64(secrets.token_bytes(24))
            signed='\n'.join(['ConnectIT-SecureBind-v1',bind_id,approval,self_info['device_id'],
                              pub_b,req['challenge'],str(interval),str(issued),'approve'])
            decision={'binding_id':bind_id,'approval_id':approval,'action':'approve',
                      'issued':issued,'interval_index':interval,'signature_b64':u64(key_a.sign(signed.encode()))}
            status,result=send(base+'/v1/bind/decision','POST',decision,key=key_a,cert=cert_a)
            assert status==200,(status,result)
            assert result['approvals']==1
            # Duplicate approval must fail via replay/unique-interval protection.
            status,_=send(base+'/v1/bind/decision','POST',decision,key=key_a,cert=cert_a)
            assert status==409,status
            status,done=send(base+'/v1/bind/finalize','POST',finish)
            assert status==200,(status,done)
            cert_b=done['device_certificate'];verify_cert(cert_b,issuer,account,pub_b)
            status,self_b=send(base+'/v1/devices/self','GET',key=key_b,cert=cert_b)
            assert status==200 and self_b['device_id']!=self_info['device_id']
            # Existing original cert immediately stops authorizing after local revoke.
            run('device-revoke','--dir',state,'--device-id',self_info['device_id'],env=env)
            status,_=send(base+'/v1/devices/self','GET',key=key_a,cert=cert_a)
            assert status==403,status
            status,_=send(base+'/v1/devices/self','GET',key=key_b,cert=cert_b)
            assert status==200,status
            print(json.dumps({'first_device_enrollment':'PASS','master_signed_certificate_pin':'PASS',
                              'signed_self_device_lookup':'PASS','missing_or_bad_auth_rejected':'PASS',
                              'second_device_enrollment_requires_bind':'PASS','pending_signed_lookup':'PASS',
                              'unauthorized_early_finalize_rejected':'PASS',
                              'trusted_approval_with_device_id':'PASS',
                              'duplicate_approval_denied':'PASS','second_device_finalize':'PASS',
                              'revoked_original_device_denied':'PASS',
                              'time_acceleration':'SQLITE_FIXTURE_ONLY'}))
        finally:
            if server.poll() is None:
                server.terminate()
            try:server.wait(timeout=5)
            except subprocess.TimeoutExpired:server.kill();server.wait()

if __name__=='__main__':main()
