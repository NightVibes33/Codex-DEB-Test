#!/usr/bin/env python3
import os, sys, struct, hashlib, plistlib
if len(sys.argv) != 4:
    raise SystemExit('usage: patch-3105-ios15.py APP_DIR TEXTRO_BIN FINAL_INFO_PLIST')
app, blob_path, final_plist = sys.argv[1:]
binary=os.path.join(app,'3105')
blob=open(blob_path,'rb').read()
if hashlib.sha256(blob).hexdigest() != 'f1eeaf99806da5ca18cfa3cc98e7d1ca270bfe17dfa273f26df862d4a92ec02d':
    raise SystemExit('fallback blob hash mismatch')
b=bytearray(open(binary,'rb').read())
if hashlib.sha256(b).hexdigest() != 'ae18fae404a058ca5076dc8a64df6850b3a308d03e5462329162c6ee783fd208':
    raise SystemExit('unexpected pristine 3105 executable')
code_off=0x2c0100
if any(b[code_off:code_off+len(blob)]): raise SystemExit('code cave not empty')
b[code_off:code_off+len(blob)] = blob
magic,cputype,cpusubtype,filetype,ncmds,sizeofcmds,flags,reserved=struct.unpack_from('<IiiIIIII',b,0)
if magic != 0xfeedfacf: raise SystemExit('not arm64 Mach-O')
LC_BUILD_VERSION=0x32; LC_MAIN=0x80000028; LC_DYLD_CHAINED_FIXUPS=0x80000034
LC_LOAD_DYLIB=0x0c; LC_LOAD_WEAK_DYLIB=0x80000018
p=32; fixups=None; main_found=build_found=0
for _ in range(ncmds):
    cmd,cmdsize=struct.unpack_from('<II',b,p)
    if cmd==LC_BUILD_VERSION:
        platform,minos,sdk,ntools=struct.unpack_from('<IIII',b,p+8)
        if platform==2:
            struct.pack_into('<I',b,p+12,(15<<16)); build_found+=1
    elif cmd==LC_MAIN:
        struct.pack_into('<Q',b,p+8,code_off); main_found+=1
    elif cmd==LC_DYLD_CHAINED_FIXUPS:
        fixups=struct.unpack_from('<II',b,p+8)
    elif cmd==LC_LOAD_DYLIB:
        struct.pack_into('<I',b,p,LC_LOAD_WEAK_DYLIB)
    p+=cmdsize
if main_found != 1 or build_found < 1 or not fixups: raise SystemExit('required load commands missing')
dataoff,datasize=fixups
_,_,imports_offset,_,imports_count,imports_format,_=struct.unpack_from('<7I',b,dataoff)
if imports_format != 1: raise SystemExit('unexpected chained import format')
for i in range(imports_count):
    off=dataoff+imports_offset+4*i
    v=struct.unpack_from('<I',b,off)[0]
    struct.pack_into('<I',b,off,v|(1<<8))
open(binary,'wb').write(b); os.chmod(binary,0o755)
# Use the exact Info.plist bytes from the already-patched local IPA.
plist_bytes=open(final_plist,'rb').read()
if hashlib.sha256(plist_bytes).hexdigest() != '773bc29c61bbe8d76d79339a59a343bdb671e4f6b21ced479a171177393d8df9':
    raise SystemExit('final plist hash mismatch')
open(os.path.join(app,'Info.plist'),'wb').write(plist_bytes)
# Append the same ad-hoc CodeDirectory + entitlement blob used by the local patched IPA.
b=bytearray(open(binary,'rb').read())
ncmds=struct.unpack_from('<I',b,16)[0]; sizeofcmds=struct.unpack_from('<I',b,20)[0]
p=32; linkedit=None
for _ in range(ncmds):
    cmd,cmdsize=struct.unpack_from('<II',b,p)
    if cmd==0x19:
        seg=bytes(b[p+8:p+24]).split(b'\0',1)[0]
        if seg==b'__LINKEDIT': linkedit=p
    if cmd==0x1d: raise SystemExit('unexpected existing signature')
    p+=cmdsize
