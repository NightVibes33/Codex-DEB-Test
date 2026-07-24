# DarkGPT iOS

DarkGPT iOS is a rootless jailbreak package for iOS 16+ that installs:

- a home-screen ChatGPT-style app using the official `chatgpt.com` session;
- an official ChatGPT sign-in screen, including Continue with Google when OpenAI offers it;
- the account's real ChatGPT model picker and conversation history;
- an experimental local tool-calling loop;
- a root LaunchDaemon for controlled filesystem, Git, process, log, build, and test operations;
- one-time local approvals for writes and privileged commands.

## Important architecture boundary

OpenAI does not expose normal ChatGPT subscription conversations through a public third-party API. The app therefore keeps authentication inside a `WKWebView` pointed at the official ChatGPT website. It does not ship an OpenAI password, cookie, API key, or model. Model availability is whatever the signed-in account shows.

The local agent loop is experimental because it observes and drives the ChatGPT web interface. ChatGPT website changes may require selector updates.

## Outputs

The GitHub Actions workflow builds:

- `com.nightvibes.darkgpt_*_iphoneos-arm64.deb`
- `DarkGPT.ipa`

The `.deb` installs both the app and root daemon. The IPA contains only the app and cannot provide root tools by itself.

## Safe research scope

The included research runner supports bounded test harnesses, source inspection, crash collection, panic-log indexing, Git diffs, and user-approved builds. It does not guarantee discovery of an exploit or a jailbreak. Destructive commands, credential extraction, filesystem erasure, unattended kernel writes, and persistence changes are blocked.

## Build

```sh
export THEOS=$HOME/theos
make clean package FINALPACKAGE=1
```

Target:

- Architecture: `iphoneos-arm64`
- Deployment target: iOS 16.0
- Tested target device profile: iPad6,11 on iOS 16.7.11

## Install

```sh
dpkg -i com.nightvibes.darkgpt_*_iphoneos-arm64.deb
sbreload
```

Then open **DarkGPT** from the Home Screen, sign in through the official ChatGPT page, and tap **Agent** to install the local-tool protocol into the current conversation.

## Local approval

From a root shell:

```sh
darkgpt-approve
```

The command prints a short-lived code. Enter that code in the app only for the exact write or privileged operation you approve.
