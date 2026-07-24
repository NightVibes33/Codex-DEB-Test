# Current IPA and DEB build status

- Run: 30117647646
- Commit: a59b2ab215ce3f0f39e7ee17a0d072f5933467a0
- Target: iOS 16.1+ (iPadOS 16.7.11 supported)
- Metal toolchain: success
- rusty_v8 cache restored: 
- Rust cache restored: 
- Rust cache valid: false
- Source verification: success
- Pinned dependencies: success
- Build tools: success
- Alley Cat runtime: success
- iOS application: failure
- Root daemon: skipped
- IPA and DEB package: skipped
- IPA exists: no
- DEB exists: no

## metal-toolchain tail
```text
Metal compiler: /Users/runner/Library/Developer/DVTDownloads/MetalToolchain/mounts/058e1b31129b642e40598a87b55aa54b2a29e538/Metal.xctoolchain/usr/bin/metal
Apple metal version 32023.864 (metalfe-32023.864)
Target: air64-apple-darwin25.4.0
Thread model: posix
InstalledDir: /Users/runner/Library/Developer/DVTDownloads/MetalToolchain/mounts/058e1b31129b642e40598a87b55aa54b2a29e538/Metal.xctoolchain/usr/metal/current/bin
```

## runtime-build tail
```text
   [1m[94m--> [0mcodex-mobile-client/src/logging/mod.rs:275:15
    [1m[94m|[0m
[1m[94m275[0m [1m[94m|[0m pub(crate) fn summarize_json_for_log(payload: &str) -> String {
    [1m[94m|[0m               [1m[33m^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `truncate_log_preview` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/logging/mod.rs:284:4
    [1m[94m|[0m
[1m[94m284[0m [1m[94m|[0m fn truncate_log_preview(value: &str, limit: usize) -> String {
    [1m[94m|[0m    [1m[33m^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `format_bytes` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/logging/mod.rs:298:4
    [1m[94m|[0m
[1m[94m298[0m [1m[94m|[0m fn format_bytes(bytes: usize) -> String {
    [1m[94m|[0m    [1m[33m^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `deserialize_typed_response` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/event_loop.rs:440:4
    [1m[94m|[0m
[1m[94m440[0m [1m[94m|[0m fn deserialize_typed_response<R>(value: &serde_json::Value) -> Result<R, serde_json::Error>
    [1m[94m|[0m    [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `queued_follow_up_kind_from_json_value` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:118:15
    [1m[94m|[0m
[1m[94m118[0m [1m[94m|[0m pub(super) fn queued_follow_up_kind_from_json_value(
    [1m[94m|[0m               [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `queued_follow_up_text_from_json_value` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:144:15
    [1m[94m|[0m
[1m[94m144[0m [1m[94m|[0m pub(super) fn queued_follow_up_text_from_json_value(value: &serde_json::Value) -> Option<String> {
    [1m[94m|[0m               [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `queued_follow_up_inputs_from_json_value` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:172:15
    [1m[94m|[0m
[1m[94m172[0m [1m[94m|[0m pub(super) fn queued_follow_up_inputs_from_json_value(
    [1m[94m|[0m               [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `string_field` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:343:15
    [1m[94m|[0m
[1m[94m343[0m [1m[94m|[0m pub(super) fn string_field(
    [1m[94m|[0m               [1m[33m^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `array_field_len` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:368:15
    [1m[94m|[0m
[1m[94m368[0m [1m[94m|[0m pub(super) fn array_field_len(
    [1m[94m|[0m               [1m[33m^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `stable_follow_up_preview_id` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:386:15
    [1m[94m|[0m
[1m[94m386[0m [1m[94m|[0m pub(super) fn stable_follow_up_preview_id(scope: &str, index: usize, text: &str) -> String {
    [1m[94m|[0m               [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `refresh_thread_list_from_app_server` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:567:21
    [1m[94m|[0m
[1m[94m567[0m [1m[94m|[0m pub(super) async fn refresh_thread_list_from_app_server(
    [1m[94m|[0m                     [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `request_thread_list_page_for_runtime` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:637:10
    [1m[94m|[0m
[1m[94m637[0m [1m[94m|[0m async fn request_thread_list_page_for_runtime(
    [1m[94m|[0m          [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `normalize_empty_thread_list_cwds` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:655:4
    [1m[94m|[0m
[1m[94m655[0m [1m[94m|[0m fn normalize_empty_thread_list_cwds(value: &mut serde_json::Value) {
    [1m[94m|[0m    [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `thread_list_page_to_thread_infos` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:674:4
    [1m[94m|[0m
[1m[94m674[0m [1m[94m|[0m fn thread_list_page_to_thread_infos(
    [1m[94m|[0m    [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `upstream_thread_status_from_summary_status` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:755:15
    [1m[94m|[0m
[1m[94m755[0m [1m[94m|[0m pub(super) fn upstream_thread_status_from_summary_status(
    [1m[94m|[0m               [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `thread_snapshot_from_upstream_thread` is never used[0m
   [1m[94m--> [0mcodex-mobile-client/src/mobile_client/thread_projection.rs:767:15
    [1m[94m|[0m
[1m[94m767[0m [1m[94m|[0m pub(super) fn thread_snapshot_from_upstream_thread(
    [1m[94m|[0m               [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: method `replace_pending_approvals_with_seeds` is never used[0m
    [1m[94m--> [0mcodex-mobile-client/src/store/reducer.rs:1014:19
     [1m[94m|[0m
[1m[94m 139[0m [1m[94m|[0m impl AppStoreReducer {
     [1m[94m|[0m [1m[94m--------------------[0m [1m[94mmethod in this implementation[0m
[1m[94m...[0m
[1m[94m1014[0m [1m[94m|[0m     pub(crate) fn replace_pending_approvals_with_seeds(
     [1m[94m|[0m                   [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m[1m: function `reconcile_local_overlay_items` is never used[0m
    [1m[94m--> [0mcodex-mobile-client/src/store/reducer.rs:3348:15
     [1m[94m|[0m
[1m[94m3348[0m [1m[94m|[0m pub(crate) fn reconcile_local_overlay_items(thread: &mut ThreadSnapshot) {
     [1m[94m|[0m               [1m[33m^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m

[1m[33mwarning[0m: `codex-mobile-client` (lib) generated 24 warnings
[1m[92m    Finished[0m `mobile-release` profile [optimized] target(s) in 61m 27s
[1m[33mwarning[0m: the following packages contain code that will be rejected by a future version of Rust: proc-macro-error2 v2.0.1
[1m[92mnote[0m: to see what the problems were, use the option `--future-incompat-report`, or run `cargo report future-incompatibilities --id 1`
==> Creating xcframework...
xcframework successfully written out to: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/Frameworks/codex_mobile_client.xcframework
==> Done: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/Frameworks/codex_mobile_client.xcframework
==> Raw device staticlib: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ios-device/libcodex_mobile_client.a
==> Headers: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/Headers
==> Swift bindings: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/Sources/Litter/Bridge/UniFFICodexClient.generated.swift
```

