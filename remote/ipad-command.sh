#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

echo "=== Dopamine installation ==="
python3 - <<'PY'
from pathlib import Path
roots = [Path('/var/containers/Bundle/Application'), Path('/Applications'), Path('/var/jb/Applications')]
apps = []
for root in roots:
    if not root.exists():
        continue
    try:
        apps.extend(root.rglob('Dopamine.app'))
    except Exception:
        pass
for app in sorted(set(apps)):
    print(app)
PY

for app in $(python3 - <<'PY'
from pathlib import Path
roots = [Path('/var/containers/Bundle/Application'), Path('/Applications'), Path('/var/jb/Applications')]
apps = []
for root in roots:
    if root.exists():
        try:
            apps.extend(root.rglob('Dopamine.app'))
        except Exception:
            pass
for app in sorted(set(apps)):
    print(app)
PY
); do
    echo "--- $app ---"
    if [ -f "$app/Info.plist" ]; then
        plutil -p "$app/Info.plist" 2>/dev/null | grep -E 'CFBundleIdentifier|CFBundleShortVersionString|CFBundleVersion|MinimumOSVersion' || true
    fi
    binary="$app/Dopamine"
    if [ -f "$binary" ]; then
        ls -lh "$binary"
        shasum -a 256 "$binary" 2>/dev/null || true
        echo "entitlements:"
        ldid -e "$binary" 2>/dev/null | grep -E 'application-identifier|platform-application|task_for_pid-allow|get-task-allow|no-container|container-required|com.apple.private.security' || true
    fi
done

echo
echo "=== DarkSword persistent stage logs ==="
python3 - <<'PY'
from pathlib import Path
roots = [Path('/var/mobile/Containers/Data/Application'), Path('/private/var/mobile/Containers/Data/Application')]
logs = []
for root in roots:
    if not root.exists():
        continue
    try:
        for path in root.rglob('DarkSword-iPad5.log'):
            try:
                logs.append((path.stat().st_mtime, path))
            except OSError:
                pass
    except Exception:
        pass
for _, path in sorted(logs, reverse=True)[:10]:
    print(path)
PY

python3 - <<'PY'
from pathlib import Path
roots = [Path('/var/mobile/Containers/Data/Application'), Path('/private/var/mobile/Containers/Data/Application')]
logs = []
for root in roots:
    if root.exists():
        try:
            for path in root.rglob('DarkSword-iPad5.log'):
                try:
                    logs.append((path.stat().st_mtime, path))
                except OSError:
                    pass
        except Exception:
            pass
for _, path in sorted(logs, reverse=True)[:5]:
    print(f'--- {path} ---')
    try:
        lines = path.read_text(errors='replace').splitlines()
        for line in lines[-160:]:
            print(line)
    except Exception as exc:
        print(f'could-not-read: {exc}')
PY

echo
echo "=== Recent Dopamine / jetsam / panic reports ==="
python3 - <<'PY'
from pathlib import Path
roots = [
    Path('/var/mobile/Library/Logs/CrashReporter'),
    Path('/private/var/mobile/Library/Logs/CrashReporter'),
]
patterns = ('dopamine', 'jetsevent', 'jetsam', 'panic-full', 'panic-base')
items = {}
for root in roots:
    if not root.exists():
        continue
    try:
        for path in root.rglob('*'):
            if not path.is_file():
                continue
            name = path.name.lower()
            if any(pattern in name for pattern in patterns):
                try:
                    items[str(path)] = (path.stat().st_mtime, path)
                except OSError:
                    pass
    except Exception:
        pass
for _, path in sorted(items.values(), reverse=True)[:30]:
    print(path)
PY

python3 - <<'PY'
import re
from pathlib import Path
roots = [
    Path('/var/mobile/Library/Logs/CrashReporter'),
    Path('/private/var/mobile/Library/Logs/CrashReporter'),
]
patterns = ('dopamine', 'jetsevent', 'jetsam', 'panic-full', 'panic-base')
items = {}
for root in roots:
    if root.exists():
        try:
            for path in root.rglob('*'):
                if path.is_file() and any(p in path.name.lower() for p in patterns):
                    try:
                        items[str(path)] = (path.stat().st_mtime, path)
                    except OSError:
                        pass
        except Exception:
            pass
selected = [path for _, path in sorted(items.values(), reverse=True)[:12]]
keys = re.compile(
    r'(Dopamine|DarkSword|bug_type|incident|timestamp|captureTime|procName|processName|bundleInfo|'
    r'Exception Type|Exception Subtype|Termination Reason|termination|jetsam|memory-status|'
    r'panicString|panic string|Kernel Extensions in backtrace|last started kext|OS Version|modelCode|'
    r'Hardware Model|codeSigningMonitor|largestProcess|reason|footprint|pages|rpages)',
    re.IGNORECASE,
)
for path in selected:
    print(f'--- {path} ---')
    try:
        text = path.read_text(errors='replace')
    except Exception as exc:
        print(f'could-not-read: {exc}')
        continue
    count = 0
    for line in text.splitlines():
        if keys.search(line):
            print(line[:1600])
            count += 1
            if count >= 120:
                break
    if count == 0:
        print('no-matching-summary-lines')
PY

echo
echo "=== Current memory and limits ==="
vm_stat 2>/dev/null | head -20 || true
ulimit -a 2>/dev/null || true

echo "=== Diagnostic collection complete ==="
