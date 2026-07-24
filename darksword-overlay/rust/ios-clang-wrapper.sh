#!/usr/bin/env bash
set -euo pipefail

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
DEPLOYMENT="${IPHONEOS_DEPLOYMENT_TARGET:-16.1}"
args=()
has_target=0
has_sysroot=0

for arg in "$@"; do
    case "$arg" in
        -mmacos-version-min=*|-miphoneos-version-min=*)
            ;;
        -isysroot)
            # Drop the flag and its following path below.
            has_sysroot=2
            ;;
        --target=*|-target)
            has_target=1
            args+=("$arg")
            ;;
        *)
            if [ "$has_sysroot" -eq 2 ]; then
                has_sysroot=1
                continue
            fi
            args+=("$arg")
            ;;
    esac
done

if [ "$has_target" -eq 0 ]; then
    args=("-target" "arm64-apple-ios${DEPLOYMENT}" "${args[@]}")
fi
args=("-isysroot" "$SDK" "-miphoneos-version-min=${DEPLOYMENT}" "${args[@]}")

exec xcrun --sdk iphoneos clang "${args[@]}"