## xcodebuild tail
```text
    Target 'TreeSitterXML' in project 'TreeSitterXML'
        ➜ Explicit dependency on target 'TreeSitterXML_TreeSitterXML' in project 'TreeSitterXML'
    Target 'TreeSitterXML_TreeSitterXML' in project 'TreeSitterXML' (no dependencies)
    Target 'TreeSitterCPP' in project 'TreeSitterCPP'
        ➜ Explicit dependency on target 'TreeSitterCPP' in project 'TreeSitterCPP'
        ➜ Explicit dependency on target 'TreeSitterCPP_TreeSitterCPP' in project 'TreeSitterCPP'
    Target 'TreeSitterCPP' in project 'TreeSitterCPP'
        ➜ Explicit dependency on target 'TreeSitterCPP_TreeSitterCPP' in project 'TreeSitterCPP'
    Target 'TreeSitterCPP_TreeSitterCPP' in project 'TreeSitterCPP' (no dependencies)
    Target 'TreeSitterC' in project 'TreeSitterC'
        ➜ Explicit dependency on target 'TreeSitterC' in project 'TreeSitterC'
        ➜ Explicit dependency on target 'TreeSitterC_TreeSitterC' in project 'TreeSitterC'
    Target 'TreeSitterC' in project 'TreeSitterC'
        ➜ Explicit dependency on target 'TreeSitterC_TreeSitterC' in project 'TreeSitterC'
    Target 'TreeSitterC_TreeSitterC' in project 'TreeSitterC' (no dependencies)
    Target 'TreeSitterObjc' in project 'TreeSitterObjc'
        ➜ Explicit dependency on target 'TreeSitterObjc' in project 'TreeSitterObjc'
        ➜ Explicit dependency on target 'TreeSitterObjc_TreeSitterObjc' in project 'TreeSitterObjc'
    Target 'TreeSitterObjc' in project 'TreeSitterObjc'
        ➜ Explicit dependency on target 'TreeSitterObjc_TreeSitterObjc' in project 'TreeSitterObjc'
    Target 'TreeSitterObjc_TreeSitterObjc' in project 'TreeSitterObjc' (no dependencies)
    Target 'SwiftTerm' in project 'SwiftTerm'
        ➜ Explicit dependency on target 'SwiftTerm' in project 'SwiftTerm'
        ➜ Explicit dependency on target 'SwiftTerm_SwiftTerm' in project 'SwiftTerm'
    Target 'SwiftTerm' in project 'SwiftTerm'
        ➜ Explicit dependency on target 'SwiftTerm_SwiftTerm' in project 'SwiftTerm'
    Target 'SwiftTerm_SwiftTerm' in project 'SwiftTerm' (no dependencies)
    Target 'Runestone' in project 'Runestone'
        ➜ Explicit dependency on target 'Runestone' in project 'Runestone'
        ➜ Explicit dependency on target 'Runestone_Runestone' in project 'Runestone'
        ➜ Explicit dependency on target 'TreeSitter' in project 'TreeSitter'
    Target 'Runestone' in project 'Runestone'
        ➜ Explicit dependency on target 'Runestone_Runestone' in project 'Runestone'
        ➜ Explicit dependency on target 'TreeSitter' in project 'TreeSitter'
    Target 'TreeSitter' in project 'TreeSitter'
        ➜ Explicit dependency on target 'TreeSitter' in project 'TreeSitter'
    Target 'TreeSitter' in project 'TreeSitter' (no dependencies)
    Target 'Runestone_Runestone' in project 'Runestone' (no dependencies)
    Target 'MobileDevelopmentKit' in project 'Litter'
        ➜ Explicit dependency on target 'CoreCompiler' in project 'Litter'
    Target 'CoreCompiler' in project 'Litter' (no dependencies)
    Target 'SideStore' in project 'Litter'
        ➜ Explicit dependency on target 'AltStoreCore' in project 'Litter'
        ➜ Explicit dependency on target 'Roxas' in project 'Litter'
        ➜ Explicit dependency on target 'Minimuxer' in project 'Litter'
        ➜ Explicit dependency on target 'AltSign-Dynamic' in project 'AltSign'
        ➜ Explicit dependency on target 'SemanticVersion' in project 'SemanticVersion'
        ➜ Explicit dependency on target 'Starscream' in project 'Starscream'
        ➜ Explicit dependency on target 'KeychainAccess' in project 'KeychainAccess'
        ➜ Explicit dependency on target 'MarkdownKit' in project 'MarkdownKit'
        ➜ Explicit dependency on target 'Nuke' in project 'Nuke'
    Target 'Nuke' in project 'Nuke'
        ➜ Explicit dependency on target 'Nuke' in project 'Nuke'
    Target 'Nuke' in project 'Nuke' (no dependencies)
    Target 'MarkdownKit' in project 'MarkdownKit'
        ➜ Explicit dependency on target 'MarkdownKit' in project 'MarkdownKit'
    Target 'MarkdownKit' in project 'MarkdownKit' (no dependencies)
    Target 'Starscream' in project 'Starscream'
        ➜ Explicit dependency on target 'Starscream' in project 'Starscream'
        ➜ Explicit dependency on target 'Starscream_Starscream' in project 'Starscream'
    Target 'Starscream' in project 'Starscream'
        ➜ Explicit dependency on target 'Starscream_Starscream' in project 'Starscream'
    Target 'Starscream_Starscream' in project 'Starscream' (no dependencies)
    Target 'Minimuxer' in project 'Litter'
        ➜ Explicit dependency on target 'RustBridge' in project 'Litter'
        ➜ Explicit dependency on target 'ZIPFoundation' in project 'ZIPFoundation'
    Target 'ZIPFoundation' in project 'ZIPFoundation'
        ➜ Explicit dependency on target 'ZIPFoundation' in project 'ZIPFoundation'
        ➜ Explicit dependency on target 'ZIPFoundation_ZIPFoundation' in project 'ZIPFoundation'
    Target 'ZIPFoundation' in project 'ZIPFoundation'
        ➜ Explicit dependency on target 'ZIPFoundation_ZIPFoundation' in project 'ZIPFoundation'
    Target 'ZIPFoundation_ZIPFoundation' in project 'ZIPFoundation' (no dependencies)
    Target 'RustBridge' in project 'Litter' (no dependencies)
    Target 'AltStoreCore' in project 'Litter'
        ➜ Explicit dependency on target 'Roxas' in project 'Litter'
        ➜ Explicit dependency on target 'AltSign-Dynamic' in project 'AltSign'
        ➜ Explicit dependency on target 'SemanticVersion' in project 'SemanticVersion'
        ➜ Explicit dependency on target 'KeychainAccess' in project 'KeychainAccess'
    Target 'KeychainAccess' in project 'KeychainAccess'
        ➜ Explicit dependency on target 'KeychainAccess' in project 'KeychainAccess'
    Target 'KeychainAccess' in project 'KeychainAccess' (no dependencies)
    Target 'SemanticVersion' in project 'SemanticVersion'
        ➜ Explicit dependency on target 'SemanticVersion' in project 'SemanticVersion'
        ➜ Explicit dependency on target 'SemanticVersion_SemanticVersion' in project 'SemanticVersion'
    Target 'SemanticVersion' in project 'SemanticVersion'
        ➜ Explicit dependency on target 'SemanticVersion_SemanticVersion' in project 'SemanticVersion'
    Target 'SemanticVersion_SemanticVersion' in project 'SemanticVersion' (no dependencies)
    Target 'AltSign-Dynamic' in project 'AltSign'
        ➜ Explicit dependency on target 'AltSign' in project 'AltSign'
        ➜ Explicit dependency on target 'CAltSign' in project 'AltSign'
        ➜ Explicit dependency on target 'CoreCrypto' in project 'AltSign'
        ➜ Explicit dependency on target 'CCoreCrypto' in project 'AltSign'
        ➜ Explicit dependency on target 'ldid' in project 'AltSign'
        ➜ Explicit dependency on target 'ldid-core' in project 'AltSign'
    Target 'AltSign' in project 'AltSign'
        ➜ Explicit dependency on target 'CCoreCrypto' in project 'AltSign'
        ➜ Explicit dependency on target 'CoreCrypto' in project 'AltSign'
        ➜ Explicit dependency on target 'ldid-core' in project 'AltSign'
        ➜ Explicit dependency on target 'ldid' in project 'AltSign'
        ➜ Explicit dependency on target 'CAltSign' in project 'AltSign'
    Target 'CAltSign' in project 'AltSign'
        ➜ Explicit dependency on target 'CCoreCrypto' in project 'AltSign'
        ➜ Explicit dependency on target 'CoreCrypto' in project 'AltSign'
        ➜ Explicit dependency on target 'ldid-core' in project 'AltSign'
        ➜ Explicit dependency on target 'ldid' in project 'AltSign'
    Target 'ldid' in project 'AltSign'
        ➜ Explicit dependency on target 'ldid-core' in project 'AltSign'
    Target 'ldid-core' in project 'AltSign' (no dependencies)
    Target 'CoreCrypto' in project 'AltSign'
        ➜ Explicit dependency on target 'CCoreCrypto' in project 'AltSign'
    Target 'CCoreCrypto' in project 'AltSign' (no dependencies)
    Target 'Roxas' in project 'Litter' (no dependencies)

** BUILD FAILED **


The following build commands failed:
	ComputeTargetDependencyGraph
	Building project Litter with scheme Litter and configuration Release
(2 failures)
```

## rootd-build tail
```text
```
