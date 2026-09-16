"""Operator-only Apple retry: status (read only) or retry (one batch, max 10).

Uses the official CLI login. Never reads server API keys or Apple tokens.
The one-use nonce travels directly over HTTPS; only its hash enters SQL.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
REF = "ebxdbadcejbytixumxrj"
STATUS_SQL = """
select jsonb_build_object(
 'checked_at',now(),
 'retry_cron_count',(select count(*) from cron.job where jobname='scoor-apple-revocation-retry'),
 'eligible',count(*) filter(where status='retry_pending' and refresh_token is not null and next_attempt_at<=now()),
 'items',coalesce(jsonb_agg(jsonb_build_object(
   'id',id,'status',status,'created_at',created_at,'attempts',attempts,
   'last_attempt_at',last_attempt_at,'next_attempt_at',next_attempt_at,
   'needs_review',status in ('needs_authorization','outcome_unknown','pending')
     or (status='in_progress' and created_at<now()-interval '5 minutes')
     or (status='retrying' and (lease_expires_at is null or lease_expires_at<=now()))
     or (status='retry_pending' and (refresh_token is null or next_attempt_at is null))
 ) order by created_at),'[]'::jsonb)) as report
from public.apple_revocation_queue;
"""


def run(action):
    if (ROOT / "supabase/.temp/project-ref").read_text().strip() != REF:
        raise RuntimeError("Wrong project")
    with tempfile.TemporaryDirectory(prefix="scoor-manual-retry-") as directory:
        os.chmod(directory, 0o700)
        env = dict(os.environ, SUPABASE_HOME=directory)

        def query(sql):
            result = subprocess.run(
                ["supabase", "--agent", "no", "--output-format", "text", "--profile", "scoor-release",
                 "db", "query", "--linked", "--file", "/dev/stdin", "--output", "json"],
                input=sql, text=True, capture_output=True, cwd=ROOT, env=env, timeout=90)
            if result.returncode:
                raise RuntimeError("SQL failed; raw output withheld")
            return json.loads(result.stdout)

        report = query(STATUS_SQL)[0]["report"]
        print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
        if action == "status":
            return
        if report["retry_cron_count"] != 0:
            raise RuntimeError("Automatic retry unexpectedly configured")
        if report["eligible"] == 0:
            print("No eligible failures; no worker call made.")
            return
        nonce = secrets.token_hex(32)
        digest = hashlib.sha256(nonce.encode()).hexdigest()
        try:
            query(f"insert into public.apple_revocation_worker_nonces(nonce_hash,expires_at) values(decode('{digest}','hex'),now()+interval '5 minutes'); select true as created;")
            request = urllib.request.Request(
                f"https://{REF}.supabase.co/functions/v1/account-delete", data=b"{}",
                headers={"Content-Type": "application/json", "x-scoor-retry-nonce": nonce}, method="POST")
            # Do not repeat HTTP automatically: a timeout does not prove failure.
            with urllib.request.urlopen(request, timeout=120) as response:
                payload = json.load(response)
            completed = payload.get("completed")
            if type(completed) is not int or not 0 <= completed <= 10:
                raise RuntimeError("Unexpected worker response")
            print(json.dumps({"completed": completed}), flush=True)
        finally:
            query(f"delete from public.apple_revocation_worker_nonces where nonce_hash=decode('{digest}','hex'); select true as cleaned;")
        print(json.dumps(query(STATUS_SQL)[0]["report"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "retry"])
    args = parser.parse_args()
    try:
        run(args.action)
    except Exception as error:
        print(json.dumps({"error": type(error).__name__,
                          "action": "Run status; do not assume failure or force queue states. Raw errors withheld."}))
        raise SystemExit(1)
