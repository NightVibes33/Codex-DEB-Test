# Alley Cãt

<p align="center">
  <img src="https://github.com/NightVibes33/Codex-DEB-Test/raw/main/upstream/litter/apps/ios/Sources/Litter/Resources/brand_logo.png" alt="Alley Cãt logo" width="180" />
</p>

<p align="center">
  Native iOS ChatGPT and Codex client with the original Alley Cãt SwiftUI interface, a Rust bridge, an embedded iSH runtime, optional rootless iOS host tools, remote computer connections, and an experimental Nyxian-based Swift BuildKit.
</p>

<p align="center">
  <a href="https://kittylitter.app"><img src="https://github.com/NightVibes33/Codex-DEB-Test/raw/main/upstream/litter/docs/badges/website.svg" alt="kittylitter.app" /></a>
  &nbsp;
  <a href="https://apps.apple.com/us/app/kittylitter/id6759521788"><img src="https://github.com/NightVibes33/Codex-DEB-Test/raw/main/upstream/litter/docs/badges/app-store.svg" alt="App Store" /></a>
</p>

## Project Purpose

Alley Cãt is being extended into a fully on-device AI development and authorized jailbreak-research workspace for jailbroken iPhones and iPads. The app keeps the complete original Alley Cãt interface and feature set while adding a rootless host bridge, a Chat/Work mode selector, crash and panic analysis, source editing, bounded experiment tools, and rootless `.deb` packaging.

The intended product experience is one Alley Cãt conversation interface with two usage routes:

- **Chat** is the ChatGPT cloud route. It is intended to use normal ChatGPT conversation usage while retaining access to approved local Alley Cãt tools through a cloud-to-device tool bridge.
- **Work** is the Codex route. It uses Alley Cãt's existing Codex transport, agent loop, model picker, permissions, terminal, files, Git, BuildKit, and remote-computer support.

Both routes are designed to request the same local filesystem, process, Git, build, crash-analysis, and research tools. Root commands do not execute silently: the exact command, working directory, and command hash must be approved on the device before the root daemon accepts the retry.

This project does not claim that an AI model can guarantee a new jailbreak. Its purpose is to make authorized, reproducible on-device research easier by combining source inspection, crash collection, controlled experiments, builds, logs, and local tool execution in one interface.

## Current Implementation Status

Implemented in the current integration:

- The **full original Alley Cãt UI** remains the app root. The old replacement DarkSword tab shell is not the product interface.
- A **Chat / Work selector** is added inside Alley Cãt's existing model changer without removing its current account, runtime, model, reasoning, planning, speed, or permission controls.
- **Work remains the default** so existing Alley Cãt/Codex behavior is preserved.
- The existing signed-in ChatGPT account and computer-bridge flows remain intact.
- A rootless host daemon can execute approved commands on the real iOS host filesystem instead of only the embedded iSH fakefs.
- The daemon uses an **exact-command, one-time approval protocol**. Approval is tied to the queued command hash and expires rather than granting a permanent unrestricted background session.
- The rootless package includes the host daemon, launch daemon, jailbreak lab, crash classifier, bounded PoC runner, and Alley Cãt application bundle.
- Alley Cãt Labs adds a research workspace, crash and panic viewer, source editor, and tool-approval interface inside the original Alley Cãt settings/navigation structure.
- The integration includes iOS 16 compatibility work for the iPad 5th generation target, including Swift Observation backporting, SwiftUI compatibility shims, Ghostty deployment changes, pinned Zig, and iOS-specific Rust compiler isolation.
- CI uses a simplified **clone Alley Cãt -> apply integration patch -> build IPA and rootless DEB** lane.

Remaining MVP work:

- The persistent **ChatGPT cloud transport** must be completed and verified so Chat consumes normal ChatGPT usage while structured local-tool requests are executed by Alley Cãt and returned to the same cloud conversation.
- The Chat route must use the exact same on-device approval system as Work. It must not bypass the root daemon or execute unapproved cloud-originated commands.
- A successful source patch or smoke test is not the same as a verified installable release. The full IPA and `.deb` workflow must finish green before a build is labeled ready.

## Current Scope

Alley Cãt is a SwiftUI iOS app that communicates with Codex through `shared/rust-bridge`. It can run Codex commands inside an embedded iSH Alpine Linux fakefs, connect to Codex app servers on other computers, pair through Slingshot, and route agent work through a signed-in ChatGPT account or OpenAI-compatible servers such as Ollama or LM Studio running on another computer.

On a normal or IPA-only installation, Alley Cãt retains the original iSH behavior. Commands run in the embedded persistent Alpine fakefs and do not automatically receive iOS host-root access.

On a supported rootless jailbreak installation, the `.deb` installs a root-owned companion daemon. When its Unix socket is available, Alley Cãt's shell bridge can queue commands for execution against the real iOS host filesystem. Each queued root command must be approved from the on-device Alley Cãt approval view before it is executed. When the daemon is unavailable, commands fall back to the original iSH runtime.

