#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

python3 <<'PY'
import json
import urllib.request

url = ('https://api.github.com/repos/NightVibes33/Dopamine/actions/workflows/'
       'ipad5-adaptive-lowmem.yml/runs?branch=ipad5%2Fadaptive-lowmem-v1&per_page=5')
req = urllib.request.Request(url, headers={
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'NightVibes33-iPad6,11-build-status',
})
with urllib.request.urlopen(req, timeout=30) as response:
    data = json.load(response)
print('workflow_total_count=' + str(data.get('total_count')))
for run in data.get('workflow_runs', []):
    print('---')
    print('run_id=' + str(run.get('id')))
    print('head_sha=' + str(run.get('head_sha')))
    print('status=' + str(run.get('status')))
    print('conclusion=' + str(run.get('conclusion')))
    print('event=' + str(run.get('event')))
    print('created_at=' + str(run.get('created_at')))
    print('updated_at=' + str(run.get('updated_at')))
    print('url=' + str(run.get('html_url')))
PY
