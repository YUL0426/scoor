"""Verify worker authentication without reading any server API key.

Only synthetic one-use nonces are created; their hashes alone enter SQL.
The real Apple queue must be empty. No user/account deletion is requested.
"""
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
REF = "ebxdbadcejbytixumxrj"
URL = f"https://{REF}.supabase.co/functions/v1/account-delete"


def main():
    assert (ROOT / "supabase/.temp/project-ref").read_text().strip() == REF
    with tempfile.TemporaryDirectory(prefix="scoor-retry-check-") as directory:
        os.chmod(directory, 0o700)
        env = dict(os.environ, SUPABASE_HOME=directory)

        def query(sql):
            command = ["supabase", "--agent", "no", "--output-format", "text", "--profile", "scoor-release",
                       "db", "query", "--linked", "--file", "/dev/stdin", "--output", "json"]
            run = subprocess.run(command, input=sql, text=True, capture_output=True, cwd=ROOT, env=env, timeout=90)
            if run.returncode:
                raise RuntimeError("SQL check failed; raw CLI output withheld")
            return json.loads(run.stdout)

        def call(nonce=None):
            headers = {"Content-Type": "application/json"}
            if nonce is not None:
                headers["x-scoor-retry-nonce"] = nonce
            request = urllib.request.Request(URL, data=b"{}", headers=headers, method="POST")
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    return response.status, json.load(response)
            except urllib.error.HTTPError as error:
                return error.code, {}

        assert query("select count(*) as count from public.apple_revocation_queue;")[0]["count"] == 0
        assert call()[0] == 401
        assert call("invalid")[0] == 403
        print("Missing and malformed authorization rejected", flush=True)
        for expired in (False, True):
            nonce = secrets.token_hex(32)
            digest = hashlib.sha256(nonce.encode()).hexdigest()
            expiry = "now()-interval '1 second'" if expired else "now()+interval '5 minutes'"
            # Hash is not an authentication credential. The raw nonce never enters SQL.
            query(f"insert into public.apple_revocation_worker_nonces(nonce_hash,expires_at) values(decode('{digest}','hex'),{expiry}); select true as created;")
            try:
                status, payload = call(nonce)
                if expired:
                    assert status == 403
                    print("Expired one-use authorization rejected", flush=True)
                else:
                    assert status == 200 and payload == {"completed": 0}
                    assert call(nonce)[0] == 403
                    print("Valid one-use authorization accepted once; replay rejected; completed=0", flush=True)
            finally:
                query(f"delete from public.apple_revocation_worker_nonces where nonce_hash=decode('{digest}','hex'); select true as cleaned;")
        print("APPLE_RETRY_LIVE_AUTH_CHECKS_PASSED", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"failed": type(error).__name__}))
        raise SystemExit(1)
