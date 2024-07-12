#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# shellcheck disable=SC2086
set -eEuo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/../..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

set -x

target="$1"
target="${target%@*}"
target_lower="${target//-/_}"
target_lower="${target_lower//./_}"
target_upper=$(tr '[:lower:]' '[:upper:]' <<<"${target_lower}")
wd="$2"
base_rustflags="${RUSTFLAGS:-}"
case "${target}" in
    *-windows*) exe=".exe" ;;
    wasm*) exe=".wasm" ;;
esac
# TODO: Print glibc version
case "${target}" in
    *-freebsd*) freebsd-version ;;
esac

skip_run() {
    case "${target}" in
        # x86_64h-apple-darwin is also x86_64 but build-only due to the CPU of GitHub-provided macOS runners is older than haswell.
        *-freebsd* | *-netbsd* | *-illumos* | x86_64h-apple-darwin | aarch64*-windows-msvc) return 0 ;;
        aarch64*-darwin* | arm64*-darwin*)
            case "$(uname -m)" in
                aarch64 | arm64) ;;
                *) return 0 ;;
            esac
            ;;
    esac
    case "$(uname -m)" in
        aarch64 | arm64)
            case "${target}" in
                aarch64* | arm64* | *-darwin* | *-windows*) return 1 ;;
            esac
            ;;
        *)
            case "${target}" in
                i?86-* | x86_64* | arm64ec-*) return 1 ;;
            esac
            ;;
    esac
    if [[ -z "$(eval "echo \${CARGO_TARGET_${target_upper}_RUNNER:-}")" ]]; then
        echo "error: runner for ${target} is not set"
        exit 1
    fi
    return 1
}
cargo_run() {
    if skip_run; then
        cargo ${BUILD_STD:-} build -v --target "${target}" ${cargo_options[@]+"${cargo_options[@]}"} "$@"
    else
        cargo ${BUILD_STD:-} run -v --target "${target}" ${cargo_options[@]+"${cargo_options[@]}"} "$@"
    fi
}
cargo_test() {
    if skip_run; then
        cargo ${BUILD_STD:-} test --no-run -v --target "${target}" ${DOCTEST_XCOMPILE:-} ${cargo_options[@]+"${cargo_options[@]}"} "$@"
    else
        cargo ${BUILD_STD:-} test -v --target "${target}" ${DOCTEST_XCOMPILE:-} ${cargo_options[@]+"${cargo_options[@]}"} "$@"
    fi
}
run_native() {
    if skip_run; then
        return
    fi
    "${target_dir}/${target}/${profile}/rust-test${exe:-}"
}
run_tests() {
    case "${target}" in
        # TODO: LLVM bug: Undefined temporary symbol error when building std.
        mips-*-linux-* | mipsel-*-linux-*) ;;
        *)
            profile=debug
            cargo_run
            cargo_test
            run_native
            ls "${target_dir}/${target}/${profile}"
            cp "${target_dir}/${target}/${profile}/rust-test${exe:-}" "/tmp/artifacts/rust-test1-${profile}${exe:-}"
            ;;
    esac

    profile=release
    cargo_run --release
    cargo_test --release
    run_native
    ls "${target_dir}/${target}/${profile}"
    cp "${target_dir}/${target}/${profile}/rust-test${exe:-}" "/tmp/artifacts/rust-test${test_id}-${profile}${exe:-}"
    ((test_id++))
    cargo clean
}

cd "${wd}"
mkdir -p /tmp/artifacts/
target_dir=$(cargo metadata --format-version=1 --no-deps | jq -r '.target_directory')
test_id=1

cargo_options=()
case "${target}" in
    # Disable C++ build for:
    # - musl with static linking
    # - WASI
    *-linux-musl* | *-wasi*) cargo_options+=(--no-default-features) ;;
esac
case "${target}" in
    # With static linking (default for target other than mips{,el}-unknown-linux-musl/mips64-openwrt-linux-musl)
    *-linux-musl*) export RUSTFLAGS="${base_rustflags} -C target-feature=+crt-static -C link-self-contained=yes" ;;
esac
run_tests

cargo_options=()
case "${target}" in
    *-linux-musl*)
        # With dynamic linking (default for mips{,el}-unknown-linux-musl/mips64-openwrt-linux-musl)
        case "${target}" in
            # TODO: No such file or directory
            i?86-* | x86_64*) ;;
            *)
                export RUSTFLAGS="${base_rustflags} -C target-feature=-crt-static"
                run_tests
                ;;
        esac
        ;;
esac