if linkedit is None: raise SystemExit('LINKEDIT missing')
lc_off=p
if lc_off+16 >= 0x4000: raise SystemExit('no load command padding')
sigoff=(len(b)+15)&~15
if sigoff>len(b): b.extend(b'\0'*(sigoff-len(b)))
ent={
 'application-identifier':'TROLLTROLL.*',
 'com.apple.developer.team-identifier':'TROLLTROLL',
 'get-task-allow':True,
 'keychain-access-groups':['TROLLTROLL.*','com.apple.token'],
 'platform-application':True,
 'com.apple.private.security.no-sandbox':True,
 'com.apple.private.security.container-required':'com.apple.mobile.MobileHouseArrest',
 'com.apple.private.MobileContainerManager.allowed':True,
 'com.apple.private.security.container-manager':True,
 'com.apple.private.security.storage.MobileDocuments':True,
 'com.apple.security.exception.files.absolute-path.read-write':['/'],
}
xml=plistlib.dumps(ent,fmt=plistlib.FMT_XML,sort_keys=True)
be=lambda x:struct.pack('>I',x)
ent_blob=be(0xfade7171)+be(8+len(xml))+xml
ident=b'com.apple.mobile.MobileHouseArrest\0'; team=b'TROLLTROLL\0'
code_limit=sigoff; hash_size=32; page_exp=12; page_size=4096
n_code=(code_limit+page_size-1)//page_size; n_special=5
ident_off=52; team_off=ident_off+len(ident)
hashes_base=(team_off+len(team)+7)&~7
hash_off=hashes_base+n_special*hash_size
cd_len=hash_off+n_code*hash_size
cd_off=28; ent_off=(cd_off+cd_len+3)&~3; sig_len=ent_off+len(ent_blob)
struct.pack_into('<IIII',b,lc_off,0x1d,16,sigoff,sig_len)
struct.pack_into('<I',b,16,ncmds+1); struct.pack_into('<I',b,20,sizeofcmds+16)
fileoff=struct.unpack_from('<Q',b,linkedit+40)[0]
new_filesize=(sigoff+sig_len)-fileoff; new_vmsize=(new_filesize+0x3fff)&~0x3fff
struct.pack_into('<Q',b,linkedit+48,new_filesize); struct.pack_into('<Q',b,linkedit+32,new_vmsize)
cd=bytearray(cd_len)
struct.pack_into('>IIIIIIIII',cd,0,0xfade0c02,cd_len,0x20200,0x2,hash_off,ident_off,n_special,n_code,code_limit)
cd[36]=32; cd[37]=2; cd[38]=0; cd[39]=12
struct.pack_into('>I',cd,40,0); struct.pack_into('>I',cd,44,0); struct.pack_into('>I',cd,48,team_off)
cd[ident_off:ident_off+len(ident)]=ident; cd[team_off:team_off+len(team)]=team
cd[hashes_base:hashes_base+32]=hashlib.sha256(ent_blob).digest()
for i in range(n_code):
    page=bytes(b[i*4096:min((i+1)*4096,code_limit)])
    st=hash_off+i*32; cd[st:st+32]=hashlib.sha256(page).digest()
sig=bytearray(sig_len)
struct.pack_into('>III',sig,0,0xfade0cc0,sig_len,2)
struct.pack_into('>II',sig,12,0,cd_off); struct.pack_into('>II',sig,20,5,ent_off)
sig[cd_off:cd_off+len(cd)]=cd; sig[ent_off:ent_off+len(ent_blob)]=ent_blob
b.extend(sig); open(binary,'wb').write(b); os.chmod(binary,0o755)
final_hash=hashlib.sha256(open(binary,'rb').read()).hexdigest()
if final_hash != '41ae16f59b0a655bc6b94d19b524a60c74a53ebb7c3aa00b4ee087fef87da356':
    raise SystemExit('patched executable mismatch: '+final_hash)
print('EXACT_PATCHED_BINARY=1')
print('patched_binary_sha256='+final_hash)
