#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

CRASH_DIR='/var/mobile/Library/Logs/CrashReporter'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'

echo '=== Exact newest Gif2Ani Browse crash parser ==='
printf 'collected_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'installed_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || true
printf 'bundle_sha256='; sha256sum "$BUNDLE/Gif2AniPrefs" 2>/dev/null | awk '{print $1}' || true

NEWEST="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name 'Preferences-*.ips' -o -name 'Preferences_*.ips' -o -name 'Preferences*.ips' \) -print 2>/dev/null | while IFS= read -r f; do stat -f '%m|%N' "$f" 2>/dev/null || stat -c '%Y|%n' "$f" 2>/dev/null || true; done | sort -t '|' -k1,1nr | head -n 1 | cut -d'|' -f2-)"

test -n "$NEWEST"
test -f "$NEWEST"
printf 'newest_crash=%s\n' "$NEWEST"
printf 'crash_bytes='; wc -c < "$NEWEST"

python3 - "$NEWEST" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1])
text=p.read_text(errors='replace')
lines=text.splitlines()
objs=[]
for candidate in (lines[0] if lines else '', '\n'.join(lines[1:]) if len(lines)>1 else '', text):
    try:
        value=json.loads(candidate)
    except Exception:
        continue
    if isinstance(value,dict): objs.append(value)
header=objs[0] if objs else {}
body=objs[1] if len(objs)>1 else (objs[-1] if objs else {})
print('incident_id='+str(header.get('incident_id') or body.get('incident') or 'unknown'))
print('timestamp='+str(header.get('timestamp') or body.get('captureTime') or 'unknown'))
print('process='+str(body.get('procName') or header.get('app_name') or 'unknown'))
print('pid='+str(body.get('pid') or 'unknown'))
print('exception='+json.dumps(body.get('exception') or {},sort_keys=True))
print('termination='+json.dumps(body.get('termination') or {},sort_keys=True))
for key in ('asi','applicationSpecificInformation','exceptionReason','reason','diagnosticMessage','coalitionName'):
    if key in body:
        print(key+'='+json.dumps(body[key],sort_keys=True,default=str))
print('body_keys='+','.join(sorted(body.keys())))
images=body.get('usedImages') or []
for i,img in enumerate(images):
    if 'Gif2Ani' in str(img.get('name','')) or 'Gif2Ani' in str(img.get('path','')):
        print('gif2ani_image_index='+str(i))
        print('gif2ani_image='+json.dumps(img,sort_keys=True))
fault=body.get('faultingThread')
threads=body.get('threads') or []
if isinstance(fault,int) and 0 <= fault < len(threads):
    t=threads[fault]
    print('faulting_thread_name='+str(t.get('name') or t.get('queue') or 'unknown'))
    for n,frame in enumerate((t.get('frames') or [])[:60]):
        idx=frame.get('imageIndex')
        image=''
        if isinstance(idx,int) and 0 <= idx < len(images): image=str(images[idx].get('name') or '')
        print('frame_%02d=image:%s|symbol:%s|symbolOffset:%s|imageOffset:%s' % (n,image,frame.get('symbol') or '',frame.get('symbolLocation'),frame.get('imageOffset')))
print('last_exception_backtrace='+json.dumps(body.get('lastExceptionBacktrace') or [],sort_keys=True))

def walk(value,path='root'):
    if isinstance(value,dict):
        for k,v in value.items():
            yield from walk(v,path+'.'+str(k))
    elif isinstance(value,list):
        for i,v in enumerate(value):
            yield from walk(v,path+'['+str(i)+']')
    elif isinstance(value,str):
        low=value.lower()
        needles=('selector','unrecognized','exception','reason','gif2ani','g2theme','controllerforspecifier','doesnotrecognize')
        if any(x in low for x in needles):
            yield path+'='+value[:1500].replace('\n','\\n')
for i,item in enumerate(walk(body)):
    print('recursive_clue_%02d=%s' % (i,item))
    if i>=79: break
PY

echo 'exact_crash_parse=complete'
