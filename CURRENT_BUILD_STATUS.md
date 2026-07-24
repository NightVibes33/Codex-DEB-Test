# Current IPA and DEB build status

- Run: 30108430068
- Commit: 9fb6701b67265be9d793fda0f98b8204ed8606ea
- Target: iOS 16.1+ (iPadOS 16.7.11 supported)
- rusty_v8 cache restored: 
- Rust cache restored: 
- Rust cache valid: false
- Source verification: success
- Pinned dependencies: success
- Build tools: success
- Alley Cat runtime: cancelled
- iOS application: skipped
- Root daemon: skipped
- IPA and DEB package: skipped
- IPA exists: no
- DEB exists: no

## runtime-build tail
```text
[1m[92m   Compiling[0m quickcheck v1.1.0
[1m[92m   Compiling[0m anstyle-parse v1.0.0
[1m[92m   Compiling[0m serde_repr v0.1.20
[1m[92m   Compiling[0m strong_hash_derive v0.1.0
[1m[92m   Compiling[0m allocative_derive v0.3.6
[1m[92m   Compiling[0m anstyle-query v1.1.5
[1m[92m   Compiling[0m unicode-width v0.1.14
[1m[92m   Compiling[0m anstyle v1.0.14
[1m[92m   Compiling[0m beef v0.5.2
[1m[92m   Compiling[0m colorchoice v1.0.5
[1m[92m   Compiling[0m oid-registry v0.8.1
[1m[92m   Compiling[0m is_terminal_polyfill v1.70.2
[1m[92m   Compiling[0m rama-http-headers v0.3.0-alpha.4
[1m[92m   Compiling[0m anstream v1.0.0
[1m[92m   Compiling[0m strong_hash v0.1.0
[1m[92m   Compiling[0m icu_locale v2.2.0
[1m[92m   Compiling[0m hickory-resolver v0.25.2
[1m[92m   Compiling[0m sorted_vector_map v0.2.1
[1m[92m   Compiling[0m fancy-regex v0.16.2
[1m[92m   Compiling[0m darling v0.23.0
[1m[92m   Compiling[0m static_interner v0.1.3
[1m[92m   Compiling[0m Inflector v0.11.4
[1m[92m   Compiling[0m schemafy_core v0.5.2
[1m[92m   Compiling[0m convert_case v0.6.0
[1m[92m   Compiling[0m terminal_size v0.4.4
[1m[92m   Compiling[0m fxhash v0.2.1
[1m[92m   Compiling[0m triomphe v0.1.16
[1m[92m   Compiling[0m quick-xml v0.41.0
[1m[92m   Compiling[0m pagable_derive v0.4.1
[1m[92m   Compiling[0m csv-core v0.1.13
[1m[92m   Compiling[0m sequence_trie v0.3.6
[1m[92m   Compiling[0m bitflags v1.3.2
[1m[92m   Compiling[0m inventory v0.3.24
[1m[92m   Compiling[0m clap_lex v1.1.0
[1m[92m   Compiling[0m paste v1.0.15
[1m[92m   Compiling[0m take_mut v0.2.2
[1m[92m   Compiling[0m starlark_map v0.14.2
[1m[92m   Compiling[0m urlencoding v2.1.3
[1m[92m   Compiling[0m shlex v1.3.0
[1m[92m   Compiling[0m pagable v0.4.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/rust-bridge/vendor/pagable-0.4.1)
[1m[92m   Compiling[0m clap_builder v4.6.0
[1m[92m   Compiling[0m fluent-uri v0.1.4
[1m[92m   Compiling[0m csv v1.4.0
[1m[92m   Compiling[0m derive_more-impl v1.0.0
[1m[92m   Compiling[0m schemafy_lib v0.5.2
[1m[92m   Compiling[0m rama-dns v0.3.0-alpha.4
[1m[92m   Compiling[0m logos-derive v0.15.1
[1m[92m   Compiling[0m der-parser v10.0.0
[1m[92m   Compiling[0m codex-utils-rustls-provider v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/utils/rustls-provider)
[1m[92m   Compiling[0m clap_derive v4.6.1
[1m[92m   Compiling[0m strum_macros v0.28.0
[1m[92m   Compiling[0m lru v0.16.4
[1m[92m   Compiling[0m serde_html_form v0.3.2
[1m[92m   Compiling[0m pem v3.0.6
[1m[92m   Compiling[0m memoffset v0.9.1
[1m[92m   Compiling[0m endian-type v0.1.2
[1m[92m   Compiling[0m matchit v0.9.2
[1m[92m   Compiling[0m http-range-header v0.4.2
[1m[92m   Compiling[0m iri-string v0.7.12
[1m[92m   Compiling[0m radix_trie v0.2.1
[1m[92m   Compiling[0m clap v4.6.1
[1m[92m   Compiling[0m x509-parser v0.18.1
[1m[92m   Compiling[0m rama-http v0.3.0-alpha.4 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/rust-bridge/vendor/rama-http-0.3.0-alpha.4)
[1m[92m   Compiling[0m rama-tcp v0.3.0-alpha.4
[1m[92m   Compiling[0m logos v0.15.1
[1m[92m   Compiling[0m derive_more v1.0.0
[1m[92m   Compiling[0m schemafy v0.5.2
[1m[92m   Compiling[0m lsp-types v0.97.0
[1m[92m   Compiling[0m annotate-snippets v0.9.2
[1m[92m   Compiling[0m derivative v2.2.0
[1m[92m   Compiling[0m tokio-test v0.4.5
[1m[92m   Compiling[0m fdeflate v0.3.7
[1m[92m   Compiling[0m globset v0.4.18
[1m[92m   Compiling[0m fd-lock v4.0.4
[1m[92m   Compiling[0m yasna v0.6.0
[1m[92m   Compiling[0m icu_decimal_data v2.2.0
[1m[92m   Compiling[0m pxfm v0.1.30
[1m[92m   Compiling[0m starlark v0.14.2 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/rust-bridge/vendor/starlark-0.14.2)
[1m[92m   Compiling[0m zune-core v0.5.1
[1m[92m   Compiling[0m weezl v0.1.12
[1m[92m   Compiling[0m byteorder-lite v0.1.0
[1m[92m   Compiling[0m color_quant v1.1.0
[1m[92m   Compiling[0m quick-error v2.0.1
[1m[92m   Compiling[0m indenter v0.3.4
[1m[92m   Compiling[0m display_container v0.9.0
[1m[92m   Compiling[0m image-webp v0.2.4
[1m[92m   Compiling[0m moxcms v0.8.1
[1m[92m   Compiling[0m gif v0.14.2
[1m[92m   Compiling[0m zune-jpeg v0.5.15
[1m[92m   Compiling[0m rcgen v0.14.8
[1m[92m   Compiling[0m rustyline v14.0.0
[1m[92m   Compiling[0m starlark_syntax v0.14.2
[1m[92m   Compiling[0m png v0.18.1
[1m[92m   Compiling[0m rama-http-core v0.3.0-alpha.4
[1m[92m   Compiling[0m debugserver-types v0.5.0
[1m[92m   Compiling[0m serde_with_macros v3.21.0
[1m[92m   Compiling[0m textwrap v0.11.0
[1m[92m   Compiling[0m starlark_derive v0.14.2
[1m[92m   Compiling[0m codex-utils-home-dir v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/utils/home-dir)
[1m[92m   Compiling[0m rama-udp v0.3.0-alpha.4
[1m[92m   Compiling[0m rama-unix v0.3.0-alpha.4
[1m[92m   Compiling[0m erased-serde v0.3.31
[1m[92m   Compiling[0m maplit v1.0.2
[1m[92m   Compiling[0m strsim v0.10.0
[1m[92m   Compiling[0m cmp_any v0.8.1
[1m[92m   Compiling[0m rama-http-backend v0.3.0-alpha.4
[1m[92m   Compiling[0m rama-socks5 v0.3.0-alpha.4
[1m[92m   Compiling[0m serde_with v3.21.0
[1m[92m   Compiling[0m image v0.25.10
[1m[92m   Compiling[0m rama-tls-rustls v0.3.0-alpha.4
[1m[92m   Compiling[0m codex-utils-cache v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/utils/cache)
[1m[92m   Compiling[0m strum_macros v0.27.2
[1m[92m   Compiling[0m fixed_decimal v0.7.2
[1m[92m   Compiling[0m multimap v0.10.1
[1m[92m   Compiling[0m parking v2.2.1
[1m[92m   Compiling[0m icu_decimal v2.2.0
[1m[92m   Compiling[0m codex-execpolicy v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/execpolicy)
[1m[92m   Compiling[0m strum v0.27.2
[1m[92m   Compiling[0m codex-utils-image v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/utils/image)
[1m[92m   Compiling[0m codex-network-proxy v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/network-proxy)
```

## xcodebuild tail
```text
```

## rootd-build tail
```text
```
