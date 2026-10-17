#!/usr/bin/env python3
"""Build an unsigned iOS 27 compatibility IPA from the original Music.app dump.

Input is the unpacked GitHub Actions extraction (extracted/Music.app).
Compiled Apple code is preserved, except six CarPlay weak-import bits
and one LC_LOAD_DYLIB dependency for the HEIC compatibility module.
"""
import hashlib, plistlib, shutil, stat, struct, sys, zipfile
from pathlib import Path

source_root = Path(sys.argv[1])
shim_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])
source_app = source_root / "extracted" / "Music.app"
assert source_app.is_dir(), f"Missing source app at {source_app}"
target = Path("staging/Payload/Music.app")
if target.parent.parent.exists():
    shutil.rmtree(target.parent.parent)
shutil.copytree(source_app, target, symlinks=False)
assert plistlib.loads((target/"Info.plist").read_bytes())["CFBundleIdentifier"] == "com.apple.Music"

for f in target.rglob("*"):
    if f.name=="_CodeSignature" and f.is_dir():
        shutil.rmtree(f)
for f in target.rglob("embedded.mobileprovision"):
    f.unlink()
modified = []
for f in target.rglob("Info.plist"):
    try:
        data=plistlib.loads(f.read_bytes())
    except Exception:
        continue
    identifier=data.get("CFBundleIdentifier")
    if identifier == "com.apple.Music" or (isinstance(identifier,str) and identifier.startswith("com.apple.Music.")):
        data["CFBundleIdentifier"]="com.nightvibes33.applemusic27"+identifier[len("com.apple.Music"):]
        data["MinimumOSVersion"]="27.0"
        if f.parent==target:
            data["CFBundleName"]="Music Legacy"
            data["CFBundleDisplayName"]="Music Legacy"
        f.write_bytes(plistlib.dumps(data,fmt=plistlib.FMT_BINARY,sort_keys=False))
        modified.append((str(f.relative_to(target)),identifier,data["CFBundleIdentifier"]))

framework=target/"Frameworks/MusicApplication.framework/MusicApplication"
data=bytearray(framework.read_bytes())
# Offsets were determined from this exact iOS 15.8.8 MusicApplication build.
offsets=(0xd45a88,0xd46d94,0xd46db8,0xd46dbc,0xd46ec8,0xd46ed8)
assert len(data)==16283648, f"Unexpected MusicApplication binary length: {len(data)}"
for offset in offsets:
    value=struct.unpack_from("<I",data,offset)[0]
    assert not (value & 0x100), f"Unexpected preexisting weak import at {offset:#x}"
    struct.pack_into("<I",data,offset,value|0x100)
framework.write_bytes(data)

# Add the compatibility dylib as an actual Mach-O dependency. This guarantees
# its constructor executes before the app initializes its artwork datasource.
exe=target/"Music"
main=bytearray(exe.read_bytes())
magic,cpu,subtype,filetype,ncmds,sizeofcmds,flags,reserved=struct.unpack_from("<IiiIIIII",main,0)
assert magic==0xfeedfacf and cpu==0x100000c and filetype==2
name=b"@loader_path/Frameworks/MusicHEICCompat.dylib\x00"
cmdsize=(24+len(name)+7)&~7
load=struct.pack("<6I",0xc,cmdsize,24,0,0,0)+name
load+=b"\x00"*(cmdsize-len(load))
end=32+sizeofcmds
assert end+cmdsize<len(main)
assert all(v==0 for v in main[end:end+cmdsize]), "Mach-O lacks safe load-command padding"
main[end:end+cmdsize]=load
struct.pack_into("<I",main,16,ncmds+1)
struct.pack_into("<I",main,20,sizeofcmds+cmdsize)
exe.write_bytes(main)
shutil.copy2(shim_path,target/"Frameworks/MusicHEICCompat.dylib")
assert len(main)==93792
manifest=[]
with zipfile.ZipFile(out_path,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=8,allowZip64=True) as z:
    for f in sorted(target.rglob("*")):
        if not f.is_file():continue
        relative=f.relative_to(target.parent.parent)
        content=f.read_bytes()
        name=str(relative)
        i=zipfile.ZipInfo(name)
        i.create_system=3
        i.external_attr=(stat.S_IFREG|(0o755 if content[:4]==b"\xcf\xfa\xed\xfe" else 0o644))<<16
        z.writestr(i,content,compress_type=zipfile.ZIP_DEFLATED,compresslevel=8)
        manifest.append((name,len(content),hashlib.sha256(content).hexdigest()))
with zipfile.ZipFile(out_path) as z:
    assert z.testzip() is None
    assert z.read("Payload/Music.app/Frameworks/MusicHEICCompat.dylib")[:4]==b"\xcf\xfa\xed\xfe"
    assert plistlib.loads(z.read("Payload/Music.app/Info.plist"))["CFBundleIdentifier"]=="com.nightvibes33.applemusic27"
Path("patch-report.txt").write_text(
    f"Source: {source_app}\n"
    f"Output: {out_path}\n"
    f"Size: {out_path.stat().st_size}\n"
    f"SHA256: {hashlib.sha256(out_path.read_bytes()).hexdigest()}\n"
    f"Six weak CarPlayUI imports preserved from previous test IPA.\n"
    f"Added LC_LOAD_DYLIB: @loader_path/Frameworks/MusicHEICCompat.dylib\n"
    f"HEIC selector is implemented as a runtime compatibility method, not removed.\n"
    f"Modified identifiers: {len(modified)}\n"
    f"Members: {len(manifest)}\n"
    f"Source binary platform remains iOS device, not iOS Simulator.\n"
)
Path("manifest.sha256").write_text("".join(f"{sha}  {name}\n" for name, size, sha in manifest))
print(Path("patch-report.txt").read_text())