iPhone-local model downloading and inference are not part of this integration. Private or local models should run on a computer and be added through the AI Providers screen as an OpenAI-compatible `/v1` endpoint.

The repository contains CI lanes for unsigned sideload IPAs, a rootless `iphoneos-arm64` `.deb`, source compatibility checks, root-approval smoke tests, and the original Alley Cãt BuildKit and mobile release work. Public source contains Nyxian and BuildKit integration code, but Apple SDK payloads and compiled private BuildKit frameworks are not committed.

Original creator/upstream maintainer: [Daniel Nakov / dnakov](https://github.com/dnakov). The Alley Cãt fork is maintained by [NightVibes33](https://github.com/NightVibes33). In this repository, NightVibes, NightVibes33, NightVibes3, ZYN, and Zyn refer to the same fork maintainer, not separate contributors. Accepted upstream contributors and third-party attribution are tracked in [AUTHORS.md](AUTHORS.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Screenshots

<p align="center">
  <img src="https://github.com/NightVibes33/Codex-DEB-Test/raw/main/upstream/litter/docs/screenshots/01-hero-iphone-1320x2868.png" alt="Home" width="200" />
  <img src="https://github.com/NightVibes33/Codex-DEB-Test/raw/main/upstream/litter/docs/screenshots/02-remote-iphone-1320x2868.png" alt="Remote servers" width="200" />
  <img src="https://github.com/NightVibes33/Codex-DEB-Test/raw/main/upstream/litter/docs/screenshots/07-generative-ui-iphone-1320x2868.png" alt="Generative UI" width="200" />
  <img src="https://github.com/NightVibes33/Codex-DEB-Test/raw/main/upstream/litter/docs/screenshots/05-realtime-voice-iphone-1320x2868.png" alt="Realtime voice" width="200" />
</p>

## Repository Layout

The build repository combines the original Alley Cãt source architecture with a small rootless/iOS-16 integration layer:

```text
apps/ios/                   Original SwiftUI app. project.yml is the XcodeGen source of truth.
apps/android/               Original Android app, Compose UI, proot/Ghostty integration, and release lanes.
shared/rust-bridge/         Rust mobile bridge, UniFFI API, iSH/proot runtime, SSH, Slingshot, terminal, and app-server transport.
shared/third_party/codex/   Upstream Codex submodule used by the bridge.
shared/third_party/ghostty/ Pinned Ghostty renderer submodule used by terminal work.
patches/codex/              Alley Cãt Codex patches applied during sync/build.
patches/ghostty/            Alley Cãt mobile embedding patch for Ghostty.
ThirdParty/Nyxian/          Nyxian/CoreCompiler/LLVM-On-iOS source used by BuildKit.
ThirdParty/SideStore/       SideStore/AltSign/minimuxer/LocalDevVPN source and references.
ThirdParty/Feather/         Feather/Zsign source snapshots and signing-flow references.
jailbreak-lab/              Harness templates, bounded PoC runner, crash classifier, and experiment schema.
darksword-overlay/          Temporary internal integration path containing Alley Cãt rootless, iOS-16, approval, and packaging patches.
tools/scripts/              Build, release, BuildKit asset, and verification scripts.
docs/                       Development notes, screenshots, badges, and release docs.
.github/workflows/          Direct-clone Alley Cãt IPA/DEB build, smoke checks, and original release lanes.
```

`darksword-overlay/` is a legacy internal directory name, not the user-facing app name. It still contains active build inputs, including the root daemon source, approval UI source, Rust host bridge, compatibility transforms, and package scripts. It must not be deleted until those paths are renamed and every workflow/package reference is updated. A future cleanup should rename it to an Alley Cãt-specific integration path without changing behavior.

Tracked source includes Swift, Rust, Objective-C/C/C++, shell scripts, XcodeGen config, GitHub Actions workflows, and vendored source required by the mobile runtime.

## Quick Start

The canonical Alley Cãt source remains `NightVibes33/litter`. This integration repository's preferred workflow clones that source directly, restores its submodules, applies the small rootless/iOS-16 patch set, builds the runtime, builds the app, builds the root daemon, and packages both distribution formats.

On macOS, install Xcode, Rust, XcodeGen, and the expected mobile toolchains, then use the upstream Make targets:

```bash
make ios-device-fast       # fast iOS device build
make ios-sim-fast          # fast simulator build
make android-emulator-fast # fast Android emulator build
make rust-check            # host cargo check for shared Rust crates
make rust-test             # host cargo test for shared Rust crates
```

`apps/ios/project.yml` drives the checked-in Xcode project:

```bash
make xcgen
```

For the rootless iOS 16 integration, use the repository workflow:

```text
.github/workflows/build-alleycat-ios16.yml
```

That lane is intentionally simple:

```text
clone NightVibes33/litter
-> restore Codex/Ghostty and other source dependencies
-> apply Alley Cãt iOS-16/rootless integration
-> build Rust, Ghostty, Alpine fakefs, and Xcode project
-> build AlleyCat.app
-> build root daemon
-> package unsigned IPA and rootless DEB
-> upload artifacts and logs
```

The integration deployment target is iOS 16.1 or newer so it can run on iPadOS 16.7.11. This is different from the current upstream Alley Cãt iOS 18 deployment target. Compatibility transforms are applied during the integration build rather than pretending the upstream app natively targets iOS 16.

The expected integration artifacts are:

```text
AlleyCat-iOS16-full-unsigned.ipa
com.nightvibes.alleycat_0.2.0_iphoneos-arm64.deb
```

All generated IPAs are unsigned and must be signed before installation. The rootless host runtime requires the `.deb`; installing only the IPA does not install or launch the root daemon.

## Architecture

The original SwiftUI app continues to own the native interface: home, conversations, model/runtime picker, settings, file workspace, terminal panel, account and Keychain flows, PiP, CarPlay, Watch surfaces, KittyStore, and BuildKit controls. This integration does not replace the original Alley Cãt UI with a separate shell.

The Rust bridge continues to own Codex app-server communication, session hydration, Slingshot pairing, SSH bridge behavior, remote path handling, saved apps/widgets, permission state, iSH command execution, and the UniFFI surface consumed by Swift.

The integration adds three layers:

1. **Chat / Work routing** inside the existing model changer.
2. **Rootless host execution** through a root-owned Unix socket daemon.
3. **Alley Cãt Labs** for crash analysis, source work, experiments, and approvals.

### Chat And Work

**Work** preserves Alley Cãt's existing Codex route. It can use the signed-in ChatGPT account, a connected computer bridge, or another supported Codex/app-server route. It retains the original model picker, reasoning controls, planning, permissions, tools, sessions, files, and terminal behavior.

**Chat** is intended to use a persistent ChatGPT cloud session and normal ChatGPT usage. The completed design must allow the cloud conversation to request structured local operations, queue them in Alley Cãt, receive on-device approval, execute them locally, and return the result to the same cloud conversation.

The Chat/Work selector by itself does not prove that separate usage routing is complete. A release must not advertise normal ChatGPT usage for Chat until the cloud transport, response extraction, tool-request parser, result return path, session persistence, and approval integration are verified end to end.

### Embedded iSH Runtime

The original local runtime is an embedded persistent iSH Alpine Linux fakefs. The default home is `/root`; Alley Cãt creates `/root/litter`, `/root/.litter/builds`, and `/usr/local/bin`; app Documents are bridged through `/mnt/apps`; the native app container is repaired at `/mnt/container`; and Codex home is bridged to `/root/.codex` so installed skills are visible to the runtime.

Before exposing local shell tools, Alley Cãt runs a native preflight command. If simple commands such as `true`, `pwd`, or `ls` fail with bootstrap errors, debug the iSH runtime bridge first. PATH, Swift, and BuildKit checks come after the fakefs is bootstrapped.

### Rootless Host Runtime

The rootless `.deb` adds a separate host runtime:

```text
Alley Cãt / Rust shell bridge
        |
        | Unix socket
        v
/var/jb/var/run/darksword-rootd.sock
        |
        v
root-owned command execution on the real iOS host
```

The current internal daemon and socket retain the `darksword` name for compatibility, but the product remains Alley Cãt.

When the socket exists, the Rust shell bridge can route a command to the host daemon. When it does not exist, Alley Cãt falls back to the embedded iSH runtime.

### Exact Root Approval

The root daemon does not treat the Chat or Work model as the approving authority. The device user is the authority.

The execution flow is:

1. Chat or Work requests a command with an explicit working directory and timeout.
2. The daemon records the exact command and computes its command hash.
3. Alley Cãt's approval view reads the pending request from the daemon.
4. The user can approve that exact command once or deny it.
5. Approval is short-lived and consumed by the approved retry.
6. A modified command, different working directory, expired approval, or second execution requires a new approval.

Approved commands are not restricted to a small path allowlist. They can read and write the host filesystem according to the privileges of the root daemon. This is intentionally powerful and can damage or disable the device if the user approves a destructive command. Keep backups and review every command before approval.

The approval mechanism is intended to prevent silent cloud-originated or agent-originated root execution. It is not a sandbox and does not make an approved command safe.

## Rootless Package Layout

The rootless package installs:

```text
/var/jb/Applications/AlleyCat.app
/var/jb/usr/libexec/darksword-rootd
/var/jb/Library/LaunchDaemons/com.nightvibes.darksword-rootd.plist
/var/jb/usr/share/darksword/jailbreak-lab
/var/jb/usr/bin/darksword-poc-run
/var/jb/usr/bin/darksword-crash-classify
```

The expected package identity is:

```text
Package: com.nightvibes.alleycat
Architecture: iphoneos-arm64
Minimum firmware: iOS 16.1
```

The post-install process creates the experiment storage directory, loads the launch daemon, and refreshes the application registration. Exact behavior depends on the rootless jailbreak environment and package manager.

## Alley Cãt Labs

Alley Cãt Labs is added inside the original Alley Cãt navigation/settings structure. It does not replace the main home or conversation UI.

### Research Workspace

The workspace links the included research resources:

```text
jailbreak-lab/harnesses/    userspace harness templates
jailbreak-lab/bin/          bounded runner and crash classifier
jailbreak-lab/schema/       experiment metadata schema
/var/mobile/Library/DarkSwordLab/experiments
                            local experiment records and logs
```

The internal experiment directory retains a legacy name for compatibility.

### Crash And Panic Viewer

The crash viewer indexes readable `.ips`, `.panic`, and `.crash` files from common iOS crash-report locations, including the mobile CrashReporter tree. It allows local review of crash and panic text without manually exporting every report first.

### Source Editor

The source editor reads and writes text files by absolute path. In the normal app sandbox it is limited by the process sandbox. Host-root edits should be performed through the approved root tool path so the daemon, command hash, and audit flow remain involved.

### Bounded Experiment Runner

The bounded PoC runner is for authorized testing on devices the researcher owns or is permitted to test. It records command metadata and applies runtime/output limits. The experiment system is not proof of an exploit, a jailbreak, or kernel-code execution.

### Crash Classifier

The classifier categorizes common report types such as panics, watchdog events, memory failures, signals, and exceptions. Classification is a triage aid, not a vulnerability verdict.

## Main iOS Features

The original Alley Cãt features remain part of the app:

- Home dashboard for local and remote sessions, active turn state, recent activity, branch/fork actions, rename/delete/hide actions, goal banners, and connection status.
- Conversation timeline with markdown, tool cards, command output display preferences, image generation cards, selectable messages, edit/fork actions, streaming rendering, and dynamic widget rendering.
- Discovery and connection flows for the local runtime, manual app-server URLs, SSH bootstrapping, LAN or remote servers, and Slingshot connected computers.
- Settings for appearance, fonts, conversation display, local terminal, experimental features, AI providers, diagnostics bundles, account/API key/base URL, connected servers, updates, BuildKit controls, and Alley Cãt Labs.
- KittyStore, a SideStore/AltStore-compatible store surface with source news, multi-source browsing, direct install links, and a Feather-style signing workspace.
- Picture-in-Picture streaming cards through `AVPictureInPictureController` with a sample-buffer SwiftUI renderer.
- CarPlay voice scene support and experimental Apple Watch projection/complication targets.
- Chat/Work mode selection within the existing model changer.
- Rootless host-tool status and exact-command approval when installed through the `.deb`.

## Files And Terminal

The Files button continues to open the iSH workspace rooted at `/root`. It uses the same fakefs command bridge used by Codex tool calls and the terminal panel, so normal file actions operate on the same fakefs the local Codex runtime sees. Native app storage remains available through `/mnt/container` for diagnostics, logs, app documents, caches, and the fakefs backing store.

The file workspace includes list/grid views, breadcrumbs, search, sorting, filters, hidden-file toggles, quick locations, favorites, recents, inspectors, archive/build-artifact detection, and bot-context path copying. It exposes file operations for creating, renaming, moving, duplicating, deleting, making executable, sharing, compressing, extracting, importing from iOS Files, and editing text/code files.

The terminal lives in Settings under `Local Tools -> Terminal`. `Open Terminal Here` from the file browser sets the starting directory for the same terminal. It is a command panel backed by the current command bridge: prompt, cwd tracking, history, shortcut keys, copy output, clear, and streaming command execution.

Runtime behavior differs by installation:

- **IPA only or daemon unavailable:** commands use iSH Alpine fakefs.
- **Rootless `.deb` and daemon available:** shell requests can be routed to the iOS host after exact on-device approval.

The file browser itself does not automatically become a root filesystem browser merely because the daemon exists. Root host operations should go through explicit tools/commands and the approval queue.

BuildKit shortcuts in the file workspace and BuildKit settings continue to call the supported fakefs commands, including Swift check, Swift build, IPA build, build status, fakefs doctor, and `LitterBuild.json` creation.

## Appearance And Streaming

Appearance settings include system/light/dark mode selection, app-wide conversation font scaling, live preview, and separate light/dark theme pickers loaded from app resources.

Conversation wallpapers are scoped per thread or per server. Supported sources include built-in generated presets, light/dark app themes, solid colors, images from Photos, videos from Photos, and video URLs. Custom image preview uses a fitted renderer instead of blindly zooming the image to fill the screen.

Built-in background presets in `WallpaperManager` are Aurora, Terminal Grid, Blueprint, Midnight Neon, Ocean Glass, Sakura, Carbon Mesh, Solar Flare, Paper, and Forest.

Typing effects are persisted with the wallpaper scope and are driven by `StreamingEffectKind` plus HairballUI `StreamingTextEffect` implementations. Current options include Fade Edge, Sparkle, Glow Cursor, Wave, Scale Pop, Rainbow, Fire Trail, Explosion, Nyan Cat, Matrix Decode, Phosphor CRT, Shockwave, Typewriter, Terminal Scan, Soft Blur, Neon Pulse, Ghost Trail, Pixel Decode, Ink Spread, Slide Up, Glitch, and Focus Beam.

## AI Providers And Usage Routes

The original provider routes remain:

- **ChatGPT Account:** signed-in ChatGPT account used by the local Codex route.
- **Computer Bridge:** selected Mac, Windows, or Linux Codex app-server bridge.
- **OpenAI-compatible server profiles:** custom `/v1` endpoints for services such as Ollama or LM Studio running on another machine.

The new Chat/Work selector is conceptually separate from the provider selector:

- The provider selector decides which account/server/runtime supplies the model connection.
- The Chat/Work selector decides whether the user is starting a normal cloud conversation or an agentic Codex task.

Work currently maps to the proven Alley Cãt/Codex architecture. Chat is intended to map to a persistent ChatGPT cloud session with separate normal ChatGPT usage. Until the cloud bridge is implemented and verified, the README and release notes must not claim that selecting Chat already changes billing/usage pools.

Both completed routes are intended to expose the same local tool catalog. The difference is the model/usage platform, not whether the user can approve local reads or writes.

Legacy on-device AI state is cleaned up on load. Old local provider records are skipped, old local routing preferences fall back to automatic, old local model files are purged from app documents, and only hosted routes are shown in the picker.

## Thread Goals

The Rust bridge advertises `features.goals` and exposes UniFFI methods for getting, setting, clearing, and hydrating thread goals. iOS stores hydrated goals in app state and renders goal status, objective, and usage in the home dashboard and PiP views. Goal persistence depends on the connected Codex server state database for that thread.

## Swift BuildKit

BuildKit is the experimental on-device Swift/iOS build path. Alley Cãt vendors Nyxian source, verifies it with `tools/scripts/verify-nyxian-source-import.sh`, and layers an Alley Cãt-specific native bridge on top. The public repository has source and reproducible scripts. Full Swift/iOS compilation still needs a private `LitterBuildKitAssets.zip` because Apple SDK files and compiled private frameworks are not committed.

If `litter-buildkit-install-assets` reports `assets-missing` with a ZIP extraction error, replace `Documents/LitterBuildKitAssets.zip` or `Documents/Inbox/LitterBuildKitAssets.zip` with a known-good private asset pack and rerun:

```bash
litter-buildkit-install-assets --timeout 300
```

The private asset pack must include:

- `Toolchains/Nyxian/CoreCompiler.framework`
- `Toolchains/Nyxian/CoreCompilerSupportLibs`
- `Toolchains/Nyxian/SwiftResourceDir`
- `Toolchains/Nyxian/LitterBuildKitNative.framework`
- `SDK/iPhoneOS<version>.sdk`
- optional `Toolchains/Nyxian/bin/litter-buildkit-runner`
- `manifest.json` with required paths and SHA256 entries

Changing `ThirdParty/Nyxian/LitterBuildKitNative/**` does not change installed app behavior by itself. The app loads `LitterBuildKitNative.framework` from `LitterBuildKitAssets.zip`. After native bridge changes, rebuild and upload the private asset pack, update `LITTER_BUILDKIT_ASSET_URL` and `LITTER_BUILDKIT_ASSET_SHA256`, then build the IPA against that asset.

Nyxian run/install mode also needs the Apple ID and signing state used by the original Nyxian flow: an Apple ID login saved in Keychain, a SideStore-compatible Anisette server, the matching `.p12` signing identity, and the embedded provisioning profile from the signed Alley Cãt installation.

KittyStore validates imported signing material before it is treated as usable. A bad `.p12` password or missing private key keeps Nyxian run/install blocked and reports the failure. The Feather-style signing workspace validates per-app provisioning profiles for parse errors, expiration, missing developer certificates, bundle ID mismatch, and profile/certificate mismatch before certificate signing starts.

Alley Cãt is open source, but it is not MIT licensed. The project is licensed under GNU GPLv3 with an additional GPLv3 section 7 permission for Apple App Store and Google Play distribution. Third-party source imports and submodules keep their own licenses; see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The Anisette picker can load SideStore's public server list, fall back to known SideStore-compatible servers, and accept a custom server URL. Anisette supplies Apple authentication metadata; it does not install apps by itself.

Full on-device install/refresh needs SideStore-style local transport. KittyStore can launch LocalDevVPN through `localdevvpn://`, then the linked SideStore minimuxer bridge checks whether the tunnel transport is ready. Swift compilation, unsigned IPA packaging, and save-only signing can work without LocalDevVPN, but direct install/refresh/remove/list operations remain unavailable until LocalDevVPN is enabled and a pairing file is imported.

Canonical fakefs commands installed into `/usr/local/bin` include:

```text
litter-buildkit
litter-nyxian-status
litter-buildkit-install-assets
litter-fs-doctor
litter-env-report
litter-dev-bootstrap
litter-swift-check
litter-swift-selftest
litter-swiftc
litter-swift-build
litter-swift-test
litter-ipa-build
litter-ipa-package
litter-clang
litter-ld
litter-build-status
litter-build-cancel
```

Compatibility shims are installed for common bot expectations:

```text
swift swiftc clang clang++ cc c++ ld ld64 xcodebuild xcrun plutil code
ar llvm-ar ranlib llvm-ranlib nm llvm-nm objdump llvm-objdump strip strings lipo
```

`litter-*` commands are the supported compatibility API. BuildKit v1 is not desktop Xcode: SwiftPM package resolution, simulator workflows, Interface Builder, previews, App Store upload flows, Apple Developer portal management, and macOS toolchains are outside scope.

Useful in-app checks:

```bash
litter-fs-doctor
litter-build-status
litter-nyxian-status
litter-swift-selftest
printf 'print("Swift is running on device")\n' > /root/hello.swift
litter-swift-check /root/hello.swift
swiftc /root/hello.swift -o /root/hello
```

## Private BuildKit Asset Flow

`.github/workflows/buildkit-assets.yml` builds or reuses the private BuildKit asset pack on `macos-26`, verifies it, and can upload it to the private asset release repository. Defaults are:

- owner: `NightVibes33`
- repo: `litter-buildkit-assets`
- tag: `buildkit-ios26.4-v1`
- asset name pattern: `LitterBuildKitAssets-<run>-<attempt>.zip`

Use this flow when BuildKit source or private framework behavior changes:

1. Run `Build Private BuildKit Assets` on the branch containing the source fix.
2. Use `force_rebuild=true` when the native framework or Swift/LLVM payload must be rebuilt.
3. Set `use_existing_private_release=false` when proving the old private release asset is not being reused.
4. Let the workflow upload a verified `LitterBuildKitAssets.zip` and update unsigned IPA asset secrets.
5. Run or dispatch the relevant IPA workflow on the same branch.
6. Install the new IPA and run `litter-swift-selftest` inside Alley Cãt.

Normal public IPAs keep the private compiler payload external for launch safety. The app can download/install user-owned BuildKit assets from BuildKit settings.

## Unsigned IPA, Rootless DEB, And AltStore Source

The original Alley Cãt unsigned IPA workflow continues to produce SideStore/AltStore-style artifacts and release metadata. This integration adds a dedicated iOS 16 rootless workflow:

```text
.github/workflows/build-alleycat-ios16.yml
```

Its expected outputs are:

```text
AlleyCat-iOS16-full-unsigned.ipa
com.nightvibes.alleycat_0.2.0_iphoneos-arm64.deb
full build logs and diagnostics
```

The IPA contains the app. The `.deb` contains the app plus the root daemon, launch daemon, research tools, and package integration. Users who need real host-root tools must install the `.deb` on a compatible rootless jailbreak.

The original `.github/workflows/ios-unsigned-ipa.yml` lane builds a SideStore/AltStore-style unsigned IPA and produces a checksum, build metadata, release notes, `litter-update.json`, and `litter-altstore-source.json`.

Original manual build modes include:

- `fast-device`: normal fast device lane that reuses generated Rust assets where possible and keeps private BuildKit compiler payload external.
- `release-device`: full device lane that rebuilds Rust.
- `nyxian-private`: private/manual lane that embeds verified private BuildKit assets and retains the required LiveProcess extension.

Every successful IPA must remain unsigned until signed by SideStore, AltStore, Feather, or another signing tool.

The AltStore/SideStore source is version-history first. Each successful versioned IPA release should remain installable through the app entry `versions` array with its own download URL, SHA-256 checksum, version date, size, minimum iOS version, and build version.

The in-app KittyStore tab retains the SideStore five-tab surface: News, Sources, Browse, My Apps, and Settings. Feather-style signing remains in Settings > Signing with IPA customization, certificate/provisioning selection, pairing import, LocalDevVPN status, advanced modification rows, entitlements, tweaks, properties, and signing.

The repository keeps source snapshots for SideStore, Feather, and LocalDevVPN at the commits recorded in `ThirdParty/UPSTREAMS.md`. Alley Cãt does not claim ownership of SideStore, Feather, or supporting tools; attribution remains in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Bots retain the fakefs command surface:

```text
litter-kittystore-status
litter-kittystore-config
litter-kittystore-source
litter-kittystore-versions
litter-kittystore-validate-profile
litter-kittystore-plan
litter-kittystore-sign
litter-kittystore-install
litter-kittystore-refresh
litter-kittystore-remove
litter-kittystore-installed
```

## Local Runtime Notes

- Alley Cãt always retains the embedded iSH Alpine runtime.
- With no root daemon, local commands run in iSH fakefs, not the iOS host filesystem.
- With the rootless `.deb` installed and the daemon socket available, the Rust shell bridge may queue a host command for exact user approval.
- Host-root approval is command-specific. A previous approval does not authorize a changed command or unlimited background access.
- The iSH fakefs can see `/root`, `/tmp`, `/usr/local/bin`, `/root/.codex`, `/root/litter`, app-provided mounts such as `/mnt/apps`, and the app container bridge at `/mnt/container`.
- Arbitrary iOS host paths are not made visible inside fakefs automatically. Host access uses the root daemon path.
- The root daemon is an execution service, not a transparent filesystem mount. Existing Files UI behavior remains rooted in iSH unless a dedicated host-files UI is added.
- `litter-dev-bootstrap` repairs expected fakefs utilities where possible. Some tools may still require Alpine packages.
- Shell failures with exit `-6` indicate the iSH runtime was not ready or bootstrapped.
- Approval-required host requests are expected to pause, appear in Alley Cãt's approval view, and succeed only after the exact command is approved and retried.
- Root execution can alter or break the device. Maintain backups and inspect every requested command.

## Build And Verification Status

The repository separates fast structural checks from the full package build:

- The root approval smoke lane type-checks the Swift approval client for an iOS 16 target.
- The same lane compiles the root daemon source with warnings treated as errors.
- The integration overlay verifies Chat/Work state, the original Alley Cãt root UI, iOS compatibility transforms, compiler wrappers, and root approval markers.
- The full lane builds Rust/Codex, Ghostty, Alpine runtime, the Xcode project, AlleyCat.app, root daemon, IPA, and `.deb`.

A smoke-test pass proves only the checked source/compile boundary. A release is ready only when the full workflow produces the expected artifacts successfully.

## Make Targets

| Target | Description |
|---|---|
| `make ios-device-fast` | Fast iOS device build using the raw device staticlib lane. |
| `make ios-sim-fast` | Fast simulator build. |
| `make ios` | Full iOS package lane. |
| `make android-emulator-fast` | Fast Android emulator build. |
| `make android-alpine-fs` | Prepare the bundled Android Alpine fakefs. |
| `make proot-android` | Build Android proot executable artifacts. |
| `make ghostty-ios` | Build pinned Ghostty iOS renderer artifacts. |
| `make ghostty-android` | Build pinned Ghostty Android renderer artifacts. |
| `make sync-ghostty` | Sync pinned Ghostty while preserving the Alley Cãt mobile patch. |
| `make watch-register` | Register a newly paired Apple Watch for CLI install flows. |
| `make rust-check` | Host `cargo check` for shared Rust crates. |
| `make rust-test` | Host `cargo test` for shared Rust crates. |
| `make bindings` | Regenerate UniFFI Swift/Kotlin bindings. |
| `make xcgen` | Regenerate `Litter.xcodeproj` from `apps/ios/project.yml`. |
| `make alpine-fs` | Prepare the bundled iOS Alpine fakefs. |
| `make nyxian-vendor` | Refresh Nyxian/LLVM-On-iOS BuildKit source while preserving Alley Cãt's bridge. |
| `make nyxian-source-verify` | Verify the committed Nyxian source import. |
| `make nyxian-buildkit-assets` | Build/package private BuildKit assets on macOS. |
| `make nyxian-buildkit-assets-verify` | Validate a BuildKit asset ZIP or folder. |
| `make sidestore-minimuxer` | Build the SideStore minimuxer bridge used by KittyStore. |
| `make clean` | Remove build artifacts. |

## Contributors

Alley Cãt began in Daniel Nakov's original upstream repository, `dnakov/litter`, and the fork continues that work under `NightVibes33/litter`. Full evidence-backed credits are maintained in [CONTRIBUTORS.md](CONTRIBUTORS.md), including upstream PRs accepted into Daniel's original repository, direct upstream commit authors, and fork-only contributors.

| Contributor | Main credited work |
|---|---|
| Daniel Nakov (`dnakov`) | Original creator/upstream maintainer; iOS and Android app architecture, Rust/Codex bridge, SSH/local runtime, iSH/Alpine work, terminal/Ghostty/proot work, watch features, mobile UI, releases, and `kittylitter`/Alleycat. |
| NightVibes33 | Fork maintainer; BuildKit asset CI/downloads, Nyxian import work, BuildKit IPA wiring, local model workflow polish, file workspace fixes, distribution maintenance, iOS 16/rootless integration direction, and jailbreak research workflow. |
| Zyn | Unsigned IPA path, iOS skills bridge, AI-provider/local-model foundation, fakefs file workspace, native llama/TurboQuant work, local agent workspace, main-chat local model routing, and on-device Swift BuildKit integration. |
| Codex | AI-assisted implementation commits for local model tooling, BuildKit hardening, diagnostics, local file browser/runtime UX, CI, xcodebuild compatibility, Swift toolchain support, iOS 16 compatibility, rootless host bridge, approval protocol, and packaging work. |
| Maky (`makyinmars`) | Android/iOS session UX, composer/session cleanup, iOS Codex RPC bridge coverage, workspace/sidebar UX, skills/edit/rename/fork flows, tool-calling/picker UX, agent identity/collaboration flows, remote-host logos, iOS 18 support, search themes, server pill polish, SSH credential entry, theme mode, and AMP support. |
| D-DRUMROLL / Dixith-dev (`Dixith-dev`) | Android keyboard fixes, OpenCode mobile shell support, Android home/discovery/settings polish, Settings popover title alignment, dropdown positioning, and session deletion fixes. |
| Kaynan Sampaio de Camargo (`kaynansc`) | Editable saved server connections, Android SSH credential prompt parity, reconnect/edit behavior, Input Required dismissal, OpenAI base URL setting, thread-scoped prompts/rate limits, and runtime-channel routing. |
| Franklin | iOS/Android file search and commands, Android picker fixes, identifier/signing cleanup, session search, fonts/UX, model-list exposure, iOS exec hook work, iOS 18 support, themes, and CI/CD fixes. |
| sigkitten | Mobile IPC/runtime work, session loading, transcript/thread reuse, permissions, native math parsing, iOS tests, Android runtime/UI fixes, generative UI Rust migration, bridge cleanup, signing/provisioning, reconnect/notification behavior, and pets overlay. |
| tabrobotics | Android OpenCode/mobile shell work, bundled Codex server and Node proxy support, discovery/local bridge fixes, CI archive fallback, Gradle/lint fixes, Android image upload fixes, and input/model selector polish. |
| eagle.one / onegaop | Folder grouping for sessions in the sidebar plus related screenshot/homepage documentation. |
| kkellyoffical | Android conversation text selection, message selection preservation, markdown callback stabilization, user bubble styling restoration, and test stabilization. |
| Coy Geek (`coygeek`) | iOS transcript display controls and UI test coverage. |
| Niklas Sheth | iOS composer editing fix that avoids forcing selection while editing text. |
| researchoor | Live Activity timer cleanup and completed-session idle indicator. |
| Sina Rabiei (`nssina`) | Mac SSH setup documentation for exposing Codex sessions in Alley Cãt. |
| Paul Pincente (`pincente`) | Android large-screen discovery modal and TV focus navigation improvements. |
| frixa / frixaco | SSH bootstrap compatibility for Macs using Fish as the default shell. |
| ryanchen01 | Expanded resolver SSH probe behavior. |
| Jason Penilla (`jpenilla`) | SSH detection for Codex installed through Bun. |
| Thomas Zarebczan (`tzarebczan`) | Windows npm publishing support for `kittylitter`. |
| shuv (`shuv1337`) | iOS theme JSON decoding fixes for null/non-string values and `#RRGGBBAA` colors. |
| zulfaza | `~/.opencode/bin` PATH probing in SSH profile initialization. |
| Benjamin Western | Pi over Alleycat transport baseline improvements. |
| sliced-paraiba | POSIX command portability using `/usr/bin/env`. |

## Credits And License

Alley Cãt is a fork of [dnakov/litter](https://github.com/dnakov/litter). The fork is maintained by NightVibes33 / ZYN / Zyn, which are the same maintainer identity for this fork, and includes additional iOS sideloading, update-source, local runtime, BuildKit, UI, iOS 16, rootless host-tool, approval, packaging, and authorized research work.

The sideloading and on-device install/refresh work credits the wider ecosystem it builds around: SideStore, AltStore, LocalDevVPN, minimuxer, em_proxy, Jitterbug, Feather, Zsign, and their maintainers/contributors. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The rootless and jailbreak-research additions are intended only for devices the user owns or is explicitly authorized to test. Contributors must not use the project to access another person's device, extract credentials, deploy persistence without consent, or conceal destructive actions.

Alley Cãt is not MIT licensed. The project uses GPLv3 with an additional GPLv3 section 7 permission for Apple App Store and iOS distribution. Vendored Nyxian/emexDE source is AGPL-3.0-or-later, OpenAI Codex source is Apache-2.0, and third-party components retain their own licenses. See [LICENSE](LICENSE), [AUTHORS.md](AUTHORS.md), and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Contributing

The app, Rust bridge, fakefs runtime, host-root daemon, approval protocol, jailbreak lab, and private BuildKit pipeline are tightly coupled. Keep PRs focused and include the workflow or command used to verify each change.

Changes to Chat/Work routing must document which service handles the request, which usage pool it consumes, how authentication is stored, how local tool requests are represented, and how results return to the same conversation.

Changes to root tools must preserve exact on-device approval, show the complete command and working directory, avoid silent privilege escalation, and include daemon plus Swift-client smoke coverage.

BuildKit, Apple ID, signing, Anisette, LocalDevVPN, AltStore source, rootless package, and launch-daemon changes must document whether a new private BuildKit asset, IPA, or `.deb` is required.

Update this README whenever verified behavior changes. Do not describe planned transport or packaging work as complete until the relevant end-to-end build and runtime test succeeds. See [CONTRIBUTING.md](CONTRIBUTING.md) for contributor expectations.
