# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

- Support aarch64_be-unknown-linux-gnu and riscv32gc-unknown-linux-gnu.

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

[Unreleased]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/taiki-e/setup-cross-toolchain-action/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/taiki-e/setup-cross-toolchain-action/releases/tag/v1.0.0
