#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
echo ===LIVECONTAINER_FELIX_PROBE===
find /var/mobile/Containers/Data/Application -type d -path "*/Documents/Applications/LiveExec32.app" -print 2>/dev/null | while read a; do
  echo LIVEEXEC="$a"
  find "$a/RootFS" -path '*/UIKit.framework/UIKit' -o -path '*/QuartzCore.framework/QuartzCore' -o -path '*/libiconv.2.dylib' -o -path '*/libstdc++.6.dylib' 2>/dev/null
  ls -l "$a/RootFS/usr/lib/libiconv.2.dylib" "$a/RootFS/usr/lib/libstdc++.6.dylib" 2>&1
  command -v nm >/dev/null && nm -gU "$a/RootFS/System/Library/Frameworks/UIKit.framework/UIKit" 2>/dev/null | grep -E 'UIKeyboardCenterEndUserInfoKey|UIKeyboard.*UserInfoKey'
done
find /var/mobile/Containers/Data/Application -type d -path "*/Documents/Applications/*FixItFelix*.app" -print 2>/dev/null
echo PROBE_DONE=1
