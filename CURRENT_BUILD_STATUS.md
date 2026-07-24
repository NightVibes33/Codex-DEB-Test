# Current IPA and DEB build status

- Run: 30106599583
- Commit: ab8736cad010e38b86440a3ab9f38d82c3b3ab49
- Target: iOS 16.1+ (iPadOS 16.7.11 supported)
- Rust cache restored: 
- Rust cache valid: false
- Source verification: success
- Pinned dependencies: success
- Build tools: success
- Alley Cat runtime: failure
- iOS application: skipped
- Root daemon: skipped
- IPA and DEB package: skipped
- IPA exists: no
- DEB exists: no

## runtime-build tail
```text
[1m[92m   Compiling[0m sqlx-macros v0.9.0
[1m[92m   Compiling[0m diplomat v0.15.0
[1m[92m   Compiling[0m supports-color v3.0.2
[1m[92m   Compiling[0m aws-sdk-signin v1.16.0
[1m[92m   Compiling[0m aws-sdk-sso v1.103.0
[1m[92m   Compiling[0m aws-sdk-ssooidc v1.105.0
[1m[92m   Compiling[0m diplomat-runtime v0.15.1
[1m[92m   Compiling[0m cpubits v0.1.1
[1m[92m   Compiling[0m temporal_capi v0.2.4
[1m[92m   Compiling[0m aws-config v1.9.0
[1m[92m   Compiling[0m sqlx v0.9.0
[1m[92m   Compiling[0m cipher v0.5.2
[1m[92m   Compiling[0m codex-collaboration-mode-templates v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/collaboration-mode-templates)
[1m[92m   Compiling[0m codex-models-manager v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/models-manager)
[1m[92m   Compiling[0m codex-aws-auth v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/aws-auth)
[1m[92m   Compiling[0m codex-feedback v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/feedback)
[1m[92m   Compiling[0m codex-state v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/state)
[1m[92m   Compiling[0m codex-response-debug-context v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/response-debug-context)
[1m[92m   Compiling[0m codex-code-mode-protocol v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/code-mode-protocol)
[1m[92m   Compiling[0m lzma-sys v0.1.20
[1m[92m   Compiling[0m bzip2-sys v0.1.13+1.0.8
[1m[92m   Compiling[0m deno_core_icudata v0.77.0
[1m[92m   Compiling[0m codex-model-provider v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/model-provider)
[1m[92m   Compiling[0m codex-connectors v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/connectors)
[1m[92m   Compiling[0m codex-context-fragments v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/context-fragments)
[1m[92m   Compiling[0m pem-rfc7468 v1.0.0
[1m[92m   Compiling[0m der v0.8.1
[1m[92m   Compiling[0m universal-hash v0.6.1
[1m[92m   Compiling[0m codex-experimental-api-macros v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/codex-experimental-api-macros)
[1m[92m   Compiling[0m include_dir_macros v0.7.4
[1m[92m   Compiling[0m unsafe-libyaml v0.2.11
[1m[92m   Compiling[0m codex-skills v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/skills)
[1m[92m   Compiling[0m jsonptr v0.7.1
[1m[92m   Compiling[0m zip v2.4.2
[1m[92m   Compiling[0m serde_yaml v0.9.34+deprecated
[1m[92m   Compiling[0m include_dir v0.7.4
[1m[92m   Compiling[0m codex-app-server-protocol v0.144.1 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/codex-rs/app-server-protocol)
[1m[91merror[0m: failed to run custom build command for `v8 v149.2.0`

Caused by:
  process didn't exit successfully: `/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/rust-bridge/target/debug/build/v8-5de11d8c11892728/build-script-build` (exit status: 101)
  --- stdout
  cargo:rerun-if-changed=.gn
  cargo:rerun-if-changed=BUILD.gn
  cargo:rerun-if-changed=src/binding.cc
  cargo:rerun-if-env-changed=CCACHE
  cargo:rerun-if-env-changed=CLANG_BASE_PATH
  cargo:rerun-if-env-changed=CXXSTDLIB
  cargo:rerun-if-env-changed=DENO_TRYBUILD
  cargo:rerun-if-env-changed=DOCS_RS
  cargo:rerun-if-env-changed=GN
  cargo:rerun-if-env-changed=GN_ARGS
  cargo:rerun-if-env-changed=HOST
  cargo:rerun-if-env-changed=NINJA
  cargo:rerun-if-env-changed=OUT_DIR
  cargo:rerun-if-env-changed=RUSTY_V8_ARCHIVE
  cargo:rerun-if-env-changed=RUSTY_V8_MIRROR
  cargo:rerun-if-env-changed=RUSTY_V8_SRC_BINDING_PATH
  cargo:rerun-if-env-changed=SCCACHE
  cargo:rerun-if-env-changed=V8_FORCE_DEBUG
  cargo:rerun-if-env-changed=V8_FROM_SOURCE
  cargo:rerun-if-env-changed=PYTHON
  cargo:rerun-if-env-changed=DISABLE_CLANG
  cargo:rerun-if-env-changed=EXTRA_GN_ARGS
  cargo:rerun-if-env-changed=PRINT_GN_ARGS
  cargo:rerun-if-env-changed=CARGO_ENCODED_RUSTFLAGS
  cargo:rustc-link-lib=static=rusty_v8
  lockfile: "/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/rust-bridge/target/debug/build/v8.fslock"
  cargo:rustc-env=RUSTY_V8_SRC_BINDING_PATH=/Users/runner/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/v8-149.2.0/gen/src_binding_release_x86_64-apple-darwin.rs
  static lib URL: https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_x86_64-apple-darwin.a.gz
  cargo:rustc-link-search=/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/rust-bridge/target/debug/gn_out/obj
  Looking for download in '"/Users/runner/.cargo/.rusty_v8/https___github_com_denoland_rusty_v8_releases_download_v149_2_0_librusty_v8_release_x86_64_apple_darwin_a_gz"'
  Downloading https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_x86_64-apple-darwin.a.gz
  Trying with Python...
  Downloading https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_x86_64-apple-darwin.a.gz...
  HTTP Error 504: Gateway Time-out
  Retrying in 5 s ...
  Downloading https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_x86_64-apple-darwin.a.gz...
  HTTP Error 504: Gateway Time-out
  Retrying in 10 s ...
  Downloading https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_x86_64-apple-darwin.a.gz...
  HTTP Error 504: Gateway Time-out
  Retrying in 20 s ...
  Downloading https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_x86_64-apple-darwin.a.gz...
  HTTP Error 504: Gateway Time-out
  Python downloader failed, trying with curl.

  --- stderr
  Traceback (most recent call last):
    File "/Users/runner/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/v8-149.2.0/./tools/download_file.py", line 63, in <module>
      sys.exit(main())
               ~~~~^^
    File "/Users/runner/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/v8-149.2.0/./tools/download_file.py", line 58, in main
      DownloadUrl(args.url, f)
      ~~~~~~~~~~~^^^^^^^^^^^^^
    File "/Users/runner/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/v8-149.2.0/./tools/download_file.py", line 44, in DownloadUrl
      raise e
    File "/Users/runner/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/v8-149.2.0/./tools/download_file.py", line 28, in DownloadUrl
      response = urlopen(url)
    File "/usr/local/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/Versions/3.14/lib/python3.14/urllib/request.py", line 187, in urlopen
      return opener.open(url, data, timeout)
             ~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^
    File "/usr/local/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/Versions/3.14/lib/python3.14/urllib/request.py", line 493, in open
      response = meth(req, response)
    File "/usr/local/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/Versions/3.14/lib/python3.14/urllib/request.py", line 602, in http_response
      response = self.parent.error(
          'http', request, response, code, msg, hdrs)
    File "/usr/local/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/Versions/3.14/lib/python3.14/urllib/request.py", line 531, in error
      return self._call_chain(*args)
             ~~~~~~~~~~~~~~~~^^^^^^^
    File "/usr/local/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/Versions/3.14/lib/python3.14/urllib/request.py", line 464, in _call_chain
      result = func(*args)
    File "/usr/local/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/Versions/3.14/lib/python3.14/urllib/request.py", line 611, in http_error_default
      raise HTTPError(req.full_url, code, msg, hdrs, fp)
  urllib.error.HTTPError: HTTP Error 504: Gateway Time-out

  thread 'main' (182790) panicked at /Users/runner/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/v8-149.2.0/build.rs:732:3:
  assertion failed: status.success()
  note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
[1m[33mwarning[0m: build failed, waiting for other jobs to finish...
```

## xcodebuild tail
```text
```

## rootd-build tail
```text
```
