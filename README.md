# setup-cross-toolchain-action

[![build status](https://img.shields.io/github/workflow/status/taiki-e/setup-cross-toolchain-action/CI/main?style=flat-square&logo=github)](https://github.com/taiki-e/setup-cross-toolchain-action/actions)

GitHub Action for setup toolchains for cross compilation and cross testing for Rust.

- [Usage](#usage)
  - [Inputs](#inputs)
  - [Example workflow: Basic usage](#example-workflow-basic-usage)
  - [Example workflow: Multiple targets](#example-workflow-multiple-targets)
  - [Example workflow: Doctest](#example-workflow-doctest)
- [Platform Support](#platform-support)
  - [Linux (GNU)](#linux-gnu)
- [Related Projects](#related-projects)
- [License](#license)

## Usage

### Inputs

| Name     | Required | Description   | Type   | Default        |
|----------|:--------:|---------------|--------|----------------|
| target   | **true** | Target triple | String |                |
| runner   | false    | Test runner   | String |                |

### Example workflow: Basic usage

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Rust
        run: rustup update stable
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: aarch64-unknown-linux-gnu
      # setup-cross-toolchain-action sets the `CARGO_BUILD_TARGET` environment variable,
      # so there is no need for an explicit `--target` flag.
      - run: cargo test --verbose
      # `cargo run` also works.
      - run: cargo run --verbose
      # You can also run the cross-compiled binaries directly.
      - run: ./target/aarch64-unknown-linux-gnu/debug/my-app
```

### Example workflow: Multiple targets

```yaml
jobs:
  test:
    strategy:
      matrix:
        target:
          - aarch64-unknown-linux-gnu
          - riscv64gc-unknown-linux-gnu
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Rust
        run: rustup update stable
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: ${{ matrix.target }}
      - run: cargo test --verbose
```

### Example workflow: Doctest

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Rust
        run: rustup update nightly && rustup default nightly
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: aarch64-unknown-linux-gnu
      - run: cargo test --verbose -Z doctest-xcompile
```

Cross-testing of doctest is currently available only on nightly.
If you want to use stable and nightly in the same matrix, you can use the `DOCTEST_XCOMPILE` environment variable set by this action to enable doctest only in nightly.

```yaml
jobs:
  test:
    strategy:
      matrix:
        rust:
          - stable
          - nightly
        target:
          - aarch64-unknown-linux-gnu
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Rust
        run: rustup update ${{ matrix.rust }} && rustup default ${{ matrix.rust }}
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: ${{ matrix.target }}
      # On nightly and `-Z doctest-xcompile` is available,
      # `$DOCTEST_XCOMPILE` is `-Zdoctest-xcompile`.
      #
      # On stable, `$DOCTEST_XCOMPILE` is not set.
      # Once `-Z doctest-xcompile` is stabilized, the corresponding flag
      # will be set to `$DOCTEST_XCOMPILE` (if it is available).
      - run: cargo test --verbose $DOCTEST_XCOMPILE
```

## Platform Support

### Linux (GNU)

| C++ | test |
| --- | ---- |
| ✓ (libstdc++) | ✓ |

**Supported targets**:

| target                                         | host                                                                       | runner                      |
| ---------------------------------------------- | -------------------------------------------------------------------------- | --------------------------- |
| `aarch64-unknown-linux-gnu`                    | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `aarch64_be-unknown-linux-gnu` (tier3)         | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-18.04/ubuntu-22.04 [4]      | qemu-user (default)         |
| `arm-unknown-linux-gnueabi`                    | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `armv5te-unknown-linux-gnueabi`                | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `armv7-unknown-linux-gnueabi`                  | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `armv7-unknown-linux-gnueabihf`                | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `i586-unknown-linux-gnu`                       | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default), native |
| `i686-unknown-linux-gnu`                       | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | native (default), qemu-user |
| `mips-unknown-linux-gnu`                       | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-18.04 [2], ubuntu-22.04 [3] | qemu-user (default)         |
| `mips64-unknown-linux-gnuabi64`                | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-18.04 [2], ubuntu-22.04 [3] | qemu-user (default)         |
| `mips64el-unknown-linux-gnuabi64`              | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `mipsel-unknown-linux-gnu`                     | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `mipsisa32r6-unknown-linux-gnu` (tier3)        | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-22.04 [3]                   | qemu-user (default) [6]     |
| `mipsisa32r6el-unknown-linux-gnu` (tier3)      | ubuntu-latest/ubuntu-20.04 [1], ubuntu-22.04 [3]                           | qemu-user (default) [6]     |
| `mipsisa64r6-unknown-linux-gnuabi64` (tier3)   | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-22.04 [3]                   | qemu-user (default)         |
| `mipsisa64r6el-unknown-linux-gnuabi64` (tier3) | ubuntu-latest/ubuntu-20.04 [1], ubuntu-22.04 [3]                           | qemu-user (default)         |
| `powerpc-unknown-linux-gnu`                    | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `powerpc64-unknown-linux-gnu`                  | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-18.04 [2], ubuntu-22.04 [3] | qemu-user (default)         |
| `powerpc64le-unknown-linux-gnu`                | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `riscv32gc-unknown-linux-gnu`                  | ubuntu-latest/ubuntu-20.04/ubuntu-18.04/ubuntu-22.04 [5]                   | qemu-user (default)         |
| `riscv64gc-unknown-linux-gnu`                  | ubuntu-latest/ubuntu-20.04 [1] <!--, ubuntu-18.04 [2]-->, ubuntu-22.04 [3] | qemu-user (default)         |
| `s390x-unknown-linux-gnu`                      | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `sparc64-unknown-linux-gnu`                    | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-18.04 [2], ubuntu-22.04 [3] | qemu-user (default)         |
| `thumbv7neon-unknown-linux-gnueabihf`          | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | qemu-user (default)         |
| `x86_64-unknown-linux-gnu`                     | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | native (default), qemu-user |
| `x86_64-unknown-linux-musl`                    | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2], ubuntu-22.04 [3]         | native (default), qemu-user |

[1] GCC 9, glibc 2.31<br>
[2] GCC 7, glibc 2.27<br>
[3] GCC 11, glibc 2.35<br>
[4] GCC 10, glibc 2.31<br>
[5] GCC 11, glibc 2.33<br>
[6] binfmt doesn't work<br>

## Related Projects

- [rust-cross-toolchain]: Toolchains for cross compilation and cross testing for Rust.
- [install-action]: GitHub Action for installing development tools.
- [create-gh-release-action]: GitHub Action for creating GitHub Releases based on changelog.
- [upload-rust-binary-action]: GitHub Action for building and uploading Rust binary to GitHub Releases.

[create-gh-release-action]: https://github.com/taiki-e/create-gh-release-action
[install-action]: https://github.com/taiki-e/install-action
[rust-cross-toolchain]: https://github.com/taiki-e/rust-cross-toolchain
[upload-rust-binary-action]: https://github.com/taiki-e/upload-rust-binary-action

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
