# DarkSword AI for iPadOS 16

`Codex-DEB-Test` rebuilds the complete advanced [`NightVibes33/litter`](https://github.com/NightVibes33/litter) source tree as a ChatGPT-account-powered, rootless jailbreak research environment for the iPad 5th generation on iPadOS 16.7.11.

It is not a small replacement UI and it does not remove Litter features. The complete Litter Codex bridge, account flow, model picker, conversations, streaming, plugins, voice, terminal, file workspace, Git integrations, KittyStore, SideStore, BuildKit, LiveProcess, Live Activities, Watch targets, PiP, CarPlay, Ghostty, and embedded iSH runtime remain in the imported source.

## Required product architecture

```text
Codex-DEB-Test
├── upstream/litter/                   complete NightVibes33/litter snapshot
├── DarkSwordAI.app
│   ├── ChatGPT login/interface        full Litter chat engine + real in-app OAuth
│   ├── research workspace             jailbreak-lab navigation and experiment state
│   ├── crash and panic viewer         indexes readable .ips/.panic/.crash reports
│   ├── source editor                  absolute-path read and approval-gated writes
│   └── tool-approval interface        root daemon status and permission boundaries
├── darksword-rootd
│   ├── filesystem tools
│   ├── process/service tools
│   ├── Git tools
│   ├── build/install tools
│   └── bounded experiment execution
├── jailbreak-lab/
│   ├── harnesses/                     minimal authorized reproducer templates
│   ├── bin/darksword-poc-run          timeout/output/resource-limited runner
│   ├── bin/darksword-crash-classify   local crash/panic classifier
│   └── schema/experiment.schema.json  reproducible experiment records
└── packaging
    ├── unsigned IPA builder
    └── rootless iphoneos-arm64 DEB builder
```

## ChatGPT and Google login

The native Chat tab contains the complete Litter `ContentView`, model picker, conversation UI, streaming renderer, attachments, and tool-call cards. Its **Continue with Google** button calls Litter's real `appModel.loginLocalChatGPTAccount(serverId:)` account flow. That opens OpenAI's official ChatGPT OAuth screen inside the existing authentication process; select **Continue with Google** there. After authorization, the resulting ChatGPT account is activated for the local runtime and managed by Litter's existing secure multi-account token store.

DarkSword does not request, intercept, or store a Google password, and it does not manually extract ChatGPT browser cookies. The account-powered local tool loop uses the full NightVibes Litter Codex transport and its ChatGPT-account authentication, presented through DarkSword's Chat interface.

Model availability comes from the signed-in account and the imported NightVibes Codex fork. The app must not hard-code a model name that the account/server does not advertise.

## Tool execution

The rootless DEB installs:

```text
/var/jb/Applications/DarkSwordAI.app
/var/jb/usr/libexec/darksword-rootd
/var/jb/Library/LaunchDaemons/com.nightvibes.darksword-rootd.plist
/var/jb/usr/share/darksword/jailbreak-lab
/var/jb/usr/bin/darksword-poc-run
/var/jb/usr/bin/darksword-crash-classify
```

The app and Litter Rust bridge communicate with `darksword-rootd` through:

```text
/var/jb/var/run/darksword-rootd.sock
```

Read-only inspection and bounded diagnostics may run automatically. Source writes, patch application, package/service changes, and elevated PoC runs require explicit local approval. Device erasure, credential extraction, destructive disk commands, unattended persistence, and unattended kernel writes remain blocked.

## Build outputs

The GitHub Actions pipeline is intended to produce both:

```text
DarkSwordAI-full-unsigned.ipa
com.nightvibes.darkswordai_0.2.0_iphoneos-arm64.deb
```

The IPA contains the full app and bundled lab templates but cannot install a root LaunchDaemon by itself. The DEB installs the same app plus the privileged daemon and executable lab tools.

## Current build state

The architecture and packaging sources are committed. A build is not considered complete until GitHub Actions reports all of these as successful:

- full NightVibes source verification;
- Rust/Codex/Ghostty build;
- iOS app and embedded targets;
- root daemon compilation;
- IPA and DEB packaging.

`BUILD_STATUS.md` is written by CI with the exact compiler and packaging results.

## Install the DEB

```sh
dpkg -i com.nightvibes.darkswordai_0.2.0_iphoneos-arm64.deb
sbreload
```

Useful terminal checks after installation:

```sh
ls -l /var/jb/var/run/darksword-rootd.sock
darksword-crash-classify
darksword-poc-run --timeout 15 -- /var/mobile/Projects/example-harness
```

A new jailbreak or exploit is never guaranteed. The lab provides source analysis, reproducible harness execution, crash/panic collection, classification, build support, and bounded iteration on the user's own device.
