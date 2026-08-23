# TweakMedic Device Status

- Run: 32670704299
- Commit: 1c8cb3aa8b82d8042f268c03cc63952c7c96ae10
- Device step: skipped

## Device proof
```text
```

## Build log tail
```text
[0;36m==> [1;39mCleaning…[m
[1;31m> [1;3;39mMaking all for application TweakMedic…[m
[0;35m==> [1;39mCopying resource directories into the application wrapper…[m
[0;32m==> [1;39mCompiling app/TMClient.m (arm64)…[m
[0;32m==> [1;39mCompiling app/TMAppDelegate.m (arm64)…[m
[0;32m==> [1;39mCompiling app/main.m (arm64)…[m
[0;32m==> [1;39mCompiling app/TMRootViewController.m (arm64)…[m
[0;33m==> [1;39mLinking application TweakMedic (arm64)…[m
[0;34m==> [1;39mGenerating debug symbols for TweakMedic…[m
[0;34m==> [1;39mStripping TweakMedic (arm64)…[m
[0;34m==> [1;39mSigning TweakMedic…[m
[1;31m> [1;3;39mMaking all for tool tweakmedicd…[m
[0;32m==> [1;39mCompiling daemon/TMScanner.m (arm64)…[m
[1mdaemon/TMScanner.m:4:9: [0m[0;1;31mfatal error: [0m[1m'libproc.h' file not found[0m
#import <libproc.h>
[0;1;32m        ^~~~~~~~~~~
[0m1 error generated.
make[3]: *** [/opt/theos/makefiles/instance/rules.mk:305: /home/runner/work/Codex-DEB-Test/Codex-DEB-Test/TweakMedic/.theos/obj/arm64/daemon/TMScanner.m.2d8ca91d.o] Error 1
make[3]: *** Waiting for unfinished jobs....
[0;32m==> [1;39mCompiling daemon/main.m (arm64)…[m
make[2]: *** [/opt/theos/makefiles/instance/tool.mk:20: /home/runner/work/Codex-DEB-Test/Codex-DEB-Test/TweakMedic/.theos/obj/arm64/tweakmedicd] Error 2
make[1]: *** [/opt/theos/makefiles/instance/tool.mk:11: internal-tool-all_] Error 2
make: *** [/opt/theos/makefiles/master/rules.mk:146: tweakmedicd.all.tool.variables] Error 2
build_rc=2
```
