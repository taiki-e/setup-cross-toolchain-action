#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# shellcheck disable=SC2086
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

set -x

target="$1"
target="${target%@*}"
wd="$2"
case "${target}" in
    *-windows*) exe=".exe" ;;
    wasm*) exe=".wasm" ;;
esac
# TODO: Print glibc version
case "${target}" in
    *-freebsd*) freebsd-version ;;
esac

cargo_build() {
    cargo ${BUILD_STD:-} build -v --target "${target}" ${cargo_options[@]+"${cargo_options[@]}"}
}
cargo_run() {
    case "${target}" in
        *-freebsd* | *-netbsd* | *-openbsd*) ;;
        *) cargo ${BUILD_STD:-} run -v --target "${target}" ${cargo_options[@]+"${cargo_options[@]}"} ;;
    esac
}
cargo_test() {
    case "${target}" in
        *-freebsd* | *-netbsd* | *-openbsd*) cargo ${BUILD_STD:-} test --no-run -v --target "${target}" ${DOCTEST_XCOMPILE:-} ${cargo_options[@]+"${cargo_options[@]}"} ;;
        *) cargo ${BUILD_STD:-} test -v --target "${target}" ${DOCTEST_XCOMPILE:-} ${cargo_options[@]+"${cargo_options[@]}"} ;;
    esac
}
run_native() {
    # Run only on targets that binfmt work.
    case "${target}" in
        mipsisa32r6* | *-windows* | *-wasi* | *-freebsd* | *-netbsd* | *-openbsd*) ;;
        *) "${target_dir}/${target}/debug/rust-test${exe:-}" ;;
    esac
}

cd "${wd}"
mkdir -p /tmp/artifacts/
target_dir=$(cargo metadata --format-version=1 --no-deps | jq -r '.target_directory')

cargo_options=()
# Disable C++ build for aarch64 OpenBSD/WASI
case "${target}" in
    aarch64-unknown-openbsd | *-wasi*) cargo_options=(--no-default-features) ;;
esac
cargo_build
cargo_run
cargo_test
run_native
ls "${target_dir}/${target}/debug"
cp "${target_dir}/${target}/debug/rust-test${exe:-}" "/tmp/artifacts/rust-test1${exe:-}"
cargo clean
