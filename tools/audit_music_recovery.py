#!/usr/bin/env python3
"""Guard the last user-confirmed playable legacy Music.app payload.

An Xcode success is not a device playback test. This validator checks that
we did not accidentally ship extra playback hooks, Apple Music metadata
changes, or a modified legacy MusicApplication binary.
"""
import hashlib, plistlib, struct, sys, zipfile

PATH = sys.argv[1]
SHA_MUSIC_APPLICATION = "067a5b3d51640d7360bd0240e4e27583c92bcda27bdf1b3091f12626587a0649"
SHA_HEIC_COMPAT = "c75ad9f311100fc88c351850bb2ff53b29506c4cf42cf55ecca3fcd40156ee56"
SHA_ROOT_INFO = "d15d668c283e1a27105db010e7342fd0a4b0fa9994482e1105ccd8fb04b4904c"
def sha(b): return hashlib.sha256(b).hexdigest()
with zipfile.ZipFile(PATH) as z:
    assert z.testzip() is None, "IPA ZIP corruption"
    assert len(z.namelist()) == 405, "IPA member count changed"
    prefix = "Payload/Music.app/"
    info_bytes = z.read(prefix + "Info.plist")
    info = plistlib.loads(info_bytes)
    assert info["CFBundleIdentifier"] == "com.nightvibes33.applemusic27"
    assert sha(info_bytes) == SHA_ROOT_INFO, "Guest Info.plist deviates from known playable version"
    assert sha(z.read(prefix + "Frameworks/MusicApplication.framework/MusicApplication")) == SHA_MUSIC_APPLICATION, "Original MusicApplication modified"
    dylib = z.read(prefix + "Frameworks/MusicHEICCompat.dylib")
    assert sha(dylib) == SHA_HEIC_COMPAT, "HEIC dylib changed; possible active playback hooks or UI"
    main = z.read(prefix + "Music")
    assert len(main) == 93792
    assert struct.unpack_from("<I", main, 0)[0] == 0xfeedfacf
    assert struct.unpack_from("<I", main, 16)[0] == 60, "Changed LC commands"
    assert b"@loader_path/Frameworks/MusicHEICCompat.dylib" in main
    assert b"MusicNowPlayingTrace" not in dylib
    assert b"MusicPlaybackStatus.log" not in dylib
    assert b"MusicExtras" not in dylib
    # Strip the only two allowed linker-header differences across runner builds.
    from pathlib import Path
    print(f"RECOVERY_GUARD_PASS file={PATH}")
    print(f"RECOVERY_GUARD_PASS sha256={sha(open(PATH,'rb').read())}")
    print("RECOVERY_GUARD_PASS 405 members, unmodified original MusicApplication, exact HEIC shim and metadata")
    print("NOT_A_DEVICE_PLAYBACK_TEST")
