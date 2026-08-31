#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
echo ===LIVECONTAINER_FELIX_LOCATE===
for root in /private/var/mobile/Containers/Data/Application /var/mobile/Containers/Data/Application; do
  echo SEARCH_ROOT="$root"
  find "$root" -name LiveExec32.app -o -name FixItFelixJr -o -path '*/RootFS/usr/lib/dyld' 2>/dev/null
  find "$root" -path '*/Documents/Applications/*.app' -maxdepth 7 2>/dev/null | head -80
done
echo LOCATE_DONE=1
