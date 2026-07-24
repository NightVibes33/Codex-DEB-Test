# Building Node.js for Rootless iOS (arm64) via GitHub Actions

## Context / Why This Exists

Target device: jailbroken iPad, iOS 16.7.11, rootless jailbreak (Dopamine or palera1n rootless — confirmed by `/var/jb/...` paths in `dpkg` status).

The problem: Procursus's `apt.procurs.us` repo lists a `nodejs` package, but it's dead —
built October 2020, version 14.13.1, architecture tag `iphoneos-arm`. That tag isn't a 32-bit
thing, it's a *pre-rootless* Procursus convention. The package hardcodes install paths like
`/usr/bin/node` and `/usr/lib/libnode.83.dylib`. On a rootless jailbreak, `/usr` is the real
Apple system partition — permanently read-only (Sealed System Volume). Real jailbreak files
live under `/var/jb/usr/...` instead. This is why `dpkg -i` fails with
`Read-only file system` even after forcing past the architecture mismatch.

`apt-cache showpkg nodejs` on-device returns nothing — the package has been fully dropped
from the current index, not just hidden by a stale cache.

Building on-device was attempted and ruled out: the iPad shell has no `make`, no `dsymutil`
(comes from a full Xcode install, macOS-only), and Procursus's own docs say macOS is the only
reliably-working build host — Linux and on-device builds are explicitly "hit or miss."

**Conclusion: cross-compile Node for rootless `iphoneos-arm64` on a macOS GitHub Actions
runner, produce a proper rootless `.deb`, then `scp`/transfer it to the iPad and `dpkg -i`
locally.** This mirrors Bobby's existing pattern of using GitHub Actions to produce artifacts
(unsigned IPAs) that get sideloaded/installed after the fact, rather than building on-device.

---

## What the Bot Needs To Do

### 1. Spin up a `macos-14` runner

Must be macOS, not Ubuntu. Procursus's build system depends on Xcode toolchain pieces
(`dsymutil`, `odcctools`, etc.) that are far more reliable to get on a real macOS box than
via Linux cross-toolchains.

### 2. Install build dependencies via Homebrew

```bash
brew install make bash wget gnu-tar gnu-sed gnupg ldid cmake automake groff gpatch \
  findutils coreutils fakeroot zstd dpkg ncurses docbook-xsl python3
```

Put GNU tool variants ahead of BSD ones on PATH, since Procursus's makefiles assume GNU
`make`/`sed`/`find` behavior:

```bash
echo "/usr/local/opt/make/libexec/gnubin" >> $GITHUB_PATH
echo "/usr/local/opt/gnu-sed/libexec/gnubin" >> $GITHUB_PATH
echo "/usr/local/opt/findutils/libexec/gnubin" >> $GITHUB_PATH
```

### 3. Clone Procursus

```bash
git clone --recursive https://github.com/ProcursusTeam/Procursus.git
cd Procursus
```

### 4. Get an iOS SDK

Procursus needs a real iPhoneOS SDK tree (not just command-line tools). The community
standard source is `theos/sdks`. Pin close to the target device's OS version (iOS 16.7.11),
but note SDK availability there drifts over time — the bot should try the closest available
version and fall back to an adjacent one if it 404s:

```bash
git clone https://github.com/theos/sdks.git /tmp/sdks
mkdir -p sdks
cp -r /tmp/sdks/iPhoneOS16.*.sdk sdks/ 2>/dev/null || cp -r /tmp/sdks/iPhoneOS15.*.sdk sdks/
```

### 5. Confirm the rootless build flag before running

**This is the part most likely to need iteration.** Before trusting any specific flag name,
have the bot actually read the live makefile:

```bash
cat makefiles/nodejs.mk
```

Look for how Procursus distinguishes rootless vs rootful targets — variable names like
`TARGET`, `ROOTLESS`, or a separate make target entirely (e.g. `nodejs-rootless-package`)
may exist instead of a flag. Confirm against the current file rather than assuming — Procursus's
build conventions have changed over the project's life, and the exact mechanism used for this
repo wasn't independently verified past what's inferable from folder/file naming.

Once confirmed, build:

```bash
make nodejs-package TARGET=rootless ARCH=iphoneos-arm64
```

(exact invocation may need adjusting per what step 5's inspection reveals)

### 6. Upload the resulting `.deb` as a build artifact

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: nodejs-ios-rootless
    path: Procursus/packages/*.deb
```

### 7. (Optional next stage) Transfer to iPad and install

Once the artifact exists, a follow-up job/step can `scp` it to the iPad over Termius/SSH and
run:

```bash
dpkg -i /path/to/nodejs_<version>_iphoneos-arm64.deb
```

This step needs the iPad reachable (Tailscale/local network/whatever Bobby already uses for
Termius access) and shouldn't be baked into the same CI run unless the runner has a path to
reach the device.

---

## Known Unknowns / What Will Likely Need Debugging

- **SDK version mismatch**: if the closest `theos/sdks` version doesn't build cleanly against
  iOS 16.7.11 target, may need to try adjacent SDK versions.
- **Missing sub-dependencies during build**: Procursus packages often pull in other Procursus-built
  tools (zlib, openssl, icu, etc.) as build-time deps — expect the first few runs to fail on these
  and need `brew install` or Procursus makefile targets added incrementally, same iterative pattern
  as the ANEMLLChat IPA workflow required (scheme name, xcconfig, SDK download fixes each needed
  their own fix pass).
- **libnode versioning**: the old on-device package depended on `libnode83`. A freshly-built rootless
  Node may package this differently (statically linked, different lib name/version) — don't assume
  the old dependency name carries over; check what the fresh build actually produces.
- **Signing**: rootless jailbreak binaries generally need `ldid`-based fake-signing to run, which
  is included in the Homebrew deps above — confirm the makefile actually invokes it on the output.

---

## Summary for the bot

1. macOS runner, not Linux.
2. Homebrew deps + GNU tools on PATH.
3. Clone Procursus, fetch a matching iOS SDK.
4. **Read `makefiles/nodejs.mk` before building** — confirm real rootless flag/target name.
5. Build, upload `.deb` artifact.
6. Manually (or in a follow-up job) transfer + `dpkg -i` on the iPad.
7. Expect iteration — treat first-run failures as normal, same as prior CI/CD work, not as a
   sign the approach is wrong.
