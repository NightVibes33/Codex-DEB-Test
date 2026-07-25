#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

python3 - <<'PY'
import json
import urllib.request

OWNER = 'NightVibes33'
REPO = 'Dopamine'
WORKFLOW = 'ipad5-darksword.yml'
TARGET_SHA = 'f725e81a24603e57764967f093d2188118783879'
HEADERS = {
    'User-Agent': 'DarkSword-iPad-Bridge',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
}

def get_json(url):
    request = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

runs_url = f'https://api.github.com/repos/{OWNER}/{REPO}/actions/workflows/{WORKFLOW}/runs?branch=main&per_page=20'
runs = get_json(runs_url).get('workflow_runs', [])
selected = next((run for run in runs if run.get('head_sha') == TARGET_SHA), None)
if selected is None and runs:
    selected = runs[0]

print('=== Dopamine iPad5 DarkSword matrix ===')
if selected is None:
    print('run=not-found')
    raise SystemExit(0)

run_id = selected['id']
print(f"run_id={run_id}")
print(f"head_sha={selected.get('head_sha')}")
print(f"status={selected.get('status')}")
print(f"conclusion={selected.get('conclusion')}")
print(f"event={selected.get('event')}")
print(f"url={selected.get('html_url')}")

jobs_url = f'https://api.github.com/repos/{OWNER}/{REPO}/actions/runs/{run_id}/jobs?per_page=20'
jobs = get_json(jobs_url).get('jobs', [])
for job in jobs:
    print(f"--- job={job.get('name')} id={job.get('id')} status={job.get('status')} conclusion={job.get('conclusion')} ---")
    for step in job.get('steps', []):
        print(
            f"step={step.get('number')} name={step.get('name')} "
            f"status={step.get('status')} conclusion={step.get('conclusion')}"
        )

artifacts_url = f'https://api.github.com/repos/{OWNER}/{REPO}/actions/runs/{run_id}/artifacts?per_page=20'
artifacts = get_json(artifacts_url).get('artifacts', [])
print('=== Artifacts ===')
for artifact in artifacts:
    print(
        f"artifact_id={artifact.get('id')} name={artifact.get('name')} "
        f"size={artifact.get('size_in_bytes')} expired={artifact.get('expired')}"
    )
print(f'artifact_count={len(artifacts)}')
PY
