# NightVibes Litter import status

- Clone and recursive submodules: success
- Vendor complete tree: success
- Apply exact DarkSword overlay: success
- Commit imported snapshot: success

## Clone log tail
```text
Cloning into '/tmp/litter'...
Submodule 'ThirdParty/EmexDE/Source' (https://github.com/emexlab/emexDE.git) registered for path 'ThirdParty/EmexDE/Source'
Submodule 'ThirdParty/SideStore/AltSign' (https://github.com/SideStore/AltSign.git) registered for path 'ThirdParty/SideStore/AltSign'
Submodule 'shared/third_party/codex' (https://github.com/NightVibes33/codex.git) registered for path 'shared/third_party/codex'
Submodule 'shared/third_party/ghostty' (https://github.com/ghostty-org/ghostty.git) registered for path 'shared/third_party/ghostty'
Cloning into '/private/tmp/litter/ThirdParty/EmexDE/Source'...
Cloning into '/private/tmp/litter/ThirdParty/SideStore/AltSign'...
Cloning into '/private/tmp/litter/shared/third_party/codex'...
Cloning into '/private/tmp/litter/shared/third_party/ghostty'...
From https://github.com/emexlab/emexDE
 * branch            7391378dcec0262bf741572f1fe97c49cfc621dc -> FETCH_HEAD
Submodule path 'ThirdParty/EmexDE/Source': checked out '7391378dcec0262bf741572f1fe97c49cfc621dc'
Submodule 'LLVM-On-iOS' (https://github.com/emexlab/LLVM-On-iOS) registered for path 'ThirdParty/EmexDE/Source/LLVM-On-iOS'
Submodule 'TrollStore' (https://github.com/opa334/TrollStore) registered for path 'ThirdParty/EmexDE/Source/TrollStore'
Cloning into '/private/tmp/litter/ThirdParty/EmexDE/Source/LLVM-On-iOS'...
Cloning into '/private/tmp/litter/ThirdParty/EmexDE/Source/TrollStore'...
From https://github.com/emexlab/LLVM-On-iOS
 * branch            490324731e6a14f263375ee3398a6b4e7d92b171 -> FETCH_HEAD
Submodule path 'ThirdParty/EmexDE/Source/LLVM-On-iOS': checked out '490324731e6a14f263375ee3398a6b4e7d92b171'
From https://github.com/opa334/TrollStore
 * branch            d11c04666a77435d1ac142af1b0b749214d60a9a -> FETCH_HEAD
Submodule path 'ThirdParty/EmexDE/Source/TrollStore': checked out 'd11c04666a77435d1ac142af1b0b749214d60a9a'
Submodule 'ChOma' (https://github.com/opa334/ChOma) registered for path 'ThirdParty/EmexDE/Source/TrollStore/ChOma'
Cloning into '/private/tmp/litter/ThirdParty/EmexDE/Source/TrollStore/ChOma'...
From https://github.com/opa334/ChOma
 * branch            964023ddac2286ef8e843f90df64d44ac6a673df -> FETCH_HEAD
Submodule path 'ThirdParty/EmexDE/Source/TrollStore/ChOma': checked out '964023ddac2286ef8e843f90df64d44ac6a673df'
From https://github.com/SideStore/AltSign
 * branch            7efe511440cfdbddc04a723490def86232c42f6c -> FETCH_HEAD
Submodule path 'ThirdParty/SideStore/AltSign': checked out '7efe511440cfdbddc04a723490def86232c42f6c'
Submodule 'Dependencies/ldid' (https://github.com/rileytestut/ldid.git) registered for path 'ThirdParty/SideStore/AltSign/Dependencies/ldid'
Cloning into '/private/tmp/litter/ThirdParty/SideStore/AltSign/Dependencies/ldid'...
Submodule path 'ThirdParty/SideStore/AltSign/Dependencies/ldid': checked out '6a6a92de56ae2110e4d6f292b315df0f586d6af5'
Submodule 'libplist' (https://github.com/libimobiledevice/libplist.git) registered for path 'ThirdParty/SideStore/AltSign/Dependencies/ldid/libplist'
Cloning into '/private/tmp/litter/ThirdParty/SideStore/AltSign/Dependencies/ldid/libplist'...
From https://github.com/libimobiledevice/libplist
 * branch            17546f53ac1377b0d4f45a800aaec7366ba5b6a0 -> FETCH_HEAD
Submodule path 'ThirdParty/SideStore/AltSign/Dependencies/ldid/libplist': checked out '17546f53ac1377b0d4f45a800aaec7366ba5b6a0'
From https://github.com/NightVibes33/codex
 * branch            b39d8b474aa039790503b9b4e34ca18696d9dfa6 -> FETCH_HEAD
Submodule path 'shared/third_party/codex': checked out 'b39d8b474aa039790503b9b4e34ca18696d9dfa6'
From https://github.com/ghostty-org/ghostty
 * branch            a968e120dd084bd886239d1cac938f0177f019d9 -> FETCH_HEAD
Submodule path 'shared/third_party/ghostty': checked out 'a968e120dd084bd886239d1cac938f0177f019d9'
Restored submodule revisions:
 7391378dcec0262bf741572f1fe97c49cfc621dc ThirdParty/EmexDE/Source (7391378)
 490324731e6a14f263375ee3398a6b4e7d92b171 ThirdParty/EmexDE/Source/LLVM-On-iOS (4903247)
 d11c04666a77435d1ac142af1b0b749214d60a9a ThirdParty/EmexDE/Source/TrollStore (d11c046)
 964023ddac2286ef8e843f90df64d44ac6a673df ThirdParty/EmexDE/Source/TrollStore/ChOma (964023d)
 7efe511440cfdbddc04a723490def86232c42f6c ThirdParty/SideStore/AltSign (7efe511)
 6a6a92de56ae2110e4d6f292b315df0f586d6af5 ThirdParty/SideStore/AltSign/Dependencies/ldid (heads/master)
 17546f53ac1377b0d4f45a800aaec7366ba5b6a0 ThirdParty/SideStore/AltSign/Dependencies/ldid/libplist (17546f5)
 b39d8b474aa039790503b9b4e34ca18696d9dfa6 shared/third_party/codex (b39d8b4)
 a968e120dd084bd886239d1cac938f0177f019d9 shared/third_party/ghostty (a968e12)
```

## Vendor log tail
```text
```

## Overlay log tail
```text
Exact DarkSword app architecture, full NightVibes Litter, iOS 16.1, pinned Zig, jailbreak lab, and rootless host runtime applied to /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter.
Perception iOS 16 backport applied: 149 Swift files changed, 298 View bodies wrapped, package revision de219a1cf34e958134e75a9ebb134cf09bf52fc6.
DarkSword core overlay and iOS 16 Perception backport completed for upstream/litter.
```

## Commit log tail
```text
[main c73ffdc] Sync complete NightVibes Litter into DarkSword architecture
 151 files changed, 1225 insertions(+), 505 deletions(-)
 mode change 100644 => 100755 darksword-overlay/backport_perception.py
To https://github.com/NightVibes33/Codex-DEB-Test
   b6f219c..c73ffdc  HEAD -> main
```
