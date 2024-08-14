# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

- Add `packages` input to install additional packages that can be build against. ([#23](https://github.com/taiki-e/setup-cross-toolchain-action/pull/23))

## [1.23.1] - 2024-08-11

- Fix build issue with 32-bit android targets on recent nightly due to [upstream change](https://github.com/rust-lang/rust/pull/120593). ([2068a2d](https://github.com/taiki-e/setup-cross-toolchain-action/commit/2068a2dd8a68fdcf653e4fa1312cbe24475ff07b))

## [1.23.0] - 2024-07-12

- Support x86_64-unknown-illumos (build-only). ([#22](https://github.com/taiki-e/setup-cross-toolchain-action/pull/22), thanks @zeeshanlakhani)

- Update the default QEMU version from 8.2 to 9.0.

## [1.22.0] - 2024-06-01

- Partially support `/system/bin/sh` on Android.

## [1.21.1] - 2024-05-03

- Document support status for ubuntu-24.04.

## [1.21.0] - 2024-04-13

- Support containers.

  Note:
  - Only Ubuntu and Debian containers are currently supported.
  - Not fully supported for some targets.
  - `--privileged` option is currently required (due to binfmt).

    ```yaml
    container:
      image: '...'
      options: --privileged
    ```

- Improve robustness of installation.

## [1.20.0] - 2024-01-25

- Update the default Wine version from 8.0 to 9.0.

## [1.19.0] - 2024-01-25

- Update the default QEMU version from 8.1 to 8.2.

## [1.18.0] - 2023-09-22

- Support i686-pc-windows-gnullvm.
- Support sparc-unknown-linux-gnu (experimental).

## [1.17.0] - 2023-08-24

- Update the default QEMU version from 8.0 to 8.1.

## [1.16.0] - 2023-08-11

- Support specifying the QEMU version by using `qemu` input option, or `@` syntax in `runner` input option (if both are set, the latter is preferred).

  For example:

  ```yaml
  - uses: taiki-e/setup-cross-toolchain-action@v1
    with:
      target: aarch64-unknown-linux-gnu
      qemu: '7.2'
  ```

  ```yaml
  - uses: taiki-e/setup-cross-toolchain-action@v1
    with:
      target: aarch64-unknown-linux-gnu
      runner: qemu@8.1
  ```

- Support specifying the Wine version by using `wine` input option. Previously only `@` syntax in `runner` input option was supported.

- Update the default Wine version to 8.0.0, which is the latest stable version.

## [1.15.0] - 2023-08-02

- Support windows-gnullvm targets on Linux host.

  - aarch64-pc-windows-gnullvm
  - x86_64-pc-windows-gnullvm

  Running tests is supported on both targets.

## [1.14.0] - 2023-07-28

- Support Windows targets on Windows host.

  - aarch64-pc-windows-msvc (build-only)
  - i586-pc-windows-msvc
  - i686-pc-windows-msvc
  - x86_64-pc-windows-msvc
  - x86_64-pc-windows-gnu

  GitHub-provided Windows runners support cross-compile for other architectures or environments, so this action just runs `rustup target add` and/or sets some environment variables.

  (Other Windows targets may also work, although this action's CI has not tested them.)

## [1.13.0] - 2023-07-28

- Support running WASI and Windows binaries directly on Linux host (via binfmt).

- Support Android targets. ([#13](https://github.com/taiki-e/setup-cross-toolchain-action/pull/13))

  All builtin Android targets are now supported:

  - aarch64-linux-android
  - arm-linux-androideabi
  - armv7-linux-androideabi
  - i686-linux-android
  - thumbv7neon-linux-androideabi
  - x86_64-linux-android

- Support linux-uclibc targets. ([#13](https://github.com/taiki-e/setup-cross-toolchain-action/pull/13))

  All builtin linux-uclibc targets are now supported:

  - armv5te-unknown-linux-uclibceabi
  - armv7-unknown-linux-uclibceabi
  - armv7-unknown-linux-uclibceabihf
  - mips-unknown-linux-uclibc
  - mipsel-unknown-linux-uclibc

- Set `BINDGEN_EXTRA_CLANG_ARGS_<target>` environment variable.

## [1.12.1] - 2023-07-28

- Work around LLVM installation failure. ([#15](https://github.com/taiki-e/setup-cross-toolchain-action/issues/15))

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

[Unreleased]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.23.1...HEAD
[1.23.1]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.23.0...v1.23.1
[1.23.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.22.0...v1.23.0
[1.22.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.21.1...v1.22.0
[1.21.1]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.21.0...v1.21.1
[1.21.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.20.0...v1.21.0
[1.20.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.19.0...v1.20.0
[1.19.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.18.0...v1.19.0
[1.18.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.17.0...v1.18.0
[1.17.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.16.0...v1.17.0
[1.16.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.15.0...v1.16.0
[1.15.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.12.1...v1.13.0
[1.12.1]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.12.0...v1.12.1
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
