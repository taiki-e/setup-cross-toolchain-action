# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

- setup-cross-toolchain-action no longer set QEMU_CPU for 32-bit ARM targets.

  It was causing problems when running tests that create many threads.

## [1.6.2] - 2023-03-12

- Fix linker error for wasm32-wasi on Rust 1.68+.

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

[Unreleased]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.6.2...HEAD
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
