# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

## [1.12.0] - 2023-07-25

- Support loongarch64-unknown-linux-gnu (experimental).

- Performance Improvements.

## [1.11.2] - 2023-07-18

- This action no longer sets `PKG_CONFIG_ALLOW_CROSS=1` environment variable. This was added in 1.10.0, but introduced a regression.

## [1.11.1] - 2023-07-11

- Only set `PKG_CONFIG_ALLOW_CROSS=1` environment variable when `PKG_CONFIG_PATH` environment variable is set by this action or users. This fixes a regression introduced in 1.10.0.

## [1.11.0] - 2023-07-11

- Support macOS targets on macOS host.

  - aarch64-apple-darwin (build-only)
  - x86_64-apple-darwin
  - x86_64h-apple-darwin (build-only due to the CPU of GitHub-provided macOS runners is older than haswell. If you use a large runner, you may be able to run the test.)

  GitHub-provided macOS runners support cross-compile for other architectures or environments, so this action just runs `rustup target add` and/or sets some environment variables.

  (Other macOS targets may also work, although this action's CI has not tested them.)

- Set `PKG_CONFIG_PATH` for most linux-gnu targets.

- This action no longer sets `PKG_CONFIG_ALLOW_CROSS=1` environment variable if `PKG_CONFIG_ALLOW_CROSS` environment variable is already set.

## [1.10.0] - 2023-07-10

- Support linux-musl targets. ([#12](https://github.com/taiki-e/setup-cross-toolchain-action/pull/12))

  All tier 1 or 2 linux-musl targets are now supported:

  - aarch64-unknown-linux-musl
  - arm-unknown-linux-musleabi
  - arm-unknown-linux-musleabihf
  - armv5te-unknown-linux-musleabi
  - armv7-unknown-linux-musleabi
  - armv7-unknown-linux-musleabihf
  - i586-unknown-linux-musl
  - i686-unknown-linux-musl
  - mips-unknown-linux-musl
  - mips64-unknown-linux-muslabi64
  - mips64el-unknown-linux-muslabi64
  - mipsel-unknown-linux-musl
  - x86_64-unknown-linux-musl

  (Other linux-musl targets supported by [rust-cross-toolchain](https://github.com/taiki-e/rust-cross-toolchain#linux-musl) may also work, although this action's CI has not tested them.)

- Add [document about cross-compilation of tier 3 targets](https://github.com/taiki-e/setup-cross-toolchain-action#example-workflow-tier-3-targets).

- Set `PKG_CONFIG_ALLOW_CROSS=1` environment variable when the target triple and host triple is different.

## [1.9.0] - 2023-07-09

- Support more targets:
  - Linux (GNU)
    - armeb-unknown-linux-gnueabi
  - FreeBSD
    - aarch64-unknown-freebsd (build-only)
  - NetBSD
    - aarch64-unknown-netbsd (build-only)
    - x86_64-unknown-netbsd (build-only)

- Support specifying OS version for FreeBSD/NetBSD.

  ```yaml
  - uses: taiki-e/setup-cross-toolchain-action@v1
    with:
      target: x86_64-unknown-freebsd@13
  ```

  ```yaml
  - uses: taiki-e/setup-cross-toolchain-action@v1
    with:
      target: x86_64-unknown-netbsd@9
  ```

- Set `RUST_TEST_THREADS=1` environment variable when QEMU is used as a runner.

  QEMU's multi-threading support is incomplete and slow.

## [1.8.0] - 2023-05-30

- setup-cross-toolchain-action now sets `RANLIB_<target>` environment variable.

- Diagnostic improvements.

## [1.7.0] - 2023-03-12

- setup-cross-toolchain-action no longer sets QEMU_CPU for 32-bit ARM targets by default.

  It was causing problems when running tests that create many threads.

## [1.6.2] - 2023-03-12

- Fix linker error for wasm32-wasi on Rust 1.68.0. This was due to rustc regression and has been [fixed](https://github.com/rust-lang/rust/pull/109156) in 1.68.1.

- Switch to composite action.

## [1.6.1] - 2022-12-13

- Improve robustness for temporary network failures.

## [1.6.0] - 2022-12-04

- Support x86_64-unknown-freebsd and i686-unknown-freebsd. (build-only)

- Fix bug in handling of `runner` input option.

## [1.5.0] - 2022-12-02

- Support wasm32-wasi.

## [1.4.1] - 2022-11-30

- Improve support for C/C++ dependencies on windows-gnu targets.

## [1.4.0] - 2022-11-30

- Support x86_64-pc-windows-gnu on Linux host.

## [1.3.0] - 2022-07-10

- Support aarch64_be-unknown-linux-gnu, riscv32gc-unknown-linux-gnu, mipsisa32r6-unknown-linux-gnu, and mipsisa64r6-unknown-linux-gnuabi64.

- Document support status for ubuntu-22.04.

## [1.2.0] - 2022-02-23

- Change default runner of i586 to qemu-user. ([#5](https://github.com/taiki-e/setup-cross-toolchain-action/pull/5))

## [1.1.1] - 2022-02-23

- Fix the `DOCTEST_XCOMPILE` environment variable.

## [1.1.0] - 2022-02-22

- Support binfmt. This allows running the cross-compiled binaries directly. ([#3](https://github.com/taiki-e/setup-cross-toolchain-action/pull/3))

- Set the `DOCTEST_XCOMPILE` environment variable to easily run cross-testing of doctest. ([#3](https://github.com/taiki-e/setup-cross-toolchain-action/pull/3))

- Add `runner` input option. ([#3](https://github.com/taiki-e/setup-cross-toolchain-action/pull/3))

## [1.0.0] - 2022-02-20

Initial release

[Unreleased]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.12.0...HEAD
[1.12.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.11.2...v1.12.0
[1.11.2]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.11.1...v1.11.2
[1.11.1]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.11.0...v1.11.1
[1.11.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.6.2...v1.7.0
[1.6.2]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/taiki-e/setup-cross-toolchain-action/releases/tag/v1.0.0
