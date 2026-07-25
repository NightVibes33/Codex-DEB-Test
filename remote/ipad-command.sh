#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

echo "=== NightVibes33/Dopamine branches ==="
python3 - <<'PY'
import json
import urllib.request

url = "https://api.github.com/repos/NightVibes33/Dopamine/branches?per_page=100"
request = urllib.request.Request(url, headers={"User-Agent": "DarkSword-iPad-Research"})
with urllib.request.urlopen(request, timeout=30) as response:
    branches = json.load(response)

for branch in branches:
    print(f"{branch['name']}\t{branch['commit']['sha']}")
print(f"branch_count={len(branches)}")
PY

echo "=== Branches containing likely DarkSword/iPad work ==="
python3 - <<'PY'
import json
import urllib.request

url = "https://api.github.com/repos/NightVibes33/Dopamine/branches?per_page=100"
request = urllib.request.Request(url, headers={"User-Agent": "DarkSword-iPad-Research"})
with urllib.request.urlopen(request, timeout=30) as response:
    branches = json.load(response)

keywords = ("dark", "sword", "ipad", "a9", "16.7", "m01", "beta", "exploit", "kfd", "paler")
for branch in branches:
    name = branch["name"]
    if any(keyword in name.lower() for keyword in keywords):
        print(f"candidate={name}\t{branch['commit']['sha']}")
PY
