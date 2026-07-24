#!/usr/bin/env bash
set -euo pipefail

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
DEPLOYMENT="${IPHONEOS_DEPLOYMENT_TARGET:-16.1}"
args=()
has_target=0
skip_sysroot_value=0

for arg in "$@"; do
    if [ "$skip_sysroot_value" -eq 1 ]; then
        skip_sysroot_value=0
        continue
    fi
    case "$arg" in
        -mmacos-version-min=*|-miphoneos-version-min=*)
            ;;
        -isysroot)
            skip_sysroot_value=1
            ;;
        --target=*)
            has_target=1
            args+=("$arg")
            ;;
        -target)
            # Preserve the following target supplied by the build system.
            has_target=1
            args+=("$arg")
            ;;
        *)
            args+=("$arg")
            ;;
    esac
done

if [ "$has_target" -eq 0 ]; then
    args=("-target" "arm64-apple-ios${DEPLOYMENT}" "${args[@]}")
fi
args=("-isysroot" "$SDK" "-miphoneos-version-min=${DEPLOYMENT}" "${args[@]}")

exec xcrun --sdk iphoneos clang++ "${args[@]}"
