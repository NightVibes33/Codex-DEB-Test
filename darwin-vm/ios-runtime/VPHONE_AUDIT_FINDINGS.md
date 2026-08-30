# vphone architecture audit — initial findings

## vphone-aio

`34306/vphone-aio` is not the primary runtime source. It is a distribution wrapper around a large prebuilt/split vphone-cli payload and a shell script. Upstream itself recommends `Lakr233/vphone-cli` for current support.

## vphone-cli

The current source project is `Lakr233/vphone-cli` (MIT). It boots an Apple vphone600ap virtual iPhone using Apple's Private Cloud Compute research VM infrastructure and private Virtualization.framework PV=3 APIs on an Apple Silicon macOS host.

This has two consequences for our iOS target:

1. The vphone firmware/boot-chain/CFW/jailbreak work is highly reusable as a reference and source dependency.
2. The host execution engine is **not** directly portable to iPhone/iPad because the macOS Virtualization.framework research VM path is the engine providing the virtual hardware/CPU environment.

## Integration decision

Do **not** vendor `vphone-aio`'s 12+ GB binary archive.

Use `Lakr233/vphone-cli` source as the primary vphone reference and selectively port/reuse:

- vphone600ap firmware preparation
- iPhone + cloudOS IPSW merge logic
- boot-chain patch definitions
- variant system (`less`, `regular`, `dev`, `jb`, `exp`)
- CFW construction/install logic
- jailbreak bootstrap package/layout logic
- guest `vphoned` daemon/control protocol
- virtual-phone identity/configuration model
- touch/screenshot/control semantics

Replace:

- macOS `Virtualization.framework` / PV=3 host launcher
- macOS-only APFS host mounting/install steps
- macOS-only signing/entitlement relaxation

with an iOS-native host runtime and storage/display/input bridges.

## Runtime direction

The iOS host must provide the machine services that Apple's vphone600ap guest expects. This is a real low-level runtime project; it cannot be achieved by merely wrapping vphone-cli in SwiftUI.

First implementation target remains: allocate guest state, parse/import the required Apple firmware artifacts, construct a vphone600ap machine configuration, and reach first boot/serial output on-device. Full graphical SpringBoard comes later.
